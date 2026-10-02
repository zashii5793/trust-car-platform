// 配信停止リンクでの購読停止（src/unsubscribeNewsletter.ts）のテスト。
// HTTPS 関数の本体は index.ts。Firestore は差し込みで差し替える。

import {
  MAX_TOKEN_LENGTH,
  MIN_TOKEN_LENGTH,
  handleUnsubscribe,
  isValidToken,
  type UnsubscribeDeps,
} from "../src/unsubscribeNewsletter";

const TOKEN = "tok_0123456789abcdef0123456789abcdef";

function fakeDeps(subs: Record<string, string> = { "user-1": TOKEN }) {
  const unsubscribed: string[] = [];
  const deps: UnsubscribeDeps = {
    findByToken: jest.fn(async (token: string) => {
      const hit = Object.entries(subs).find(([, t]) => t === token);
      return hit ? hit[0] : null;
    }),
    markUnsubscribed: jest.fn(async (id: string) => {
      unsubscribed.push(id);
    }),
  };
  return { deps, unsubscribed };
}

describe("handleUnsubscribe", () => {
  test("トークンが一致する購読を止める", async () => {
    const { deps, unsubscribed } = fakeDeps();
    const res = await handleUnsubscribe("POST", { token: TOKEN }, deps);
    expect(res).toEqual({ status: 200, body: { ok: true } });
    expect(unsubscribed).toEqual(["user-1"]);
  });

  test("一致する購読が無ければ 404 で、何も書かない", async () => {
    const { deps, unsubscribed } = fakeDeps();
    const res = await handleUnsubscribe(
      "POST",
      { token: "tok_doesnotexist_0000000000" },
      deps
    );
    expect(res.status).toBe(404);
    expect(unsubscribed).toEqual([]);
  });

  test("応答に誰の購読かを含めない", async () => {
    const { deps } = fakeDeps();
    const res = await handleUnsubscribe("POST", { token: TOKEN }, deps);
    expect(JSON.stringify(res.body)).not.toContain("user-1");
  });

  describe("Edge Cases", () => {
    test.each(["GET", "PUT", "DELETE"])(
      "%s は 405（リンクの先読みで勝手に止めない）",
      async (method) => {
        const { deps, unsubscribed } = fakeDeps();
        const res = await handleUnsubscribe(method, { token: TOKEN }, deps);
        expect(res.status).toBe(405);
        expect(deps.findByToken).not.toHaveBeenCalled();
        expect(unsubscribed).toEqual([]);
      }
    );

    test("空のトークンは 400 で、検索もしない（未発行の購読に当たらない）", async () => {
      // 既定値が空文字なので、空で検索すると未発行の購読が全部当たる
      const { deps } = fakeDeps({ "user-1": "", "user-2": "" });
      const res = await handleUnsubscribe("POST", { token: "" }, deps);
      expect(res.status).toBe(400);
      expect(deps.findByToken).not.toHaveBeenCalled();
    });

    test.each([
      ["本文なし", undefined],
      ["null", null],
      ["token なし", {}],
      ["数値", { token: 12345678901234567890 }],
      ["配列", { token: [TOKEN] }],
      ["短すぎる", { token: "a".repeat(MIN_TOKEN_LENGTH - 1) }],
      ["長すぎる", { token: "a".repeat(MAX_TOKEN_LENGTH + 1) }],
      ["使えない文字", { token: "tok/../../0123456789abcdef" }],
    ])("%s は 400", async (_label, body) => {
      const { deps } = fakeDeps();
      const res = await handleUnsubscribe("POST", body, deps);
      expect(res.status).toBe(400);
      expect(deps.findByToken).not.toHaveBeenCalled();
    });

    test("ちょうど最小・最大の長さは通す", async () => {
      expect(isValidToken("a".repeat(MIN_TOKEN_LENGTH))).toBe(true);
      expect(isValidToken("a".repeat(MAX_TOKEN_LENGTH))).toBe(true);
    });

    test("Firestore が失敗したら 500（中身は返さない）", async () => {
      const { deps } = fakeDeps();
      deps.markUnsubscribed = jest.fn(async () => {
        throw new Error("internal: secret detail");
      });
      const spy = jest.spyOn(console, "error").mockImplementation(() => {});
      const res = await handleUnsubscribe("POST", { token: TOKEN }, deps);
      spy.mockRestore();
      expect(res.status).toBe(500);
      expect(JSON.stringify(res.body)).not.toContain("secret detail");
    });

    test("2回目も成功を返す（同じリンクを2回押しても困らない）", async () => {
      const { deps } = fakeDeps();
      await handleUnsubscribe("POST", { token: TOKEN }, deps);
      const res = await handleUnsubscribe("POST", { token: TOKEN }, deps);
      expect(res.status).toBe(200);
    });
  });
});
