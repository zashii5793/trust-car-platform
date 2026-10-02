// ウェブのエラーの日次解析と、運営者への日次レポートのメール（opsDailyReport）。
//
// 2026-10-02 のオーナー判断: 毎朝 8 時（日本時間）に、前日（0〜24 時）の client_errors を
// 集計し、同じ時刻の健康診断（ops_health/latest）・定期ジョブの最終実行とまとめて
// ops_reports/{YYYY-MM-DD} に書き、OPERATOR_EMAIL に送る。
//
// - 集計: 総数・前日比・メッセージの上位10件・buildId ごと・source ごと・path の上位10件
// - 二重送信しない: 送る前に ops_reports の文書をトランザクションで作り、mail.state を
//   sending にする。既に文書があれば送らない（前回が failed のときだけ送り直す）
// - 宛先が空なら、レポートは書いて送らない（mail.state = skipped）
// - 本文・文書に uid・メール・入力値を入れない。メッセージはクライアントで伏せてあるが、
//   念のためここでもメール・7桁以上の数字を伏せ、path のクエリは落とす
//
// Firebase のトリガー本体は index.ts。ここは依存を差し込める純粋な処理だけ。

import { MAIL_FROM, formatJst, type OperatorMail } from "./notifyPlanRequest";
import {
  HOUR_MS,
  SCHEDULED_JOBS,
  type HeartbeatSnapshot,
  type StoredHealth,
} from "./opsHealth";
import { RUNBOOK_REF, safeLine } from "./opsAlert";

export const REPORT_COLLECTION = "ops_reports";
/** レポートを残す日数（expireAt の TTL ポリシーで消す）。 */
export const REPORT_RETENTION_DAYS = 180;
/** 内訳のために読む client_errors の上限（総数は count() で別に数える）。 */
export const MAX_ERROR_ROWS = 5000;
/** 健康診断がこれより古ければ「止まっている」として問題に数える。 */
export const HEALTH_STALE_MS = 2 * HOUR_MS;

const DAY_MS = 24 * HOUR_MS;
const JST_OFFSET_MS = 9 * HOUR_MS;
const UNKNOWN = "(不明)";

/** 対象の日（日本時間の前日）。終わったばかりの日を返す。 */
export function jstReportDay(nowMs: number): {
  date: string;
  startMs: number;
  endMs: number;
  prevStartMs: number;
} {
  // 日本時間の今日の 0 時（UTC のミリ秒）。日本は夏時間が無いので +9 時間で足りる
  const todayStart =
    Math.floor((nowMs + JST_OFFSET_MS) / DAY_MS) * DAY_MS - JST_OFFSET_MS;
  const startMs = todayStart - DAY_MS;
  const date = new Date(startMs + JST_OFFSET_MS).toISOString().slice(0, 10);
  return { date, startMs, endMs: todayStart, prevStartMs: startMs - DAY_MS };
}

const EMAIL = /[\w.+-]+@[\w-]+(?:\.[\w-]+)+/g;
const NUMBER_RUN = /\+?\d[\d\- ]*\d/g;

/** エラーのメッセージを集計の鍵にする（1行・伏せ字・200 文字まで）。 */
export function normalizeMessage(message: unknown): string {
  if (typeof message !== "string") return UNKNOWN;
  const oneLine = message.replace(/\s+/g, " ").trim();
  if (!oneLine) return UNKNOWN;
  return oneLine
    .replace(EMAIL, "[email]")
    .replace(NUMBER_RUN, (m) =>
      m.replace(/\D/g, "").length >= 7 ? "[number]" : m
    )
    .slice(0, 200);
}

function normalizePath(path: unknown): string {
  if (typeof path !== "string") return UNKNOWN;
  // クエリには入力値が入りうるので落とす（クライアントも落としているが念のため）
  const p = path.split("?")[0].trim();
  return p ? p.slice(0, 200) : UNKNOWN;
}

function normalizeShort(v: unknown): string {
  if (typeof v !== "string" || !v.trim()) return UNKNOWN;
  return v.trim().slice(0, 40);
}

/** client_errors の1件のうち、集計に使うところ（uid・stack・userAgent は読まない）。 */
export interface ErrorRow {
  message?: unknown;
  source?: unknown;
  buildId?: unknown;
  path?: unknown;
}

export interface CountEntry {
  key: string;
  count: number;
}

export interface ErrorSummary {
  total: number;
  prevTotal: number | null;
  diff: number | null;
  /** 内訳は読んだ行（sampleSize 件）から。総数より少なければ sampled。 */
  sampled: boolean;
  sampleSize: number;
  topMessages: CountEntry[];
  byBuildId: CountEntry[];
  bySource: CountEntry[];
  topPaths: CountEntry[];
}

