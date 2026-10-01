// アプリを使っているお客さんへの車検案内（プッシュ通知）。
// 2026-09-29 プロダクト評価 #2 の「アプリ有り」の側。
//
// 店のスタッフが shops/{shopId}/inspection_notices/{noticeId} に「この車の
// 持ち主に案内を送って」と置く（lib/services/inspection_push_service.dart）。
// ここで車ごとに確かめてから送る。
//
// - 台帳の車がある・満了日が案内の時期（今日の前日〜MAX_DAYS_AHEAD 日先）
// - いまの満了日で、まだ案内していない（はがきの書き出しと同じ「案内した日」
//   inspectionNoticeAt / inspectionNoticeExpiry を見る。二重に送らない）
// - 台帳の顧客がアプリの利用者とつながっていて（linkedUserId）、その利用者の
//   札（shop_customers/{uid}）もこの店を指している（つながりを利用者が
//   外していたら送らない）
// - 利用者が通知を切っていない（notificationSettings.pushEnabled と
//   carInspectionReminder。lib/models/user.dart の NotificationSettings）
// - 利用者の端末が登録されている（users/{uid}.fcmTokens。
//   lib/services/fcm_token_service.dart が書く）
//
// 送る前に車ごとに「案内した日」をトランザクションで付けて（引き受け）、
// 1台の端末にも届かなかったら元に戻す。同じ車が別の依頼に入っていても、
// 先に引き受けた方だけが送る。届かなくなったトークンは users から外す。
//
// 依頼の文書にも「処理を引き受けた」印（delivery）を書くので、同じイベントが
// 二度届いても二度は処理しない。結果（台数）は依頼の文書に書く。
//
// Firebase のトリガー本体は index.ts。ここは依存を差し込める純粋な処理だけ。

/** Firestore の Timestamp（toDate を持つ）。 */
export interface TimestampLike {
  toDate(): Date;
}

/** 依頼の文書（lib/models/inspection_push_request.dart と同じ形）。 */
export interface NoticeRequestData {
  requesterUid?: string;
  vehicleIds?: unknown;
  status?: string;
  createdAt?: TimestampLike | null;
}

/** 台帳の車（shops/{shopId}/customer_vehicles/{id}）のうち、使うところ。 */
export interface LedgerVehicleData {
  customerId?: unknown;
  maker?: unknown;
  model?: unknown;
  inspectionExpiry?: TimestampLike | null;
  inspectionNoticeAt?: TimestampLike | null;
  inspectionNoticeExpiry?: TimestampLike | null;
}

/** 台帳の顧客のうち、使うところ。 */
export interface LedgerCustomerData {
  linkedUserId?: unknown;
}

/** 利用者（users/{uid}）のうち、使うところ。 */
export interface LinkedUserData {
  fcmTokens?: unknown;
  notificationSettings?: {
    pushEnabled?: unknown;
    carInspectionReminder?: unknown;
  } | null;
}

/** 送った結果（台数）。lib/models/inspection_push_request.dart の InspectionPushResult と同じ。 */
export interface NoticeResult {
  sent: number;
  alreadyNoticed: number;
  notLinked: number;
  pushOff: number;
  noDevice: number;
  outOfRange: number;
  notFound: number;
  failed: number;
}

/** 引き受けた車と、元に戻すための前の値。 */
export interface VehicleClaim {
  id: string;
  prevNoticeAt: TimestampLike | null;
  prevNoticeExpiry: TimestampLike | null;
}

/** 送る通知の中身。 */
export interface PushMessage {
  title: string;
  body: string;
  data: Record<string, string>;
}

/** 1人の端末に送った結果。 */
export interface SendOutcome {
  successCount: number;
  /** もう届かないトークン（アプリを消した等）。users から外す。 */
  invalidTokens: string[];
}

export type ClaimResult = "claimed" | "already";

/** 差し込む副作用（テストでは差し替える）。 */
export interface NoticeDeps {
  /** 依頼の文書に「処理を引き受けた」印をトランザクションで書く。 */
  claimRequest: (eventId: string) => Promise<ClaimResult>;
  loadShopName: () => Promise<string | null>;
  loadVehicle: (vehicleId: string) => Promise<LedgerVehicleData | null>;
  loadCustomer: (customerId: string) => Promise<LedgerCustomerData | null>;
  /** shop_customers/{uid}.shopId。札が無ければ null。 */
  loadLinkShopId: (uid: string) => Promise<string | null>;
  loadUser: (uid: string) => Promise<LinkedUserData | null>;
  /**
   * 車に「案内した日」を付けて引き受ける（トランザクション）。いまの満了日で
   * 案内済みの車・消えた車は引き受けない。引き受けた車だけを返す。
   */
  claimVehicles: (vehicleIds: string[], now: Date) => Promise<VehicleClaim[]>;
  /** 届かなかったので、案内した日を元に戻す。 */
  releaseVehicles: (claims: VehicleClaim[]) => Promise<void>;
  send: (tokens: string[], message: PushMessage) => Promise<SendOutcome>;
  removeTokens: (uid: string, tokens: string[]) => Promise<void>;
  writeResult: (
    status: "done" | "failed",
    result: NoticeResult,
    error?: string
  ) => Promise<void>;
}

