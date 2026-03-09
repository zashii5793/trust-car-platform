# Claude開発セッションメモ

> **最終更新**: 2026-03-09

---

## 現在の状態（SNS機能実装完了 → P2へ）

### 直近の完了作業

| 作業 | 状態 |
|------|------|
| marketplace 4画面 ウィジェットテスト（56ケース） | ✅ |
| ユーザーシナリオ統合テスト（3シナリオ47ケース） | ✅ |
| `docs/ARCHITECTURE.md` 全面改訂 | ✅ |
| `PostProvider` 実装（いいね楽観的更新・ページネーション） | ✅ |
| `SnsFeedScreen` / `PostCreateScreen` 実装 | ✅ |
| HomeScreen に「みんなの投稿」タブ追加（5タブ構成） | ✅ |
| `PostProvider` 単体テスト（30ケース） | ✅ |

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

### SNS設計決定

- SNSは独立した5番目のBottomNavigationBarタブ（index=2、通知=3、プロフィール=4）
- いいねは楽観的更新（即時UI → Firestore同期 → 失敗時ロールバック）
- SNSタブ内のFABは SnsFeedScreen 自身が管理

---

## 次セッションでやること（優先順）

### P1（推奨）
- [ ] `part_detail_screen.dart`（パーツ詳細: pros/cons・互換性詳細・問い合わせボタン）
- [ ] SNSフィード画面 ウィジェットテスト

### P2（余裕があれば）
- [ ] ドライブログ画面 `screens/drive/`
- [ ] Firestoreインデックス定義 `firestore.indexes.json`

---

## ファイル構成（重要ファイル）

```
lib/
  main.dart                           ← PostProvider を MultiProvider に追加済み
  injection.dart                      ← DI登録場所（21サービス）
  providers/
    post_provider.dart                ← 今回追加
    part_recommendation_provider.dart
    shop_provider.dart
  screens/
    home_screen.dart                  ← 5タブ構成（マイカー/マーケット/SNS/通知/プロフィール）
    sns/
      sns_feed_screen.dart            ← 今回追加
      post_create_screen.dart         ← 今回追加
    marketplace/
      shop_list_screen.dart
      shop_detail_screen.dart
      inquiry_screen.dart
      part_list_screen.dart
  models/
    post.dart                         ← PostCategory(9種), PostVisibility, PostMedia
    part_listing.dart
    shop.dart
  services/
    post_service.dart                 ← createPost/getFeed/likePost/unlikePost/deletePost
    follow_service.dart
docs/
  ARCHITECTURE.md                     ← 保守用設計書（10セクション）
  FEATURE_SPEC.md
  REPORT_AI_DEV_STATUS.md
```

---

## テスト状況

- **合計**: 約972件（unit: ~900, widget: ~72）
- 内訳増加: PostProvider 30ケース追加
- 実行コマンド: `flutter test 2>&1 | tail -5`
