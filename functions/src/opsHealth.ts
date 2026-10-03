// 本番の健康診断（opsHealthCheck が1時間ごとに ops_health/latest に書く）。
//
// 2026-10-02 のオーナー判断: 外からの見張り（scripts/prod_watch.sh）では見えない
// 「中で回っているか」を確かめる。見るものは次の5つ。
//
//   1. 定期ジョブ … ops_heartbeats/{関数名}（opsHeartbeat.ts）。許容時間を過ぎても
//      成功していない・最後が失敗なら NG
//   2. 申し込みの滞留 … plan_requests が受付中のまま 72 時間／運営者への通知が failed
//   3. 車検案内の滞留 … inspection_notices が処理されないまま 1 時間
//   4. ウェブのエラー … 直近1時間の client_errors が、7日の1時間平均の 5 倍以上かつ 10 件以上
//   5. バックアップ … 最新の READY が 48 時間より古い
//
// 各項目は ok / ng / unknown。unknown（読めなかった・まだ記録が無い）は NG に数えない。
// 判定できないもので毎時騒ぐと、本当の NG が埋もれるため。unknown は結果に出す。
//
// detail は運営者が読む説明。件数・時間・エラーの先頭だけを書き、uid・メール・入力値は
// 入れない。外からの口（opsHealth）は detail を返さない（publicView）。
//
// Firebase のトリガー本体と Firestore・Admin API の読み取りは index.ts。
// ここは純粋な判定だけで、エミュレータなしでテストできる。

export const HOUR_MS = 60 * 60 * 1000;

export const HEALTH_COLLECTION = "ops_health";
export const HEALTH_LATEST_DOC = "latest";
export const HEALTH_HISTORY_COLLECTION = "ops_health_history";
/** 履歴を残す日数（expireAt の TTL ポリシーで消す）。 */
export const HEALTH_HISTORY_DAYS = 30;

/** 見張る定期ジョブと、成功の間隔の許容時間。日次ジョブは 24 時間 + 2 時間の余裕。 */
export const SCHEDULED_JOBS: readonly { name: string; maxAgeHours: number }[] = [
  { name: "purgeDeletedAccounts", maxAgeHours: 26 },
  { name: "purgeExpiredShares", maxAgeHours: 26 },
  { name: "aggregateModelCosts", maxAgeHours: 26 },
];

export const THRESHOLDS = {
  /** plan_requests が受付中（pending）のまま、これを過ぎたら NG。 */
  planRequestPendingHours: 72,
  /**
   * 定期ジョブの記録が一度も無いまま、監視を始めてからこれを過ぎたら NG。
   * 日次ジョブなら必ず1回は走っているはずの長さ（2026-10-04 オーナー判断）。
   */
  missingHeartbeatGraceHours: 48,
  /** inspection_notices が pending のまま、これを過ぎたら NG。 */
  inspectionNoticePendingHours: 1,
  /** client_errors の急増: 平均の何倍で NG か。 */
  errorSpikeFactor: 5,
  /** client_errors の急増: 最低これだけ無いと NG にしない。 */
  errorSpikeMin: 10,
  /** client_errors の平均を取る日数。 */
  errorBaselineDays: 7,
  /** バックアップ: 最新の READY がこれより古ければ NG。 */
  backupMaxAgeHours: 48,
} as const;

export type CheckStatus = "ok" | "ng" | "unknown";

export interface CheckItem {
  name: string;
  status: CheckStatus;
  /** 運営者向けの説明。個人情報は入れない。外からの口では返さない。 */
  detail: string;
}

/** ops_heartbeats/{関数名} を読んだもの（時刻はミリ秒）。 */
export interface HeartbeatSnapshot {
  lastRunAtMs: number | null;
  lastSuccessAtMs: number | null;
  ok: boolean | null;
  processed: number | null;
  error: string | null;
}

export type BackupInput =
  | { latestReadyMs: number | null; unreachable?: string[] }
  | { error: string };

/** 判定に使う材料。null は「数えられなかった」。 */
export interface HealthInputs {
  /** 関数名 → ハートビート。無ければ（文書が無い）キー無し、読めなければ "error"。 */
  heartbeats: Record<string, HeartbeatSnapshot | "error" | null | undefined>;
  stalePlanRequests: number | null;
  failedPlanNotifications: number | null;
  staleInspectionNotices: number | null;
  clientErrors: { lastHour: number; last7Days: number } | null;
  backup: BackupInput;
  /** 健康診断を初めて走らせた時刻。記録の無いジョブを NG にするかの起点。分からなければ null。 */
  monitoringSinceMs?: number | null;
}

export interface HealthReport {
  overall: "ok" | "ng";
  checkedAtMs: number;
  items: CheckItem[];
}

