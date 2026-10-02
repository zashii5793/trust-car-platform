// エラーの日次解析と運営者へのメール（src/opsDailyReport.ts）のテスト。
// トリガー本体は index.ts。Firestore・SendGrid は差し込みで差し替える。

import {
  REPORT_RETENTION_DAYS,
  aggregateClientErrors,
  buildDailyReportMail,
  countProblems,
  handleDailyReport,
  jstReportDay,
  normalizeMessage,
  type DailyReportDeps,
  type ErrorRow,
  type ReportDoc,
} from "../src/opsDailyReport";
import { MAIL_FROM, type OperatorMail } from "../src/notifyPlanRequest";
import type { HeartbeatSnapshot, StoredHealth } from "../src/opsHealth";

const HOUR = 60 * 60 * 1000;
// 2026-10-02 08:00 JST = 2026-10-01 23:00 UTC
const NOW = Date.parse("2026-10-01T23:00:00Z");

describe("jstReportDay", () => {
  it("朝 8 時（JST）に走ったら、前日の 0〜24 時（JST）を対象にする", () => {
    const d = jstReportDay(NOW);
    expect(d.date).toBe("2026-10-01");
    expect(d.startMs).toBe(Date.parse("2026-09-30T15:00:00Z"));
    expect(d.endMs).toBe(Date.parse("2026-10-01T15:00:00Z"));
    expect(d.prevStartMs).toBe(Date.parse("2026-09-29T15:00:00Z"));
  });

  describe("Edge Cases", () => {
    it("JST の 0:00 ちょうどなら、終わったばかりの前日", () => {
      expect(jstReportDay(Date.parse("2026-10-01T15:00:00Z")).date).toBe(
        "2026-10-01"
      );
    });

    it("JST の 23:59 でも前日（その日はまだ終わっていない）", () => {
      expect(jstReportDay(Date.parse("2026-10-02T14:59:59Z")).date).toBe(
        "2026-10-01"
      );
    });

    it("月・年をまたぐ", () => {
      expect(jstReportDay(Date.parse("2027-01-01T00:00:00Z")).date).toBe(
        "2026-12-31"
      );
    });
  });
});

describe("normalizeMessage", () => {
  it("前後の空白を落とし、1行にする", () => {
    expect(normalizeMessage("  Bad state:\n  oops ")).toBe("Bad state: oops");
  });

  it("メール・7桁以上の数字は伏せる（クライアントが伏せ損ねたとき用）", () => {
    expect(normalizeMessage("no user taro@example.com tel 090-1234-5678")).toBe(
      "no user [email] tel [number]"
    );
  });

  it("短い数字（行番号など）は残す", () => {
    expect(normalizeMessage("RangeError (index): 5")).toBe(
      "RangeError (index): 5"
    );
  });

  describe("Edge Cases", () => {
    it("空・文字列でない値は (不明)", () => {
      expect(normalizeMessage("")).toBe("(不明)");
      expect(normalizeMessage(undefined)).toBe("(不明)");
      expect(normalizeMessage(42)).toBe("(不明)");
    });

    it("長いものは 200 文字で切る", () => {
      expect(normalizeMessage("a".repeat(500))).toHaveLength(200);
    });
  });
});

function row(o: Partial<ErrorRow> = {}): ErrorRow {
  return {
    message: "Bad state: 壊れた",
    source: "flutter",
    buildId: "a1b2c3d",
    path: "/",
    ...o,
  };
}

