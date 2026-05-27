# ZAXEL-Learning

**現場で鍛えたビジネススキルを、スマホで遊べる一問一答クイズに。**

セミナー・研修コンテンツを学習ゲーム化する Web アプリ（PWA）です。Next.js + TypeScript + Tailwind v4 で構築されています。

## 特徴

- 4つの初期デッキ（コミュニケーション・思考法・読書・組織戦略）計 40 問
- Duolingo 風の一問一答 / 即時フィードバック / 解説つき
- 連続日数（ストリーク）とベストスコアを localStorage に記録
- 買い切りモデル: FREEデッキは全問無料 / PROデッキは ¥240 から永続アンロック
- PWA 対応（スマホで「ホーム画面に追加」可）

## ローカル起動

```bash
cd learning-game
npm install
npm run dev
```

→ http://localhost:3000

## ディレクトリ

```
src/
├── app/
│   ├── page.tsx                 # ホーム（デッキ一覧）
│   ├── decks/[id]/page.tsx      # デッキ詳細
│   ├── decks/[id]/play/page.tsx # クイズプレイ
│   └── pro/page.tsx             # PROデッキ購入一覧
├── components/
│   ├── QuizPlayer.tsx           # クイズ本体（試遊→Paywall→結果）
│   ├── DeckPurchaseCTA.tsx      # デッキ詳細の購入CTA
│   ├── ProDeckPurchaseList.tsx  # 購入カード一覧（モック決済）
│   ├── DeckCard.tsx
│   ├── Brand.tsx
│   └── StreakBadge.tsx
└── lib/
    ├── types.ts                 # Deck / Question / Progress
    ├── decks/                   # 各デッキ TS データ（priceJpy 含む）
    └── progress.ts              # localStorage: 進捗 / 購入アンロック
```

## デッキを追加する

`src/lib/decks/<your-deck>.ts` に新しいファイルを作り、`src/lib/decks/index.ts` の `ALL_DECKS` に追加します。`priceJpy` を必ず設定してください（FREEなら `0`、PROなら `240` を標準とする）。

## 課金モデル（買い切り）

- **FREEデッキ** (`priceJpy: 0`): 全問・無制限プレイ無料
- **PROデッキ** (`priceJpy: 240` 等): 最初の 3 問は試遊可、4 問目以降は購入が必要
- **PROバンドル** (`¥600`): 公開中の全 PROデッキを一括アンロック
- 購入は現状 localStorage モック (`unlockDeck` / `unlockBundle`)。本番は Stripe Checkout 予定。

## ビジネスモデル

`docs/BUSINESS_MODEL.md` を参照。
