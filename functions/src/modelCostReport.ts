// 車種別の維持費レポート（docs/SHOP_CRM_DESIGN_2026-09-27.md §8）。
//
// 「Mini クーパーを買ったら、年にいくらかかるか」を、実際の記録から出す。
//
// 集めるもの:
//   1. アプリ利用者の整備記録と給油記録
//   2. 統計への利用に同意した店の整備実績（shops/{id}/service_records）
//
// 守ること:
//   - 持ち主が MIN_OWNERS 人に満たない数字は出さない（個人が特定される）。
//     車種で足りなければメーカー単位に広げ、それでも足りなければ出さない
//   - 1社が同じ車を何十台も持っていても、その会社の数字にならないよう、
//     持ち主ごとに1つの値にまとめてから数える
//   - 1年分の記録が無い車は、年あたりの数字に使わない（3か月で車検を
//     1回受けた車を「年に4回車検」と数えない）
//
// ここは Firestore に触らない純粋な計算だけ。読み書きは index.ts。

export const MIN_OWNERS = 5;

/// 1年分の記録が無い車は、年あたりの数字に使わない。
export const MIN_OBSERVED_DAYS = 365;

const DAY = 24 * 60 * 60 * 1000;
const YEAR = 365.25 * DAY;

export type CostKind = "inspection" | "maintenance" | "fuel";

export interface CostVehicle {
  /// 一意なキー（アプリ: "u:{vehicleId}", 店: "s:{shopId}:{vehicleId}"）。
  key: string;
  /// 持ち主（アプリ: "u:{userId}", 店: "s:{shopId}:{customerId}"）。
  ownerKey: string;
  maker: string;
  model: string;
  /// 年式（西暦）。わからなければ undefined。
  year?: number;
  /// 手放した日（ms）。それ以降は観測していない。
  retiredAt?: number;
  source: "app" | "shop";
}

export interface CostEvent {
  vehicleKey: string;
  /// ms
  date: number;
  cost: number;
  kind: CostKind;
  /// 整備の種類（表示用）。
  type: string;
}

export interface Stat {
  median: number;
  p25: number;
  p75: number;
  n: number;
}

export interface AgeBucket {
  label: string;
  minAge: number;
  maxAge: number | null;
  median: number;
  n: number;
}

export interface TopItem {
  type: string;
  owners: number;
  medianCost: number;
}

export interface ModelCostReport {
  id: string;
  level: "model" | "maker";
  maker: string;
  model: string | null;
  makerKey: string;
  modelKey: string | null;
  ownerCount: number;
  vehicleCount: number;
  /// 車検以外の整備（年あたり）
  maintenanceAnnual: Stat | null;
  /// 車検1回あたり
  inspectionPerEvent: Stat | null;
  /// 燃料（年あたり）。店の実績には入っていないので、アプリ利用者だけ。
  fuelAnnual: Stat | null;
  /// 年あたりの目安 = 整備 + 車検/2 + 燃料（出せるものだけ足す）
  annualEstimate: number | null;
  byAge: AgeBucket[];
  topItems: TopItem[];
  sources: { app: number; shop: number };
}

