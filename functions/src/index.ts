// Cloud Functions entry point.
//
// Exports:
//   onRevenueCatWebhook — HTTP endpoint called by RevenueCat after subscription events.
//   askCarAi           — HTTPS proxy for Anthropic API (API key never leaves the server).
//   onPlanRequestCreated — 店舗プランの申し込みを運営者にメールで知らせる。
//   onInspectionNoticeCreated — 店からアプリ利用者へ車検案内のプッシュを送る。
//
// Deploy:
//   firebase deploy --only functions
//
// Environment secrets:
//   REVENUECAT_WEBHOOK_SECRET  — set via: firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET
//   ANTHROPIC_API_KEY          — set via: firebase functions:secrets:set ANTHROPIC_API_KEY
//   SENDGRID_API_KEY           — set via: firebase functions:secrets:set SENDGRID_API_KEY
//   OPERATOR_EMAIL             — 運営者の宛先。set via: firebase functions:secrets:set OPERATOR_EMAIL

import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import { handleWebhook } from "./webhook";
import {
  handleReportCreated,
  type CommentReportData,
  type ModerationTarget,
  type ModerationUpdate,
} from "./moderateComments";
import {
  handlePlanRequestCreated,
  type OperatorMail,
  type PlanRequestData,
} from "./notifyPlanRequest";
import {
  handleInspectionNoticeCreated,
  invalidTokensFrom,
  isNoticedForCurrentExpiry,
  type LedgerVehicleData,
  type NoticeRequestData,
  type VehicleClaim,
} from "./inspectionNotice";
import type { ShopSubscriptionUpdate } from "./types";
export { onNewsletterSend } from "./sendNewsletter";
export { askCarAi } from "./askCarAi";
import {
  buildAllReports,
  classifyType,
  type CostEvent,
  type CostVehicle,
} from "./modelCostReport";
import {
  handleScheduledPurge,
  isDue,
  type DeletionMarker,
} from "./purgeDeletedAccounts";

admin.initializeApp();

const revenueCatWebhookSecret = defineSecret("REVENUECAT_WEBHOOK_SECRET");

/**
 * Writes subscription state to Firestore.
 * Only Cloud Functions (running as service account) can write
 * subscriptionStatus / planType — enforced by firestore.rules.
 */
async function updateShopSubscription(
  shopId: string,
  data: ShopSubscriptionUpdate
): Promise<void> {
  const db = admin.firestore();
  const ref = db.collection("shops").doc(shopId);

  await ref.update({
    subscriptionStatus: data.subscriptionStatus,
    planType: data.planType,
    revenueCatUserId: data.revenueCatUserId,
    subscriptionExpiresAt:
      data.subscriptionExpiresAt !== null
        ? admin.firestore.Timestamp.fromDate(data.subscriptionExpiresAt)
        : null,
    updatedAt: admin.firestore.Timestamp.fromDate(data.updatedAt),
  });
}

/**
 * HTTP Cloud Function — RevenueCat webhook receiver.
 *
 * RevenueCat Configuration:
 *   URL: https://<region>-trust-car-platform.cloudfunctions.net/onRevenueCatWebhook
 *   Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>
 */
export const onRevenueCatWebhook = onRequest(
  { secrets: [revenueCatWebhookSecret], region: "asia-northeast1" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const result = await handleWebhook(
      req.headers.authorization,
      req.body,
      revenueCatWebhookSecret.value(),
      updateShopSubscription
    );

    res.status(result.status).json({ message: result.message });
  }
);

/**
 * Counts the authoritative number of distinct reports for a comment.
 * Uses a Firestore aggregation (count) query — cheap and race-free.
 */
async function countCommentReports(target: ModerationTarget): Promise<number> {
  const db = admin.firestore();
  // Single equality filter on the (globally unique) Firestore comment id — no
  // composite index required. showcaseId is carried on the target only to
  // locate the comment doc for the write.
  const snap = await db
    .collection("comment_reports")
    .where("commentId", "==", target.commentId)
    .count()
    .get();
  return snap.data().count;
}

/**
 * Writes the server-computed moderation fields onto the comment document.
 * Only Cloud Functions (service account) may set reportCount / isHidden —
 * enforced by firestore.rules.
 */
async function applyCommentModeration(
  target: ModerationTarget,
  update: ModerationUpdate
): Promise<void> {
  const db = admin.firestore();
  await db
    .collection("accessory_showcases")
    .doc(target.showcaseId)
    .collection("comments")
    .doc(target.commentId)
    .update({
      reportCount: update.reportCount,
      isHidden: update.isHidden,
    });
}

