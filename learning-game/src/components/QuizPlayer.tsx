"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import type { Deck, QuizAnswer } from "@/lib/types";
import {
  consumeFreePlay,
  getFreePlaysRemaining,
  recordResult,
} from "@/lib/progress";

type Phase = "playing" | "reveal" | "finished";

export function QuizPlayer({ deck }: { deck: Deck }) {
  const total = deck.questions.length;
  const [index, setIndex] = useState(0);
  const [phase, setPhase] = useState<Phase>("playing");
  const [selected, setSelected] = useState<number | null>(null);
  const [answers, setAnswers] = useState<QuizAnswer[]>([]);
  const [savedScore, setSavedScore] = useState<number | null>(null);

  useEffect(() => {
    consumeFreePlay();
    // we intentionally consume one play on mount
  }, []);

  const current = deck.questions[index];
  const progressPct = Math.round(((index + (phase !== "playing" ? 1 : 0)) / total) * 100);
  const correctCount = useMemo(
    () => answers.filter((a) => a.isCorrect).length,
    [answers],
  );

  if (phase === "finished") {
    const scorePct = Math.round((correctCount / total) * 100);
    return (
      <ResultScreen
        deck={deck}
        correct={correctCount}
        total={total}
        scorePercent={scorePct}
        answers={answers}
        savedScore={savedScore}
        onSave={() => {
          const result = recordResult(deck.id, scorePct);
          setSavedScore(result.bestScore);
        }}
      />
    );
  }

  function selectChoice(i: number) {
    if (phase !== "playing") return;
    const isCorrect = i === current.answerIndex;
    setSelected(i);
    setPhase("reveal");
    setAnswers((prev) => [
      ...prev,
      { questionId: current.id, selectedIndex: i, isCorrect },
    ]);
  }

  function next() {
    if (index + 1 < total) {
      setIndex(index + 1);
      setSelected(null);
      setPhase("playing");
    } else {
      setPhase("finished");
    }
  }

  return (
    <div className="mx-auto flex w-full max-w-2xl flex-col gap-6">
      <header className="flex items-center justify-between text-sm text-muted">
        <Link
          href={`/decks/${deck.id}`}
          className="rounded-full px-3 py-1.5 hover:bg-card"
        >
          ← 中断
        </Link>
        <span>
          {index + 1} / {total}
        </span>
      </header>

      <div className="h-1.5 w-full overflow-hidden rounded-full bg-card">
        <div
          className={`h-full bg-gradient-to-r ${deck.accentColor} transition-all duration-300`}
          style={{ width: `${progressPct}%` }}
        />
      </div>

      <div key={current.id} className="pop-in rounded-2xl border border-border bg-card p-6 sm:p-8">
        <div className="mb-3 text-xs font-medium uppercase tracking-wider text-muted">
          {current.format === "multiple_choice" ? "4択問題" : "○× 問題"}
        </div>
        <h2 className="text-lg font-semibold leading-relaxed sm:text-xl">
          {current.prompt}
        </h2>

        <div className={`mt-6 grid gap-3 ${current.format === "true_false" ? "grid-cols-2" : "grid-cols-1"}`}>
          {current.choices.map((choice, i) => {
            const isAnswer = i === current.answerIndex;
            const isSelected = selected === i;
            const reveal = phase !== "playing";

            let cls =
              "rounded-xl border px-4 py-3 text-left text-sm font-medium transition active:scale-[0.99] sm:text-base ";
            if (!reveal) {
              cls += "border-border bg-card-elevated hover:border-indigo-400/50 hover:bg-card-elevated/80";
            } else if (isAnswer) {
              cls +=
                "border-emerald-500/60 bg-emerald-500/15 text-emerald-100";
            } else if (isSelected) {
              cls += "border-rose-500/60 bg-rose-500/15 text-rose-100 shake";
            } else {
              cls += "border-border bg-card-elevated opacity-50";
            }
            if (current.format === "true_false") {
              cls += " text-center text-2xl py-6";
            }

            return (
              <button
                type="button"
                key={i}
                disabled={reveal}
                onClick={() => selectChoice(i)}
                className={cls}
              >
                <span className="flex items-center justify-between gap-3">
                  <span>{choice}</span>
                  {reveal && isAnswer && (
                    <span aria-hidden className="text-emerald-400">
                      ✓
                    </span>
                  )}
                  {reveal && !isAnswer && isSelected && (
                    <span aria-hidden className="text-rose-400">
                      ✗
                    </span>
                  )}
                </span>
              </button>
            );
          })}
        </div>

        {phase !== "playing" && (
          <div className="pop-in mt-6 rounded-xl border border-border bg-card-elevated p-4 text-sm leading-relaxed">
            <div className="mb-1 text-xs font-semibold uppercase tracking-wider text-indigo-300">
              解説
            </div>
            <p>{current.explanation}</p>
          </div>
        )}
      </div>

      <div className="flex items-center justify-between">
        <div className="text-sm text-muted">
          正解 {correctCount} / 回答 {answers.length}
        </div>
        {phase === "reveal" && (
          <button
            type="button"
            onClick={next}
            className="rounded-full bg-gradient-to-r from-indigo-500 to-fuchsia-500 px-6 py-2.5 text-sm font-semibold text-white shadow-lg shadow-indigo-500/25 transition hover:opacity-95"
          >
            {index + 1 < total ? "次の問題 →" : "結果を見る"}
          </button>
        )}
      </div>
    </div>
  );
}