/** ops_health/latest に保存されている形（Timestamp はミリ秒に直したもの）。 */
export type StoredHealth = HealthReport;

const EMAIL = /[\w.+-]+@[\w-]+(?:\.[\w-]+)+/g;

function clean(text: string, max = 200): string {
  return text.replace(EMAIL, "[email]").replace(/\s+/g, " ").trim().slice(0, max);
}

function hoursAgo(ms: number, now: number): string {
  const h = Math.max(0, (now - ms) / HOUR_MS);
  return h < 1 ? "1 時間以内" : `${Math.floor(h)} 時間前`;
}

function safeCount(n: number): number {
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
}

/** 定期ジョブ1つの判定。 */
export function checkJob(
  job: string,
  maxAgeHours: number,
  hb: HeartbeatSnapshot | "error" | null | undefined,
  now: number,
  monitoringSinceMs: number | null = null
): CheckItem {
  const name = `job.${job}`;
  if (hb === "error") {
    return { name, status: "unknown", detail: "ハートビートを読めなかった" };
  }
  if (!hb) {
    const grace = THRESHOLDS.missingHeartbeatGraceHours;
    if (monitoringSinceMs !== null && now - monitoringSinceMs > grace * HOUR_MS) {
      return {
        name,
        status: "ng",
        detail: `監視を始めて ${grace} 時間を過ぎても記録が無い（ジョブが動いていない・消えた）`,
      };
    }
    return {
      name,
      status: "unknown",
      detail: "まだ記録が無い（デプロイ直後なら次の実行を待つ）",
    };
  }
  if (hb.ok === false) {
    const err = hb.error ? `: ${clean(hb.error)}` : "";
    const last = hb.lastRunAtMs !== null ? `（${hoursAgo(hb.lastRunAtMs, now)}）` : "";
    return { name, status: "ng", detail: `最後の実行が失敗${last}${err}` };
  }
  if (hb.lastSuccessAtMs === null) {
    return { name, status: "ng", detail: "成功の記録が無い" };
  }
  const processed = hb.processed !== null ? `・処理 ${safeCount(hb.processed)} 件` : "";
  if (now - hb.lastSuccessAtMs > maxAgeHours * HOUR_MS) {
    return {
      name,
      status: "ng",
      detail: `最後の成功が ${hoursAgo(hb.lastSuccessAtMs, now)}（許容 ${maxAgeHours} 時間）`,
    };
  }
  return {
    name,
    status: "ok",
    detail: `最後の成功: ${hoursAgo(hb.lastSuccessAtMs, now)}${processed}`,
  };
}

/** 滞留の件数の判定。1件でもあれば NG。 */
export function checkPending(
  name: string,
  label: string,
  count: number | null
): CheckItem {
  if (count === null) {
    return { name, status: "unknown", detail: "数えられなかった" };
  }
  const n = safeCount(count);
  return n > 0
    ? { name, status: "ng", detail: `${label}: ${n} 件` }
    : { name, status: "ok", detail: `${label}: 0 件` };
}

/**
 * ウェブのエラーの急増の判定。
 *
 * 平均は「直近1時間を除いた 7 日」から取る（急増そのものが平均を押し上げないように）。
 * 平均 0（データ無し・始めたばかり）なら倍率の条件は常に満たし、最低件数だけで決まる。
 * 割り算は平均の計算だけで、分母は定数なのでゼロ除算は起きない。
 */
export function checkClientErrors(
  counts: { lastHour: number; last7Days: number } | null
): CheckItem {
  const name = "client_errors.spike";
  if (counts === null) {
    return { name, status: "unknown", detail: "数えられなかった" };
  }
  const lastHour = safeCount(counts.lastHour);
  const total = safeCount(counts.last7Days);
  const baselineHours = THRESHOLDS.errorBaselineDays * 24 - 1;
  const baseline = Math.max(0, total - lastHour) / baselineHours;
  const spike =
    lastHour >= THRESHOLDS.errorSpikeMin &&
    lastHour >= THRESHOLDS.errorSpikeFactor * baseline;
  const detail =
    `直近1時間 ${lastHour} 件（${THRESHOLDS.errorBaselineDays}日の1時間平均 ` +
    `${baseline.toFixed(1)} 件）`;
  return { name, status: spike ? "ng" : "ok", detail };
}

/**
 * Firestore Admin API の backups.list の結果から、(default) の READY のうち
 * 一番新しい snapshotTime（ミリ秒）を返す。無ければ null。
 */
export function latestReadyBackupMs(
  backups: readonly unknown[],
  database = "(default)"
): number | null {
  let latest: number | null = null;
  for (const b of backups) {
    if (!b || typeof b !== "object") continue;
    const { state, database: db, snapshotTime } = b as Record<string, unknown>;
    if (state !== "READY") continue;
    if (typeof db !== "string" || !db.endsWith(`/databases/${database}`)) continue;
    if (typeof snapshotTime !== "string") continue;
    const ms = Date.parse(snapshotTime);
    if (!Number.isFinite(ms)) continue;
    if (latest === null || ms > latest) latest = ms;
  }
  return latest;
}