/**
 * Firestore-triggered Cloud Function — comment moderation.
 *
 * Fires when a user files a report (comment_reports/{reportId}). Re-counts the
 * reports server-side and writes reportCount / isHidden back to the comment, so
 * clients can no longer forge the moderation state.
 */
export const onCommentReportCreated = onDocumentCreated(
  { document: "comment_reports/{reportId}", region: "asia-northeast1" },
  async (event) => {
    const data = event.data?.data() as CommentReportData | undefined;
    if (!data) return;

    try {
      await handleReportCreated(data, {
        countReports: countCommentReports,
        updateComment: applyCommentModeration,
      });
    } catch (err) {
      // A missing comment (already deleted) or transient error must not crash
      // the function; the report doc is still retained for manual moderation.
      console.error("Comment moderation failed:", err);
    }
  }
);

const sendgridApiKey = defineSecret("SENDGRID_API_KEY");
// 運営者の宛先。公開リポジトリに書かないため Secret Manager に置く
const operatorEmail = defineSecret("OPERATOR_EMAIL");

/**
 * Firestore-triggered Cloud Function — 店舗プランの申し込みの通知。
 *
 * 店主が shops/{shopId}/plan_requests/{requestId} を作ったら、運営者に
 * SendGrid でメールを送る。処理の中身は notifyPlanRequest.ts。
 *
 * 二重送信の防止: 送る前に申し込みの文書へ operatorNotification を
 * トランザクションで書き、既にあれば送らない（再試行・重複配信の両方に効く）。
 * retry: true なので、SendGrid の一時的な失敗は Cloud Functions が再試行する。
 */
