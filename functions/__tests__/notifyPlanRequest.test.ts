// 店舗プランの申し込みの通知メール（src/notifyPlanRequest.ts）のテスト。
// トリガー本体は index.ts。SendGrid・Firestore は差し込みで差し替える。

import {
  MAIL_FROM,
  MAX_RETRY_AGE_MS,
  buildOperatorMail,
  consoleUrl,
  formatJst,
  handlePlanRequestCreated,
  isTransientSendError,
  planLabel,
  type ClaimResult,
  type NotifyDeps,
  type OperatorMail,
  type PlanRequestData,
} from "../src/notifyPlanRequest";

// 2026-10-01 05:03 UTC = 14:03 JST
const CREATED = new Date("2026-10-01T05:03:00Z");
const ts = (d: Date) => ({ toDate: () => d });

function request(overrides: Partial<PlanRequestData> = {}): PlanRequestData {
  return {
    plan: "standard",
    currentPlan: "free",
    requesterUid: "owner-1",
    contactEmail: "owner@example.com",
    billingName: "株式会社タカヤ",
    status: "pending",
    createdAt: ts(CREATED),
    ...overrides,
  };
}

/** 文書上の印（operatorNotification）を模した、差し替え用の依存。 */
function fakeDeps(opts: {
  operatorEmail?: string;
  shopName?: string | null;
  send?: (mail: OperatorMail) => Promise<void>;
} = {}) {
  const state: { notification: string | null; sent: OperatorMail[] } = {
    notification: null,
    sent: [],
  };
  const deps: NotifyDeps = {
    operatorEmail: () => opts.operatorEmail ?? "ops@example.com",
    loadShopName: jest.fn(async () =>
      opts.shopName === undefined ? "タカヤモーター" : opts.shopName
    ),
    claim: jest.fn(async (): Promise<ClaimResult> => {
      if (state.notification !== null) return "already";
      state.notification = "sending";
      return "claimed";
    }),
    release: jest.fn(async () => {
      state.notification = null;
    }),
    markSent: jest.fn(async () => {
      state.notification = "sent";
    }),
    markFailed: jest.fn(async () => {
      state.notification = "failed";
    }),
    send: jest.fn(async (mail: OperatorMail) => {
      if (opts.send) await opts.send(mail);
      state.sent.push(mail);
    }),
  };
  return { deps, state };
}

const params = (data: PlanRequestData | undefined = request()) => ({
  shopId: "shop-1",
  requestId: "req-1",
  eventId: "evt-1",
  eventTime: CREATED,
  data,
});

const justAfter = () => CREATED.getTime() + 1000;

beforeEach(() => {
  jest.spyOn(console, "log").mockImplementation(() => undefined);
  jest.spyOn(console, "warn").mockImplementation(() => undefined);
  jest.spyOn(console, "error").mockImplementation(() => undefined);
});
afterEach(() => jest.restoreAllMocks());

describe("planLabel", () => {
  it("知っているプランは日本語の表示名", () => {
    expect(planLabel("free")).toBe("フリー");
    expect(planLabel("standard")).toBe("スタンダード");
    expect(planLabel("premium")).toBe("プレミアム");
    expect(planLabel("enterprise")).toBe("エンタープライズ");
  });

  describe("Edge Cases", () => {
    it("知らない値はそのまま", () => {
      expect(planLabel("platinum")).toBe("platinum");
    });
    it("空・undefined は (不明)", () => {
      expect(planLabel("")).toBe("(不明)");
      expect(planLabel(undefined)).toBe("(不明)");
    });
  });
});

describe("formatJst", () => {
  it("日本時間で年月日 時分", () => {
    expect(formatJst(CREATED)).toBe("2026-10-01 14:03");
  });
  it("日付をまたぐ（UTC 15時以降は翌日）", () => {
    expect(formatJst(new Date("2026-09-30T15:30:00Z"))).toBe(
      "2026-10-01 00:30"
    );
  });
});

describe("consoleUrl", () => {
  it("文書のパスを ~2F でつないだ Console の URL", () => {
    expect(consoleUrl("shop-1", "req-1")).toBe(
      "https://console.firebase.google.com/project/trust-car-platform" +
        "/firestore/data/~2Fshops~2Fshop-1~2Fplan_requests~2Freq-1"
    );
  });
});

