"use client";

import type { DeckProgress } from "./types";

const STORAGE_KEY = "zaxel-learning:progress:v1";
const STREAK_KEY = "zaxel-learning:streak:v1";
const FREE_PLAYS_KEY = "zaxel-learning:free-plays:v1";

type ProgressMap = Record<string, DeckProgress>;

type StreakState = {
  currentStreak: number;
  lastPlayedDate: string;
};

type FreePlaysState = {
  date: string;
  count: number;
};

const FREE_PLAYS_PER_DAY = 3;

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

export function getFreePlaysRemaining(): number {
  const state = readJSON<FreePlaysState | null>(FREE_PLAYS_KEY, null);
  const today = todayKey();
  if (!state || state.date !== today) {
    return FREE_PLAYS_PER_DAY;
  }
  return Math.max(0, FREE_PLAYS_PER_DAY - state.count);
}

export function consumeFreePlay(): void {
  const today = todayKey();
  const state = readJSON<FreePlaysState | null>(FREE_PLAYS_KEY, null);
  if (!state || state.date !== today) {
    writeJSON(FREE_PLAYS_KEY, { date: today, count: 1 });
    return;
  }
  writeJSON(FREE_PLAYS_KEY, { date: today, count: state.count + 1 });
}

export const FREE_PLAY_LIMIT = FREE_PLAYS_PER_DAY;
