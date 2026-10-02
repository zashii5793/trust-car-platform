// 健康診断（src/opsHealth.ts）のテスト。
// 判定は純粋な関数。Firestore・Firestore Admin API の読み取りは index.ts。

import {
  HOUR_MS,
  SCHEDULED_JOBS,
  THRESHOLDS,
  checkBackup,
  checkClientErrors,
  checkJob,
  checkPending,
  evaluateHealth,
  handleOpsHealthRequest,
  latestReadyBackupMs,
  publicView,
  type HealthInputs,
  type HeartbeatSnapshot,
  type StoredHealth,
} from "../src/opsHealth";

const NOW = Date.parse("2026-10-02T01:00:00Z");

function hb(overrides: Partial<HeartbeatSnapshot> = {}): HeartbeatSnapshot {
  return {
    lastRunAtMs: NOW - 2 * HOUR_MS,
    lastSuccessAtMs: NOW - 2 * HOUR_MS,
    ok: true,
    processed: 3,
    error: null,
    ...overrides,
  };
}

describe("SCHEDULED_JOBS", () => {
  it("定期の Functions 3つを、日次ジョブとして 26 時間で見る", () => {
    expect(SCHEDULED_JOBS).toEqual([
      { name: "purgeDeletedAccounts", maxAgeHours: 26 },
      { name: "purgeExpiredShares", maxAgeHours: 26 },
      { name: "aggregateModelCosts", maxAgeHours: 26 },
    ]);
  });
});

describe("checkJob", () => {
  it("許容時間内に成功していれば ok", () => {
    const item = checkJob("purgeDeletedAccounts", 26, hb(), NOW);
    expect(item.name).toBe("job.purgeDeletedAccounts");
    expect(item.status).toBe("ok");
  });

  it("最後の実行が失敗なら ng（error の先頭を detail に出す）", () => {
    const item = checkJob(
      "purgeDeletedAccounts",
      26,
      hb({ ok: false, error: "DEADLINE_EXCEEDED" }),
      NOW
    );
    expect(item.status).toBe("ng");
    expect(item.detail).toContain("DEADLINE_EXCEEDED");
  });

  it("最後の成功が許容時間より古ければ ng", () => {
    const item = checkJob(
      "aggregateModelCosts",
      26,
      hb({ lastSuccessAtMs: NOW - 27 * HOUR_MS }),
      NOW
    );
    expect(item.status).toBe("ng");
    expect(item.detail).toContain("27");
  });

  describe("Edge Cases", () => {
    it("ちょうど許容時間なら ok、1ミリ秒でも過ぎたら ng", () => {
      const at = (ms: number) =>
        checkJob("x", 26, hb({ lastSuccessAtMs: ms }), NOW).status;
      expect(at(NOW - 26 * HOUR_MS)).toBe("ok");
      expect(at(NOW - 26 * HOUR_MS - 1)).toBe("ng");
    });

    it("ハートビートが無い（デプロイ直後）なら unknown（NG にはしない）", () => {
      expect(checkJob("x", 26, null, NOW).status).toBe("unknown");
    });

    it("読み取りに失敗したら unknown", () => {
      expect(checkJob("x", 26, "error", NOW).status).toBe("unknown");
    });

    it("文書はあるのに成功の記録が無い（失敗しかしていない）なら ng", () => {
      const item = checkJob(
        "x",
        26,
        hb({ ok: false, lastSuccessAtMs: null, error: null }),
        NOW
      );
      expect(item.status).toBe("ng");
    });

    it("時計のずれで未来の時刻でも ok", () => {
      expect(
        checkJob("x", 26, hb({ lastSuccessAtMs: NOW + HOUR_MS }), NOW).status
      ).toBe("ok");
    });

    it("ok が無い古い形でも、成功が新しければ ok", () => {
      expect(checkJob("x", 26, hb({ ok: null }), NOW).status).toBe("ok");
    });
  });
});

describe("checkPending", () => {
  it("0 件なら ok、1 件以上なら ng（件数を detail に出す）", () => {
    expect(checkPending("plan_requests.pending", "受付中のまま", 0).status).toBe(
      "ok"
    );
    const ng = checkPending("plan_requests.pending", "受付中のまま", 2);
    expect(ng.status).toBe("ng");
    expect(ng.detail).toContain("2");
  });

  describe("Edge Cases", () => {
    it("数えられなかった（null）なら unknown", () => {
      expect(checkPending("x", "y", null).status).toBe("unknown");
    });

    it("負の数・NaN は 0 とみなす", () => {
      expect(checkPending("x", "y", -1).status).toBe("ok");
      expect(checkPending("x", "y", NaN).status).toBe("ok");
    });
  });
});

