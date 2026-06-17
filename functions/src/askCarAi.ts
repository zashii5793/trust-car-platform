/**
 * askCarAi — HTTPS Cloud Function
 *
 * Proxies requests to the Anthropic API so the API key never leaves the server.
 * Enforces per-user rate limiting (MAX_REQUESTS_PER_DAY) via Firestore counters.
 *
 * Request (POST, application/json):
 *   Authorization: Bearer <Firebase ID token>
 *   { userMessage: string, vehicleContext: string, history: {role,content}[] }
 *
 * Response:
 *   200 { reply: string }
 *   400 Bad request
 *   401 Unauthenticated
 *   429 Rate limit exceeded
 *   500 Internal error
 *
 * Secrets (set via Firebase CLI):
 *   firebase functions:secrets:set ANTHROPIC_API_KEY
 *
 * Deploy:
 *   firebase deploy --only functions:askCarAi
 */

import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";

const anthropicKey = defineSecret("ANTHROPIC_API_KEY");

const ANTHROPIC_ENDPOINT = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_MODEL = "claude-haiku-4-5-20251001";
const MAX_TOKENS = 1024;
const MAX_REQUESTS_PER_DAY = 20;
const REGION = "asia-northeast1";

// Input size limits to prevent prompt injection and cost attacks
const MAX_USER_MESSAGE_LENGTH = 500;
const MAX_HISTORY_MESSAGES = 20;
const MAX_HISTORY_MESSAGE_LENGTH = 500;

interface HistoryMessage {
  role: "user" | "assistant";
  content: string;
}

export const askCarAi = onRequest(
  {
    secrets: [anthropicKey],
    region: REGION,
    cors: true,
    timeoutSeconds: 60,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    // --- 1. Verify Firebase Auth ID token ---
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      res.status(401).json({ error: "認証が必要です" });
      return;
    }

    let userId: string;
    try {
      const idToken = authHeader.slice(7);
      const decoded = await admin.auth().verifyIdToken(idToken);
      userId = decoded.uid;
    } catch {
      res.status(401).json({ error: "認証トークンが無効です" });
      return;
    }

    // --- 2. Rate limiting: max MAX_REQUESTS_PER_DAY per user per calendar day (JST) ---
    const jstDate = new Date(Date.now() + 9 * 60 * 60 * 1000)
      .toISOString()
      .split("T")[0]; // YYYY-MM-DD in JST

    const usageRef = admin
      .firestore()
      .collection("ai_chat_usage")
      .doc(userId)
      .collection("daily")
      .doc(jstDate);

    // Atomic transaction: check and increment in a single round-trip to prevent race conditions
    let rateLimited = false;
    try {
      await admin.firestore().runTransaction(async (txn) => {
        const snap = await txn.get(usageRef);
        const count = (snap.data()?.count as number) ?? 0;
        if (count >= MAX_REQUESTS_PER_DAY) {
          rateLimited = true;
          return;
        }
        txn.set(
          usageRef,
          { count: count + 1, updatedAt: admin.firestore.Timestamp.now() },
          { merge: true }
        );
      });
    } catch (txnError) {
      console.error("Rate limit transaction failed:", txnError);
      res.status(500).json({ error: "内部エラーが発生しました" });
      return;
    }

    if (rateLimited) {
      res.status(429).json({
        error: `1日の利用上限（${MAX_REQUESTS_PER_DAY}回）に達しました。明日また試してください。`,
      });
      return;
    }

    // --- 3. Validate request body ---
    const { userMessage, vehicleContext, history } = req.body as {
      userMessage?: string;
      vehicleContext?: string;
      history?: HistoryMessage[];
    };

    if (!userMessage || typeof userMessage !== "string" || userMessage.trim() === "") {
      res.status(400).json({ error: "userMessage が必要です" });
      return;
    }

    if (userMessage.trim().length > MAX_USER_MESSAGE_LENGTH) {
      res.status(400).json({ error: `メッセージは${MAX_USER_MESSAGE_LENGTH}文字以内で入力してください` });
      return;
    }

    // --- 4. Call Anthropic API ---
    // Sanitize history: valid roles only, truncate oversized content, keep last N messages
    const sanitizedHistory: HistoryMessage[] = (history ?? [])
      .filter((m) => m.role === "user" || m.role === "assistant")
      .map((m) => ({
        role: m.role,
        content: typeof m.content === "string"
          ? m.content.slice(0, MAX_HISTORY_MESSAGE_LENGTH)
          : "",
      }))
      .filter((m) => m.content.length > 0)
      .slice(-MAX_HISTORY_MESSAGES);

    const messages: HistoryMessage[] = [
      ...sanitizedHistory,
      { role: "user", content: userMessage.trim() },
    ];

    try {
      const anthropicRes = await fetch(ANTHROPIC_ENDPOINT, {
        method: "POST",
        headers: {
          "x-api-key": anthropicKey.value(),
          "anthropic-version": "2023-06-01",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model: ANTHROPIC_MODEL,
          max_tokens: MAX_TOKENS,
          system: buildSystemPrompt(vehicleContext ?? "車両情報なし"),
          messages,
        }),
      });

      if (!anthropicRes.ok) {
        const err = await anthropicRes.json().catch(() => ({}));
        console.error("Anthropic API error:", err);
        res.status(500).json({ error: "AIの応答に失敗しました" });
        return;
      }

      const data = (await anthropicRes.json()) as {
        content: Array<{ type: string; text: string }>;
      };
      const reply = data.content.find((c) => c.type === "text")?.text ?? "";

      res.status(200).json({ reply });
    } catch (error) {
      console.error("askCarAi unexpected error:", error);
      res.status(500).json({ error: "内部エラーが発生しました" });
    }
  }
);