describe("aggregateClientErrors", () => {
  it("総数・前日比・メッセージ／buildId／source／path ごとの件数を出す", () => {
    const rows = [
      row(),
      row(),
      row({ message: "TypeError: null", path: "/#/vehicles", buildId: "b2" }),
      row({ source: "zone" }),
    ];
    const s = aggregateClientErrors(rows, { total: 4, prevTotal: 1 });
    expect(s.total).toBe(4);
    expect(s.prevTotal).toBe(1);
    expect(s.diff).toBe(3);
    expect(s.sampled).toBe(false);
    expect(s.topMessages).toEqual([
      { key: "Bad state: 壊れた", count: 3 },
      { key: "TypeError: null", count: 1 },
    ]);
    expect(s.byBuildId).toEqual([
      { key: "a1b2c3d", count: 3 },
      { key: "b2", count: 1 },
    ]);
    expect(s.bySource).toEqual([
      { key: "flutter", count: 3 },
      { key: "zone", count: 1 },
    ]);
    expect(s.topPaths).toEqual([
      { key: "/", count: 3 },
      { key: "/#/vehicles", count: 1 },
    ]);
  });

  it("メッセージ・path は上位 10 件まで", () => {
    const rows = Array.from({ length: 15 }, (_, i) =>
      row({ message: `E${i}`, path: `/p${i}` })
    );
    const s = aggregateClientErrors(rows, { total: 15, prevTotal: 0 });
    expect(s.topMessages).toHaveLength(10);
    expect(s.topPaths).toHaveLength(10);
  });

  describe("Edge Cases", () => {
    it("0 件なら空の集計（前日比はマイナスもありうる）", () => {
      const s = aggregateClientErrors([], { total: 0, prevTotal: 4 });
      expect(s).toMatchObject({
        total: 0,
        prevTotal: 4,
        diff: -4,
        topMessages: [],
        byBuildId: [],
        bySource: [],
        topPaths: [],
      });
    });

    it("同数なら名前の順（毎回同じ並びにする）", () => {
      const s = aggregateClientErrors(
        [row({ message: "b" }), row({ message: "a" })],
        { total: 2, prevTotal: 0 }
      );
      expect(s.topMessages.map((m) => m.key)).toEqual(["a", "b"]);
    });

    it("読んだ行が総数より少なければ sampled（内訳は一部から）", () => {
      const s = aggregateClientErrors([row()], { total: 9000, prevTotal: 0 });
      expect(s.sampled).toBe(true);
      expect(s.total).toBe(9000);
    });

    it("総数が数えられなかった（null）なら読んだ行数を使う", () => {
      const s = aggregateClientErrors([row(), row()], {
        total: null,
        prevTotal: null,
      });
      expect(s.total).toBe(2);
      expect(s.prevTotal).toBeNull();
      expect(s.diff).toBeNull();
    });

    it("欠けた項目は (不明) にまとめる", () => {
      const s = aggregateClientErrors(
        [{ message: null, source: undefined, buildId: 3, path: "" }],
        { total: 1, prevTotal: 0 }
      );
      expect(s.byBuildId).toEqual([{ key: "(不明)", count: 1 }]);
      expect(s.bySource).toEqual([{ key: "(不明)", count: 1 }]);
      expect(s.topPaths).toEqual([{ key: "(不明)", count: 1 }]);
    });

    it("path のクエリは落とす（入力値が入りうる）", () => {
      const s = aggregateClientErrors([row({ path: "/search?q=taro" })], {
        total: 1,
        prevTotal: 0,
      });
      expect(s.topPaths).toEqual([{ key: "/search", count: 1 }]);
    });
  });
});

function hb(o: Partial<HeartbeatSnapshot> = {}): HeartbeatSnapshot {
  return {
    lastRunAtMs: NOW - 5 * HOUR,
    lastSuccessAtMs: NOW - 5 * HOUR,
    ok: true,
    processed: 2,
    error: null,
    ...o,
  };
}

const okHealth: StoredHealth = {
  overall: "ok",
  checkedAtMs: NOW - 10 * 60 * 1000,
  items: [
    { name: "job.purgeDeletedAccounts", status: "ok", detail: "最後の成功: 5 時間前" },
    { name: "backup.firestore", status: "unknown", detail: "取得できなかった" },
  ],
};

const ngHealth: StoredHealth = {
  overall: "ng",
  checkedAtMs: NOW - 10 * 60 * 1000,
  items: [
    { name: "plan_requests.pending", status: "ng", detail: "受付中のまま: 2 件" },
    { name: "client_errors.spike", status: "ng", detail: "直近1時間 30 件" },
    { name: "backup.firestore", status: "ok", detail: "7 時間前" },
  ],
};

describe("countProblems", () => {
  it("健康診断の NG の数", () => {
    expect(countProblems(okHealth, NOW)).toBe(0);
    expect(countProblems(ngHealth, NOW)).toBe(2);
  });

  describe("Edge Cases", () => {
    it("健康診断が無い・2時間より古いなら、それも1件と数える", () => {
      expect(countProblems(null, NOW)).toBe(1);
      expect(
        countProblems({ ...okHealth, checkedAtMs: NOW - 3 * HOUR }, NOW)
      ).toBe(1);
      expect(
        countProblems({ ...ngHealth, checkedAtMs: NOW - 3 * HOUR }, NOW)
      ).toBe(3);
    });
  });
});

