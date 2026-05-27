"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import type { Deck } from "@/lib/types";
import {
  getUnlockedDeckIds,
  hasBundle,
  unlockBundle,
  unlockDeck,
} from "@/lib/progress";

type Props = {
  decks: Deck[];
  bundlePriceJpy: number;
  bundleSavings: number;
};

export function ProDeckPurchaseList({
  decks,
  bundlePriceJpy,
  bundleSavings,
}: Props) {
  const [unlockedIds, setUnlockedIds] = useState<string[]>([]);
  const [bundleOwned, setBundleOwned] = useState<boolean>(false);
  const [pendingId, setPendingId] = useState<string | null>(null);

  const refresh = useCallback(() => {
    setUnlockedIds(getUnlockedDeckIds());
    setBundleOwned(hasBundle());
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  function handlePurchaseDeck(deck: Deck) {
    setPendingId(deck.id);
    // 本番ではここで Stripe Checkout へ。MVP はモック即時アンロック。
    setTimeout(() => {
      unlockDeck(deck.id);
      refresh();
      setPendingId(null);
    }, 400);
  }

  function handlePurchaseBundle() {
    setPendingId("__bundle__");
    setTimeout(() => {
      unlockBundle();
      refresh();
      setPendingId(null);
    }, 400);
  }

  function isUnlocked(deckId: string): boolean {
    return bundleOwned || unlockedIds.includes(deckId);
  }

  return (
    <>
      <section className="rounded-3xl border border-amber-500/40 bg-gradient-to-br from-amber-500/10 via-card to-card p-6 sm:p-8">
        <div className="flex flex-col items-start gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full border border-amber-400/40 bg-amber-500/15 px-2.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-amber-200">
              バンドル
            </div>
            <h2 className="mt-2 text-xl font-bold sm:text-2xl">
              PROデッキ全部入りパック
            </h2>
            <p className="mt-1 text-sm text-muted">
              現在公開中のPROデッキ {decks.length} 個を一括アンロック。
              {bundleSavings > 0 && (
                <span className="ml-1 text-amber-200">
                  ¥{bundleSavings.toLocaleString()} お得
                </span>
              )}
            </p>
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-3xl font-bold tabular-nums">
              ¥{bundlePriceJpy.toLocaleString()}
            </span>
            <span className="text-xs text-muted">買い切り</span>
          </div>
        </div>
        <button
          type="button"
          onClick={handlePurchaseBundle}
          disabled={bundleOwned || pendingId !== null}
          className="mt-4 w-full rounded-full bg-gradient-to-r from-amber-400 to-orange-500 px-5 py-3 text-sm font-semibold text-amber-950 shadow-lg shadow-amber-500/20 transition disabled:cursor-not-allowed disabled:opacity-60 sm:w-auto"
        >
          {bundleOwned
            ? "✓ 購入済み（全PROデッキ開放中）"
            : pendingId === "__bundle__"
              ? "処理中..."
              : "バンドルを購入する"}
        </button>
        <p className="mt-2 text-[10px] text-muted">
          ※ 現在は決済モック実装。実決済（Stripe）は次バージョンで対応予定。
        </p>
      </section>

      <section className="grid gap-4 sm:grid-cols-2">
        {decks.map((deck) => {
          const unlocked = isUnlocked(deck.id);
          const pending = pendingId === deck.id;
          return (
            <div
              key={deck.id}
              className="flex flex-col rounded-2xl border border-border bg-card p-5"
            >
              <div className="flex items-start gap-3">
                <div
                  className={`grid h-12 w-12 shrink-0 place-items-center rounded-xl bg-gradient-to-br ${deck.accentColor} text-2xl shadow-md`}
                  aria-hidden
                >
                  {deck.emoji}
                </div>
                <div className="min-w-0 flex-1">
                  <h3 className="text-base font-semibold leading-tight">
                    {deck.title}
                  </h3>
                  <p className="mt-0.5 text-xs text-muted">{deck.subtitle}</p>
                </div>
                <div className="text-right">
                  <div className="text-lg font-bold tabular-nums">
                    ¥{deck.priceJpy.toLocaleString()}
                  </div>
                  <div className="text-[10px] text-muted">買い切り</div>
                </div>
              </div>

              <p className="mt-3 line-clamp-3 text-sm text-muted">
                {deck.description}
              </p>

              <div className="mt-4 flex items-center justify-between text-xs text-muted">
                <span>{deck.questions.length}問</span>
                <span>約{deck.estimatedMinutes}分</span>
              </div>

              <div className="mt-4 flex flex-col gap-2 sm:flex-row">
                <Link
                  href={`/decks/${deck.id}/play`}
                  className="flex-1 rounded-full border border-border bg-card-elevated px-4 py-2 text-center text-xs font-semibold"
                >
                  3問お試し
                </Link>
                <button
                  type="button"
                  onClick={() => handlePurchaseDeck(deck)}
                  disabled={unlocked || pending || bundleOwned}
                  className="flex-1 rounded-full bg-gradient-to-r from-indigo-500 to-fuchsia-500 px-4 py-2 text-center text-xs font-semibold text-white shadow-md shadow-indigo-500/20 transition disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {unlocked
                    ? "✓ 購入済み"
                    : pending
                      ? "処理中..."
                      : "購入してアンロック"}
                </button>
              </div>
            </div>
          );
        })}
      </section>
    </>
  );
}
