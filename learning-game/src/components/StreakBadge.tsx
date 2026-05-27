"use client";

import { useEffect, useState } from "react";
import { getStreak, getFreePlaysRemaining, FREE_PLAY_LIMIT } from "@/lib/progress";

export function StreakBadge() {
  const [streak, setStreak] = useState<number | null>(null);
  const [freePlays, setFreePlays] = useState<number | null>(null);

  useEffect(() => {
    setStreak(getStreak());
    setFreePlays(getFreePlaysRemaining());
  }, []);

  if (streak === null || freePlays === null) {
    return <div className="h-9 w-32" aria-hidden />;
  }

  return (
    <div className="flex items-center gap-2 text-xs">
      <div className="flex items-center gap-1.5 rounded-full border border-border bg-card px-3 py-1.5">
        <span aria-hidden>🔥</span>
        <span className="font-medium">{streak}日連続</span>
      </div>
      <div className="flex items-center gap-1.5 rounded-full border border-border bg-card px-3 py-1.5">
        <span aria-hidden>🎟️</span>
        <span className="font-medium">
          {freePlays}/{FREE_PLAY_LIMIT}
        </span>
      </div>
    </div>
  );
}