function rank(keys: string[], limit: number): CountEntry[] {
  const counts = new Map<string, number>();
  for (const k of keys) counts.set(k, (counts.get(k) ?? 0) + 1);
  return [...counts.entries()]
    .map(([key, count]) => ({ key, count }))
    .sort((a, b) => b.count - a.count || (a.key < b.key ? -1 : a.key > b.key ? 1 : 0))
    .slice(0, limit);
}

/** 前日の client_errors を集計する。総数は count() の値（数えられなければ読んだ行数）。 */
export function aggregateClientErrors(
  rows: readonly ErrorRow[],
  counts: { total: number | null; prevTotal: number | null }
): ErrorSummary {
  const total = counts.total ?? rows.length;
  const prevTotal = counts.prevTotal;
  return {
    total,
    prevTotal,
    diff: prevTotal === null ? null : total - prevTotal,
    sampled: rows.length < total,
    sampleSize: rows.length,
    topMessages: rank(rows.map((r) => normalizeMessage(r.message)), 10),
    byBuildId: rank(rows.map((r) => normalizeShort(r.buildId)), 20),
    bySource: rank(rows.map((r) => normalizeShort(r.source)), 10),
    topPaths: rank(rows.map((r) => normalizePath(r.path)), 10),
  };
}

/** 問題の件数: 健康診断の NG の数。健康診断が無い・止まっていれば +1。 */
export function countProblems(health: StoredHealth | null, nowMs: number): number {
  if (!health) return 1;
  const ng = health.items.filter((i) => i.status === "ng").length;
  const stale = nowMs - health.checkedAtMs > HEALTH_STALE_MS ? 1 : 0;
  return ng + stale;
}

function signed(n: number): string {
  return n > 0 ? `+${n}` : n < 0 ? `${n}` : "±0";
}

function at(ms: number | null): string {
  return ms === null ? "なし" : formatJst(new Date(ms));
}

const STATUS_LABEL: Record<string, string> = { ok: "[OK]", ng: "[NG]" };

export function buildDailyReportMail(params: {
  to: string;
  date: string;
  errors: ErrorSummary;
  health: StoredHealth | null;
  heartbeats: Record<string, HeartbeatSnapshot | null | undefined>;
  nowMs: number;
}): OperatorMail {
  const { to, date, errors, health, heartbeats, nowMs } = params;
  const problems = countProblems(health, nowMs);
  const lines: string[] = [
    `TrustCar の日次レポートです（対象: ${date} 0:00〜24:00 日本時間）。`,
    "",
    "■ 健康診断",
  ];

  if (!health) {
    lines.push("健康診断の結果が無い（opsHealthCheck が動いていない）");
  } else {
    const ago = Math.floor((nowMs - health.checkedAtMs) / HOUR_MS);
    lines.push(
      `${formatJst(new Date(health.checkedAtMs))} 時点: 全体 ${health.overall}`
    );
    if (nowMs - health.checkedAtMs > HEALTH_STALE_MS) {
      lines.push(`健康診断が ${ago} 時間前で止まっている`);
    }
    for (const i of health.items) {
      lines.push(
        `- ${STATUS_LABEL[i.status] ?? "[不明]"} ${i.name} — ${safeLine(i.detail)}`
      );
    }
  }

  lines.push("", "■ 定期ジョブ（最後の実行）");
  for (const job of SCHEDULED_JOBS) {
    const hb = heartbeats[job.name];
    if (!hb) {
      lines.push(`- ${job.name}: 記録なし`);
      continue;
    }
    const failed =
      hb.ok === false ? ` / 失敗: ${safeLine(hb.error ?? "(理由なし)", 200)}` : "";
    lines.push(
      `- ${job.name}: 実行 ${at(hb.lastRunAtMs)} / 成功 ${at(hb.lastSuccessAtMs)}` +
        ` / 処理 ${hb.processed ?? 0} 件${failed}`
    );
  }

  const prev =
    errors.prevTotal === null || errors.diff === null
      ? "前日 不明"
      : `前日 ${errors.prevTotal} 件、${signed(errors.diff)}`;
  lines.push("", "■ ウェブのエラー（client_errors）", `総数: ${errors.total} 件（${prev}）`);
  if (errors.sampled) {
    lines.push(`（内訳は先頭の ${errors.sampleSize} 件から）`);
  }
  const section = (title: string, entries: CountEntry[]) => {
    if (entries.length === 0) return;
    lines.push("", `${title}:`);
    for (const e of entries) lines.push(`  ${e.count} 件  ${safeLine(e.key, 200)}`);
  };
  section("メッセージの上位", errors.topMessages);
  section("buildId ごと", errors.byBuildId);
  section("source ごと", errors.bySource);
  section("path の上位", errors.topPaths);

  lines.push(
    "",
    `NG のときに見るもの・打つコマンドは ${RUNBOOK_REF}。`,
    "",
    "-- ",
    "このメールは TrustCar の Cloud Functions（opsDailyReport）が自動で送っています。"
  );

  return {
    to,
    from: MAIL_FROM,
    subject:
      `[TrustCar] 日次レポート ${date}：` +
      (problems > 0 ? `問題あり ${problems}件` : "問題なし"),
    text: lines.join("\n"),
  };
}