export const onPlanRequestCreated = onDocumentCreated(
  {
    document: "shops/{shopId}/plan_requests/{requestId}",
    region: "asia-northeast1",
    secrets: [sendgridApiKey, operatorEmail],
    retry: true,
  },
  async (event) => {
    const { shopId, requestId } = event.params;
    const db = admin.firestore();
    const ref = db.doc(`shops/${shopId}/plan_requests/${requestId}`);

    await handlePlanRequestCreated(
      {
        shopId,
        requestId,
        eventId: event.id,
        eventTime: new Date(event.time),
        data: event.data?.data() as PlanRequestData | undefined,
      },
      {
        operatorEmail: () => operatorEmail.value(),
        loadShopName: async (id) => {
          const shop = await db.collection("shops").doc(id).get();
          const name = shop.data()?.name;
          return typeof name === "string" ? name : null;
        },
        claim: (eventId) =>
          db.runTransaction(async (tx) => {
            const snap = await tx.get(ref);
            if (!snap.exists || snap.get("operatorNotification") != null) {
              return "already" as const;
            }
            tx.update(ref, {
              operatorNotification: {
                state: "sending",
                eventId,
                claimedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
            });
            return "claimed" as const;
          }),
        release: async () => {
          await ref.update({
            operatorNotification: admin.firestore.FieldValue.delete(),
          });
        },
        markSent: async () => {
          await ref.update({
            "operatorNotification.state": "sent",
            "operatorNotification.sentAt":
              admin.firestore.FieldValue.serverTimestamp(),
          });
        },
        markFailed: async (message) => {
          await ref.update({
            "operatorNotification.state": "failed",
            "operatorNotification.error": message,
            "operatorNotification.failedAt":
              admin.firestore.FieldValue.serverTimestamp(),
          });
        },
        send: async (mail: OperatorMail) => {
          // sendNewsletter.ts と同じく @sendgrid/mail を使う
          // eslint-disable-next-line @typescript-eslint/no-var-requires
          const sgMail = require("@sendgrid/mail");
          sgMail.setApiKey(sendgridApiKey.value());
          await sgMail.send(mail);
        },
      }
    );
  }
);

/**
 * Firestore-triggered Cloud Function — 店からアプリ利用者への車検案内（プッシュ）。
 *
 * 店のスタッフが shops/{shopId}/inspection_notices/{noticeId} を置いたら、
 * 車ごとに台帳のつながり・利用者の通知設定・案内済みかを確かめて FCM で送り、
 * 送れた車に「案内した日」を付ける。処理の中身は inspectionNotice.ts。
 *
 * retry は付けない。車ごとに「案内した日」を先に付けてから送るので、
 * 途中で落ちても二重には送らない（届かなかった車は案内した日を戻す）。
 * 失敗は依頼の文書の status: failed で画面に出る。
 */
export const onInspectionNoticeCreated = onDocumentCreated(
  {
    document: "shops/{shopId}/inspection_notices/{noticeId}",
    region: "asia-northeast1",
  },
  async (event) => {
    const { shopId, noticeId } = event.params;
    const db = admin.firestore();
    const shopRef = db.collection("shops").doc(shopId);
    const ref = shopRef.collection("inspection_notices").doc(noticeId);
    const vehicleRef = (id: string) =>
      shopRef.collection("customer_vehicles").doc(id);

    await handleInspectionNoticeCreated(
      {
        shopId,
        noticeId,
        eventId: event.id,
        data: event.data?.data() as NoticeRequestData | undefined,
      },
      {
        claimRequest: (eventId) =>
          db.runTransaction(async (tx) => {
            const snap = await tx.get(ref);
            if (!snap.exists || snap.get("delivery") != null) {
              return "already" as const;
            }
            tx.update(ref, {
              delivery: {
                state: "sending",
                eventId,
                claimedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
            });
            return "claimed" as const;
          }),
        loadShopName: async () => {
          const name = (await shopRef.get()).data()?.name;
          return typeof name === "string" ? name : null;
        },
        loadVehicle: async (id) => {
          const snap = await vehicleRef(id).get();
          return snap.exists ? (snap.data() as LedgerVehicleData) : null;
        },
        loadCustomer: async (id) => {
          const snap = await shopRef.collection("customers").doc(id).get();
          return snap.exists ? (snap.data() ?? null) : null;
        },
        loadLinkShopId: async (uid) => {
          const shop = (await db.collection("shop_customers").doc(uid).get())
            .data()?.shopId;
          return typeof shop === "string" ? shop : null;
        },
        loadUser: async (uid) => {
          const snap = await db.collection("users").doc(uid).get();
          return snap.exists ? (snap.data() ?? null) : null;
        },
        claimVehicles: (ids, now) =>
          db.runTransaction(async (tx) => {
            const snaps = await Promise.all(ids.map((id) => tx.get(vehicleRef(id))));
            const claims: VehicleClaim[] = [];
            for (const snap of snaps) {
              if (!snap.exists) continue;
              const v = snap.data() as LedgerVehicleData;
              if (isNoticedForCurrentExpiry(v) || !v.inspectionExpiry) continue;
              claims.push({
                id: snap.id,
                prevNoticeAt: v.inspectionNoticeAt ?? null,
                prevNoticeExpiry: v.inspectionNoticeExpiry ?? null,
              });
              tx.update(snap.ref, {
                inspectionNoticeAt: admin.firestore.Timestamp.fromDate(now),
                inspectionNoticeExpiry: v.inspectionExpiry,
              });
            }
            return claims;
          }),
        releaseVehicles: async (claims) => {
          const batch = db.batch();
          for (const c of claims) {
            batch.update(vehicleRef(c.id), {
              inspectionNoticeAt:
                c.prevNoticeAt ?? admin.firestore.FieldValue.delete(),
              inspectionNoticeExpiry:
                c.prevNoticeExpiry ?? admin.firestore.FieldValue.delete(),
            });
          }
          await batch.commit();
        },
        send: async (tokens, message) => {
          const res = await admin.messaging().sendEachForMulticast({
            tokens,
            notification: { title: message.title, body: message.body },
            data: message.data,
            android: {
              priority: "high",
              // アプリが作る通知チャンネル（push_notification_service.dart）
              notification: { channelId: "trust_car_high_importance" },
            },
            apns: { payload: { aps: { sound: "default" } } },
          });
          return {
            successCount: res.successCount,
            invalidTokens: invalidTokensFrom(tokens, res.responses),
          };
        },
        removeTokens: async (uid, tokens) => {
          await db.collection("users").doc(uid).update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokens),
          });
        },
        writeResult: async (status, result, error) => {
          await ref.update({
            status,
            result,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            "delivery.state": "finished",
            ...(error ? { error } : {}),
          });
        },
      }
    );
  }
);

/**
 * Scheduled Cloud Function — deleted-account purge.
 *
 * The client writes an account_deletions/{uid} marker on account deletion,
 * and the privacy policy promises the data is removed on withdrawal. This
 * job executes that promise nightly - there is no grace period, so a marker
 * written today is purged on the next run. Until it was added, the marker
 * was written but nothing ever deleted the data.
 */
