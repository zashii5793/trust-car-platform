import { notFound } from "next/navigation";
import { Brand } from "@/components/Brand";
import { QuizPlayer } from "@/components/QuizPlayer";
import { ALL_DECKS, getDeckById } from "@/lib/decks";

export function generateStaticParams() {
  return ALL_DECKS.map((d) => ({ id: d.id }));
}

export default async function PlayPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const deck = getDeckById(id);
  if (!deck) notFound();

  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-3xl flex-col gap-6 px-4 pb-20 pt-6 sm:px-6 sm:pt-10">
      <header className="flex items-center justify-between">
        <Brand size="sm" />
        <div className="text-right">
          <div className="text-xs text-muted">{deck.title}</div>
        </div>
      </header>
      <QuizPlayer deck={deck} />
    </div>
  );
}
