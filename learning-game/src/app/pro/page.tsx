import Link from "next/link";
import { Brand } from "@/components/Brand";

type Plan = {
  name: string;
  price: string;
  period?: string;
  badge?: string;
  features: string[];
  cta: string;
  highlight?: boolean;
};

const PLANS: Plan[] = [
  {
    name: "Free",
    price: "¥0",
    features: [
      "1日3問まで無料プレイ",
      "FREE デッキは全問プレイ可能",
      "連続日数（ストリーク）記録",
      "スコア記録（端末内）",
    ],
    cta: "今のままで使う",
  },
  {
    name: "Pro Monthly",
    price: "¥480",
    period: "/月",
    badge: "人気",
    highlight: true,
    features: [
      "すべての PRO デッキを開放",
      "無制限プレイ（1日制限なし）",
      "間違えた問題だけ復習モード",
      "クラウド進捗同期（マルチデバイス）",
      "新規デッキへの早期アクセス",
    ],
    cta: "月額で始める",
  },
  {
    name: "Pro Annual",
    price: "¥3,980",
    period: "/年",
    badge: "31% OFF",
    features: [
      "Pro Monthly のすべて",
      "実質 ¥332/月（2か月分お得）",
      "解約しなければ自動更新",
    ],
    cta: "年額で始める",
  },
];

export default function ProPage() {
  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-4xl flex-col gap-10 px-4 pb-20 pt-6 sm:px-6 sm:pt-10">
      <header className="flex items-center justify-between">
        <Brand size="sm" />
        <Link
          href="/"
          className="text-sm text-muted hover:text-foreground"
        >
          ← ホーム
        </Link>
      </header>

      <section className="text-center">
        <div className="inline-flex items-center gap-2 rounded-full border border-amber-500/30 bg-amber-500/10 px-3 py-1 text-xs text-amber-200">
          <span aria-hidden>✨</span> ZAXEL Pro
        </div>
        <h1 className="mt-3 text-3xl font-bold tracking-tight sm:text-4xl">
          スキルを、本気で磨く人へ。
        </h1>
        <p className="mx-auto mt-3 max-w-xl text-sm text-muted sm:text-base">
          1日3問の制限を外して、すべてのデッキを無制限にプレイ。 通勤時間に1テーマを完走できます。
        </p>
      </section>

      <section className="grid gap-4 sm:grid-cols-3">
        {PLANS.map((p) => (
          <div
            key={p.name}
            className={`relative flex flex-col rounded-2xl border p-5 ${
              p.highlight
                ? "border-indigo-400/60 bg-card shadow-xl shadow-indigo-500/10"
                : "border-border bg-card"
            }`}
          >
            {p.badge && (
              <span
                className={`absolute -top-3 left-1/2 -translate-x-1/2 rounded-full px-3 py-0.5 text-[10px] font-semibold uppercase tracking-wider ${
                  p.highlight
                    ? "bg-gradient-to-r from-indigo-500 to-fuchsia-500 text-white"
                    : "bg-amber-500/20 text-amber-200"
                }`}
              >
                {p.badge}
              </span>
            )}
            <div className="text-sm font-semibold text-muted">{p.name}</div>
            <div className="mt-1 flex items-baseline gap-1">
              <span className="text-3xl font-bold tracking-tight">
                {p.price}
              </span>
              {p.period && (
                <span className="text-sm text-muted">{p.period}</span>
              )}
            </div>
            <ul className="mt-5 flex-1 space-y-2 text-sm">
              {p.features.map((f) => (
                <li key={f} className="flex items-start gap-2">
                  <span
                    aria-hidden
                    className={`mt-0.5 ${p.highlight ? "text-indigo-300" : "text-emerald-400"}`}
                  >
                    ✓
                  </span>
                  <span className="text-foreground/85">{f}</span>
                </li>
              ))}
            </ul>
            <button
              type="button"
              disabled
              className={`mt-6 rounded-full px-5 py-2.5 text-sm font-semibold transition disabled:cursor-not-allowed disabled:opacity-60 ${
                p.highlight
                  ? "bg-gradient-to-r from-indigo-500 to-fuchsia-500 text-white"
                  : "border border-border bg-card-elevated"
              }`}
            >
              {p.cta}
            </button>
            <div className="mt-2 text-center text-[10px] text-muted">
              ※ 決済は次バージョンで実装予定
            </div>
          </div>
        ))}
      </section>

      <section className="rounded-2xl border border-border bg-card p-6 text-sm">
        <h2 className="font-semibold">よくある質問</h2>
        <dl className="mt-4 space-y-4 text-foreground/85">
          <div>
            <dt className="font-medium">Q. なぜ有料プランがあるの？</dt>
            <dd className="mt-1 text-muted">
              実戦で磨かれた研修コンテンツを継続的に追加・運営するためです。
              無料で多くの方に試してもらいつつ、深く学びたい方に支えていただく形を取っています。
            </dd>
          </div>
          <div>
            <dt className="font-medium">Q. 法人での導入は可能？</dt>
            <dd className="mt-1 text-muted">
              チーム / 法人プランは別途ご相談ください（10名以上、月額1人 ¥300〜想定）。
            </dd>
          </div>
          <div>
            <dt className="font-medium">Q. 無料で十分？</dt>
            <dd className="mt-1 text-muted">
              はい、まずはFREEデッキで体験してください。続きを学びたくなったらProへ。
            </dd>
          </div>
        </dl>
      </section>
    </div>
  );
}