describe("checkClientErrors", () => {
  it("平段の件数なら ok", () => {
    // 7日で 168 件（1時間 1 件）・直近 1 時間 2 件
    expect(checkClientErrors({ lastHour: 2, last7Days: 168 }).status).toBe("ok");
  });

  it("平均の 5 倍以上かつ 10 件以上なら ng", () => {
    // 直近 1 時間を除いた平均: (167 + 20 - 20) / 167 = 1 件/時
    const item = checkClientErrors({ lastHour: 20, last7Days: 187 });
    expect(item.status).toBe("ng");
    expect(item.detail).toContain("20");
  });

  it("平均の 5 倍以上でも 10 件未満なら ok（少ない件数で騒がない）", () => {
    expect(checkClientErrors({ lastHour: 9, last7Days: 9 }).status).toBe("ok");
  });

  it("10 件以上でも平均の 5 倍未満なら ok", () => {
    // 平均 = (167*10) / 167 = 10 件/時、直近 40 件 < 50
    expect(
      checkClientErrors({ lastHour: 40, last7Days: 1670 + 40 }).status
    ).toBe("ok");
  });

  describe("Edge Cases", () => {
    it("データが無い（0 件・0 件）なら ok（ゼロ除算しない）", () => {
      expect(checkClientErrors({ lastHour: 0, last7Days: 0 }).status).toBe("ok");
    });

    it("過去 7 日が 0 件で直近だけ 10 件なら ng（平均 0 の扱い）", () => {
      expect(checkClientErrors({ lastHour: 10, last7Days: 10 }).status).toBe(
        "ng"
      );
    });

    it("境界: ちょうど 10 件・ちょうど 5 倍なら ng", () => {
      // 平均 2 件/時（167*2）、直近 10 件 = 5 倍
      expect(
        checkClientErrors({ lastHour: 10, last7Days: 334 + 10 }).status
      ).toBe("ng");
    });

    it("7日の件数が直近より少ない（数える間の書き込み）でも落ちない", () => {
      expect(checkClientErrors({ lastHour: 12, last7Days: 5 }).status).toBe("ng");
    });

    it("数えられなかった（null）なら unknown", () => {
      expect(checkClientErrors(null).status).toBe("unknown");
    });

    it("閾値は THRESHOLDS と同じ", () => {
      expect(THRESHOLDS.errorSpikeFactor).toBe(5);
      expect(THRESHOLDS.errorSpikeMin).toBe(10);
    });
  });
});

describe("latestReadyBackupMs", () => {
  const backup = (o: Record<string, unknown>) => ({
    name: "projects/p/locations/nam5/backups/b1",
    database: "projects/trust-car-platform/databases/(default)",
    snapshotTime: "2026-10-01T18:00:00Z",
    state: "READY",
    ...o,
  });

  it("READY のうち一番新しい snapshotTime を返す", () => {
    expect(
      latestReadyBackupMs([
        backup({ snapshotTime: "2026-09-30T18:00:00Z" }),
        backup({ snapshotTime: "2026-10-01T18:00:00Z" }),
        backup({ snapshotTime: "2026-10-02T00:30:00Z", state: "CREATING" }),
      ])
    ).toBe(Date.parse("2026-10-01T18:00:00Z"));
  });

  describe("Edge Cases", () => {
    it("空・READY が無いなら null", () => {
      expect(latestReadyBackupMs([])).toBeNull();
      expect(latestReadyBackupMs([backup({ state: "NOT_AVAILABLE" })])).toBeNull();
    });

    it("別のデータベース（復元の練習用など）のバックアップは数えない", () => {
      expect(
        latestReadyBackupMs([
          backup({ database: "projects/p/databases/restore-20261002" }),
        ])
      ).toBeNull();
    });

    it("壊れた要素（null・時刻が読めない）は飛ばす", () => {
      expect(
        latestReadyBackupMs([null, "x", backup({ snapshotTime: "not a date" })])
      ).toBeNull();
    });
  });
});

describe("checkBackup", () => {
  it("48 時間以内に READY があれば ok", () => {
    expect(checkBackup({ latestReadyMs: NOW - 7 * HOUR_MS }, NOW).status).toBe(
      "ok"
    );
  });

  it("最新の READY が 48 時間より古ければ ng", () => {
    expect(checkBackup({ latestReadyMs: NOW - 49 * HOUR_MS }, NOW).status).toBe(
      "ng"
    );
  });

  describe("Edge Cases", () => {
    it("ちょうど 48 時間なら ok", () => {
      expect(
        checkBackup({ latestReadyMs: NOW - 48 * HOUR_MS }, NOW).status
      ).toBe("ok");
    });

    it("一覧は取れたが READY が1つも無いなら ng", () => {
      expect(checkBackup({ latestReadyMs: null }, NOW).status).toBe("ng");
    });

    it("一覧に届かない場所があり READY が見つからないなら unknown", () => {
      expect(
        checkBackup({ latestReadyMs: null, unreachable: ["nam5"] }, NOW).status
      ).toBe("unknown");
    });

    it("取得できなかったら unknown（NG にはしない）で、理由を detail に出す", () => {
      const item = checkBackup({ error: "403 PERMISSION_DENIED" }, NOW);
      expect(item.status).toBe("unknown");
      expect(item.detail).toContain("403");
    });
  });
});