/** バックアップの判定。取得できなかったら unknown（NG にはしない）。 */
export function checkBackup(input: BackupInput, now: number): CheckItem {
  const name = "backup.firestore";
  if ("error" in input) {
    return {
      name,
      status: "unknown",
      detail: `バックアップの一覧を取得できなかった: ${clean(input.error)}`,
    };
  }
  const { latestReadyMs, unreachable } = input;
  if (latestReadyMs === null) {
    if (unreachable && unreachable.length > 0) {
      return {
        name,
        status: "unknown",
        detail: `一覧に届かない場所がある: ${clean(unreachable.join(", "))}`,
      };
    }
    return { name, status: "ng", detail: "READY のバックアップが1つも無い" };
  }
  const max = THRESHOLDS.backupMaxAgeHours;
  if (now - latestReadyMs > max * HOUR_MS) {
    return {
      name,
      status: "ng",
      detail: `最新の READY が ${hoursAgo(latestReadyMs, now)}（許容 ${max} 時間）`,
    };
  }
  return {
    name,
    status: "ok",
    detail: `最新の READY: ${hoursAgo(latestReadyMs, now)}`,
  };
}

/** 全体の判定。項目の順は固定（外からの口・メールで見比べやすいように）。 */
export function evaluateHealth(inputs: HealthInputs, now: number): HealthReport {
  const items: CheckItem[] = [
    ...SCHEDULED_JOBS.map((j) =>
      checkJob(
        j.name,
        j.maxAgeHours,
        inputs.heartbeats[j.name],
        now,
        inputs.monitoringSinceMs ?? null
      )
    ),
    checkPending(
      "plan_requests.pending",
      `受付中のまま ${THRESHOLDS.planRequestPendingHours} 時間を過ぎた申し込み`,
      inputs.stalePlanRequests
    ),
    checkPending(
      "plan_requests.notify_failed",
      "運営者への通知に失敗した受付中の申し込み",
      inputs.failedPlanNotifications
    ),
    checkPending(
      "inspection_notices.pending",
      `処理されないまま ${THRESHOLDS.inspectionNoticePendingHours} 時間を過ぎた車検案内`,
      inputs.staleInspectionNotices
    ),
    checkClientErrors(inputs.clientErrors),
    checkBackup(inputs.backup, now),
  ];
  const overall = items.some((i) => i.status === "ng") ? "ng" : "ok";
  return { overall, checkedAtMs: now, items };
}

/** 外からの口（opsHealth）で返す形。detail・件数の中身は返さない。 */
export interface PublicHealth {
  overall: "ok" | "ng";
  checkedAt: string;
  checkedAtMs: number;
  items: { name: string; status: CheckStatus }[];
}

const STATUSES: readonly string[] = ["ok", "ng", "unknown"];

/** 保存されている診断結果から、外に出してよいものだけを取り出す。 */
export function publicView(stored: StoredHealth): PublicHealth {
  const items: { name: string; status: CheckStatus }[] = [];
  for (const i of Array.isArray(stored.items) ? stored.items : []) {
    if (!i || typeof i !== "object" || typeof i.name !== "string") continue;
    const status = STATUSES.includes(i.status) ? i.status : "unknown";
    items.push({ name: i.name.slice(0, 100), status });
  }
  return {
    // 知らない値は ng に寄せる（見張りが見逃さない向き）
    overall: stored.overall === "ok" ? "ok" : "ng",
    checkedAt: new Date(stored.checkedAtMs).toISOString(),
    checkedAtMs: stored.checkedAtMs,
    items,
  };
}

export interface HttpResult {
  status: number;
  cacheControl: string;
  body: unknown;
}

/** 外からの口（GET /opsHealth）の本体。 */
export async function handleOpsHealthRequest(
  method: string,
  loadLatest: () => Promise<StoredHealth | null>
): Promise<HttpResult> {
  if (method !== "GET") {
    return { status: 405, cacheControl: "no-store", body: { error: "method-not-allowed" } };
  }
  let stored: StoredHealth | null;
  try {
    stored = await loadLatest();
  } catch (err) {
    console.error("ops_health/latest を読めませんでした:", err);
    return { status: 500, cacheControl: "no-store", body: { error: "unavailable" } };
  }
  if (!stored || typeof stored.checkedAtMs !== "number" || !Number.isFinite(stored.checkedAtMs)) {
    return { status: 503, cacheControl: "no-store", body: { error: "not-checked-yet" } };
  }
  return { status: 200, cacheControl: "public, max-age=60", body: publicView(stored) };
}
