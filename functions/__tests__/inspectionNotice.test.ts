// アプリ利用者への車検案内（src/inspectionNotice.ts）のテスト。
// トリガー本体は index.ts。Firestore・FCM は差し込みで差し替える。

import {
  MAX_DAYS_AHEAD,
  MAX_VEHICLES,
  buildPushMessage,
  handleInspectionNoticeCreated,
  invalidTokensFrom,
  isInNoticeWindow,
  isNoticedForCurrentExpiry,
  jstDateKey,
  jstMonthDay,
  tokensOf,
  vehicleIdsOf,
  wantsInspectionPush,
  type LedgerCustomerData,
  type LedgerVehicleData,
  type LinkedUserData,
  type NoticeDeps,
  type NoticeResult,
  type PushMessage,
  type SendOutcome,
  type TimestampLike,
  type VehicleClaim,
} from "../src/inspectionNotice";

// 2026-10-01 10:00 JST
const NOW = new Date("2026-10-01T01:00:00Z");
const DAY = 24 * 60 * 60 * 1000;
const ts = (d: Date): TimestampLike => ({ toDate: () => d });
/** 日本時間のその日の 0:00（台帳の日付はこの形で入る）。 */
const jst = (y: number, m: number, d: number) =>
  new Date(Date.UTC(y, m - 1, d) - 9 * 60 * 60 * 1000);

const SHOP = "shop-1";

interface World {
  vehicles: Record<string, LedgerVehicleData>;
  customers: Record<string, LedgerCustomerData>;
  links: Record<string, string>;
  users: Record<string, LinkedUserData>;
}

function world(overrides: Partial<World> = {}): World {
  return {
    vehicles: {
      v1: {
        customerId: "c1",
        maker: "トヨタ",
        model: "プリウス",
        inspectionExpiry: ts(jst(2026, 10, 20)),
      },
    },
    customers: { c1: { linkedUserId: "u1" } },
    links: { u1: SHOP },
    users: { u1: { fcmTokens: ["tok-a"] } },
    ...overrides,
  };
}

/** 文書の状態を持つ、差し替え用の依存。 */
function fakeDeps(
  w: World,
  opts: {
    send?: (tokens: string[], m: PushMessage) => Promise<SendOutcome>;
    requestClaimed?: boolean;
  } = {}
) {
  const state = {
    requestClaimed: opts.requestClaimed ?? false,
    sent: [] as { tokens: string[]; message: PushMessage }[],
    removed: [] as { uid: string; tokens: string[] }[],
    released: [] as VehicleClaim[],
    result: null as null | { status: string; result: NoticeResult; error?: string },
  };
  const deps: NoticeDeps = {
    claimRequest: jest.fn(async () => {
      if (state.requestClaimed) return "already" as const;
      state.requestClaimed = true;
      return "claimed" as const;
    }),
    loadShopName: async () => "タカヤモーター",
    loadVehicle: async (id) => w.vehicles[id] ?? null,
    loadCustomer: async (id) => w.customers[id] ?? null,
    loadLinkShopId: jest.fn(async (uid: string) => w.links[uid] ?? null),
    loadUser: async (uid) => w.users[uid] ?? null,
    claimVehicles: jest.fn(async (ids: string[], now: Date) => {
      const claims: VehicleClaim[] = [];
      for (const id of ids) {
        const v = w.vehicles[id];
        if (!v || isNoticedForCurrentExpiry(v)) continue;
        claims.push({
          id,
          prevNoticeAt: v.inspectionNoticeAt ?? null,
          prevNoticeExpiry: v.inspectionNoticeExpiry ?? null,
        });
        v.inspectionNoticeAt = ts(now);
        v.inspectionNoticeExpiry = v.inspectionExpiry;
      }
      return claims;
    }),
    releaseVehicles: jest.fn(async (claims: VehicleClaim[]) => {
      for (const c of claims) {
        state.released.push(c);
        w.vehicles[c.id].inspectionNoticeAt = c.prevNoticeAt;
        w.vehicles[c.id].inspectionNoticeExpiry = c.prevNoticeExpiry;
      }
    }),
    send: jest.fn(async (tokens: string[], message: PushMessage) => {
      state.sent.push({ tokens, message });
      return opts.send
        ? opts.send(tokens, message)
        : { successCount: tokens.length, invalidTokens: [] };
    }),
    removeTokens: jest.fn(async (uid: string, tokens: string[]) => {
      state.removed.push({ uid, tokens });
    }),
    writeResult: jest.fn(async (status, result, error) => {
      state.result = { status, result, error };
    }),
  };
  return { deps, state };
}