function inputs(overrides: Partial<HealthInputs> = {}): HealthInputs {
  return {
    heartbeats: {
      purgeDeletedAccounts: hb(),
      purgeExpiredShares: hb(),
      aggregateModelCosts: hb(),
    },
    stalePlanRequests: 0,
    failedPlanNotifications: 0,
    staleInspectionNotices: 0,
    clientErrors: { lastHour: 0, last7Days: 0 },
    backup: { latestReadyMs: NOW - 7 * HOUR_MS },
    ...overrides,
  };
}

describe("evaluateHealth", () => {
  it("全部 ok なら全体も ok。項目は決まった順に並ぶ", () => {
    const r = evaluateHealth(inputs(), NOW);
    expect(r.overall).toBe("ok");
    expect(r.checkedAtMs).toBe(NOW);
    expect(r.items.map((i) => i.name)).toEqual([
      "job.purgeDeletedAccounts",
      "job.purgeExpiredShares",
      "job.aggregateModelCosts",
      "plan_requests.pending",
      "plan_requests.notify_failed",
      "inspection_notices.pending",
      "client_errors.spike",
      "backup.firestore",
    ]);
  });

  it("1つでも ng なら全体は ng", () => {
    expect(evaluateHealth(inputs({ failedPlanNotifications: 1 }), NOW).overall).toBe(
      "ng"
    );
  });

  describe("Edge Cases", () => {
    it("unknown だけなら全体は ok（判定できないものでは騒がない）", () => {
      const r = evaluateHealth(
        inputs({
          heartbeats: {},
          stalePlanRequests: null,
          backup: { error: "x" },
        }),
        NOW
      );
      expect(r.overall).toBe("ok");
      expect(r.items.filter((i) => i.status === "unknown")).toHaveLength(5);
    });

    it("detail に個人情報の元になる値（uid・メール）を入れない", () => {
      const r = evaluateHealth(
        inputs({
          heartbeats: {
            purgeDeletedAccounts: hb({ ok: false, error: "failed for a@b.co" }),
          },
        }),
        NOW
      );
      expect(JSON.stringify(r)).not.toContain("a@b.co");
    });
  });
});

describe("publicView", () => {
  const stored: StoredHealth = {
    overall: "ng",
    checkedAtMs: NOW,
    items: [
      { name: "job.purgeDeletedAccounts", status: "ok", detail: "secret detail" },
      { name: "plan_requests.pending", status: "ng", detail: "2 件" },
    ],
  };

  it("全体・確かめた時刻・各項目の name と status だけを返す", () => {
    expect(publicView(stored)).toEqual({
      overall: "ng",
      checkedAt: "2026-10-02T01:00:00.000Z",
      checkedAtMs: NOW,
      items: [
        { name: "job.purgeDeletedAccounts", status: "ok" },
        { name: "plan_requests.pending", status: "ng" },
      ],
    });
  });

  describe("Edge Cases", () => {
    it("detail・知らない項目は出さない", () => {
      const view = publicView({
        ...stored,
        extra: "x",
      } as unknown as StoredHealth);
      const text = JSON.stringify(view);
      expect(text).not.toContain("detail");
      expect(text).not.toContain("extra");
    });

    it("知らない status・overall は unknown / ng に寄せる", () => {
      const view = publicView({
        overall: "weird",
        checkedAtMs: NOW,
        items: [{ name: "a", status: "bad", detail: "" }, null],
      } as unknown as StoredHealth);
      expect(view.overall).toBe("ng");
      expect(view.items).toEqual([{ name: "a", status: "unknown" }]);
    });
  });
});

describe("handleOpsHealthRequest", () => {
  const stored: StoredHealth = {
    overall: "ok",
    checkedAtMs: NOW,
    items: [{ name: "backup.firestore", status: "ok", detail: "7 時間前" }],
  };

  it("GET なら 200 で公開してよい形を返し、短いキャッシュを付ける", async () => {
    const res = await handleOpsHealthRequest("GET", async () => stored);
    expect(res.status).toBe(200);
    expect(res.body).toEqual(publicView(stored));
    expect(res.cacheControl).toBe("public, max-age=60");
  });

  describe("Edge Cases", () => {
    it("GET 以外は 405", async () => {
      const load = jest.fn(async () => stored);
      const res = await handleOpsHealthRequest("POST", load);
      expect(res.status).toBe(405);
      expect(load).not.toHaveBeenCalled();
    });

    it("まだ一度も診断していない（文書が無い）なら 503", async () => {
      const res = await handleOpsHealthRequest("GET", async () => null);
      expect(res.status).toBe(503);
      expect(res.cacheControl).toBe("no-store");
    });

    it("読めなかったら 500（中身のエラーは返さない）", async () => {
      const spy = jest.spyOn(console, "error").mockImplementation(() => {});
      const res = await handleOpsHealthRequest("GET", async () => {
        throw new Error("internal path /secret");
      });
      expect(res.status).toBe(500);
      expect(JSON.stringify(res.body)).not.toContain("secret");
      spy.mockRestore();
    });

    it("checkedAtMs が無い壊れた文書は 503", async () => {
      const res = await handleOpsHealthRequest(
        "GET",
        async () => ({ overall: "ok", items: [] }) as unknown as StoredHealth
      );
      expect(res.status).toBe(503);
    });
  });
});