const summary = aggregateClientErrors(
  [row(), row({ message: "TypeError: null" })],
  { total: 2, prevTotal: 5 }
);

describe("buildDailyReportMail", () => {
  const base = {
    to: "ops@example.com",
    date: "2026-10-01",
    errors: summary,
    health: ngHealth,
    heartbeats: {
      purgeDeletedAccounts: hb(),
      purgeExpiredShares: hb({ ok: false, error: "DEADLINE_EXCEEDED" }),
      aggregateModelCosts: null,
    },
    nowMs: NOW,
  };

  it("件名に日付と問題の件数を入れる", () => {
    const mail = buildDailyReportMail(base);
    expect(mail.subject).toBe("[TrustCar] 日次レポート 2026-10-01：問題あり 2件");
    expect(mail.to).toBe("ops@example.com");
    expect(mail.from).toBe(MAIL_FROM);
  });

  it("問題が無ければ「問題なし」", () => {
    expect(buildDailyReportMail({ ...base, health: okHealth }).subject).toBe(
      "[TrustCar] 日次レポート 2026-10-01：問題なし"
    );
  });

  it("本文に健康診断・定期ジョブ・エラーの集計が入る", () => {
    const { text } = buildDailyReportMail(base);
    expect(text).toContain("2026-10-01");
    expect(text).toContain("[NG] plan_requests.pending");
    expect(text).toContain("受付中のまま: 2 件");
    expect(text).toContain("purgeExpiredShares");
    expect(text).toContain("DEADLINE_EXCEEDED");
    expect(text).toContain("aggregateModelCosts: 記録なし");
    expect(text).toContain("総数: 2 件（前日 5 件、-3）");
    expect(text).toContain("TypeError: null");
    expect(text).toContain("a1b2c3d");
    expect(text).toContain("MAINTENANCE_RUNBOOK.md");
  });

  describe("Edge Cases", () => {
    it("健康診断が無いときもメールは作れる", () => {
      const mail = buildDailyReportMail({ ...base, health: null });
      expect(mail.text).toContain("健康診断の結果が無い");
      expect(mail.subject).toContain("問題あり 1件");
    });

    it("エラーが 0 件ならそう書く", () => {
      const mail = buildDailyReportMail({
        ...base,
        errors: aggregateClientErrors([], { total: 0, prevTotal: 0 }),
      });
      expect(mail.text).toContain("総数: 0 件（前日 0 件、±0）");
    });

    it("一部だけ読んだ内訳ならそう書く", () => {
      const mail = buildDailyReportMail({
        ...base,
        errors: aggregateClientErrors([row()], { total: 9000, prevTotal: 0 }),
      });
      expect(mail.text).toContain("内訳は先頭の 1 件から");
    });

    it("本文に uid・メールアドレスを入れない", () => {
      const mail = buildDailyReportMail({
        ...base,
        errors: aggregateClientErrors(
          [row({ message: "denied for hanako@example.com" })],
          { total: 1, prevTotal: 0 }
        ),
        heartbeats: {
          purgeDeletedAccounts: hb({ ok: false, error: "x taro@example.com" }),
        },
      });
      expect(mail.text).not.toContain("@example.com");
      expect(mail.text).not.toMatch(/uid/i);
    });
  });
});

// --- 本体 -------------------------------------------------------------------

function fakeDeps(opts: {
  operatorEmail?: string;
  existing?: ReportDoc["mail"]["state"] | null;
  send?: () => Promise<void>;
  health?: StoredHealth | null;
} = {}) {
  const state: {
    doc: ReportDoc | null;
    sent: OperatorMail[];
    marks: { state: string; error?: string }[];
  } = {
    doc: null,
    sent: [],
    marks: [],
  };
  const deps: DailyReportDeps = {
    operatorEmail: () => opts.operatorEmail ?? "ops@example.com",
    countErrors: jest.fn(async (start: number) =>
      start === Date.parse("2026-09-30T15:00:00Z") ? 2 : 5
    ),
    loadErrorRows: jest.fn(async () => [row(), row({ message: "TypeError" })]),
    loadHealth: jest.fn(async () =>
      opts.health === undefined ? okHealth : opts.health
    ),
    loadHeartbeats: jest.fn(async () => ({ purgeDeletedAccounts: hb() })),
    claimReport: jest.fn(async (_date: string, doc: ReportDoc) => {
      if (opts.existing && opts.existing !== "failed") return "already" as const;
      state.doc = doc;
      return "claimed" as const;
    }),
    markMail: jest.fn(async (_date: string, s: string, error?: string) => {
      state.marks.push({ state: s, ...(error ? { error } : {}) });
    }),
    send: jest.fn(async (mail: OperatorMail) => {
      if (opts.send) await opts.send();
      state.sent.push(mail);
    }),
  };
  return { deps, state };
}