async function run(w: World, vehicleIds: unknown, opts = {}) {
  const { deps, state } = fakeDeps(w, opts);
  const outcome = await handleInspectionNoticeCreated(
    {
      shopId: SHOP,
      noticeId: "n1",
      eventId: "ev1",
      data: { requesterUid: "staff-1", vehicleIds, status: "pending" },
    },
    deps,
    () => NOW
  );
  return { outcome, state, deps };
}

describe("handleInspectionNoticeCreated", () => {
  it("つながっている利用者の端末に送り、案内した日を付け、結果を書く", async () => {
    const w = world();
    const { outcome, state } = await run(w, ["v1"]);

    expect(outcome).toBe("done");
    expect(state.sent).toHaveLength(1);
    expect(state.sent[0].tokens).toEqual(["tok-a"]);
    expect(state.sent[0].message.title).toBe("車検のご案内（タカヤモーター）");
    expect(state.sent[0].message.body).toContain("トヨタ プリウス");
    expect(state.sent[0].message.body).toContain("10月20日");
    expect(state.sent[0].message.data).toEqual({
      type: "inspection_notice",
      shopId: SHOP,
      noticeId: "n1",
    });
    expect(w.vehicles.v1.inspectionNoticeAt?.toDate()).toEqual(NOW);
    expect(jstDateKey(w.vehicles.v1.inspectionNoticeExpiry!.toDate())).toBe(
      "2026-10-20"
    );
    expect(state.result?.status).toBe("done");
    expect(state.result?.result.sent).toBe(1);
  });

  it("同じ利用者の車は1通にまとめ、満了日の近い順に書く", async () => {
    const w = world({
      vehicles: {
        late: {
          customerId: "c1",
          maker: "ホンダ",
          model: "フィット",
          inspectionExpiry: ts(jst(2026, 11, 30)),
        },
        early: {
          customerId: "c1",
          maker: "トヨタ",
          model: "プリウス",
          inspectionExpiry: ts(jst(2026, 10, 5)),
        },
      },
    });
    const { state } = await run(w, ["late", "early"]);

    expect(state.sent).toHaveLength(1);
    expect(state.sent[0].message.body).toContain("2台");
    expect(state.sent[0].message.body).toContain("トヨタ プリウス・10月5日");
    expect(state.result?.result.sent).toBe(2);
  });

  it("通知を切っている利用者には送らない（プッシュ・車検リマインダーのどちらでも）", async () => {
    const w = world({
      vehicles: {
        v1: { customerId: "c1", inspectionExpiry: ts(jst(2026, 10, 20)) },
        v2: { customerId: "c2", inspectionExpiry: ts(jst(2026, 10, 21)) },
      },
      customers: { c1: { linkedUserId: "u1" }, c2: { linkedUserId: "u2" } },
      links: { u1: SHOP, u2: SHOP },
      users: {
        u1: { fcmTokens: ["a"], notificationSettings: { pushEnabled: false } },
        u2: {
          fcmTokens: ["b"],
          notificationSettings: { pushEnabled: true, carInspectionReminder: false },
        },
      },
    });
    const { state } = await run(w, ["v1", "v2"]);

    expect(state.sent).toHaveLength(0);
    expect(state.result?.result.pushOff).toBe(2);
    // 案内した日は付けない（はがきで案内できるように）
    expect(w.vehicles.v1.inspectionNoticeAt).toBeUndefined();
  });

  it("届かなくなったトークンは外し、届いた端末があれば送れたことにする", async () => {
    const w = world({ users: { u1: { fcmTokens: ["old", "new"] } } });
    const { state } = await run(w, ["v1"], {
      send: async () => ({ successCount: 1, invalidTokens: ["old"] }),
    });

    expect(state.removed).toEqual([{ uid: "u1", tokens: ["old"] }]);
    expect(state.result?.result.sent).toBe(1);
  });

  describe("Edge Cases", () => {
    it("データが無ければ何もしない", async () => {
      const { deps } = fakeDeps(world());
      const outcome = await handleInspectionNoticeCreated(
        { shopId: SHOP, noticeId: "n1", eventId: "ev1", data: undefined },
        deps
      );
      expect(outcome).toBe("no-data");
      expect(deps.claimRequest).not.toHaveBeenCalled();
    });

    it("同じ依頼を二度処理しない（イベントの重複配信）", async () => {
      const { outcome, state, deps } = await run(world(), ["v1"], {
        requestClaimed: true,
      });
      expect(outcome).toBe("already");
      expect(state.sent).toHaveLength(0);
      expect(deps.writeResult).not.toHaveBeenCalled();
    });

    it("いまの満了日で案内済み（はがきで出した）車には送らない", async () => {
      const w = world();
      w.vehicles.v1.inspectionNoticeAt = ts(new Date(NOW.getTime() - 7 * DAY));
      w.vehicles.v1.inspectionNoticeExpiry = ts(jst(2026, 10, 20));
      const { state } = await run(w, ["v1"]);

      expect(state.sent).toHaveLength(0);
      expect(state.result?.result.alreadyNoticed).toBe(1);
    });

    it("前の満了日で案内した車は、満了日が進めばまた送る", async () => {
      const w = world();
      w.vehicles.v1.inspectionNoticeAt = ts(new Date("2024-09-01T00:00:00Z"));
      w.vehicles.v1.inspectionNoticeExpiry = ts(jst(2024, 10, 20));
      const { state } = await run(w, ["v1"]);
      expect(state.result?.result.sent).toBe(1);
    });

    it("別の依頼が先に引き受けた車は送らない（引き受けで弾かれる）", async () => {
      const w = world();
      const { deps, state } = fakeDeps(w);
      (deps.claimVehicles as jest.Mock).mockResolvedValueOnce([]);
      await handleInspectionNoticeCreated(
        {
          shopId: SHOP,
          noticeId: "n1",
          eventId: "ev1",
          data: { vehicleIds: ["v1"] },
        },
        deps,
        () => NOW
      );
      expect(state.sent).toHaveLength(0);
      expect(state.result?.result.alreadyNoticed).toBe(1);
    });

    it("消された車・満了日が無い／先すぎる／過ぎた車は数えるだけ", async () => {
      const w = world({
        vehicles: {
          none: { customerId: "c1" },
          far: {
            customerId: "c1",
            inspectionExpiry: ts(new Date(NOW.getTime() + (MAX_DAYS_AHEAD + 1) * DAY)),
          },
          past: {
            customerId: "c1",
            inspectionExpiry: ts(new Date(NOW.getTime() - 2 * DAY)),
          },
        },
      });
      const { state } = await run(w, ["gone", "none", "far", "past"]);
      expect(state.sent).toHaveLength(0);
      expect(state.result?.result.notFound).toBe(1);
      expect(state.result?.result.outOfRange).toBe(3);
    });

    it("台帳のつながりが無い・利用者が札を外した／別の店に替えた車には送らない", async () => {
      const w = world({
        vehicles: {
          a: { customerId: "c-none", inspectionExpiry: ts(jst(2026, 10, 20)) },
          b: { customerId: "c-unlinked", inspectionExpiry: ts(jst(2026, 10, 20)) },
          c: { customerId: "c-other", inspectionExpiry: ts(jst(2026, 10, 20)) },
          d: { customerId: "c-gone", inspectionExpiry: ts(jst(2026, 10, 20)) },
        },
        customers: {
          "c-unlinked": {},
          "c-other": { linkedUserId: "u-other" },
          "c-gone": { linkedUserId: "u-gone" },
        },
        links: { "u-other": "shop-2" },
      });
      const { state } = await run(w, ["a", "b", "c", "d"]);
      expect(state.sent).toHaveLength(0);
      expect(state.result?.result.notLinked).toBe(4);
    });

    it("端末が登録されていなければ送らない", async () => {
      const w = world({ users: { u1: {} } });
      const { state } = await run(w, ["v1"]);
      expect(state.sent).toHaveLength(0);
      expect(state.result?.result.noDevice).toBe(1);
      expect(w.vehicles.v1.inspectionNoticeAt).toBeUndefined();
    });

    it("1台の端末にも届かなければ、案内した日を戻す", async () => {
      const w = world({ users: { u1: { fcmTokens: ["a", "b"] } } });
      const { state } = await run(w, ["v1"], {
        send: async () => ({ successCount: 0, invalidTokens: ["a"] }),
      });
      expect(state.released).toHaveLength(1);
      expect(w.vehicles.v1.inspectionNoticeAt).toBeNull();
      expect(state.result?.result.failed).toBe(1);
      expect(state.result?.result.sent).toBe(0);
    });

    it("全部の端末が届かないトークンだったら、端末なしとして数える", async () => {
      const w = world({ users: { u1: { fcmTokens: ["a"] } } });
      const { state } = await run(w, ["v1"], {
        send: async () => ({ successCount: 0, invalidTokens: ["a"] }),
      });
      expect(state.result?.result.noDevice).toBe(1);
      expect(state.removed).toEqual([{ uid: "u1", tokens: ["a"] }]);
    });

    it("送信が例外を投げたら、その人の車は戻して失敗に数え、ほかの人には送る", async () => {
      const w = world({
        vehicles: {
          v1: { customerId: "c1", inspectionExpiry: ts(jst(2026, 10, 20)) },
          v2: { customerId: "c2", inspectionExpiry: ts(jst(2026, 10, 21)) },
        },
        customers: { c1: { linkedUserId: "u1" }, c2: { linkedUserId: "u2" } },
        links: { u1: SHOP, u2: SHOP },
        users: { u1: { fcmTokens: ["a"] }, u2: { fcmTokens: ["b"] } },
      });
      const { state } = await run(w, ["v1", "v2"], {
        send: async (tokens: string[]) => {
          if (tokens[0] === "a") throw new Error("unavailable");
          return { successCount: 1, invalidTokens: [] };
        },
      });
      expect(state.result?.result.failed).toBe(1);
      expect(state.result?.result.sent).toBe(1);
      expect(w.vehicles.v1.inspectionNoticeAt).toBeNull();
    });

    it("読み込みで落ちたら failed を書いて終える（例外は外に出さない）", async () => {
      const { deps, state } = fakeDeps(world());
      deps.loadVehicle = async () => {
        throw new Error("boom");
      };
      const outcome = await handleInspectionNoticeCreated(
        { shopId: SHOP, noticeId: "n1", eventId: "ev1", data: { vehicleIds: ["v1"] } },
        deps,
        () => NOW
      );
      expect(outcome).toBe("failed");
      expect(state.result?.status).toBe("failed");
      expect(state.result?.error).toBe("boom");
    });

    it("vehicleIds が配列でない・空なら、何も送らず done", async () => {
      for (const ids of [undefined, "v1", [], [1, null, ""]]) {
        const { state, outcome } = await run(world(), ids);
        expect(outcome).toBe("done");
        expect(state.sent).toHaveLength(0);
        expect(state.result?.result.sent).toBe(0);
      }
    });

    it("同じ利用者の札は1回だけ読む", async () => {
      const w = world({
        vehicles: {
          v1: { customerId: "c1", inspectionExpiry: ts(jst(2026, 10, 20)) },
          v2: { customerId: "c1", inspectionExpiry: ts(jst(2026, 10, 21)) },
        },
      });
      const { deps } = await run(w, ["v1", "v2"]);
      expect(deps.loadLinkShopId).toHaveBeenCalledTimes(1);
    });
  });
});