/// 表記の揺れを揃えたキー（全角/半角・大文字/小文字・空白・カタカナ/ひらがな）。
export function normalizeKey(s: string): string {
  const nfkc = s.normalize("NFKC").toLowerCase().replace(/\s+/g, "");
  let out = "";
  for (const ch of nfkc) {
    const code = ch.codePointAt(0)!;
    // カタカナ → ひらがな
    out +=
      code >= 0x30a1 && code <= 0x30f6
        ? String.fromCodePoint(code - 0x60)
        : ch;
  }
  // Firestore のドキュメントIDに / は使えない
  return out.replace(/\//g, "_");
}

/// アプリの整備種別（MaintenanceType.name）と、店の実績の種別を分類する。
export function classifyType(type: string): CostKind {
  const t = type.toLowerCase();
  if (
    t === "carinspection" ||
    t === "legalinspection24" ||
    t.includes("車検")
  ) {
    return "inspection";
  }
  return "maintenance";
}

export function stat(values: number[]): Stat | null {
  if (values.length < MIN_OWNERS) return null;
  const v = [...values].sort((a, b) => a - b);
  return {
    median: Math.round(quantile(v, 0.5)),
    p25: Math.round(quantile(v, 0.25)),
    p75: Math.round(quantile(v, 0.75)),
    n: v.length,
  };
}

function quantile(sorted: number[], q: number): number {
  const pos = (sorted.length - 1) * q;
  const lo = Math.floor(pos);
  const hi = Math.ceil(pos);
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

function mean(values: number[]): number {
  return values.reduce((a, b) => a + b, 0) / values.length;
}

/// 持ち主ごとに1つの値にまとめる（同じ持ち主の複数台は平均）。
function perOwner(
  entries: { ownerKey: string; value: number }[]
): number[] {
  const byOwner = new Map<string, number[]>();
  for (const e of entries) {
    const list = byOwner.get(e.ownerKey) ?? [];
    list.push(e.value);
    byOwner.set(e.ownerKey, list);
  }
  return [...byOwner.values()].map(mean);
}

const AGE_BUCKETS: { label: string; min: number; max: number | null }[] = [
  { label: "〜3年目", min: 0, max: 3 },
  { label: "4〜6年目", min: 4, max: 6 },
  { label: "7〜9年目", min: 7, max: 9 },
  { label: "10年目〜", min: 10, max: null },
];

export interface VehicleFacts {
  vehicle: CostVehicle;
  events: CostEvent[];
  observedYears: number | null;
  /// 観測の始まりと終わり（ms）。記録が無ければ null。
  observedFrom: number | null;
  observedTo: number | null;
}

function factsOf(
  vehicles: CostVehicle[],
  eventsByVehicle: Map<string, CostEvent[]>,
  now: number
): VehicleFacts[] {
  return vehicles.map((vehicle) => {
    const events = (eventsByVehicle.get(vehicle.key) ?? []).filter(
      (e) => e.cost > 0 && e.date <= now
    );
    if (events.length === 0) {
      return {
        vehicle,
        events,
        observedYears: null,
        observedFrom: null,
        observedTo: null,
      };
    }
    const start = Math.min(...events.map((e) => e.date));
    const end = Math.min(now, vehicle.retiredAt ?? now);
    const days = (end - start) / DAY;
    return {
      vehicle,
      events,
      observedYears: days >= MIN_OBSERVED_DAYS ? (end - start) / YEAR : null,
      observedFrom: start,
      observedTo: end,
    };
  });
}

/// 1つの車種（またはメーカー）について、レポートを組み立てる。
/// 持ち主が MIN_OWNERS に満たなければ null。
export function buildReport(
  id: string,
  level: "model" | "maker",
  facts: VehicleFacts[],
  displayMaker: string,
  displayModel: string | null,
  makerKey: string,
  modelKey: string | null
): ModelCostReport | null {
  const withData = facts.filter((f) => f.events.length > 0);
  const owners = new Set(withData.map((f) => f.vehicle.ownerKey));
  if (owners.size < MIN_OWNERS) return null;

  const maint: { ownerKey: string; value: number }[] = [];
  const fuel: { ownerKey: string; value: number }[] = [];
  const insp: { ownerKey: string; value: number }[] = [];
  const ageEntries = new Map<number, { ownerKey: string; value: number }[]>();
  const itemEntries = new Map<string, { ownerKey: string; value: number }[]>();

  for (const f of withData) {
    const ownerKey = f.vehicle.ownerKey;

    const inspections = f.events.filter((e) => e.kind === "inspection");
    if (inspections.length > 0) {
      insp.push({ ownerKey, value: mean(inspections.map((e) => e.cost)) });
    }

    for (const e of f.events) {
      if (e.kind === "fuel") continue;
      const list = itemEntries.get(e.type) ?? [];
      list.push({ ownerKey, value: e.cost });
      itemEntries.set(e.type, list);
    }

    if (f.observedYears !== null) {
      const years = f.observedYears;
      const m = f.events
        .filter((e) => e.kind === "maintenance")
        .reduce((a, e) => a + e.cost, 0);
      maint.push({ ownerKey, value: m / years });
      const fuelEvents = f.events.filter((e) => e.kind === "fuel");
      if (fuelEvents.length > 0) {
        fuel.push({
          ownerKey,
          value: fuelEvents.reduce((a, e) => a + e.cost, 0) / years,
        });
      }
    }

    // 年数ごと: 暦年ごとの（燃料を除く）費用。年式が分からない車は使わない。
    // **丸1年見えている暦年だけ**を使う。記録を付け始めた年・今年は
    // 途中までしか見えていないので、足すと低く出る。
    const year = f.vehicle.year;
    if (
      year !== undefined &&
      f.observedFrom !== null &&
      f.observedTo !== null
    ) {
      const firstFull = new Date(f.observedFrom).getUTCFullYear() + 1;
      const lastFull = new Date(f.observedTo).getUTCFullYear() - 1;
      const byCalendarYear = new Map<number, number>();
      for (let y = firstFull; y <= lastFull; y++) byCalendarYear.set(y, 0);
      for (const e of f.events) {
        if (e.kind === "fuel") continue;
        const y = new Date(e.date).getUTCFullYear();
        if (!byCalendarYear.has(y)) continue;
        byCalendarYear.set(y, byCalendarYear.get(y)! + e.cost);
      }
      for (const [y, cost] of byCalendarYear) {
        const age = y - year + 1; // 登録した年を1年目と数える
        if (age < 1) continue;
        const list = ageEntries.get(age) ?? [];
        list.push({ ownerKey, value: cost });
        ageEntries.set(age, list);
      }
    }
  }

  const maintenanceAnnual = stat(perOwner(maint));
  const inspectionPerEvent = stat(perOwner(insp));
  const fuelAnnual = stat(perOwner(fuel));

  const parts: number[] = [];
  if (maintenanceAnnual) parts.push(maintenanceAnnual.median);
  if (inspectionPerEvent) parts.push(inspectionPerEvent.median / 2);
  if (fuelAnnual) parts.push(fuelAnnual.median);
  const annualEstimate =
    maintenanceAnnual === null ? null : Math.round(parts.reduce((a, b) => a + b, 0));

  const byAge: AgeBucket[] = [];
  for (const b of AGE_BUCKETS) {
    const entries: { ownerKey: string; value: number }[] = [];
    for (const [age, list] of ageEntries) {
      if (age >= b.min && (b.max === null || age <= b.max)) entries.push(...list);
    }
    const s = stat(perOwner(entries));
    if (s) {
      byAge.push({
        label: b.label,
        minAge: b.min,
        maxAge: b.max,
        median: s.median,
        n: s.n,
      });
    }
  }

  const topItems: TopItem[] = [...itemEntries.entries()]
    .map(([type, list]) => {
      const values = perOwner(list);
      const sorted = [...values].sort((a, b) => a - b);
      return {
        type,
        owners: values.length,
        medianCost: Math.round(quantile(sorted, 0.5)),
      };
    })
    .filter((t) => t.owners >= MIN_OWNERS)
    .sort((a, b) => b.owners - a.owners)
    .slice(0, 8);

  const appOwners = new Set(
    withData.filter((f) => f.vehicle.source === "app").map((f) => f.vehicle.ownerKey)
  );
  const shopOwners = new Set(
    withData.filter((f) => f.vehicle.source === "shop").map((f) => f.vehicle.ownerKey)
  );

  return {
    id,
    level,
    maker: displayMaker,
    model: displayModel,
    makerKey,
    modelKey,
    ownerCount: owners.size,
    vehicleCount: withData.length,
    maintenanceAnnual,
    inspectionPerEvent,
    fuelAnnual,
    annualEstimate,
    byAge,
    topItems,
    sources: { app: appOwners.size, shop: shopOwners.size },
  };
}

/// いちばん多く使われている表記を、表示名にする。
function mostCommon(values: string[]): string {
  const counts = new Map<string, number>();
  for (const v of values) counts.set(v, (counts.get(v) ?? 0) + 1);
  return [...counts.entries()].sort((a, b) => b[1] - a[1])[0][0];
}

/// すべての車種・メーカーのレポートを作る。出せないもの（持ち主が足りない）は含めない。
export function buildAllReports(
  vehicles: CostVehicle[],
  events: CostEvent[],
  now: number
): ModelCostReport[] {
  const eventsByVehicle = new Map<string, CostEvent[]>();
  for (const e of events) {
    const list = eventsByVehicle.get(e.vehicleKey) ?? [];
    list.push(e);
    eventsByVehicle.set(e.vehicleKey, list);
  }
  const facts = factsOf(vehicles, eventsByVehicle, now);

  const byModel = new Map<string, VehicleFacts[]>();
  const byMaker = new Map<string, VehicleFacts[]>();
  for (const f of facts) {
    const makerKey = normalizeKey(f.vehicle.maker);
    const modelKey = normalizeKey(f.vehicle.model);
    if (!makerKey || !modelKey) continue;
    const mk = `${makerKey}__${modelKey}`;
    // 配列を毎回作り直すと、台数の2乗で遅くなる
    if (!byModel.has(mk)) byModel.set(mk, []);
    byModel.get(mk)!.push(f);
    if (!byMaker.has(makerKey)) byMaker.set(makerKey, []);
    byMaker.get(makerKey)!.push(f);
  }

  const reports: ModelCostReport[] = [];
  for (const [id, list] of byModel) {
    const [makerKey, modelKey] = id.split("__");
    const r = buildReport(
      id,
      "model",
      list,
      mostCommon(list.map((f) => f.vehicle.maker)),
      mostCommon(list.map((f) => f.vehicle.model)),
      makerKey,
      modelKey
    );
    if (r) reports.push(r);
  }
  for (const [makerKey, list] of byMaker) {
    const r = buildReport(
      makerKey,
      "maker",
      list,
      mostCommon(list.map((f) => f.vehicle.maker)),
      null,
      makerKey,
      null
    );
    if (r) reports.push(r);
  }
  return reports;
}
