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

    const usageSnap = await usageRef.get();
    const currentCount = (usageSnap.data()?.count as number) ?? 0;

    if (currentCount >= MAX_REQUESTS_PER_DAY) {
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

    // --- 4. Call Anthropic API ---
    const messages: HistoryMessage[] = [
      ...(history ?? []).filter(
        (m) =>
          m.role === "user" || m.role === "assistant"
      ),
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

      // --- 5. Increment usage counter (fire-and-forget safe to fail) ---
      usageRef
        .set(
          {
            count: currentCount + 1,
            updatedAt: admin.firestore.Timestamp.now(),
          },
          { merge: true }
        )
        .catch((e) => console.warn("Failed to update usage counter:", e));

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
- 整備は専門家（整備士）に相談することを推奨する`;
}
