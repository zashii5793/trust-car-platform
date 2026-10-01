// 法人向けの整備集計（src/fleetMaintenanceSummary.ts）のテスト。
// トリガー本体は index.ts。Firestore は差し込みで差し替える。

import {
  affectedVehicleIds,
  recomputeSummary,
  summarize,
  vehicleChangeNeedsRecompute,
  type FleetMaintenanceSummary,
  type RecordForSummary,
  type SummaryDeps,
  type VehicleForSummary,
} from "../src/fleetMaintenanceSummary";

const OWNER = "member-1";
const CAR = "car-1";
const ts = (iso: string) => ({ toMillis: () => new Date(iso).getTime() });

function rec(o: Partial<RecordForSummary> = {}): RecordForSummary {
  return { userId: OWNER, vehicleId: CAR, cost: 5000, date: ts("2026-08-01"), ...o };
}

describe("summarize", () => {
  test("最終日・合計費用・件数を出す", () => {
    const s = summarize(CAR, OWNER, [
      rec({ cost: 5000, date: ts("2026-08-01") }),
      rec({ cost: 7000, date: ts("2026-09-01") }),
    ]);
    expect(s).toEqual({
      vehicleId: CAR,
      ownerId: OWNER,
      lastMaintenanceDateMs: new Date("2026-09-01").getTime(),
      totalCost: 12000,
      recordCount: 2,
    });
  });

  test("集計の項目以外（メモ・店名など）は出さない", () => {
    const s = summarize(CAR, OWNER, [
      { ...rec(), notes: "私的なメモ", shopName: "近所の店" } as RecordForSummary,
    ]);
    expect(Object.keys(s!).sort()).toEqual(
      ["lastMaintenanceDateMs", "ownerId", "recordCount", "totalCost", "vehicleId"]
    );
  });

  test("車の持ち主以外が書いた記録は数えない（vehicleId を借りた記録で汚させない）", () => {
    const s = summarize(CAR, OWNER, [
      rec({ cost: 5000 }),
      rec({ userId: "intruder", cost: 999999, date: ts("2030-01-01") }),
    ]);
    expect(s!.totalCost).toBe(5000);
    expect(s!.recordCount).toBe(1);
    expect(s!.lastMaintenanceDateMs).toBe(new Date("2026-08-01").getTime());
  });

  test("別の車の記録は数えない", () => {
    const s = summarize(CAR, OWNER, [rec(), rec({ vehicleId: "car-2", cost: 1 })]);
    expect(s!.recordCount).toBe(1);
  });

  describe("Edge Cases", () => {
    test("記録が無ければ null", () => {
      expect(summarize(CAR, OWNER, [])).toBeNull();
    });

    test("数える記録が無ければ null（他人の記録しか無い）", () => {
      expect(summarize(CAR, OWNER, [rec({ userId: "intruder" })])).toBeNull();
    });

    test("費用が無い・負・数値でない・NaN は 0 として数える", () => {
      const s = summarize(CAR, OWNER, [
        rec({ cost: undefined }),
        rec({ cost: -100 }),
        rec({ cost: "5000" }),
        rec({ cost: Number.NaN }),
        rec({ cost: Number.POSITIVE_INFINITY }),
        rec({ cost: 0 }),
      ]);
      expect(s!.totalCost).toBe(0);
      expect(s!.recordCount).toBe(6);
    });

    test("日付の無い記録だけなら最終日は null", () => {
      const s = summarize(CAR, OWNER, [rec({ date: null }), rec({ date: "2026-01-01" })]);
      expect(s!.lastMaintenanceDateMs).toBeNull();
      expect(s!.recordCount).toBe(2);
    });

    test("Date 型の日付も読める", () => {
      const s = summarize(CAR, OWNER, [rec({ date: new Date("2026-07-07") })]);
      expect(s!.lastMaintenanceDateMs).toBe(new Date("2026-07-07").getTime());
    });

    test("大きな費用でも合計が壊れない", () => {
      const s = summarize(CAR, OWNER, [
        rec({ cost: 2_000_000_000 }),
        rec({ cost: 2_000_000_000 }),
      ]);
      expect(s!.totalCost).toBe(4_000_000_000);
    });
  });
});

