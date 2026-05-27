"use client";

import type { DeckProgress } from "./types";

const STORAGE_KEY = "zaxel-learning:progress:v1";
const STREAK_KEY = "zaxel-learning:streak:v1";
const UNLOCKED_KEY = "zaxel-learning:unlocked:v1";
const BUNDLE_FLAG = "__bundle__";

export const PREVIEW_QUESTIONS = 3;
export const BUNDLE_PRICE_JPY = 600;

type ProgressMap = Record<string, DeckProgress>;

type StreakState = {
  currentStreak: number;
  lastPlayedDate: string;
};

type UnlockedState = {
  deckIds: string[];
  bundle: boolean;
};

function todayKey(): string {
  const d = new Date();
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
}

function readJSON<T>(key: string, fallback: T): T {
  if (typeof window === "undefined") return fallback;
  try {
    const raw = window.localStorage.getItem(key);
    if (!raw) return fallback;
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

function writeJSON<T>(key: string, value: T): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(key, JSON.stringify(value));
  } catch {
    /* ignore quota errors */
  }
}

export function getAllProgress(): ProgressMap {
  return readJSON<ProgressMap>(STORAGE_KEY, {});
}

export function getDeckProgress(deckId: string): DeckProgress | undefined {
  return getAllProgress()[deckId];
}

export function recordResult(
  deckId: string,
  scorePercent: number,
): DeckProgress {
  const map = getAllProgress();
  const prev = map[deckId];
  const updated: DeckProgress = {
    deckId,
    bestScore: Math.max(prev?.bestScore ?? 0, scorePercent),
    attempts: (prev?.attempts ?? 0) + 1,
    lastPlayedAt: new Date().toISOString(),
  };
  map[deckId] = updated;
  writeJSON(STORAGE_KEY, map);
  bumpStreak();
  return updated;
}

export function getStreak(): number {
  const state = readJSON<StreakState | null>(STREAK_KEY, null);
  if (!state) return 0;
  const today = todayKey();
  const yesterday = (() => {
    const d = new Date();
    d.setDate(d.getDate() - 1);
    return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
  })();
  if (state.lastPlayedDate === today || state.lastPlayedDate === yesterday) {
    return state.currentStreak;
  }
  return 0;
}

function bumpStreak(): void {
  const today = todayKey();
  const state = readJSON<StreakState | null>(STREAK_KEY, null);
  if (!state) {
    writeJSON(STREAK_KEY, { currentStreak: 1, lastPlayedDate: today });
    return;
  }
  if (state.lastPlayedDate === today) return;
  const yesterday = (() => {
    const d = new Date();
    d.setDate(d.getDate() - 1);
    return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
  })();
  const newStreak =
    state.lastPlayedDate === yesterday ? state.currentStreak + 1 : 1;
  writeJSON(STREAK_KEY, {
    currentStreak: newStreak,
    lastPlayedDate: today,
  });
}

function readUnlocked(): UnlockedState {
  return readJSON<UnlockedState>(UNLOCKED_KEY, { deckIds: [], bundle: false });
}

export function getUnlockedDeckIds(): string[] {
  return readUnlocked().deckIds;
}

export function hasBundle(): boolean {
  return readUnlocked().bundle;
}

export function isDeckUnlocked(deckId: string): boolean {
  const state = readUnlocked();
  return state.bundle || state.deckIds.includes(deckId);
}

export function unlockDeck(deckId: string): void {
  const state = readUnlocked();
  if (state.deckIds.includes(deckId)) return;
  writeJSON(UNLOCKED_KEY, {
    ...state,
    deckIds: [...state.deckIds, deckId],
  });
}

export function unlockBundle(): void {
  const state = readUnlocked();
  writeJSON(UNLOCKED_KEY, { ...state, bundle: true });
}

export function resetUnlocks(): void {
  writeJSON(UNLOCKED_KEY, { deckIds: [], bundle: false });
}

export { BUNDLE_FLAG };
