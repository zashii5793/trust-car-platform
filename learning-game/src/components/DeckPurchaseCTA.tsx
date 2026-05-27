"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import type { Deck } from "@/lib/types";
import { PREVIEW_QUESTIONS, isDeckUnlocked } from "@/lib/progress";

export function DeckPurchaseCTA({ deck }: { deck: Deck }) {
  const isPaid = deck.tier === "paid";
  const [unlocked, setUnlocked] = useState<boolean>(!isPaid);

  useEffect(() => {
    if (isPaid) setUnlocked(isDeckUnlocked(deck.id));
  }, [deck.id, isPaid]);

  const showPaywall = isPaid && !unlocked;

  return (
    <div className="mt-8 flex flex-col gap-3 sm:flex-row">
      <Link
        href={`/decks/${deck.id}/play`}
        className="flex-1 rounded-full bg-gradient-to-r from-indigo-500 to-fuchsia-500 px-5 py-3 text-center text-base font-semibold text-white shadow-lg shadow-indigo-500/25"
      >
        {showPaywall ? `▶ お試し ${PREVIEW_QUESTIONS}問プレイ` : "▶ プレイする"}
      </Link>
      {showPaywall && (
        <Link
          href={`/pro?deck=${deck.id}`}
          className="rounded-full border border-amber-500/40 bg-amber-500/10 px-5 py-3 text-center text-sm font-semibold text-amber-200"
        >
          ¥{deck.priceJpy.toLocaleString()} で購入
        </Link>
      )}
      {isPaid && unlocked && (
        <span className="grid place-items-center rounded-full border border-emerald-500/40 bg-emerald-500/10 px-4 py-2 text-xs font-semibold text-emerald-300">
          ✓ 購入済み
        </span>
      )}
    </div>
  );
}
