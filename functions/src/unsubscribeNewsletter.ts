// メールの配信停止リンク（トークン）での購読停止（Issue #192）。
//
// 以前は NewsletterService.unsubscribeByToken がクライアントから
// newsletter_subscriptions を unsubscribeToken で引いていた。リンクから来る
// 人はログインしていない（または別のアカウント）ので、ルールでは
// 「トークンを知っている」ことを証明できず、本番では必ず permission-denied
// になる。ルールを緩めると全員の購読が引けてしまうので、Admin SDK で
// 動くここに移した。
//
// - POST だけ受ける。GET で止めると、メールソフトのリンク先読みで勝手に
//   配信停止される
// - トークンは空・短すぎ・長すぎを弾く。既定値が空文字なので、空を
//   通すと「トークン未発行の購読」に当たってしまう
// - 返すのは成功か「無効なリンク」だけ。誰の購読かは返さない
//
// Firebase の HTTPS 関数の本体は index.ts。ここは依存を差し込める純粋な処理。

export const MIN_TOKEN_LENGTH = 16;
export const MAX_TOKEN_LENGTH = 256;

export interface UnsubscribeDeps {
  /** トークンが一致する購読の ID を1件返す。無ければ null。 */
  findByToken(token: string): Promise<string | null>;
  /** 購読を止める（isSubscribed=false, updatedAt=now）。 */
  markUnsubscribed(subscriptionId: string): Promise<void>;
}

export interface UnsubscribeResponse {
  status: number;
  body: { ok: true } | { error: string };
}

/** トークンの形だけを見る（英数字と - _ だけ。URL にそのまま載る形）。 */
export function isValidToken(token: unknown): token is string {
  return (
    typeof token === "string" &&
    token.length >= MIN_TOKEN_LENGTH &&
    token.length <= MAX_TOKEN_LENGTH &&
    /^[A-Za-z0-9_-]+$/.test(token)
  );
}

export async function handleUnsubscribe(
  method: string,
  body: unknown,
  deps: UnsubscribeDeps
): Promise<UnsubscribeResponse> {
  if (method !== "POST") {
    return { status: 405, body: { error: "Method Not Allowed" } };
  }
  const token =
    body && typeof body === "object" ? (body as { token?: unknown }).token : undefined;
  if (!isValidToken(token)) {
    return { status: 400, body: { error: "無効な配信停止リンクです" } };
  }
  try {
    const id = await deps.findByToken(token);
    if (id === null) {
      return { status: 404, body: { error: "無効な配信停止リンクです" } };
    }
    await deps.markUnsubscribed(id);
    return { status: 200, body: { ok: true } };
  } catch (err) {
    console.error("Newsletter unsubscribe failed:", err);
    return { status: 500, body: { error: "配信停止処理に失敗しました" } };
  }
}
