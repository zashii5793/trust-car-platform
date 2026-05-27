import type { Deck, DeckCategory } from "../types";
import { communicationTheory } from "./communication-theory";
import { abstractionPower } from "./abstraction-power";
import { readingHabit } from "./reading-habit";
import { engagementReview } from "./engagement-review";

export const ALL_DECKS: Deck[] = [
  communicationTheory,
  readingHabit,
  abstractionPower,
  engagementReview,
];

export const CATEGORIES: { id: DeckCategory; label: string }[] = [
  { id: "communication", label: "コミュニケーション" },
  { id: "thinking", label: "思考法" },
  { id: "growth", label: "学習・成長" },
  { id: "strategy", label: "戦略・組織" },
];

export function getDeckById(id: string): Deck | undefined {
  return ALL_DECKS.find((d) => d.id === id);
}

export function getDecksByCategory(category: DeckCategory): Deck[] {
  return ALL_DECKS.filter((d) => d.category === category);
}
