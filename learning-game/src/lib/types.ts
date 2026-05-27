export type QuestionFormat = "multiple_choice" | "true_false";

export type Question = {
  id: string;
  format: QuestionFormat;
  prompt: string;
  choices: string[];
  answerIndex: number;
  explanation: string;
};

export type DeckTier = "free" | "paid";

export type DeckCategory =
  | "communication"
  | "thinking"
  | "growth"
  | "strategy";

export type Deck = {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  category: DeckCategory;
  tier: DeckTier;
  emoji: string;
  accentColor: string;
  estimatedMinutes: number;
  questions: Question[];
};

export type QuizAnswer = {
  questionId: string;
  selectedIndex: number;
  isCorrect: boolean;
};

export type DeckProgress = {
  deckId: string;
  bestScore: number;
  attempts: number;
  lastPlayedAt: string;
};
