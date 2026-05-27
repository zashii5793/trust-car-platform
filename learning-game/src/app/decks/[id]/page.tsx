import Link from "next/link";
import { notFound } from "next/navigation";
import { Brand } from "@/components/Brand";
import { StreakBadge } from "@/components/StreakBadge";
import { ALL_DECKS, getDeckById } from "@/lib/decks";

export function generateStaticParams() {
  return ALL_DECKS.map((d) => ({ id: d.id }));
}

export default async function DeckDetail({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const deck = getDeckById(id);
  if (!deck) notFound();

  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-3xl flex-col gap-8 px-4 pb-20 pt-6 sm:px-6 sm:pt-10">
      <header className="flex items-center justify-between">
        <Brand size="sm" />
        <StreakBadge />
      </header>

      <Link
        href="/"
        className="-mb-3 inline-flex w-fit items-center gap-1 text-sm text-muted hover:text-foreground"
      >
        ← デッキ一覧へ
      </Link>

      <section className="overflow-hidden rounded-3xl border border-border bg-card">
        <div className={`h-2 w-full bg-gradient-to-r ${deck.accentColor}`} />
        <div className="p-6 sm:p-8">
          <div className="flex items-start gap-4">
            <div
              className={`grid h-16 w-16 shrink-0 place-items-center rounded-2xl bg-gradient-to-br ${deck.accentColor} text-3xl shadow-lg`}
              aria-hidden
            >
              {deck.emoji}
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                {deck.tier === "paid" ? (
                  <span className="rounded-md bg-amber-500/15 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-amber-400">
                    PRO
                  </span>
                ) : (
                  <span className="rounded-md bg-emerald-500/15 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-emerald-400">
                    FREE
                  </span>
                )}
                <span className="text-xs text-muted">
                  {deck.questions.length}問 · 約{deck.estimatedMinutes}分
                </span>
              </div>
              <h1 className="mt-1 text-2xl font-bold tracking-tight sm:text-3xl">
                {deck.title}
              </h1>
              <p className="mt-1 text-sm text-muted">{deck.subtitle}</p>
            </div>
          </div>

          <p className="mt-6 text-sm leading-relaxed text-foreground/85 sm:text-base">
            {deck.description}
          </p>

          <div className="mt-6 grid grid-cols-3 gap-3 rounded-2xl border border-border bg-card-elevated p-4 text-center sm:gap-6">
            <DeckStat label="問題数" value={`${deck.questions.length}`} />
            <DeckStat label="所要時間" value={`${deck.estimatedMinutes}分`} />
            <DeckStat
              label="形式"
              value={(() => {
                const tf = deck.questions.filter(
                  (q) => q.format === "true_false",
                ).length;
                return tf > 0 ? `4択 + ○×` : "4択";
              })()}
            />
          </div>

          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            <Link
              href={`/decks/${deck.id}/play`}
              className="flex-1 rounded-full bg-gradient-to-r from-indigo-500 to-fuchsia-500 px-5 py-3 text-center text-base font-semibold text-white shadow-lg shadow-indigo-500/25"
            >
              ▶ プレイする
            </Link>
            {deck.tier === "paid" && (
              <Link
                href="/pro"
                className="rounded-full border border-amber-500/40 bg-amber-500/10 px-5 py-3 text-center text-sm font-semibold text-amber-200"
              >
                Pro なら無制限プレイ
              </Link>
            )}
          </div>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold text-muted">
          このデッキで学べること
        </h2>
        <ul className="grid gap-2 rounded-2xl border border-border bg-card p-4 text-sm">
          {deck.questions.slice(0, 5).map((q) => (
            <li key={q.id} className="flex items-start gap-2">
              <span aria-hidden className="mt-0.5 text-indigo-400">
                ◆
              </span>
              <span className="text-foreground/85">{q.prompt}</span>
            </li>
          ))}
          {deck.questions.length > 5 && (
            <li className="text-xs text-muted">
              ほか {deck.questions.length - 5} 問
            </li>
          )}
        </ul>
      </section>
    </div>
  );
}

function DeckStat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-[10px] uppercase tracking-wider text-muted">
        {label}
      </div>
      <div className="mt-0.5 text-base font-bold tabular-nums sm:text-lg">
        {value}
      </div>
    </div>
  );
}