/** 1回の依頼で扱う車の上限（firestore.rules の validInspectionNotice と同じ）。 */
export const MAX_VEHICLES = 200;

/** 満了日がこれより先の車には送らない（日）。画面は最長3か月。 */
export const MAX_DAYS_AHEAD = 100;

const DAY_MS = 24 * 60 * 60 * 1000;
const JST_OFFSET_MS = 9 * 60 * 60 * 1000;

export function emptyResult(): NoticeResult {
  return {
    sent: 0,
    alreadyNoticed: 0,
    notLinked: 0,
    pushOff: 0,
    noDevice: 0,
    outOfRange: 0,
    notFound: 0,
    failed: 0,
  };
}

/** 日本時間の日付（2026-10-01）。台帳の日付は日本の日付で比べる。 */
export function jstDateKey(d: Date): string {
  return new Date(d.getTime() + JST_OFFSET_MS).toISOString().slice(0, 10);
}

/** 「10月20日」。 */
export function jstMonthDay(d: Date): string {
  const j = new Date(d.getTime() + JST_OFFSET_MS);
  return `${j.getUTCMonth() + 1}月${j.getUTCDate()}日`;
}

function toDate(v: TimestampLike | null | undefined): Date | null {
  if (!v || typeof v.toDate !== "function") return null;
  const d = v.toDate();
  return d instanceof Date && !Number.isNaN(d.getTime()) ? d : null;
}

/**
 * いまの満了日について、もう案内を出したか
 * （lib/models/shop_ledger.dart の isNoticedForCurrentExpiry と同じ判定）。
 */
export function isNoticedForCurrentExpiry(v: LedgerVehicleData): boolean {
  const expiry = toDate(v.inspectionExpiry);
  const noticed = toDate(v.inspectionNoticeExpiry);
  if (!expiry || !noticed || !toDate(v.inspectionNoticeAt)) return false;
  return jstDateKey(expiry) === jstDateKey(noticed);
}

/** 満了日が案内の時期か（今日の前日〜MAX_DAYS_AHEAD 日先）。 */
export function isInNoticeWindow(v: LedgerVehicleData, now: Date): boolean {
  const expiry = toDate(v.inspectionExpiry);
  if (!expiry) return false;
  const t = expiry.getTime();
  return t >= now.getTime() - DAY_MS && t <= now.getTime() + MAX_DAYS_AHEAD * DAY_MS;
}

/** 利用者が車検の通知を受け取る設定か。設定が無ければ受け取る（アプリの既定と同じ）。 */
export function wantsInspectionPush(user: LinkedUserData): boolean {
  const s = user.notificationSettings;
  if (!s) return true;
  return s.pushEnabled !== false && s.carInspectionReminder !== false;
}

/** 文字列のトークンだけを、重ならないように。 */
export function tokensOf(user: LinkedUserData): string[] {
  const raw = Array.isArray(user.fcmTokens) ? user.fcmTokens : [];
  return [...new Set(raw.filter((t): t is string => typeof t === "string" && t.length > 0))];
}

/** 依頼の vehicleIds から、使える ID だけを（重ねず・上限まで）。 */
export function vehicleIdsOf(data: NoticeRequestData): string[] {
  const raw = Array.isArray(data.vehicleIds) ? data.vehicleIds : [];
  const ids = raw.filter(
    (v): v is string => typeof v === "string" && v.length > 0 && !v.includes("/")
  );
  return [...new Set(ids)].slice(0, MAX_VEHICLES);
}

function carName(v: LedgerVehicleData): string {
  const name = [v.maker, v.model]
    .filter((s): s is string => typeof s === "string" && s.trim().length > 0)
    .map((s) => s.trim())
    .join(" ");
  return name || "お車";
}

/**
 * 通知の文面。ロック画面に出るので、登録番号は載せない（車名と満了日だけ）。
 * 車は満了日の近い順に渡すこと。
 */
export function buildPushMessage(params: {
  shopId: string;
  noticeId: string;
  shopName: string | null;
  vehicles: LedgerVehicleData[];
}): PushMessage {
  const shop = params.shopName?.trim() || "整備工場";
  const [first] = params.vehicles;
  const expiry = toDate(first?.inspectionExpiry);
  const date = expiry ? jstMonthDay(expiry) : "";
  const body =
    params.vehicles.length <= 1
      ? `${carName(first ?? {})}の車検満了日は${date}です。ご予約・ご相談は${shop}まで。`
      : `お持ちの車${params.vehicles.length}台の車検満了日が近づいています` +
        `（いちばん早いのは${carName(first)}・${date}）。ご予約・ご相談は${shop}まで。`;
  return {
    title: `車検のご案内（${shop}）`,
    body,
    data: {
      type: "inspection_notice",
      shopId: params.shopId,
      noticeId: params.noticeId,
    },
  };
}