export const purgeDeletedAccounts = onSchedule(
  { schedule: "every day 03:17", timeZone: "Asia/Tokyo",
    region: "asia-northeast1" },
  async () => {
    const db = admin.firestore();
    const bucket = admin.storage().bucket();
    const now = Date.now();

    const result = await handleScheduledPurge({
      listDueMarkers: async () => {
        const snap = await db
          .collection("account_deletions")
          .where("status", "==", "pending")
          .get();
        return snap.docs
          .filter((d) => isDue(d.data() as DeletionMarker, now))
          .map((d) => d.id);
      },
      deleteByUserId: async (collection, uid) => {
        const deleted: string[] = [];
        // 400 per batch: Firestore rejects batches above 500 writes.
        for (;;) {
          const snap = await db
            .collection(collection)
            .where("userId", "==", uid)
            .limit(400)
            .get();
          if (snap.empty) break;
          const batch = db.batch();
          for (const doc of snap.docs) {
            batch.delete(doc.ref);
            deleted.push(doc.id);
          }
          await batch.commit();
        }
        return deleted;
      },
      deleteSharesOf: async (uid) => {
        for (;;) {
          const snap = await db
            .collection("vehicle_sharing_permissions")
            .where("ownerId", "==", uid)
            .limit(200)
            .get();
          if (snap.empty) break;
          const batch = db.batch();
          for (const doc of snap.docs) {
            const { shopId, vehicleId } = doc.data() as {
              shopId?: string;
              vehicleId?: string;
            };
            if (shopId && vehicleId) {
              batch.delete(
                db.doc(`shops/${shopId}/shared_vehicles/${vehicleId}`)
              );
            }
            batch.delete(doc.ref);
          }
          await batch.commit();
        }
      },
      deleteWaypointsFor: async (driveLogIds) => {
        for (const driveLogId of driveLogIds) {
          for (;;) {
            const snap = await db
              .collection("drive_waypoints")
              .where("driveLogId", "==", driveLogId)
              .limit(400)
              .get();
            if (snap.empty) break;
            const batch = db.batch();
            snap.docs.forEach((doc) => batch.delete(doc.ref));
            await batch.commit();
          }
        }
      },
      deleteUserDoc: async (uid) => {
        await db.collection("users").doc(uid).delete();
      },
      deleteStoragePrefix: async (prefix) => {
        await bucket.deleteFiles({ prefix });
      },
      markCompleted: async (uid) => {
        await db.collection("account_deletions").doc(uid).update({
          status: "completed",
          purgedAt: admin.firestore.Timestamp.now(),
        });
      },
    });

    console.log(
      `Account purge: ${result.purgedUids.length} purged, ` +
        `${result.failedUids.length} failed` +
        (result.failedUids.length > 0
          ? ` (${result.failedUids.join(", ")})`
          : "")
    );
  }
);

function millis(v: unknown): number | undefined {
  if (v && typeof (v as { toMillis?: unknown }).toMillis === "function") {
    return (v as { toMillis(): number }).toMillis();
  }
  if (typeof v === "number") return v;
  return undefined;
}

function num(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? v : 0;
}

/**
 * Scheduled Cloud Function — 車種別の維持費レポート（docs/SHOP_CRM_DESIGN_2026-09-27.md §8）。
 *
 * 毎晩、アプリ利用者の整備・給油記録と、統計への利用に同意した店
 * （shops.allowsStatistics == true）の整備実績から、車種ごとの維持費を
 * 集計して model_cost_reports に書く。持ち主が5人に満たない車種は
 * 書かず、前回まで出ていたものは消す。
 *
 * 全件を読み直す作り。記録が数十万件になったら差分集計に変える
 * （目安: 8万件で読み取り約 $0.05/晩）。
 */
