# Trust Car Platform - AI開発 現状レポート

> **最終更新**: 2026-03-05（Phase 6.1 完了後）

## 1. プロジェクト概要

| 項目 | 内容 |
|------|------|
| プロダクト | 車両管理・メンテナンス記録アプリ |
| 技術スタック | Flutter / Firebase (Auth, Firestore, Storage) |
| AI開発ツール | Claude Code (Claude Sonnet 4.6) |
| 開発期間 | Phase 1〜6.1 完了 |
| コード規模 | Dart 約9,000行（lib/）、テスト約942件 |

---

## 2. フェーズ別進捗

| フェーズ | 状態 | 主な内容 |
|---------|------|---------|
| Phase 1〜3 | ✅ 完了 | 認証・車両管理・整備記録・OCR・アラート・PDF |
| Phase 3.5 | ✅ 完了 | アーキテクチャ統一（domain/data削除、DI統一） |
| Phase 4 | ✅ 完了 | オフライン対応・プッシュ通知・Crashlytics・CI/CD |
| Phase 5 | ✅ 完了 | 書類/請求書管理・SNS/BtoBモデル基盤・AI推薦基盤 |
| **Phase 6** | ✅ **完了** | **車両マスタUI・愛車タイムライン・ホームAI提案・BtoBマーケット画面** |

---

## 3. 実装済み機能（全量）

### コア機能
- 認証（メール/パスワード・Google OAuth）
- 車両管理 CRUD（ナンバー重複チェック・走行距離整合性チェック）
- 整備記録管理（22タイプ・CRUD・タイムライン表示・BottomSheet詳細）
- 車検証 OCR（ML Kit）・請求書 OCR
- アラート（車検/自賠責期限・メンテ推奨）
- PDF出力（整備記録）

### Phase 5〜6 新機能
- **車両マスタ（ドロップダウン選択）**: VehicleMaker/VehicleModel/VehicleGrade、Firestoreフォールバック付き
- **愛車タイムライン**: タイムライン形式（線 + アイコン + カード）、BottomSheet詳細表示
- **ホームAI提案セクション**: NotificationProviderのtopSuggestionsを横スクロールカードで表示
- **BtoBマーケット 工場一覧** (`shop_list_screen.dart`): DropdownChip 3段フィルタ・件数表示・今日の営業時間
- **BtoBマーケット 工場詳細** (`shop_detail_screen.dart`): ページドット画像・ExpansionTile営業時間・星評価
- **問い合わせ画面** (`inquiry_screen.dart`): 工場ミニカード・ChoiceChip種別選択・文字数カウンタ
- **パーツ一覧** (`part_list_screen.dart`): カテゴリフィルタ・検索・互換性バッジ（車両指定時）
- **メンテナンス統計画面**: 年間コスト推移・月別・タイプ別・店舗別

### 品質基盤
- オフラインサポート（Firestore永続化 100MB）
- Firebase Crashlytics / Performance
- LoggingService・MetricsAggregator
- GitHub Actions CI/CD

---

## 4. テストカバレッジ（2026-03-05 時点）

### 4.1 テスト全体

| 項目 | 数値 |
|------|------|
| テストファイル数 | 47ファイル |
| テスト件数（unit）| 約 877件 |
| テスト件数（widget）| 約 65件 |
| **合計** | **約 942件** |

### 4.2 層別カバレッジ

| 層 | 状態 | 備考 |
|----|------|------|
| `core/` (Result, AppError等) | ✅ 充実 | 67件 |
| `models/` | ✅ 充実 | 全主要モデルカバー |
| `services/` | ✅ 充実 | OCR・Auth・Firebase・Notification・Push |
| `providers/` | ✅ 改善済 | 7ファイル（auth/vehicle/maintenance/connectivity/notification/part_recommendation/shop） |
| `screens/` | 🔶 部分的 | 6ファイル（home/login/vehicle/add_maintenance/golden） |
| `marketplace screens/` | ❌ 未追加 | shop_list/shop_detail/inquiry/part_list のテストなし |

### 4.3 未テストの重要箇所

