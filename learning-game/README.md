# ZAXEL Learning

**現場で鍛えたビジネススキルを、スマホで遊べる一問一答クイズに。**

セミナー・研修コンテンツを学習ゲーム化する Web アプリ（PWA）です。Next.js + TypeScript + Tailwind v4 で構築されています。

## 特徴

- 4つの初期デッキ（コミュニケーション・思考法・読書・組織戦略）計 40 問
- Duolingo 風の一問一答 / 即時フィードバック / 解説つき
- 連続日数（ストリーク）とベストスコアを localStorage に記録
- フリーミアム: 1日3問まで無料 + PRO デッキ
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
│   └── pro/page.tsx             # 料金プラン
├── components/
│   ├── QuizPlayer.tsx           # クイズの本体
│   ├── DeckCard.tsx
│   ├── Brand.tsx
│   └── StreakBadge.tsx
└── lib/
    ├── types.ts                 # Deck / Question / Progress
    ├── decks/                   # 各デッキ TS データ
    └── progress.ts              # localStorage ユーティリティ
```

## デッキを追加する

`src/lib/decks/<your-deck>.ts` に新しいファイルを作り、`src/lib/decks/index.ts` の `ALL_DECKS` に追加します。

## ビジネスモデル

`docs/BUSINESS_MODEL.md` を参照。