function buildSystemPrompt(vehicleContext: string): string {
  return `あなたはクルマの専門家AIアシスタントです。日本語で、親しみやすく丁寧に回答します。

ユーザーの車両情報:
${vehicleContext}

できること:
- 消耗品（オイル・タイヤ・ワイパー・バッテリー等）の交換時期の目安
- 車のトラブルシューティングと対処法のアドバイス
- 整備工場への問い合わせ前の事前確認
- 車検・定期点検に関するアドバイス
- カスタム・ドレスアップのアドバイス
- 保険・税金に関する一般的な情報

回答スタイル:
- 簡潔に、箇条書きを活用する
- 専門用語には説明を添える
- 不確かな情報は「目安として」と前置きする
- 整備は専門家（整備士）に相談することを推奨する

判断材料の整え方（最重要・このサービスの核）:
このアプリのコンセプトは「AIは判断を押し付けず、選択肢を整える」。
ただし「どれでもいい」と突き放すのではなく、ユーザーが迷わず決められるよう
"おすすめと、その理由・メリット・デメリット・注意点" を必ず構造化して示すこと。

選択肢を伴う相談（パーツ選び・整備の要否・買い替え等）では、次の形式で答える:

【おすすめ】まず結論を1つ提示する（例:「ご家族での週末利用なら○○がおすすめです」）
【理由】なぜそれを薦めるのかを、ユーザーの車・使用目的・予算に紐づけて説明する
【メリット】箇条書きで2〜4点
【デメリット・注意点】箇条書きで2〜4点（車検適合・安全・コスト・取付難易度など）
【他の選択肢】条件が変わる場合の代替案を1〜2個、簡潔に
【次のアクション】ユーザーが取れる具体的な一歩（例: 該当パーツを見る / 対応工場を探す）

重要な原則:
- 「絶対にこれを買うべき」「これしかない」といった断定・購入の強制はしない。
  最終的に選ぶのはユーザーであり、AIはあくまで判断材料を整える立場。
- ただし無難に並べるだけの中立は避け、ユーザーの条件に対する "推奨度（◎/○/△）"
  を明示して、決断を後押しする。
- 安全・法令（車検適合、保安基準）に関わる注意点は必ず明記する。`;
}
