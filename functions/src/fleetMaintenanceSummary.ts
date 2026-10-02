// 法人（フリート）向けの整備集計（Issue #192）。
//
// 法人の管理者は、メンバーの車の整備記録（maintenance_records）を直接は
// 読めない（ルールで本人だけ）。フリート画面の CSV に要るのは
// 「最終整備日・合計費用・件数」だけなので、それだけを
// fleet_maintenance_summaries/{vehicleId} に書き出す。
//
// - 書くのはここ（Admin SDK）だけ。クライアントはルールで書けない
// - 集計に入れるのは「車の持ち主（vehicles.userId）の記録」だけ。
//   maintenance_records の作成ルールは車の持ち主かどうかを見ていないので、
//   他人が vehicleId だけ借りて書いた記録で集計を汚せないようにする
// - 誰が読めるかはルールが「いまの車の文書」で決める（法人を抜けたら即座に
//   読めなくなる）。ここで companyId を写さないのはそのため
//
// Firebase のトリガー本体は index.ts。ここは依存を差し込める純粋な処理だけ
// （notifyPlanRequest.ts と同じ作り）。

/** 集計の出力先コレクション。 */
export const SUMMARY_COLLECTION = "fleet_maintenance_summaries";

/** 集計に使う整備記録の項目（maintenance_records の一部）。 */
export interface RecordForSummary {
  userId?: unknown;
  vehicleId?: unknown;
  cost?: unknown;
  /** Firestore の Timestamp（toMillis を持つ）。 */
  date?: unknown;
}

/** 車の文書のうち、集計に要る項目。 */
export interface VehicleForSummary {
  userId?: unknown;
}

/** fleet_maintenance_summaries/{vehicleId} の中身（updatedAt は書くときに足す）。 */
export interface FleetMaintenanceSummary {
  vehicleId: string;
  ownerId: string;
  /** 最終整備日（epoch ミリ秒）。日付の無い記録しか無ければ null。 */
  lastMaintenanceDateMs: number | null;
  totalCost: number;
  recordCount: number;
}

function toMillis(v: unknown): number | null {
  if (v && typeof (v as { toMillis?: unknown }).toMillis === "function") {
    return (v as { toMillis(): number }).toMillis();
  }
  if (v instanceof Date) return v.getTime();
  return null;
}

function toCost(v: unknown): number {
  // 負の値・NaN・無限大は 0 として扱う（打ち間違いで合計を壊さない）
  if (typeof v !== "number" || !Number.isFinite(v) || v < 0) return 0;
  return Math.round(v);
}

/**
 * 1台ぶんの記録から集計を作る。持ち主以外の記録・別の車の記録は数えない。
 * 数える記録が1件も無ければ null（集計の文書は置かない）。
 */
export function summarize(
  vehicleId: string,
  ownerId: string,
  records: RecordForSummary[]
): FleetMaintenanceSummary | null {
  let last: number | null = null;
  let total = 0;
  let count = 0;
  for (const r of records) {
    if (r.userId !== ownerId || r.vehicleId !== vehicleId) continue;
    count++;
    total += toCost(r.cost);
    const ms = toMillis(r.date);
    if (ms !== null && (last === null || ms > last)) last = ms;
  }
  if (count === 0) return null;
  return {
    vehicleId,
    ownerId,
    lastMaintenanceDateMs: last,
    totalCost: total,
    recordCount: count,
  };
}

/** 記録の書き込み前後から、集計し直す車の ID を出す（重複・空は除く）。 */
export function affectedVehicleIds(
  before: RecordForSummary | undefined,
  after: RecordForSummary | undefined
): string[] {
  const ids = new Set<string>();
  for (const r of [before, after]) {
    if (typeof r?.vehicleId === "string" && r.vehicleId !== "") {
      ids.add(r.vehicleId);
    }
  }
  return [...ids];
}

/** 車の書き込みのうち、集計を作り直す必要があるもの（持ち主・法人の変更、削除）。 */
export function vehicleChangeNeedsRecompute(
  before: (VehicleForSummary & { companyId?: unknown }) | undefined,
  after: (VehicleForSummary & { companyId?: unknown }) | undefined
): boolean {
  if (!after) return before !== undefined;
  if (!before) return true;
  return (
    before.userId !== after.userId ||
    (before.companyId ?? null) !== (after.companyId ?? null)
  );
}

export interface SummaryDeps {
  loadVehicle(vehicleId: string): Promise<VehicleForSummary | null>;
  /** その車の ID が付いた記録をすべて返す（Admin SDK なので持ち主以外も含む）。 */
  loadRecords(vehicleId: string): Promise<RecordForSummary[]>;
  writeSummary(vehicleId: string, summary: FleetMaintenanceSummary): Promise<void>;
  deleteSummary(vehicleId: string): Promise<void>;
}

export type RecomputeResult = "written" | "deleted";

/**
 * 1台ぶんの集計を作り直す。車が無い・持ち主が分からない・数える記録が
 * 無いときは集計の文書を消す。
 */
export async function recomputeSummary(
  vehicleId: string,
  deps: SummaryDeps
): Promise<RecomputeResult> {
  const vehicle = await deps.loadVehicle(vehicleId);
  const ownerId = vehicle?.userId;
  if (typeof ownerId !== "string" || ownerId === "") {
    await deps.deleteSummary(vehicleId);
    return "deleted";
  }
  const summary = summarize(vehicleId, ownerId, await deps.loadRecords(vehicleId));
  if (summary === null) {
    await deps.deleteSummary(vehicleId);
    return "deleted";
  }
  await deps.writeSummary(vehicleId, summary);
  return "written";
}