function ResultScreen({
  deck,
  correct,
  total,
  scorePercent,
  answers,
  savedScore,
  onSave,
}: {
  deck: Deck;
  correct: number;
  total: number;
  scorePercent: number;
  answers: QuizAnswer[];
  savedScore: number | null;
  onSave: () => void;
}) {
  const [freePlays, setFreePlays] = useState<number | null>(null);
  useEffect(() => {
    onSave();
    setFreePlays(getFreePlaysRemaining());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const grade =
    scorePercent >= 90
      ? { label: "Excellent", emoji: "🏆", color: "from-amber-400 to-orange-500" }
      : scorePercent >= 70
        ? { label: "Great", emoji: "🎉", color: "from-emerald-400 to-teal-500" }
        : scorePercent >= 40
          ? { label: "Good Try", emoji: "💪", color: "from-sky-400 to-indigo-500" }
          : { label: "Keep Going", emoji: "📘", color: "from-rose-400 to-fuchsia-500" };

  return (
    <div className="pop-in mx-auto flex w-full max-w-2xl flex-col gap-6">
      <div className="overflow-hidden rounded-2xl border border-border bg-card p-8 text-center">
        <div className={`mx-auto grid h-24 w-24 place-items-center rounded-full bg-gradient-to-br ${grade.color}`}>
          <span className="text-5xl" aria-hidden>
            {grade.emoji}
          </span>
        </div>
        <div className="mt-4 text-sm uppercase tracking-widest text-muted">
          {grade.label}
        </div>
        <div className="mt-1 text-5xl font-bold tabular-nums">
          {scorePercent}
          <span className="text-2xl text-muted">%</span>
        </div>
        <div className="mt-2 text-sm text-muted">
          {correct} / {total} 問正解
        </div>
        {savedScore !== null && savedScore > 0 && (
          <div className="mt-3 text-xs text-muted">
            ベストスコア: <span className="text-foreground">{savedScore}%</span>
          </div>
        )}
      </div>

      <div className="rounded-2xl border border-border bg-card p-5">
        <div className="mb-3 text-sm font-semibold">問題ごとの結果</div>
        <ul className="grid grid-cols-5 gap-2 sm:grid-cols-10">
          {answers.map((a, i) => (
            <li
              key={a.questionId}
              className={`grid aspect-square place-items-center rounded-md text-xs font-bold ${
                a.isCorrect
                  ? "bg-emerald-500/20 text-emerald-300"
                  : "bg-rose-500/20 text-rose-300"
              }`}
              title={deck.questions[i].prompt}
            >
              {i + 1}
            </li>
          ))}
        </ul>
      </div>

      <div className="flex flex-col gap-3 sm:flex-row">
        <Link
          href={`/decks/${deck.id}/play`}
          className="flex-1 rounded-full border border-border bg-card px-5 py-3 text-center text-sm font-semibold transition hover:border-indigo-400/50"
        >
          もう一度
        </Link>
        <Link
          href="/"
          className="flex-1 rounded-full bg-gradient-to-r from-indigo-500 to-fuchsia-500 px-5 py-3 text-center text-sm font-semibold text-white shadow-lg shadow-indigo-500/25"
        >
          ホームに戻る
        </Link>
      </div>

      {freePlays !== null && freePlays === 0 && (
        <div className="rounded-2xl border border-amber-500/30 bg-amber-500/10 p-4 text-sm text-amber-200">
          <strong className="font-semibold">本日の無料プレイを使い切りました。</strong>
          <p className="mt-1 text-xs">
            ZAXEL Pro に登録すると、すべてのデッキを無制限にプレイできます。
          </p>
          <Link
            href="/pro"
            className="mt-3 inline-block rounded-full bg-amber-400 px-4 py-1.5 text-xs font-semibold text-amber-950"
          >
            Pro を見る →
          </Link>
        </div>
      )}
    </div>
  );
}
