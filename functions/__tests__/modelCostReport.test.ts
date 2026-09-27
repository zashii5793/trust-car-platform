// 車種別の維持費レポートの集計。
//
// 間違え方で害が大きいのは2つ:
//   1. 少人数の数字を出してしまう（個人が特定される）
//   2. 1社の大量の車で、その車種の数字が1社の数字になる
// どちらも必ず確かめる。

import {
  MIN_OWNERS,
  buildAllReports,
  classifyType,
  normalizeKey,
  stat,
  type CostEvent,
  type CostVehicle,
} from "../src/modelCostReport";

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.UTC(2026, 8, 27);

function vehicle(
  i: number,
  overrides: Partial<CostVehicle> = {}
): CostVehicle {
  return {
    key: `u:v${i}`,
    ownerKey: `u:owner${i}`,
    maker: "MINI",
    model: "クーパー",
    year: 2019,
    source: "app",
    ...overrides,
  };
}

/// 2年分の記録: 年2回の整備（各 20,000円）と、車検1回（100,000円）、
/// 月1回の給油（各 6,000円）。
function twoYears(vehicleKey: string, scale = 1): CostEvent[] {
  const start = NOW - 2 * 365 * DAY;
  const events: CostEvent[] = [];
  for (let m = 0; m < 24; m++) {
    events.push({
      vehicleKey,
      date: start + m * 30 * DAY,
      cost: 6000 * scale,
      kind: "fuel",
      type: "給油",
    });
  }
  for (let k = 0; k < 4; k++) {
    events.push({
      vehicleKey,
      date: start + k * 180 * DAY,
      cost: 20000 * scale,
      kind: "maintenance",
      type: "オイル交換",
    });
  }
  events.push({
    vehicleKey,
    date: start + 400 * DAY,
    cost: 100000 * scale,
    kind: "inspection",
    type: "車検",
  });
  return events;
}

describe("normalizeKey", () => {
  // アプリ側（test/models/model_cost_report_test.dart）も同じ表を読む。
  // ずれると、アプリが引くIDとここで書くIDが食い違う。
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const vectors: [string, string][] = require("./model_cost_key_vectors.json");

  it.each(vectors)("%j → %j", (input, expected) => {
    expect(normalizeKey(input)).toBe(expected);
  });
});

describe("classifyType", () => {
  it("アプリの車検の種別と、店の「車検」を車検に分ける", () => {
    expect(classifyType("carInspection")).toBe("inspection");
    expect(classifyType("legalInspection24")).toBe("inspection");
    expect(classifyType("車検整備")).toBe("inspection");
    expect(classifyType("oilChange")).toBe("maintenance");
    // 12か月点検は車検ではない
    expect(classifyType("legalInspection12")).toBe("maintenance");
  });
});

describe("stat", () => {
  it(`${MIN_OWNERS}件未満なら出さない`, () => {
    expect(stat([1, 2, 3, 4])).toBeNull();
  });

  it("中央値と四分位", () => {
    expect(stat([10, 20, 30, 40, 50])).toEqual({
      median: 30,
      p25: 20,
      p75: 40,
      n: 5,
    });
  });
});