describe("判定の小さな関数", () => {
  it("isNoticedForCurrentExpiry は日本の日付で比べる", () => {
    const v: LedgerVehicleData = {
      inspectionExpiry: ts(jst(2026, 10, 20)),
      inspectionNoticeAt: ts(NOW),
      // 同じ日の昼（取込のやり直しで時刻がずれた）
      inspectionNoticeExpiry: ts(new Date(jst(2026, 10, 20).getTime() + 12 * 3600 * 1000)),
    };
    expect(isNoticedForCurrentExpiry(v)).toBe(true);
    expect(isNoticedForCurrentExpiry({ ...v, inspectionNoticeAt: null })).toBe(false);
    expect(isNoticedForCurrentExpiry({ ...v, inspectionExpiry: ts(jst(2026, 10, 21)) })).toBe(
      false
    );
  });

  it("isInNoticeWindow は前日〜MAX_DAYS_AHEAD 日先（境界を含む）", () => {
    const at = (ms: number) => ({ inspectionExpiry: ts(new Date(NOW.getTime() + ms)) });
    expect(isInNoticeWindow(at(-DAY), NOW)).toBe(true);
    expect(isInNoticeWindow(at(-DAY - 1), NOW)).toBe(false);
    expect(isInNoticeWindow(at(MAX_DAYS_AHEAD * DAY), NOW)).toBe(true);
    expect(isInNoticeWindow(at(MAX_DAYS_AHEAD * DAY + 1), NOW)).toBe(false);
    expect(isInNoticeWindow({}, NOW)).toBe(false);
  });

  it("wantsInspectionPush は設定が無ければ受け取る（アプリの既定と同じ）", () => {
    expect(wantsInspectionPush({})).toBe(true);
    expect(wantsInspectionPush({ notificationSettings: null })).toBe(true);
    expect(wantsInspectionPush({ notificationSettings: { pushEnabled: true } })).toBe(true);
    expect(wantsInspectionPush({ notificationSettings: { pushEnabled: false } })).toBe(false);
    expect(
      wantsInspectionPush({ notificationSettings: { carInspectionReminder: false } })
    ).toBe(false);
  });

  it("tokensOf は文字列だけを重ねずに", () => {
    expect(tokensOf({ fcmTokens: ["a", "a", "", 3, null, "b"] })).toEqual(["a", "b"]);
    expect(tokensOf({ fcmTokens: "a" })).toEqual([]);
  });

  it("vehicleIdsOf はパスを含む ID を捨て、上限で切る", () => {
    expect(vehicleIdsOf({ vehicleIds: ["a", "a", "x/y", "b"] })).toEqual(["a", "b"]);
    const many = Array.from({ length: MAX_VEHICLES + 5 }, (_, i) => `v${i}`);
    expect(vehicleIdsOf({ vehicleIds: many })).toHaveLength(MAX_VEHICLES);
  });

  it("invalidTokensFrom は登録切れ・不正なトークンだけを選ぶ", () => {
    expect(
      invalidTokensFrom(
        ["a", "b", "c", "d"],
        [
          { success: true },
          { success: false, error: { code: "messaging/registration-token-not-registered" } },
          { success: false, error: { code: "messaging/internal-error" } },
          { success: false, error: { code: "messaging/invalid-registration-token" } },
        ]
      )
    ).toEqual(["b", "d"]);
  });

  it("文面に登録番号は載せない・店名が無ければ「整備工場」", () => {
    const m = buildPushMessage({
      shopId: SHOP,
      noticeId: "n1",
      shopName: "  ",
      vehicles: [{ maker: "", model: "", inspectionExpiry: ts(jst(2026, 12, 1)) }],
    });
    expect(m.title).toBe("車検のご案内（整備工場）");
    expect(m.body).toBe("お車の車検満了日は12月1日です。ご予約・ご相談は整備工場まで。");
  });

  it("jstMonthDay は日本の日付", () => {
    expect(jstMonthDay(jst(2026, 1, 1))).toBe("1月1日");
  });
});
