// 健康診断が NG に変わったときに、日次レポートを待たずに運営者へメールで知らせる。
//
// 2026-10-02 のオーナー判断: ok → ng に変わったときだけ送る。同じ NG で何度も送らない。
//
// - ops_health/latest に「この NG を知らせた」印（ngNotified）を持つ。ok に戻ったら外す
// - 前が ng でも印が無い（送信に失敗した・この仕組みを入れる前からの NG）なら送る。
//   送信に失敗したら印を付けず、次の診断（1時間後）で送り直す
// - 宛先（OPERATOR_EMAIL）が空なら送らず、印を付ける（毎時ログを出し続けない）
// - 本文は項目名と detail（件数・時間・エラーの先頭）だけ。個人情報は入れない
//
// 呼ぶのは index.ts の opsHealthCheck。ここは依存を差し込める純粋な処理だけ。

import {
  MAIL_FROM,
  formatJst,
  type OperatorMail,
} from "./notifyPlanRequest";
import type { HealthReport } from "./opsHealth";

/** 前回の診断のうち、知らせるかどうかの判断に使うところ。 */
export interface PreviousHealth {
  overall?: "ok" | "ng";
  ngNotified?: boolean;
}

export function decideHealthAlert(
  prev: PreviousHealth | null,
  overall: "ok" | "ng"
): "send" | "none" {
  if (overall !== "ng") return "none";
  if (prev && prev.overall === "ng" && prev.ngNotified === true) return "none";
  return "send";
}

const EMAIL = /[\w.+-]+@[\w-]+(?:\.[\w-]+)+/g;

/** 運営者向けの1行に整える（メールを伏せ、改行を消す）。 */
export function safeLine(text: string, max = 300): string {
  return text.replace(EMAIL, "[email]").replace(/\s+/g, " ").trim().slice(0, max);
}

/** 手順書の場所（NG のときに見るもの）。 */
export const RUNBOOK_REF =
  "docs/MAINTENANCE_RUNBOOK.md の 0-8「見張りの通知が来たら」";

export function buildHealthAlertMail(params: {
  to: string;
  report: HealthReport;
}): OperatorMail {
  const { to, report } = params;
  const ngItems = report.items.filter((i) => i.status === "ng");
  const first = ngItems[0]?.name ?? "(項目なし)";
  const more = ngItems.length > 1 ? " ほか" : "";
  const lines = [
    "本番の健康診断が NG になりました。",
    "",
    `確かめた時刻: ${formatJst(new Date(report.checkedAtMs))}（日本時間）`,
    "",
    "NG の項目:",
    ...ngItems.map((i) => `- [NG] ${i.name} — ${safeLine(i.detail)}`),
    "",
    `見るもの・打つコマンドは ${RUNBOOK_REF}。`,
    "./scripts/prod_watch.sh で今の状態を見られます。",
    "",
    "同じ NG が続く間は、このメールは再送しません（ok に戻ってから再び NG になったら送ります）。",
    "",
    "-- ",
    "このメールは TrustCar の Cloud Functions（opsHealthCheck）が自動で送っています。",
  ];
  return {
    to,
    from: MAIL_FROM,
    subject: `[TrustCar] 健康診断: NG ${ngItems.length}件（${first}${more}）`,
    text: lines.join("\n"),
  };
}

export interface AlertDeps {
  /** OPERATOR_EMAIL の値。未設定なら空文字。 */
  operatorEmail: () => string;
  send: (mail: OperatorMail) => Promise<void>;
}

export type AlertOutcome = "sent" | "none" | "failed" | "no-operator-email";

/**
 * 前回と今回の診断から、必要ならメールを送る。
 * 返す ngNotified を ops_health/latest に書く。例外は投げない（診断の書き込みを止めない）。
 */
export async function notifyHealthChange(
  prev: PreviousHealth | null,
  report: HealthReport,
  deps: AlertDeps
): Promise<{ ngNotified: boolean; outcome: AlertOutcome }> {
  if (report.overall === "ok") return { ngNotified: false, outcome: "none" };
  if (decideHealthAlert(prev, report.overall) === "none") {
    return { ngNotified: true, outcome: "none" };
  }
  const to = deps.operatorEmail().trim();
  if (!to) {
    console.warn("OPERATOR_EMAIL が未設定のため、健康診断の NG を知らせるメールを送りません");
    return { ngNotified: true, outcome: "no-operator-email" };
  }
  try {
    await deps.send(buildHealthAlertMail({ to, report }));
  } catch (err) {
    console.error("健康診断の NG を知らせるメールの送信に失敗（次の診断で送り直します）:", err);
    return { ngNotified: false, outcome: "failed" };
  }
  console.log("健康診断の NG を運営者にメールで知らせました");
  return { ngNotified: true, outcome: "sent" };
}
