// Cloud Functions entry point.
//
// Exports:
//   onRevenueCatWebhook — HTTP endpoint called by RevenueCat after subscription events.
//   askCarAi           — HTTPS proxy for Anthropic API (API key never leaves the server).
//
// Deploy:
//   firebase deploy --only functions
//
// Environment secrets:
//   REVENUECAT_WEBHOOK_SECRET  — set via: firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET
//   ANTHROPIC_API_KEY          — set via: firebase functions:secrets:set ANTHROPIC_API_KEY

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
import type { ShopSubscriptionUpdate } from "./types";
export { onNewsletterSend } from "./sendNewsletter";
export { askCarAi } from "./askCarAi";
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

