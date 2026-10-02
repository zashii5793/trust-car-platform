// 定期ジョブのハートビート（src/opsHeartbeat.ts）のテスト。
// 書き込み先（ops_heartbeats/{関数名}）は差し込みで差し替える。

import {
  MAX_HEARTBEAT_ERROR_LENGTH,
  heartbeatFor,
  runWithHeartbeat,
  shortError,
  type HeartbeatWrite,
} from "../src/opsHeartbeat";

const NOW = new Date("2026-10-02T00:00:00Z");

function recorder() {
  const writes: { name: string; hb: HeartbeatWrite }[] = [];
  const write = jest.fn(async (name: string, hb: HeartbeatWrite) => {
    writes.push({ name, hb });
  });
  return { writes, write };
}

describe("heartbeatFor", () => {
  it("成功なら ok=true・lastSuccessAt を付け、error は null", () => {
    expect(heartbeatFor({ processed: 3 }, NOW)).toEqual({
      lastRunAt: NOW,
      lastSuccessAt: NOW,
      ok: true,
      processed: 3,
      error: null,
    });
  });

  it("一部失敗（error あり）なら ok=false で、lastSuccessAt は付けない", () => {
    const hb = heartbeatFor({ processed: 2, error: "1 件の削除に失敗" }, NOW);
    expect(hb.ok).toBe(false);
    expect(hb.error).toBe("1 件の削除に失敗");
    expect(hb.processed).toBe(2);
    expect("lastSuccessAt" in hb).toBe(false);
  });

  describe("Edge Cases", () => {
    it("processed が負・NaN・小数なら 0 以上の整数に丸める", () => {
      expect(heartbeatFor({ processed: -1 }, NOW).processed).toBe(0);
      expect(heartbeatFor({ processed: NaN }, NOW).processed).toBe(0);
      expect(heartbeatFor({ processed: 2.7 }, NOW).processed).toBe(2);
    });

    it("error が空文字なら成功として扱う", () => {
      expect(heartbeatFor({ processed: 0, error: "" }, NOW).ok).toBe(true);
    });
  });
});

describe("shortError", () => {
  it("Error はメッセージの先頭だけ", () => {
    const long = "x".repeat(1000);
    expect(shortError(new Error(long))).toHaveLength(MAX_HEARTBEAT_ERROR_LENGTH);
  });

  it("メールアドレスは伏せる（個人情報を残さない）", () => {
    expect(shortError(new Error("not found: taro@example.com"))).toBe(
      "not found: [email]"
    );
  });

  it("複数行なら最初の行だけ", () => {
    expect(shortError(new Error("first\nsecond"))).toBe("first");
  });

  describe("Edge Cases", () => {
    it("Error でない値（文字列・null・undefined・オブジェクト）でも落ちない", () => {
      expect(shortError("boom")).toBe("boom");
      expect(shortError(null)).toBe("(不明なエラー)");
      expect(shortError(undefined)).toBe("(不明なエラー)");
      expect(shortError({})).toBe("[object Object]");
    });

    it("空のメッセージは (不明なエラー)", () => {
      expect(shortError(new Error(""))).toBe("(不明なエラー)");
    });
  });
});

describe("runWithHeartbeat", () => {
  it("成功したら結果を返し、ok=true のハートビートを関数名で書く", async () => {
    const { writes, write } = recorder();
    const out = await runWithHeartbeat(
      "purgeExpiredShares",
      async () => ({ processed: 5 }),
      write,
      () => NOW
    );
    expect(out).toEqual({ processed: 5 });
    expect(writes).toEqual([
      {
        name: "purgeExpiredShares",
        hb: {
          lastRunAt: NOW,
          lastSuccessAt: NOW,
          ok: true,
          processed: 5,
          error: null,
        },
      },
    ]);
  });

  it("本処理が投げたら ok=false を書いてから、同じ例外を投げ直す", async () => {
    const { writes, write } = recorder();
    const err = new Error("DEADLINE_EXCEEDED");
    await expect(
      runWithHeartbeat("aggregateModelCosts", async () => {
        throw err;
      }, write, () => NOW)
    ).rejects.toBe(err);
    expect(writes).toHaveLength(1);
    expect(writes[0].hb).toEqual({
      lastRunAt: NOW,
      ok: false,
      processed: 0,
      error: "DEADLINE_EXCEEDED",
    });
  });

  describe("Edge Cases", () => {
    it("ハートビートが書けなくても、本処理の結果はそのまま返す", async () => {
      const spy = jest.spyOn(console, "error").mockImplementation(() => {});
      const out = await runWithHeartbeat(
        "purgeDeletedAccounts",
        async () => ({ processed: 1 }),
        async () => {
          throw new Error("PERMISSION_DENIED");
        },
        () => NOW
      );
      expect(out).toEqual({ processed: 1 });
      expect(spy).toHaveBeenCalled();
      spy.mockRestore();
    });

    it("本処理もハートビートも失敗したら、本処理の例外を投げる", async () => {
      const spy = jest.spyOn(console, "error").mockImplementation(() => {});
      const err = new Error("job failed");
      await expect(
        runWithHeartbeat("purgeDeletedAccounts", async () => {
          throw err;
        }, async () => {
          throw new Error("write failed");
        }, () => NOW)
      ).rejects.toBe(err);
      spy.mockRestore();
    });

    it("本処理は1回だけ呼ぶ", async () => {
      const { write } = recorder();
      const job = jest.fn(async () => ({ processed: 0 }));
      await runWithHeartbeat("purgeExpiredShares", job, write, () => NOW);
      expect(job).toHaveBeenCalledTimes(1);
    });
  });
});
