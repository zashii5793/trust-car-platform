import Link from "next/link";
import { Brand } from "@/components/Brand";
import { ProDeckPurchaseList } from "@/components/ProDeckPurchaseList";
import { ALL_DECKS } from "@/lib/decks";
import { BUNDLE_PRICE_JPY } from "@/lib/progress";

export default function ProPage() {
  const proDecks = ALL_DECKS.filter((d) => d.tier === "paid");
  const totalIfBought = proDecks.reduce((sum, d) => sum + d.priceJpy, 0);
  const bundleSavings = totalIfBought - BUNDLE_PRICE_JPY;

  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-4xl flex-col gap-10 px-4 pb-20 pt-6 sm:px-6 sm:pt-10">
      <header className="flex items-center justify-between">
        <Brand size="sm" />
        <Link href="/" className="text-sm text-muted hover:text-foreground">
          ← ホーム
        </Link>
      </header>

      <section className="text-center">
        <div className="inline-flex items-center gap-2 rounded-full border border-amber-500/30 bg-amber-500/10 px-3 py-1 text-xs text-amber-200">
          <span aria-hidden>✨</span> ZAXEL-Learning PRO
        </div>
        <h1 className="mt-3 text-3xl font-bold tracking-tight sm:text-4xl">
          欲しいデッキだけ、買い切りで。
        </h1>
        <p className="mx-auto mt-3 max-w-xl text-sm text-muted sm:text-base">
          サブスクではなく、1デッキ単位の永続アンロック。
          解約忘れもなく、必要な学びを必要な分だけ手元に置けます。
        </p>
      </section>

      <ProDeckPurchaseList
        decks={proDecks}
        bundlePriceJpy={BUNDLE_PRICE_JPY}
        bundleSavings={bundleSavings}
      />

      <section className="rounded-2xl border border-border bg-card p-6 text-sm">
        <h2 className="font-semibold">よくある質問</h2>
        <dl className="mt-4 space-y-4 text-foreground/85">
          <div>
            <dt className="font-medium">Q. サブスクは無いの？</dt>
            <dd className="mt-1 text-muted">
              ありません。1デッキ買い切り＝1度払えば永続でアンロック。
              必要なテーマだけを手元に置けるよう、あえて買い切りモデルを採用しています。
            </dd>
          </div>
          <div>
            <dt className="font-medium">Q. FREEデッキは何ができる？</dt>
            <dd className="mt-1 text-muted">
              FREEデッキは全問・無制限プレイ無料です。学習の入口として、まずは試してください。
            </dd>
          </div>
          <div>
            <dt className="font-medium">Q. PROデッキはいきなり購入が必要？</dt>
            <dd className="mt-1 text-muted">
              いいえ。最初の{" "}
              <span className="text-foreground">3問</span>{" "}
              はお試しでプレイできます。雰囲気をつかんでから購入を判断してください。
            </dd>
          </div>
          <div>
            <dt className="font-medium">Q. バンドルを買うと将来のPROデッキも含まれる？</dt>
            <dd className="mt-1 text-muted">
              現バージョンでは「現在公開中のPROデッキ全部」が対象です。
              将来追加されるデッキの扱いはローンチ前に確定します。
            </dd>
          </div>
          <div>
            <dt className="font-medium">Q. 法人での導入は可能？</dt>
            <dd className="mt-1 text-muted">
              チーム / 法人向けの一括ライセンスは別途ご相談ください（10名以上想定）。
            </dd>
          </div>
        </dl>
      </section>
    </div>
  );
}