describe("buildOperatorMail", () => {
  const build = (
    r: PlanRequestData = request(),
    shopName: string | null = "タカヤモーター"
  ) =>
    buildOperatorMail({
      to: "ops@example.com",
      shopId: "shop-1",
      requestId: "req-1",
      shopName,
      request: r,
      fallbackTime: new Date("2026-12-31T00:00:00Z"),
    });

  it("宛先・送信元・件名", () => {
    const mail = build();
    expect(mail.to).toBe("ops@example.com");
    expect(mail.from).toBe(MAIL_FROM);
    expect(mail.from).toBe("no-reply@trustcar.jp");
    expect(mail.subject).toBe(
      "[TrustCar] 店舗プランの申し込み: タカヤモーター → スタンダード"
    );
  });

  it("本文に店名・店ID・プラン・宛名・連絡先・日時・URL が入る", () => {
    const { text } = build();
    expect(text).toContain("店名: タカヤモーター");
    expect(text).toContain("店ID: shop-1");
    expect(text).toContain("プラン: フリー → スタンダード");
    expect(text).toContain("請求書の宛名: 株式会社タカヤ");
    expect(text).toContain("連絡先: owner@example.com");
    expect(text).toContain("申し込み日時: 2026-10-01 14:03（日本時間）");
    expect(text).toContain("申し込みID: req-1");
    expect(text).toContain(consoleUrl("shop-1", "req-1"));
  });

  it("ご要望があれば本文に入る", () => {
    const { text } = build(request({ note: "  月末締めでお願いします  " }));
    expect(text).toContain("ご要望:\n月末締めでお願いします");
  });

  it("ご要望が無ければ見出しも出さない", () => {
    expect(build().text).not.toContain("ご要望");
  });

  it("エンタープライズは見積もりの相談と分かる", () => {
    const mail = build(request({ plan: "enterprise", currentPlan: "premium" }));
    expect(mail.subject).toContain("→ エンタープライズ");
    expect(mail.text).toContain(
      "プラン: プレミアム → エンタープライズ（個別見積もりの相談）"
    );
  });

  it("フリーへの変更は解約の申し込みと分かる", () => {
    const mail = build(request({ plan: "free", currentPlan: "standard" }));
    expect(mail.text).toContain("（フリーへの変更＝解約の申し込み）");
  });

  describe("Edge Cases", () => {
    it("店名が読めなければ (店名未設定)", () => {
      const mail = build(request(), null);
      expect(mail.subject).toContain("(店名未設定)");
      expect(mail.text).toContain("店名: (店名未設定)");
    });
    it("店名が空白だけでも (店名未設定)", () => {
      expect(build(request(), "   ").text).toContain("店名: (店名未設定)");
    });
    it("createdAt が無ければイベントの時刻", () => {
      const { text } = build(request({ createdAt: null }));
      expect(text).toContain("申し込み日時: 2026-12-31 09:00（日本時間）");
    });
    it("宛名・連絡先が空なら (未入力)", () => {
      const { text } = build(request({ billingName: "", contactEmail: "" }));
      expect(text).toContain("請求書の宛名: (未入力)");
      expect(text).toContain("連絡先: (未入力)");
    });
  });
});

describe("isTransientSendError", () => {
  it("429・5xx は一時的", () => {
    expect(isTransientSendError({ code: 429 })).toBe(true);
    expect(isTransientSendError({ code: 500 })).toBe(true);
    expect(isTransientSendError({ code: 503 })).toBe(true);
    expect(isTransientSendError({ response: { statusCode: 502 } })).toBe(true);
  });
  it("HTTP 応答の無いエラー（通信エラー）は一時的", () => {
    expect(isTransientSendError(new Error("ECONNRESET"))).toBe(true);
  });
  it("それ以外の 4xx は一時的ではない", () => {
    expect(isTransientSendError({ code: 400 })).toBe(false);
    expect(isTransientSendError({ code: 401 })).toBe(false);
    expect(isTransientSendError({ code: 403 })).toBe(false);
  });
});

