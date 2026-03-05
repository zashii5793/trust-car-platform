# Claude開発セッションメモ

> **最終更新**: 2026-03-05

---

## 現在の状態（Phase 6.1 完了 → Phase 7 へ）

### 直近の完了作業

| 作業 | 状態 |
|------|------|
| BtoBマーケット 3画面UI大幅改善 | ✅ |
| `part_list_screen.dart` 新規実装 | ✅ |
| `PartRecommendationProvider.loadBrowseParts` 追加 | ✅ |
| `REPORT_AI_DEV_STATUS.md` 更新 | ✅ |
| `CLAUDE_SESSION_NOTES.md` 更新 | ✅ |

### ブランチ情報

- **開発ブランチ**: `claude/continue-development-WYZZp`
- **ベースブランチ**: `main`

---

## 重要な設計決定

### アーキテクチャ（変更禁止）

```
main.dart → Injection.init() → ServiceLocator
                                      ↓
Provider（コンストラクタ注入）← Service（Result<T,AppError>）
      ↓                                ↓
  UI層（screens/）              Firebase SDK
```

- **DI必須**: Providerはコンストラクタ注入（`new`禁止）
- **domain/data層は存在しない**: 再作成禁止
- **新Serviceは必ず `injection.dart` に登録**

### UIの設計原則

- **売り込まない**: BtoBは業者からのプッシュ型アクション禁止
- **AIは提案する、決めない**: 「ベスト1」「最適」ラベルを付けない
- **広告は「広告」と明示**: `isFeatured` は「広告」ラベルで表示

---

## 未解決の設計議論

| 議論 | 選択肢 | 現状の方針 |
|------|--------|-----------|
| SNSフィードを優先するか、パーツ詳細を先にするか | 未決定 | 次セッションで判断 |
| Firestoreインデックス定義タイミング | 開発中 / デプロイ前 | 未着手 |

---

## 次セッションでやること（優先順）

### P0（必須）
- [ ] `marketplace screens` のテスト追加（4画面: shop_list/shop_detail/inquiry/part_list）
- [ ] `PartRecommendationProvider.loadBrowseParts` のテスト追加

### P1（推奨）
- [ ] SNSフィード画面 `screens/sns/` 実装（Post一覧・投稿作成）
- [ ] Firestoreインデックス定義 `firestore.indexes.json`

### P2（余裕があれば）
- [ ] `part_detail_screen.dart`（パーツ詳細: pros/cons・互換性詳細・問い合わせボタン）
- [ ] ドライブログ画面 `screens/drive/`

---

## ファイル構成（重要ファイル）

```
lib/
  injection.dart                       ← DI登録場所
  providers/
    part_recommendation_provider.dart  ← loadBrowseParts を今回追加
    shop_provider.dart
  screens/marketplace/
    shop_list_screen.dart              ← DropdownChip 3段フィルタ
    shop_detail_screen.dart            ← ページドット・ExpansionTile・星評価
    inquiry_screen.dart                ← ミニカード・ChoiceChip・文字数カウンタ
    part_list_screen.dart              ← 今回新規実装
  models/
    part_listing.dart                  ← PartCategory(17種), CompatibilityLevel
    shop.dart                          ← Shop, BusinessHours, ShopType, ServiceCategory
  services/
    part_recommendation_service.dart   ← getPartsByCategory, searchParts, getFeaturedParts
    vehicle_master_service.dart        ← getMakers / getModelsForMaker / getGradesForModel
  data/
    vehicle_master_data.dart           ← 静的メーカーデータ（Firestoreフォールバック）
docs/
  FEATURE_SPEC.md                      ← 機能仕様（優先度付き）
  REPORT_AI_DEV_STATUS.md              ← 今回更新済み。942テスト
```

---

## テスト状況

- **合計**: 約942件（unit: 877, widget: 65）、47ファイル
- **未テスト**: marketplace 4画面 + `loadBrowseParts`
- 実行コマンド: `flutter test 2>&1 | tail -5`
