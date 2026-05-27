import Link from "next/link";
import { Brand } from "@/components/Brand";
import { DeckCard } from "@/components/DeckCard";
import { StreakBadge } from "@/components/StreakBadge";
import { ALL_DECKS, CATEGORIES, getDecksByCategory } from "@/lib/decks";

export default function Home() {
  const totalQuestions = ALL_DECKS.reduce(
    (acc, d) => acc + d.questions.length,
    0,
  );

  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-5xl flex-col gap-10 px-4 pb-20 pt-6 sm:px-6 sm:pt-10">
      <header className="flex items-center justify-between">
        <Brand />
        <StreakBadge />
      </header>

      <section className="rounded-3xl border border-border bg-card p-6 sm:p-10">
        <div className="inline-flex items-center gap-2 rounded-full border border-border bg-card-elevated px-3 py-1 text-xs text-muted">
          <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
          現場で鍛えた研修コンテンツをクイズで
        </div>
        <h1 className="mt-4 text-3xl font-bold leading-tight tracking-tight sm:text-5xl">
          スキマ時間で、
          <br className="sm:hidden" />
          仕事の地力を鍛える。
        </h1>
        <p className="mt-4 max-w-2xl text-sm text-muted sm:text-base">
          コミュニケーション、思考法、組織論。実戦で磨かれたビジネススキルを、
          スマホで遊べる一問一答に。FREEデッキは全問無料、PROデッキはお気に入りだけ買い切りでアンロック。
        </p>
        <div className="mt-6 flex flex-wrap items-center gap-3 text-sm">
          <Link
            href={`/decks/${ALL_DECKS[0].id}`}
            className="rounded-full bg-gradient-to-r from-indigo-500 to-fuchsia-500 px-5 py-2.5 font-semibold text-white shadow-lg shadow-indigo-500/25"
          >
            まずは無料で始める
          </Link>
          <Link
            href="/pro"
            className="rounded-full border border-border bg-card-elevated px-5 py-2.5 font-semibold text-foreground"
          >
            PROデッキ一覧を見る
          </Link>
        </div>

        <dl className="mt-8 grid grid-cols-3 gap-4 border-t border-border pt-6 text-center sm:gap-8">
          <Stat label="デッキ" value={`${ALL_DECKS.length}`} />
          <Stat label="問題数" value={`${totalQuestions}`} />
          <Stat label="平均所要" value="7分" />
        </dl>
      </section>

      {CATEGORIES.map((cat) => {
        const decks = getDecksByCategory(cat.id);
        if (decks.length === 0) return null;
        return (
          <section key={cat.id}>
            <div className="mb-4 flex items-end justify-between">
              <h2 className="text-lg font-semibold sm:text-xl">{cat.label}</h2>
              <span className="text-xs text-muted">{decks.length} デッキ</span>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              {decks.map((d) => (
                <DeckCard key={d.id} deck={d} />
              ))}
            </div>
          </section>
        );
      })}

      <footer className="mt-6 border-t border-border pt-6 text-center text-xs text-muted">
        © {new Date().getFullYear()} ZAXEL-Learning · 現場で鍛えた研修コンテンツを、世界に開放する。
      </footer>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs text-muted">{label}</dt>
      <dd className="text-xl font-bold tabular-nums sm:text-2xl">{value}</dd>
    </div>
  );
}