describe("handleDailyReport", () => {
  it("前日を集計して ops_reports に書き、メールを送って sent を付ける", async () => {
    const { deps, state } = fakeDeps();
    const out = await handleDailyReport(deps, NOW);
    expect(out).toBe("sent");
    expect(state.doc?.date).toBe("2026-10-01");
    expect(state.doc?.errors.total).toBe(2);
    expect(state.doc?.errors.prevTotal).toBe(5);
    expect(state.doc?.mail.state).toBe("sending");
    expect(state.doc?.expireAtMs).toBe(NOW + REPORT_RETENTION_DAYS * 24 * HOUR);
    expect(state.sent).toHaveLength(1);
    expect(state.marks).toEqual([{ state: "sent" }]);
    expect(deps.loadErrorRows).toHaveBeenCalledWith(
      Date.parse("2026-09-30T15:00:00Z"),
      Date.parse("2026-10-01T15:00:00Z"),
      expect.any(Number)
    );
  });

  describe("Edge Cases", () => {
    it("同じ日のレポートを送り済み（sending・sent・skipped）なら送らない", async () => {
      for (const existing of ["sending", "sent", "skipped"] as const) {
        const { deps, state } = fakeDeps({ existing });
        expect(await handleDailyReport(deps, NOW)).toBe("already-sent");
        expect(state.sent).toHaveLength(0);
      }
    });

    it("前回が failed なら送り直す", async () => {
      const { deps, state } = fakeDeps({ existing: "failed" });
      expect(await handleDailyReport(deps, NOW)).toBe("sent");
      expect(state.sent).toHaveLength(1);
    });

    it("宛先が空ならレポートは書くが送らない（skipped）", async () => {
      const spy = jest.spyOn(console, "warn").mockImplementation(() => {});
      const { deps, state } = fakeDeps({ operatorEmail: "  " });
      expect(await handleDailyReport(deps, NOW)).toBe("no-operator-email");
      expect(state.doc?.mail.state).toBe("skipped");
      expect(state.sent).toHaveLength(0);
      spy.mockRestore();
    });

    it("送信に失敗したら failed を付け、例外は投げない", async () => {
      const spy = jest.spyOn(console, "error").mockImplementation(() => {});
      const { deps, state } = fakeDeps({
        send: async () => {
          throw new Error("401 Unauthorized");
        },
      });
      expect(await handleDailyReport(deps, NOW)).toBe("failed");
      expect(state.marks).toEqual([
        { state: "failed", error: "401 Unauthorized" },
      ]);
      spy.mockRestore();
    });

    it("エラーの件数が数えられなくても、レポートは作って送る", async () => {
      const spy = jest.spyOn(console, "error").mockImplementation(() => {});
      const { deps, state } = fakeDeps();
      deps.countErrors = jest.fn(async () => {
        throw new Error("index");
      });
      expect(await handleDailyReport(deps, NOW)).toBe("sent");
      expect(state.doc?.errors.total).toBe(2);
      expect(state.doc?.errors.prevTotal).toBeNull();
      spy.mockRestore();
    });

    it("健康診断・ハートビートが読めなくても送る（無いものとして書く）", async () => {
      const spy = jest.spyOn(console, "error").mockImplementation(() => {});
      const { deps, state } = fakeDeps();
      deps.loadHealth = jest.fn(async () => {
        throw new Error("x");
      });
      deps.loadHeartbeats = jest.fn(async () => {
        throw new Error("y");
      });
      expect(await handleDailyReport(deps, NOW)).toBe("sent");
      expect(state.sent[0].text).toContain("健康診断の結果が無い");
      spy.mockRestore();
    });
  });
});