describe("handlePlanRequestCreated", () => {
  it("申し込みができたら運営者に1通送り、送信済みにする", async () => {
    const { deps, state } = fakeDeps();
    await expect(
      handlePlanRequestCreated(params(), deps, justAfter)
    ).resolves.toBe("sent");
    expect(state.sent).toHaveLength(1);
    expect(state.sent[0].to).toBe("ops@example.com");
    expect(state.sent[0].subject).toBe(
      "[TrustCar] 店舗プランの申し込み: タカヤモーター → スタンダード"
    );
    expect(deps.claim).toHaveBeenCalledWith("evt-1");
    expect(deps.loadShopName).toHaveBeenCalledWith("shop-1");
    expect(state.notification).toBe("sent");
  });

  it("宛先の前後の空白は落とす", async () => {
    const { deps, state } = fakeDeps({ operatorEmail: "  ops@example.com\n" });
    await handlePlanRequestCreated(params(), deps, justAfter);
    expect(state.sent[0].to).toBe("ops@example.com");
  });

  describe("宛先が未設定", () => {
    it.each([[""], ["   "]])("%j なら送らず、印も書かない", async (email) => {
      const { deps, state } = fakeDeps({ operatorEmail: email });
      await expect(
        handlePlanRequestCreated(params(), deps, justAfter)
      ).resolves.toBe("no-operator-email");
      expect(deps.send).not.toHaveBeenCalled();
      expect(deps.claim).not.toHaveBeenCalled();
      expect(state.notification).toBeNull();
      expect(console.warn).toHaveBeenCalled();
    });
  });

  describe("二重送信しない", () => {
    it("同じ申し込みでもう一度呼ばれても（再試行・重複配信）送るのは1通", async () => {
      const { deps, state } = fakeDeps();
      await handlePlanRequestCreated(params(), deps, justAfter);
      await expect(
        handlePlanRequestCreated(params(), deps, justAfter)
      ).resolves.toBe("already-notified");
      expect(state.sent).toHaveLength(1);
    });

    it("送信中の印が残っていたら（前回が途中で落ちた）送らない", async () => {
      const { deps, state } = fakeDeps();
      state.notification = "sending";
      await expect(
        handlePlanRequestCreated(params(), deps, justAfter)
      ).resolves.toBe("already-notified");
      expect(deps.send).not.toHaveBeenCalled();
    });

    it("一時的な失敗のあとの再試行では、送れるのは1通", async () => {
      let calls = 0;
      const { deps, state } = fakeDeps({
        send: async () => {
          calls++;
          if (calls === 1) throw Object.assign(new Error("busy"), { code: 503 });
        },
      });
      await expect(
        handlePlanRequestCreated(params(), deps, justAfter)
      ).rejects.toThrow("busy");
      expect(deps.release).toHaveBeenCalledTimes(1);
      expect(state.notification).toBeNull();

      // Cloud Functions の再試行
      await expect(
        handlePlanRequestCreated(params(), deps, justAfter)
      ).resolves.toBe("sent");
      // もう一度来ても送らない
      await handlePlanRequestCreated(params(), deps, justAfter);
      expect(state.sent).toHaveLength(1);
    });
  });

  describe("送信の失敗", () => {
    it("一時的でない失敗（4xx）は投げずに failed にする（再試行しない）", async () => {
      const { deps, state } = fakeDeps({
        send: async () => {
          throw Object.assign(new Error("Unauthorized"), { code: 401 });
        },
      });
      await expect(
        handlePlanRequestCreated(params(), deps, justAfter)
      ).resolves.toBe("failed");
      expect(deps.markFailed).toHaveBeenCalledWith("Unauthorized");
      expect(deps.release).not.toHaveBeenCalled();
      expect(state.notification).toBe("failed");
    });

    it("一時的な失敗でも、申し込みから1時間を過ぎたら諦める", async () => {
      const { deps, state } = fakeDeps({
        send: async () => {
          throw Object.assign(new Error("busy"), { code: 503 });
        },
      });
      const late = () => CREATED.getTime() + MAX_RETRY_AGE_MS + 1;
      await expect(handlePlanRequestCreated(params(), deps, late)).resolves.toBe(
        "failed"
      );
      expect(deps.release).not.toHaveBeenCalled();
      expect(state.notification).toBe("failed");
    });
  });

  describe("Edge Cases", () => {
    it("文書の中身が無ければ何もしない", async () => {
      const { deps } = fakeDeps();
      await expect(
        handlePlanRequestCreated(
          { ...params(), data: undefined },
          deps,
          justAfter
        )
      ).resolves.toBe("no-data");
      expect(deps.claim).not.toHaveBeenCalled();
      expect(deps.send).not.toHaveBeenCalled();
    });

    it("店名の読み込みに失敗しても、店名未設定として送る", async () => {
      const { deps, state } = fakeDeps();
      deps.loadShopName = jest.fn(async () => {
        throw new Error("unavailable");
      });
      await expect(
        handlePlanRequestCreated(params(), deps, justAfter)
      ).resolves.toBe("sent");
      expect(state.sent[0].subject).toContain("(店名未設定)");
    });
  });
});
