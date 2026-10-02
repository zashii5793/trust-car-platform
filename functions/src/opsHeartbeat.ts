// 定期ジョブのハートビート（ops_heartbeats/{関数名}）。
//
// 2026-10-02 のオーナー判断: 定期の Functions が「回っているか」を外から確かめられるように、
// 終わるたびに最後の実行・最後の成功・処理件数を書く。健康診断（opsHealth.ts）がこれを読み、
// 許容時間を過ぎても成功していない・最後が失敗ならNGにする。
//
// - 失敗しても ok=false で書く（lastSuccessAt は前の値を残す。書き込みは merge）
// - ハートビートが書けなくても本処理は止めない（ログだけ残す）
// - 本処理の例外は書いたあとに投げ直す（Cloud Scheduler 側でも失敗として残る）
// - error はメッセージの先頭だけ。メールアドレスは伏せる（個人情報を残さない）
//
// Firebase のトリガー本体は index.ts。ここは依存を差し込める純粋な処理だけ。

export const HEARTBEAT_COLLECTION = "ops_heartbeats";

/** error に残す長さの上限。 */
export const MAX_HEARTBEAT_ERROR_LENGTH = 300;

/** 本処理の結果。error があれば一部失敗（ok=false）として書く。 */
export interface JobOutcome {
  processed: number;
  error?: string;
}

/** ops_heartbeats/{関数名} に書く中身。成功のときだけ lastSuccessAt を持つ。 */
export interface HeartbeatWrite {
  lastRunAt: Date;
  lastSuccessAt?: Date;
  ok: boolean;
  processed: number;
  error: string | null;
}

const EMAIL = /[\w.+-]+@[\w-]+(?:\.[\w-]+)+/g;

/** 例外を、ハートビートに残せる短い1行にする。 */
export function shortError(err: unknown): string {
  let text: string;
  if (err instanceof Error) {
    text = err.message;
  } else if (err === null || err === undefined) {
    text = "";
  } else {
    text = String(err);
  }
  const first = text
    .split("\n")
    .map((l) => l.trim())
    .find((l) => l.length > 0);
  if (!first) return "(不明なエラー)";
  return first.replace(EMAIL, "[email]").slice(0, MAX_HEARTBEAT_ERROR_LENGTH);
}

function count(n: number): number {
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
}

/** 本処理の結果からハートビートを作る。 */
export function heartbeatFor(outcome: JobOutcome, now: Date): HeartbeatWrite {
  const error = outcome.error ? shortError(outcome.error) : null;
  if (error) {
    return { lastRunAt: now, ok: false, processed: count(outcome.processed), error };
  }
  return {
    lastRunAt: now,
    lastSuccessAt: now,
    ok: true,
    processed: count(outcome.processed),
    error: null,
  };
}

/**
 * 本処理を走らせ、終わったらハートビートを書く。
 * 本処理の例外は、ok=false を書いてから投げ直す。
 */
export async function runWithHeartbeat(
  name: string,
  job: () => Promise<JobOutcome>,
  write: (name: string, hb: HeartbeatWrite) => Promise<void>,
  now: () => Date = () => new Date()
): Promise<JobOutcome> {
  const safeWrite = async (hb: HeartbeatWrite) => {
    try {
      await write(name, hb);
    } catch (err) {
      console.error(`ハートビートを書けませんでした（${name}）:`, err);
    }
  };

  let outcome: JobOutcome;
  try {
    outcome = await job();
  } catch (err) {
    await safeWrite({
      lastRunAt: now(),
      ok: false,
      processed: 0,
      error: shortError(err),
    });
    throw err;
  }
  await safeWrite(heartbeatFor(outcome, now()));
  return outcome;
}