describe("buildAllReports", () => {
  it(`持ち主が${MIN_OWNERS}人いれば、車種のレポートが出る`, () => {
    const vehicles = Array.from({ length: 5 }, (_, i) => vehicle(i));
    const events = vehicles.flatMap((v) => twoYears(v.key));

    const reports = buildAllReports(vehicles, events, NOW);
    const r = reports.find((x) => x.level === "model")!;

    expect(r.maker).toBe("MINI");
    expect(r.model).toBe("クーパー");
    expect(r.ownerCount).toBe(5);
    // 整備 80,000円 / 2年 ≒ 年 40,000円
    expect(r.maintenanceAnnual!.median).toBeGreaterThan(38000);
    expect(r.maintenanceAnnual!.median).toBeLessThan(42000);
    expect(r.inspectionPerEvent!.median).toBe(100000);
    // 燃料 144,000円 / 2年 ≒ 年 72,000円
    expect(r.fuelAnnual!.median).toBeGreaterThan(70000);
    // 目安 = 整備 + 車検/2 + 燃料
    expect(r.annualEstimate).toBe(
      r.maintenanceAnnual!.median + 50000 + r.fuelAnnual!.median
    );
  });

  it(`持ち主が${MIN_OWNERS - 1}人しかいなければ、何も出さない（個人が特定される）`, () => {
    const vehicles = Array.from({ length: MIN_OWNERS - 1 }, (_, i) =>
      vehicle(i)
    );
    const events = vehicles.flatMap((v) => twoYears(v.key));
    expect(buildAllReports(vehicles, events, NOW)).toEqual([]);
  });

  it("1社が20台持っていても、持ち主1人として数える", () => {
    // 1社で20台（高い）＋ 個人4人（安い）＝ 持ち主5人
    const fleet = Array.from({ length: 20 }, (_, i) =>
      vehicle(100 + i, { ownerKey: "s:shop1:bigcorp", source: "shop" })
    );
    const people = Array.from({ length: 4 }, (_, i) => vehicle(i));
    const events = [
      ...fleet.flatMap((v) => twoYears(v.key, 10)),
      ...people.flatMap((v) => twoYears(v.key, 1)),
    ];

    const r = buildAllReports([...fleet, ...people], events, NOW).find(
      (x) => x.level === "model"
    )!;

    expect(r.ownerCount).toBe(5);
    expect(r.vehicleCount).toBe(24);
    // 中央値は個人側（1社の20台に引っぱられない）
    expect(r.maintenanceAnnual!.median).toBeLessThan(42000);
    expect(r.sources).toEqual({ app: 4, shop: 1 });
  });

  it("記録が1年に満たない車は、年あたりの数字に使わない", () => {
    const vehicles = Array.from({ length: 5 }, (_, i) => vehicle(i));
    // 5人とも3か月分しかない
    const events: CostEvent[] = vehicles.flatMap((v) => [
      { vehicleKey: v.key, date: NOW - 90 * DAY, cost: 100000, kind: "inspection", type: "車検" },
      { vehicleKey: v.key, date: NOW - 10 * DAY, cost: 5000, kind: "maintenance", type: "オイル交換" },
    ]);

    const r = buildAllReports(vehicles, events, NOW).find(
      (x) => x.level === "model"
    )!;

    // 車検1回あたりは出せる（回数あたりなので期間に依らない）
    expect(r.inspectionPerEvent!.median).toBe(100000);
    // 年あたりは出さない。3か月の数字を4倍して出すと、嘘になる
    expect(r.maintenanceAnnual).toBeNull();
    expect(r.annualEstimate).toBeNull();
  });

  it("車種で足りなくても、メーカーで足りればメーカーのレポートが出る", () => {
    const models = ["クーパー", "クロスオーバー", "クラブマン", "クーパー", "ワン"];
    const vehicles = models.map((model, i) => vehicle(i, { model }));
    const events = vehicles.flatMap((v) => twoYears(v.key));

    const reports = buildAllReports(vehicles, events, NOW);

    expect(reports.filter((r) => r.level === "model")).toEqual([]);
    const maker = reports.find((r) => r.level === "maker")!;
    expect(maker.maker).toBe("MINI");
    expect(maker.model).toBeNull();
    expect(maker.ownerCount).toBe(5);
  });

  it("表記が揺れていても同じ車種にまとめ、多い方の表記で出す", () => {
    const spellings = ["クーパー", "クーパー", "クーパー", "くーぱー", "クーパー "];
    const vehicles = spellings.map((model, i) => vehicle(i, { model }));
    const events = vehicles.flatMap((v) => twoYears(v.key));

    const r = buildAllReports(vehicles, events, NOW).find(
      (x) => x.level === "model"
    )!;
    expect(r.ownerCount).toBe(5);
    expect(r.model).toBe("クーパー");
  });

  it("年数ごとの費用は、丸1年見えている暦年だけで出す", () => {
    // 2019年式を 2024-09〜2026-09 の2年分見る。丸1年見えているのは
    // 2025年だけ（= 7年目）。2024年・2026年は途中までしか見えていない
    const vehicles = Array.from({ length: 5 }, (_, i) => vehicle(i));
    const events = vehicles.flatMap((v) => twoYears(v.key));

    const r = buildAllReports(vehicles, events, NOW).find(
      (x) => x.level === "model"
    )!;

    expect(r.byAge.map((b) => b.label)).toEqual(["7〜9年目"]);
  });

  it("記録の無い暦年は、0円の年として数える（何もしなかった年も1年）", () => {
    // 2021-01 から 2026-09 まで見ていて、費用は2022年に1回だけ
    const vehicles = Array.from({ length: 5 }, (_, i) =>
      vehicle(i, { year: 2020 })
    );
    const events: CostEvent[] = vehicles.flatMap((v) => [
      { vehicleKey: v.key, date: Date.UTC(2021, 0, 5), cost: 1000, kind: "maintenance", type: "点検" },
      { vehicleKey: v.key, date: Date.UTC(2022, 5, 1), cost: 60000, kind: "maintenance", type: "修理" },
      { vehicleKey: v.key, date: Date.UTC(2026, 8, 1), cost: 1000, kind: "maintenance", type: "点検" },
    ]);
    const r = buildAllReports(vehicles, events, NOW).find(
      (x) => x.level === "model"
    )!;
    // 丸1年見えているのは 2022〜2025（3〜6年目）。
    // 〜3年目 = 2022（3年目）だけ → 60,000円
    // 4〜6年目 = 2023〜2025 の0円
    expect(r.byAge.find((b) => b.label === "〜3年目")!.median).toBe(60000);
    expect(r.byAge.find((b) => b.label === "4〜6年目")!.median).toBe(0);
  });

  it("よくある整備を、持ち主の多い順に出す", () => {
    const vehicles = Array.from({ length: 5 }, (_, i) => vehicle(i));
    const events = vehicles.flatMap((v) => twoYears(v.key));

    const r = buildAllReports(vehicles, events, NOW).find(
      (x) => x.level === "model"
    )!;
    expect(r.topItems.map((t) => t.type)).toEqual(
      expect.arrayContaining(["オイル交換", "車検"])
    );
    expect(r.topItems.find((t) => t.type === "オイル交換")!.medianCost).toBe(20000);
    // 燃料は「整備」ではないので出さない
    expect(r.topItems.map((t) => t.type)).not.toContain("給油");
  });

  describe("Edge Cases", () => {
    it("車も記録も無ければ空", () => {
      expect(buildAllReports([], [], NOW)).toEqual([]);
    });

    it("記録の無い車は、持ち主に数えない", () => {
      const vehicles = Array.from({ length: 10 }, (_, i) => vehicle(i));
      // 記録があるのは4人だけ
      const events = vehicles.slice(0, 4).flatMap((v) => twoYears(v.key));
      expect(buildAllReports(vehicles, events, NOW)).toEqual([]);
    });

    it("未来の日付・0円の記録は使わない", () => {
      const vehicles = Array.from({ length: 5 }, (_, i) => vehicle(i));
      const events: CostEvent[] = vehicles.flatMap((v) => [
        ...twoYears(v.key),
        { vehicleKey: v.key, date: NOW + 30 * DAY, cost: 9_999_999, kind: "maintenance", type: "予約" },
        { vehicleKey: v.key, date: NOW - DAY, cost: 0, kind: "maintenance", type: "無料点検" },
      ]);
      const r = buildAllReports(vehicles, events, NOW).find(
        (x) => x.level === "model"
      )!;
      expect(r.maintenanceAnnual!.median).toBeLessThan(42000);
      expect(r.topItems.map((t) => t.type)).not.toContain("予約");
      expect(r.topItems.map((t) => t.type)).not.toContain("無料点検");
    });

    it("手放した車は、手放した日までで割る", () => {
      const vehicles = Array.from({ length: 5 }, (_, i) =>
        vehicle(i, { retiredAt: NOW - 365 * DAY })
      );
      // 記録は手放す前の1年+α だけ
      const start = NOW - 2 * 365 * DAY - 10 * DAY;
      const events: CostEvent[] = vehicles.flatMap((v) => [
        { vehicleKey: v.key, date: start, cost: 30000, kind: "maintenance", type: "オイル交換" },
        { vehicleKey: v.key, date: start + 300 * DAY, cost: 30000, kind: "maintenance", type: "オイル交換" },
      ]);
      const r = buildAllReports(vehicles, events, NOW).find(
        (x) => x.level === "model"
      )!;
      // 60,000円を「今日まで2年」で割ると30,000円になるが、
      // 手放した日までの約1年で割るので約60,000円
      expect(r.maintenanceAnnual!.median).toBeGreaterThan(55000);
    });

    it("メーカーか車種が空の車は数えない", () => {
      const vehicles = Array.from({ length: 5 }, (_, i) =>
        vehicle(i, { model: "  " })
      );
      const events = vehicles.flatMap((v) => twoYears(v.key));
      expect(
        buildAllReports(vehicles, events, NOW).filter((r) => r.level === "model")
      ).toEqual([]);
    });
  });
});