| 対象 | 優先度 | 理由 |
|------|--------|------|
| `part_list_screen.dart` | 高 | 新規実装、フィルタロジックがある |
| `shop_list_screen.dart` | 中 | フィルタDropdownの動作確認 |
| `inquiry_screen.dart` | 中 | フォームバリデーション |
| `PartRecommendationProvider.loadBrowseParts` | 高 | 新規追加メソッド |

---

## 5. アーキテクチャ現状

```
main.dart → Injection.init() → ServiceLocator
                                      ↓
Provider（コンストラクタ注入）← Service（Result<T,AppError>）
      ↓                                ↓
  UI層（screens/）              Firebase SDK
```

### 解決済みの技術的負債

| 項目 | 状態 |
|------|------|
| domain/data層の削除、services/に統一 | ✅ |
| 全ProviderにDI適用（コンストラクタ注入） | ✅ |
| Providerテスト追加（7 Provider） | ✅ |

### 残存する技術的負債

| 項目 | 内容 | 優先度 |
|------|------|--------|
| marketplace screensのテスト | 4画面ぶんのテスト未追加 | 中 |
| Firestoreインデックス定義 | `firestore.indexes.json` 未定義 | 中 |
| Screen層のDI（OCR/PDF） | 一部ServiceをScreen内で直接`new` | 低 |

---

## 6. AI開発の評価

### 6.1 品質スコア: 8.5/10（Phase 6.1 完了後）

| 領域 | スコア | 備考 |
|------|--------|------|
| コア層の品質 | 9.5/10 | Result型・AppError・モデル層は堅実 |
| アーキテクチャ一貫性 | 9/10 | DI統一・services/集約 |
| テストカバレッジ | 7.5/10 | 942件、marketplace UIは未カバー |
| 運用準備度 | 7/10 | CI/CD・Crashlytics 稼働。Firestoreインデックス未定義 |

### 6.2 今回セッションの成果

| 内容 | 説明 |
|------|------|
| BtoBマーケット3画面UI大幅改善 | DropdownChip・星評価・ページドット・ChoiceChip・文字数カウンタ |
| `part_list_screen.dart` 新規実装 | 17カテゴリ・検索・互換性バッジ |
| `PartRecommendationProvider.loadBrowseParts` 追加 | カテゴリ/検索/おすすめのフォールバック付き |
| 設計上の議論点の整理 | BtoBマーケット vs Phase 6優先度・TypeaheadかDropdownか等 |

### 6.3 AI開発の課題（率直に）

| 課題 | 詳細 | 対策 |
|------|------|------|
| **事前調査の省略** | P0機能が「既に実装済み」と気づかず書き直しそうになった | セッション開始時に必ずコード探索を先行する |
| **コンテキスト喪失** | セッション切れで設計方針が断絶 | CLAUDE.mdにアーキテクチャ方針を明記（実施済み） |
| **楽観バイアス** | 「問題なし」と報告しがちで構造的課題の発見が遅れる | 定期的な批判的レビューを組み込む |

---

## 7. 次のフェーズ計画

| 優先度 | 内容 | 説明 |
|--------|------|------|
| P0 | marketplace screensのテスト追加 | TDD補完。4画面 × フォームバリデーション |
| P1 | SNSフィード画面 | `screens/sns/` - 投稿一覧・投稿作成・コメント |
| P1 | Firestoreインデックス定義 | `firestore.indexes.json` で複合クエリを安定化 |
| P2 | パーツ詳細画面 | `part_detail_screen.dart` - pros/cons・互換性詳細 |
| P2 | ドライブログ画面 | `screens/drive/` - 走行ルート・訪問スポット |

---

## 8. 教訓

- **「AIはコンテキストがすべて」**: 設計方針をCLAUDE.mdに明示しないと、セッションごとに異なる判断をする
- **AIの自己評価を鵜呑みにしない**: 定期的な批判的レビューが必要
- **Progressive Disclosure**: CLAUDE.mdは最小限に、詳細は別ドキュメントに分離する運用が有効
- **事前コード調査が必須**: 「新規実装」を始める前に、既存コードを必ず確認する
