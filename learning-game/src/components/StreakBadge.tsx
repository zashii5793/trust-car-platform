"use client";

import { useEffect, useState } from "react";
import { getStreak } from "@/lib/progress";

export function StreakBadge() {
  const [streak, setStreak] = useState<number | null>(null);

  useEffect(() => {
    setStreak(getStreak());
  }, []);

  if (streak === null) {
    return <div className="h-9 w-20" aria-hidden />;
  }

  return (
    <div className="flex items-center gap-1.5 rounded-full border border-border bg-card px-3 py-1.5 text-xs">
      <span aria-hidden>🔥</span>
      <span className="font-medium">{streak}日連続</span>
    </div>
  );
}
