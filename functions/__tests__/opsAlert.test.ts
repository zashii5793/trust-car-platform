// 健康診断が NG に変わったときのメール（src/opsAlert.ts）のテスト。

import {
  buildHealthAlertMail,
  decideHealthAlert,
  notifyHealthChange,
  type AlertDeps,
} from "../src/opsAlert";
import { MAIL_FROM, type OperatorMail } from "../src/notifyPlanRequest";
import type { HealthReport } from "../src/opsHealth";

const NOW = Date.parse("2026-10-02T01:00:00Z");

const ng: HealthReport = {
  overall: "ng",
  checkedAtMs: NOW,
  items: [
    { name: "job.purgeDeletedAccounts", status: "ok", detail: "最後の成功: 2 時間前" },
    { name: "plan_requests.notify_failed", status: "ng", detail: "通知に失敗: 1 件" },
    { name: "backup.firestore", status: "ng", detail: "最新の READY が 50 時間前" },
  ],
};
const ok: HealthReport = { ...ng, overall: "ok", items: [ng.items[0]] };

describe("decideHealthAlert", () => {
  it("ok → ng に変わったら送る", () => {
    expect(decideHealthAlert({ overall: "ok", ngNotified: false }, "ng")).toBe(
      "send"
    );
  });

  it("ng のまま・送り済みなら送らない（同じ NG で何度も送らない）", () => {
    expect(decideHealthAlert({ overall: "ng", ngNotified: true }, "ng")).toBe(
      "none"
    );
  });

  it("ok のままなら送らない", () => {
    expect(decideHealthAlert({ overall: "ok", ngNotified: false }, "ok")).toBe(
      "none"
    );
  });

  it("ng → ok では送らない", () => {
    expect(decideHealthAlert({ overall: "ng", ngNotified: true }, "ok")).toBe(
      "none"
    );
  });

  describe("Edge Cases", () => {
    it("前の結果が無い（初回）で ng なら送る", () => {
      expect(decideHealthAlert(null, "ng")).toBe("send");
    });

    it("前も ng だが送れていなかった（失敗・印が無い）なら送り直す", () => {
      expect(decideHealthAlert({ overall: "ng", ngNotified: false }, "ng")).toBe(
        "send"
      );
      expect(decideHealthAlert({ overall: "ng" }, "ng")).toBe("send");
    });

    it("前の overall が壊れた値でも、ng なら送る", () => {
      expect(
        decideHealthAlert({ overall: "weird" as unknown as "ok" }, "ng")
      ).toBe("send");
    });
  });
});

describe("buildHealthAlertMail", () => {
  it("件名に NG の件数と最初の項目、本文に NG の項目と理由・手順書を入れる", () => {
    const mail = buildHealthAlertMail({ to: "ops@example.com", report: ng });
    expect(mail.from).toBe(MAIL_FROM);
    expect(mail.to).toBe("ops@example.com");
    expect(mail.subject).toBe(
      "[TrustCar] 健康診断: NG 2件（plan_requests.notify_failed ほか）"
    );
    expect(mail.text).toContain("[NG] plan_requests.notify_failed — 通知に失敗: 1 件");
    expect(mail.text).toContain("[NG] backup.firestore");
    expect(mail.text).toContain("2026-10-02 10:00");
    expect(mail.text).toContain("MAINTENANCE_RUNBOOK.md");
    // ok の項目は並べない
    expect(mail.text).not.toContain("job.purgeDeletedAccounts");
  });

  describe("Edge Cases", () => {
    it("NG が1件なら「ほか」を付けない", () => {
      const one = { ...ng, items: [ng.items[1]] };
      expect(buildHealthAlertMail({ to: "a@b.co", report: one }).subject).toBe(
        "[TrustCar] 健康診断: NG 1件（plan_requests.notify_failed）"
      );
    });

    it("detail にメールが紛れていても伏せる", () => {
      const leaky = {
        ...ng,
        items: [{ name: "job.x", status: "ng" as const, detail: "a taro@example.com" }],
      };
      expect(
        buildHealthAlertMail({ to: "ops@example.com", report: leaky }).text
      ).not.toContain("taro@example.com");
    });
  });
});

function deps(o: { email?: string; send?: () => Promise<void> } = {}) {
  const sent: OperatorMail[] = [];
  const d: AlertDeps = {
    operatorEmail: () => o.email ?? "ops@example.com",
    send: jest.fn(async (mail: OperatorMail) => {
      if (o.send) await o.send();
      sent.push(mail);
    }),
  };
  return { d, sent };
}

describe("notifyHealthChange", () => {
  it("ok → ng で送り、ngNotified=true を返す", async () => {
    const { d, sent } = deps();
    expect(await notifyHealthChange({ overall: "ok" }, ng, d)).toEqual({
      ngNotified: true,
      outcome: "sent",
    });
    expect(sent).toHaveLength(1);
  });

  it("送り済みの ng のままなら送らず、印は残す", async () => {
    const { d, sent } = deps();
    expect(
      await notifyHealthChange({ overall: "ng", ngNotified: true }, ng, d)
    ).toEqual({ ngNotified: true, outcome: "none" });
    expect(sent).toHaveLength(0);
  });

  it("ok に戻ったら印を外す", async () => {
    const { d } = deps();
    expect(
      await notifyHealthChange({ overall: "ng", ngNotified: true }, ok, d)
    ).toEqual({ ngNotified: false, outcome: "none" });
  });

  describe("Edge Cases", () => {
    it("送信に失敗したら印を付けない（次の診断で送り直す）・例外は投げない", async () => {
      const spy = jest.spyOn(console, "error").mockImplementation(() => {});
      const { d } = deps({
        send: async () => {
          throw new Error("503");
        },
      });
      expect(await notifyHealthChange({ overall: "ok" }, ng, d)).toEqual({
        ngNotified: false,
        outcome: "failed",
      });
      spy.mockRestore();
    });

    it("宛先が空なら送らず、送ったことにする（毎時ログを出し続けない）", async () => {
      const spy = jest.spyOn(console, "warn").mockImplementation(() => {});
      const { d, sent } = deps({ email: "" });
      expect(await notifyHealthChange({ overall: "ok" }, ng, d)).toEqual({
        ngNotified: true,
        outcome: "no-operator-email",
      });
      expect(sent).toHaveLength(0);
      spy.mockRestore();
    });
  });
});
