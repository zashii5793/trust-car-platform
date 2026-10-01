// 店舗プランの申し込み（shops/{shopId}/plan_requests/{id}）を運営者にメールで知らせる。
//
// 2026-10-01 のオーナー判断: 申し込みが来たら運営者にメールで知らせる。
//
// - 宛先は Secret Manager の OPERATOR_EMAIL（公開リポジトリに書かない）。
//   未設定・空なら送らずにログだけ残す
// - 二重送信を防ぐため、送る前に申し込みの文書へ「送信を引き受けた」印
//   （operatorNotification）を Admin SDK のトランザクションで書く。印が既に
//   あれば送らない。クライアントはルールでこの文書を書き換えられないので、
//   印を偽造・消去される心配はない
// - SendGrid の一時的な失敗（429・5xx・通信エラー）は印を外して投げ直し、
//   Cloud Functions の再試行に任せる。それ以外（4xx など）は再試行しても
//   直らないので、印を failed にして終える。一時的な失敗でも、申し込みから
//   1時間を過ぎたら諦めて failed にする（再試行が丸一日続かないように）
//
// Firebase のトリガー本体は index.ts。ここは依存を差し込める純粋な処理だけで、
// エミュレータなしでテストできる（moderateComments.ts と同じ作り）。

/** plan_requests の文書の形（lib/models/shop_plan_request.dart と同じ）。 */
export interface PlanRequestData {
  plan?: string;
  currentPlan?: string;
  requesterUid?: string;
  contactEmail?: string;
  billingName?: string;
  note?: string;
  status?: string;
  /** Firestore の Timestamp（toDate を持つ）。サーバ時刻なので通常は入っている。 */
  createdAt?: { toDate(): Date } | null;
}

/** メールの中身。 */
export interface OperatorMail {
  to: string;
  from: string;
  subject: string;
  text: string;
}

/** 送信元（sendNewsletter.ts と同じ）。 */
export const MAIL_FROM = "no-reply@trustcar.jp";

/** Firebase プロジェクト ID（Console の URL に使う）。 */
export const FIREBASE_PROJECT_ID = "trust-car-platform";

/** 店舗プランの表示名（lib/models/shop.dart の ShopPlanType.displayName と同じ）。 */
const PLAN_LABELS: Record<string, string> = {
  free: "フリー",
  standard: "スタンダード",
  premium: "プレミアム",
  enterprise: "エンタープライズ",
};

/** プランの表示名。知らない値はそのまま出す（運営者が見て分かるように）。 */
export function planLabel(plan: string | undefined): string {
  if (!plan) return "(不明)";
  return PLAN_LABELS[plan] ?? plan;
}