/** FCM がもう届かないと返したトークンのエラー。 */
const INVALID_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

/** sendEachForMulticast の応答から、外すべきトークンを選ぶ。 */
export function invalidTokensFrom(
  tokens: string[],
  responses: { success: boolean; error?: { code?: string } }[]
): string[] {
  return tokens.filter((_, i) => {
    const r = responses[i];
    return r && !r.success && INVALID_TOKEN_CODES.has(r.error?.code ?? "");
  });
}

export type NoticeOutcome = "done" | "failed" | "no-data" | "already";

/** 本体。inspection_notices の文書ができたときに呼ぶ。例外は投げない。 */
export async function handleInspectionNoticeCreated(
  params: {
    shopId: string;
    noticeId: string;
    eventId: string;
    data: NoticeRequestData | undefined;
  },
  deps: NoticeDeps,
  now: () => Date = () => new Date()
): Promise<NoticeOutcome> {
  const { shopId, noticeId, data } = params;
  if (!data) return "no-data";

  if ((await deps.claimRequest(params.eventId)) === "already") {
    console.log(
      `車検案内 shops/${shopId}/inspection_notices/${noticeId} は処理済み（または処理中）`
    );
    return "already";
  }

  const result = emptyResult();
  try {
    const at = now();
    const shopName = await deps.loadShopName().catch(() => null);

    // 1. 車ごとに確かめ、送る相手（利用者）ごとにまとめる
    const byUser = new Map<string, { id: string; v: LedgerVehicleData }[]>();
    const linkCache = new Map<string, string | null>();
    for (const id of vehicleIdsOf(data)) {
      const v = await deps.loadVehicle(id);
      if (!v) {
        result.notFound++;
        continue;
      }
      if (!isInNoticeWindow(v, at)) {
        result.outOfRange++;
        continue;
      }
      if (isNoticedForCurrentExpiry(v)) {
        result.alreadyNoticed++;
        continue;
      }
      const customerId = typeof v.customerId === "string" ? v.customerId : "";
      const customer = customerId ? await deps.loadCustomer(customerId) : null;
      const uid =
        typeof customer?.linkedUserId === "string" ? customer.linkedUserId : "";
      if (!uid) {
        result.notLinked++;
        continue;
      }
      if (!linkCache.has(uid)) {
        linkCache.set(uid, await deps.loadLinkShopId(uid));
      }
      if (linkCache.get(uid) !== shopId) {
        result.notLinked++;
        continue;
      }
      const list = byUser.get(uid) ?? [];
      list.push({ id, v });
      byUser.set(uid, list);
    }

    // 2. 利用者ごとに、設定と端末を確かめて送る
    for (const [uid, list] of byUser) {
      const user = await deps.loadUser(uid);
      if (!user) {
        result.notLinked += list.length;
        continue;
      }
      if (!wantsInspectionPush(user)) {
        result.pushOff += list.length;
        continue;
      }
      const tokens = tokensOf(user);
      if (tokens.length === 0) {
        result.noDevice += list.length;
        continue;
      }

      const claims = await deps.claimVehicles(
        list.map((e) => e.id),
        at
      );
      result.alreadyNoticed += list.length - claims.length;
      if (claims.length === 0) continue;

      const claimedIds = new Set(claims.map((c) => c.id));
      const vehicles = list
        .filter((e) => claimedIds.has(e.id))
        .map((e) => e.v)
        .sort(
          (a, b) =>
            (toDate(a.inspectionExpiry)?.getTime() ?? 0) -
            (toDate(b.inspectionExpiry)?.getTime() ?? 0)
        );
      const message = buildPushMessage({ shopId, noticeId, shopName, vehicles });

      let outcome: SendOutcome;
      try {
        outcome = await deps.send(tokens, message);
      } catch (err) {
        console.error(`車検案内の送信に失敗 uid=${uid}:`, err);
        await deps.releaseVehicles(claims);
        result.failed += claims.length;
        continue;
      }
      if (outcome.invalidTokens.length > 0) {
        await deps.removeTokens(uid, outcome.invalidTokens).catch((err) =>
          console.error(`届かないトークンを外せませんでした uid=${uid}:`, err)
        );
      }
      if (outcome.successCount > 0) {
        result.sent += claims.length;
        continue;
      }
      // 1台の端末にも届かなかった。次の案内で送れるよう、案内した日を戻す
      await deps.releaseVehicles(claims);
      if (outcome.invalidTokens.length === tokens.length) {
        result.noDevice += claims.length;
      } else {
        result.failed += claims.length;
      }
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(
      `車検案内の処理に失敗 shops/${shopId}/inspection_notices/${noticeId}:`,
      err
    );
    await deps
      .writeResult("failed", result, message.slice(0, 500))
      .catch((e) => console.error("結果を書けませんでした:", e));
    return "failed";
  }

  await deps.writeResult("done", result);
  console.log(
    `車検案内 shops/${shopId}/inspection_notices/${noticeId}: ` +
      JSON.stringify(result)
  );
  return "done";
}