export type MailState = "sending" | "sent" | "failed" | "skipped";

/** ops_reports/{YYYY-MM-DD} の中身（時刻はミリ秒。index.ts で Timestamp に直す）。 */
export interface ReportDoc {
  date: string;
  rangeStartMs: number;
  rangeEndMs: number;
  errors: ErrorSummary;
  health: { overall: string; checkedAtMs: number; ngItems: string[] } | null;
  problems: number;
  mail: { state: MailState };
  createdAtMs: number;
  expireAtMs: number;
}

export interface DailyReportDeps {
  operatorEmail: () => string;
  /** createdAt が [startMs, endMs) の client_errors の件数。 */
  countErrors: (startMs: number, endMs: number) => Promise<number>;
  /** createdAt が [startMs, endMs) の client_errors（最大 limit 件）。 */
  loadErrorRows: (startMs: number, endMs: number, limit: number) => Promise<ErrorRow[]>;
  loadHealth: () => Promise<StoredHealth | null>;
  loadHeartbeats: () => Promise<Record<string, HeartbeatSnapshot | null>>;
  /**
   * ops_reports/{date} をトランザクションで作る。既にあれば（前回が failed の
   * ときを除き）何もせず "already"。
   */
  claimReport: (date: string, doc: ReportDoc) => Promise<"claimed" | "already">;
  markMail: (date: string, state: MailState, error?: string) => Promise<void>;
  send: (mail: OperatorMail) => Promise<void>;
}

export type DailyReportOutcome =
  | "sent"
  | "failed"
  | "no-operator-email"
  | "already-sent";

async function orElse<T>(label: string, p: Promise<T>, fallback: T): Promise<T> {
  try {
    return await p;
  } catch (err) {
    console.error(`日次レポート: ${label} を読めませんでした:`, err);
    return fallback;
  }
}

/** 本体。毎朝 8 時（日本時間）に呼ぶ。送信の失敗は failed を書いて返す（投げない）。 */
export async function handleDailyReport(
  deps: DailyReportDeps,
  nowMs: number
): Promise<DailyReportOutcome> {
  const day = jstReportDay(nowMs);
  const [rows, total, prevTotal, health, heartbeats] = await Promise.all([
    orElse("client_errors", deps.loadErrorRows(day.startMs, day.endMs, MAX_ERROR_ROWS), [] as ErrorRow[]),
    orElse<number | null>("client_errors の件数", deps.countErrors(day.startMs, day.endMs), null),
    orElse<number | null>("前日の client_errors の件数", deps.countErrors(day.prevStartMs, day.startMs), null),
    orElse<StoredHealth | null>("健康診断", deps.loadHealth(), null),
    orElse<Record<string, HeartbeatSnapshot | null>>("ハートビート", deps.loadHeartbeats(), {}),
  ]);

  const errors = aggregateClientErrors(rows, { total, prevTotal });
  const to = deps.operatorEmail().trim();
  const doc: ReportDoc = {
    date: day.date,
    rangeStartMs: day.startMs,
    rangeEndMs: day.endMs,
    errors,
    health: health
      ? {
          overall: health.overall,
          checkedAtMs: health.checkedAtMs,
          ngItems: health.items.filter((i) => i.status === "ng").map((i) => i.name),
        }
      : null,
    problems: countProblems(health, nowMs),
    mail: { state: to ? "sending" : "skipped" },
    createdAtMs: nowMs,
    expireAtMs: nowMs + REPORT_RETENTION_DAYS * DAY_MS,
  };

  if ((await deps.claimReport(day.date, doc)) === "already") {
    console.log(`日次レポート ${day.date} は作成済み（送信済み）のため送りません`);
    return "already-sent";
  }
  if (!to) {
    console.warn(`OPERATOR_EMAIL が未設定のため、日次レポート ${day.date} を送りません`);
    return "no-operator-email";
  }

  const mail = buildDailyReportMail({
    to,
    date: day.date,
    errors,
    health,
    heartbeats,
    nowMs,
  });
  try {
    await deps.send(mail);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    await deps.markMail(day.date, "failed", safeLine(message));
    console.error(`日次レポート ${day.date} の送信に失敗:`, err);
    return "failed";
  }
  await deps.markMail(day.date, "sent");
  console.log(`日次レポート ${day.date} を送りました（問題 ${doc.problems} 件）`);
  return "sent";
}
