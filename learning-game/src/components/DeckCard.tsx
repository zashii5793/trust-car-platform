import Link from "next/link";
import type { Deck } from "@/lib/types";

export function DeckCard({ deck }: { deck: Deck }) {
  const isPaid = deck.tier === "paid";
  return (
    <Link
      href={`/decks/${deck.id}`}
      className="group relative block overflow-hidden rounded-2xl border border-border bg-card p-5 transition hover:border-indigo-400/40 hover:shadow-xl hover:shadow-indigo-500/5"
    >
      <div
        className={`absolute inset-x-0 top-0 h-1 bg-gradient-to-r ${deck.accentColor}`}
        aria-hidden
      />
      <div className="flex items-start gap-3">
        <div
          className={`grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-gradient-to-br ${deck.accentColor} text-2xl shadow-md`}
          aria-hidden
        >
          {deck.emoji}
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <h3 className="truncate text-base font-semibold leading-tight sm:text-lg">
              {deck.title}
            </h3>
            {isPaid ? (
              <span className="shrink-0 rounded-md bg-amber-500/15 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-amber-400">
                PRO
              </span>
            ) : (
              <span className="shrink-0 rounded-md bg-emerald-500/15 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-emerald-400">
                FREE
              </span>
            )}
          </div>
          <p className="mt-0.5 text-xs text-muted sm:text-sm">{deck.subtitle}</p>
        </div>
      </div>

      <p className="mt-3 line-clamp-2 text-sm text-muted">{deck.description}</p>

      <div className="mt-4 flex items-center justify-between text-xs text-muted">
        <span>{deck.questions.length}問</span>
        <span>約{deck.estimatedMinutes}分</span>
        <span className="font-medium text-foreground/80 group-hover:text-foreground">
          始める →
        </span>
      </div>
    </Link>
  );
}