describe("affectedVehicleIds", () => {
  test("作成は後ろの車だけ", () => {
    expect(affectedVehicleIds(undefined, rec())).toEqual([CAR]);
  });

  test("削除は前の車だけ", () => {
    expect(affectedVehicleIds(rec(), undefined)).toEqual([CAR]);
  });

  test("車を付け替えたら両方", () => {
    expect(affectedVehicleIds(rec(), rec({ vehicleId: "car-2" }))).toEqual([CAR, "car-2"]);
  });

  describe("Edge Cases", () => {
    test("同じ車なら1回だけ", () => {
      expect(affectedVehicleIds(rec(), rec({ cost: 1 }))).toEqual([CAR]);
    });

    test("vehicleId が空・文字列でないものは除く", () => {
      expect(affectedVehicleIds(rec({ vehicleId: "" }), rec({ vehicleId: 42 }))).toEqual([]);
      expect(affectedVehicleIds(undefined, undefined)).toEqual([]);
    });
  });
});

describe("vehicleChangeNeedsRecompute", () => {
  const v = { userId: OWNER, companyId: "admin-1" };

  test("法人に入った・抜けた・持ち主が変わった・消された・作られたときは作り直す", () => {
    expect(vehicleChangeNeedsRecompute({ ...v, companyId: null }, v)).toBe(true);
    expect(vehicleChangeNeedsRecompute(v, { ...v, companyId: null })).toBe(true);
    expect(vehicleChangeNeedsRecompute(v, { ...v, userId: "someone" })).toBe(true);
    expect(vehicleChangeNeedsRecompute(v, undefined)).toBe(true);
    expect(vehicleChangeNeedsRecompute(undefined, v)).toBe(true);
  });

  test("走行距離などの更新では作り直さない", () => {
    expect(
      vehicleChangeNeedsRecompute(
        { ...v, mileage: 1 } as VehicleForSummary,
        { ...v, mileage: 2 } as VehicleForSummary
      )
    ).toBe(false);
  });

  describe("Edge Cases", () => {
    test("companyId の未設定と null は同じとみなす", () => {
      expect(
        vehicleChangeNeedsRecompute({ userId: OWNER }, { userId: OWNER, companyId: null } as VehicleForSummary)
      ).toBe(false);
    });

    test("前後とも無ければ作り直さない", () => {
      expect(vehicleChangeNeedsRecompute(undefined, undefined)).toBe(false);
    });
  });
});

describe("recomputeSummary", () => {
  function fakeDeps(opts: {
    vehicle?: VehicleForSummary | null;
    records?: RecordForSummary[];
  } = {}) {
    const written: Record<string, FleetMaintenanceSummary> = {};
    const deleted: string[] = [];
    const deps: SummaryDeps = {
      loadVehicle: jest.fn(async () =>
        opts.vehicle === undefined ? { userId: OWNER } : opts.vehicle
      ),
      loadRecords: jest.fn(async () => opts.records ?? [rec()]),
      writeSummary: jest.fn(async (id: string, s: FleetMaintenanceSummary) => {
        written[id] = s;
      }),
      deleteSummary: jest.fn(async (id: string) => {
        deleted.push(id);
      }),
    };
    return { deps, written, deleted };
  }

  test("記録があれば集計を書く", async () => {
    const { deps, written, deleted } = fakeDeps();
    expect(await recomputeSummary(CAR, deps)).toBe("written");
    expect(written[CAR].recordCount).toBe(1);
    expect(deleted).toEqual([]);
  });

  test("記録が全部消えたら集計も消す", async () => {
    const { deps, written, deleted } = fakeDeps({ records: [] });
    expect(await recomputeSummary(CAR, deps)).toBe("deleted");
    expect(written).toEqual({});
    expect(deleted).toEqual([CAR]);
  });

  describe("Edge Cases", () => {
    test("車が消されていたら集計を消し、記録は読まない", async () => {
      const { deps, deleted } = fakeDeps({ vehicle: null });
      expect(await recomputeSummary(CAR, deps)).toBe("deleted");
      expect(deleted).toEqual([CAR]);
      expect(deps.loadRecords).not.toHaveBeenCalled();
    });

    test("車の持ち主が分からなければ集計を消す", async () => {
      const { deps, deleted } = fakeDeps({ vehicle: { userId: "" } });
      expect(await recomputeSummary(CAR, deps)).toBe("deleted");
      expect(deleted).toEqual([CAR]);
    });

    test("書き込みの失敗はそのまま投げる（トリガーのログに残す）", async () => {
      const { deps } = fakeDeps();
      deps.writeSummary = jest.fn(async () => {
        throw new Error("unavailable");
      });
      await expect(recomputeSummary(CAR, deps)).rejects.toThrow("unavailable");
    });
  });
});