export const aggregateModelCosts = onSchedule(
  { schedule: "every day 04:07", timeZone: "Asia/Tokyo",
    region: "asia-northeast1", timeoutSeconds: 540, memory: "1GiB" },
  async () => {
    const db = admin.firestore();
    const now = Date.now();
    const vehicles: CostVehicle[] = [];
    const events: CostEvent[] = [];

    // 1. アプリ利用者
    const appVehicles = await db.collection("vehicles").get();
    const known = new Set<string>();
    for (const d of appVehicles.docs) {
      const v = d.data();
      if (!v.userId || !v.maker || !v.model) continue;
      known.add(d.id);
      vehicles.push({
        key: `u:${d.id}`,
        ownerKey: `u:${v.userId}`,
        maker: String(v.maker),
        model: String(v.model),
        year: typeof v.year === "number" && v.year > 1900 ? v.year : undefined,
        retiredAt: millis(v.retiredAt),
        source: "app",
      });
    }
    for (const d of (await db.collection("maintenance_records").get()).docs) {
      const r = d.data();
      const date = millis(r.date);
      if (!known.has(r.vehicleId) || date === undefined) continue;
      const type = String(r.type ?? "");
      events.push({
        vehicleKey: `u:${r.vehicleId}`,
        date,
        cost: num(r.cost),
        kind: classifyType(type),
        type: String(r.title || type),
      });
    }
    for (const d of (await db.collection("fuel_records").get()).docs) {
      const r = d.data();
      const date = millis(r.date);
      if (!known.has(r.vehicleId) || date === undefined) continue;
      events.push({
        vehicleKey: `u:${r.vehicleId}`,
        date,
        cost: num(r.cost),
        kind: "fuel",
        type: "給油",
      });
    }

    // 2. 統計への利用に同意した店の整備実績
    const shops = await db
      .collection("shops")
      .where("allowsStatistics", "==", true)
      .get();
    for (const shop of shops.docs) {
      const shopVehicles = await shop.ref.collection("customer_vehicles").get();
      const shopKnown = new Set<string>();
      for (const d of shopVehicles.docs) {
        const v = d.data();
        if (!v.maker || !v.model || !v.customerId) continue;
        shopKnown.add(d.id);
        vehicles.push({
          key: `s:${shop.id}:${d.id}`,
          ownerKey: `s:${shop.id}:${v.customerId}`,
          maker: String(v.maker),
          model: String(v.model),
          year: typeof v.year === "number" && v.year > 1900 ? v.year : undefined,
          source: "shop",
        });
      }
      for (const d of (await shop.ref.collection("service_records").get()).docs) {
        const r = d.data();
        const date = millis(r.date);
        if (!shopKnown.has(r.customerVehicleId) || date === undefined) continue;
        const type = String(r.type ?? "");
        events.push({
          vehicleKey: `s:${shop.id}:${r.customerVehicleId}`,
          date,
          cost: num(r.totalCost),
          kind: classifyType(type),
          type: type || "整備",
        });
      }
    }

    const reports = buildAllReports(vehicles, events, now);
    const col = db.collection("model_cost_reports");
    const keep = new Set(reports.map((r) => r.id));
    const updatedAt = admin.firestore.Timestamp.fromMillis(now);

    for (let i = 0; i < reports.length; i += 400) {
      const batch = db.batch();
      for (const r of reports.slice(i, i + 400)) {
        batch.set(col.doc(r.id), { ...r, updatedAt });
      }
      await batch.commit();
    }
    // 持ち主が足りなくなった車種は消す（古い数字を出し続けない）
    const existing = await col.listDocuments();
    const stale = existing.filter((ref) => !keep.has(ref.id));
    for (let i = 0; i < stale.length; i += 400) {
      const batch = db.batch();
      stale.slice(i, i + 400).forEach((ref) => batch.delete(ref));
      await batch.commit();
    }

    console.log(
      `Model cost reports: ${reports.length} written, ${stale.length} removed ` +
        `(${vehicles.length} vehicles, ${events.length} events, ` +
        `${shops.size} shops)`
    );
  }
);

/**
 * Scheduled Cloud Function — 期限の過ぎた「車の写し」を消す。
 *
 * ユーザーが店に渡す写し（shops/{id}/shared_vehicles）は期限つき。
 * 画面では期限切れを出していないが、期限を約束している以上、
 * データも残さない。索引（vehicle_sharing_permissions）も一緒に消す。
 */
export const purgeExpiredShares = onSchedule(
  { schedule: "every day 03:37", timeZone: "Asia/Tokyo",
    region: "asia-northeast1" },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    let removed = 0;
    for (const shop of (await db.collection("shops").get()).docs) {
      const expired = await shop.ref
        .collection("shared_vehicles")
        .where("expiresAt", "<=", now)
        .get();
      if (expired.empty) continue;
      const batch = db.batch();
      for (const d of expired.docs) {
        batch.delete(d.ref);
        batch.delete(
          db.doc(`vehicle_sharing_permissions/${d.id}_${shop.id}`)
        );
        removed++;
      }
      await batch.commit();
    }
    console.log(`Expired vehicle shares: ${removed} removed`);
  }
);