/** 日本時間で「2026-10-01 14:03」の形にする。 */
export function formatJst(date: Date): string {
  const parts = new Intl.DateTimeFormat("ja-JP", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(date);
  const get = (type: string) =>
    parts.find((p) => p.type === type)?.value ?? "";
  return `${get("year")}-${get("month")}-${get("day")} ${get("hour")}:${get("minute")}`;
}

/** Firestore Console でこの申し込みを開く URL。 */
export function consoleUrl(shopId: string, requestId: string): string {
  const path = `/shops/${shopId}/plan_requests/${requestId}`;
  // Console は「/」を ~2F に置き換えた形で文書を指す
  const encoded = path
    .split("/")
    .map((seg) => encodeURIComponent(seg))
    .join("~2F");
  return (
    `https://console.firebase.google.com/project/${FIREBASE_PROJECT_ID}` +
    `/firestore/data/${encoded}`
  );
}

/** メールの件名と本文を組み立てる。 */
export function buildOperatorMail(params: {
  to: string;
  shopId: string;
  requestId: string;
  shopName: string | null;
  request: PlanRequestData;
  /** createdAt が無いときに使う時刻（イベントの時刻）。 */
  fallbackTime: Date;
}): OperatorMail {
  const { to, shopId, requestId, request } = params;
  const shopName = params.shopName?.trim() || "(店名未設定)";
  const plan = planLabel(request.plan);
  const current = planLabel(request.currentPlan);
  const created = request.createdAt?.toDate?.() ?? params.fallbackTime;
  const isQuote = request.plan === "enterprise";
  const isDowngrade = request.plan === "free";

  const kind = isQuote
    ? "（個別見積もりの相談）"
    : isDowngrade
      ? "（フリーへの変更＝解約の申し込み）"
      : "";

  const lines = [
    "店舗プランの申し込みが届きました。",
    "",
    `店名: ${shopName}`,
    `店ID: ${shopId}`,
    `プラン: ${current} → ${plan}${kind}`,
    `請求書の宛名: ${request.billingName || "(未入力)"}`,
    `連絡先: ${request.contactEmail || "(未入力)"}`,
    `申し込み日時: ${formatJst(created)}（日本時間）`,
    `申し込みID: ${requestId}`,
  ];
  if (request.note && request.note.trim()) {
    lines.push("", "ご要望:", request.note.trim());
  }
  lines.push(
    "",
    "Console で開く:",
    consoleUrl(shopId, requestId),
    "",
    "プランの切り替え（planType・subscriptionStatus）は、入金を確かめてから",
    "サーバ側で行ってください。アプリからは切り替わりません。",
    "",
    "-- ",
    "このメールは TrustCar の Cloud Functions（onPlanRequestCreated）が自動で送っています。"
  );

  return {
    to,
    from: MAIL_FROM,
    subject: `[TrustCar] 店舗プランの申し込み: ${shopName} → ${plan}`,
    text: lines.join("\n"),
  };
}

/**
 * SendGrid のエラーが一時的なもの（再試行で直りうる）か。
 * 429・5xx・HTTP 応答なし（通信エラー）を一時的とみなす。
 */
export function isTransientSendError(err: unknown): boolean {
  const code = (err as { code?: unknown })?.code;
  const status =
    typeof code === "number"
      ? code
      : (err as { response?: { statusCode?: unknown } })?.response?.statusCode;
  if (typeof status !== "number") return true;
  return status === 429 || status >= 500;
}

/** 送信の引き受けを試みた結果。 */
export type ClaimResult = "claimed" | "already";

/** 差し込む副作用（テストでは差し替える）。 */
export interface NotifyDeps {
  /** OPERATOR_EMAIL の値。未設定なら空文字。 */
  operatorEmail: () => string;
  /** 店名（shops/{shopId}.name）。読めなければ null。 */
  loadShopName: (shopId: string) => Promise<string | null>;
  /**
   * 申し込みの文書に「送信を引き受けた」印をトランザクションで書く。
   * 既に印があれば何もせず "already" を返す。
   */
  claim: (eventId: string) => Promise<ClaimResult>;
  /** 一時的な失敗のとき、再試行に備えて印を外す。 */
  release: () => Promise<void>;
  /** 送れたことを書く。 */
  markSent: () => Promise<void>;
  /** 再試行しても直らない失敗を書く。 */
  markFailed: (message: string) => Promise<void>;
  /** メールを送る（SendGrid）。 */
  send: (mail: OperatorMail) => Promise<void>;
}

/** 一時的な失敗でも、これより古いイベントは再試行せずに諦める（1時間）。 */
export const MAX_RETRY_AGE_MS = 60 * 60 * 1000;

export type NotifyOutcome =
  | "sent"
  | "no-operator-email"
  | "no-data"
  | "already-notified"
  | "failed";

/**
 * 本体。plan_requests の文書ができたときに呼ぶ。
 * 一時的な送信失敗だけは例外を投げる（Cloud Functions に再試行させる）。
 */
export async function handlePlanRequestCreated(
  params: {
    shopId: string;
    requestId: string;
    eventId: string;
    eventTime: Date;
    data: PlanRequestData | undefined;
  },
  deps: NotifyDeps,
  now: () => number = Date.now
): Promise<NotifyOutcome> {
  const { shopId, requestId, eventId, data } = params;
  if (!data) return "no-data";

  const to = deps.operatorEmail().trim();
  if (!to) {
    console.warn(
      `OPERATOR_EMAIL が未設定のため、申し込み shops/${shopId}/plan_requests/${requestId} の通知を送りません`
    );
    return "no-operator-email";
  }

  if ((await deps.claim(eventId)) === "already") {
    console.log(
      `申し込み shops/${shopId}/plan_requests/${requestId} は通知済み（または送信中）のため送りません`
    );
    return "already-notified";
  }

  const shopName = await deps.loadShopName(shopId).catch(() => null);
  const mail = buildOperatorMail({
    to,
    shopId,
    requestId,
    shopName,
    request: data,
    fallbackTime: params.eventTime,
  });

  try {
    await deps.send(mail);
  } catch (err) {
    const tooOld = now() - params.eventTime.getTime() > MAX_RETRY_AGE_MS;
    if (isTransientSendError(err) && !tooOld) {
      await deps.release();
      console.error(
        `申し込みの通知メールの送信に失敗（再試行します） shops/${shopId}/plan_requests/${requestId}:`,
        err
      );
      throw err;
    }
    const message = err instanceof Error ? err.message : String(err);
    await deps.markFailed(message.slice(0, 500));
    console.error(
      `申し込みの通知メールの送信に失敗（再試行しません） shops/${shopId}/plan_requests/${requestId}:`,
      err
    );
    return "failed";
  }

  await deps.markSent();
  console.log(
    `申し込みの通知メールを送りました shops/${shopId}/plan_requests/${requestId}`
  );
  return "sent";
}
