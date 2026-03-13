# Claude開発セッションメモ

> **最終更新**: 2026-03-13

---

## 現在の状態（SNS/ドライブ/マーケット完了 → ローンチ準備フェーズ）

### 直近の完了作業（2026-03-13）

| 作業 | 状態 |
|------|------|
| `firestore.indexes.json` 約30件を完成（drive_logs startTime修正含む） | ✅ |
| Bundle ID を `com.example.*` → `jp.trustcar.app` へ全プラットフォーム変更 | ✅ |
| `SnsFeedScreen` / `PostCreateScreen` 実装 + テスト（40件） | ✅ |
| `DriveLogScreen` 実装 + `DriveLogProvider` | ✅ |
| `PartDetailScreen` 実装 + `PartRecommendationProvider.loadPartDetail` | ✅ |
| SNS / PostCreate / PartDetail ウィジェットテスト（63件）| ✅ |
| `PostProvider` 単体テスト（30件） | ✅ |
| HomeScreen 5タブ構成（マイカー/マーケット/SNS/通知/プロフィール） | ✅ |

### ブランチ情報

- **開発ブランチ**: `claude/continue-development-WYZZp`
- **ベースブランチ**: `main`

---

## 重要な設計決定（変更禁止）

### アーキテクチャ

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

### モデルの注意点（ハマりやすい）

| モデル | 正しいフィールド名 | 間違えやすい例 |
|--------|-----------------|--------------|
| `VehicleSpec` | `makerId`, `modelId`, `yearFrom`, `yearTo` | `makerName`, `modelName` ❌ |
| `DriveLog` | `startTime` | `startedAt` ❌ |
| `PostService.createPost` | `media: List<PostMedia>` | `imageUrls`, `hashtags` ❌ |
| `DriveLogProvider.loadMore` | re-fetchでlimit増加方式 | cursor(DocumentSnapshot)方式 ❌ |

### SNS設計決定

- SNSは独立した5番目のBottomNavigationBarタブ（index=2、通知=3、プロフィール=4）
- いいねは楽観的更新（即時UI → Firestore同期 → 失敗時ロールバック）
- SNSタブ内のFABは `SnsFeedScreen` 自身が管理

### UIの設計原則

- **売り込まない**: BtoBは業者からのプッシュ型アクション禁止
- **AIは提案する、決めない**: 「ベスト1」「最適」ラベルを付けない
- **広告は「広告」と明示**: `isFeatured` は「広告」ラベルで表示

---

## P0バグ（修正優先）

### BUG-1: `part_detail_screen.dart` 状態二重管理

**場所**: `lib/screens/marketplace/part_detail_screen.dart`

**問題**:
```dart
// Screen内のローカル状態
bool _isLoading = false;
String? _errorMessage;
PartListing? _detail;

// Provider側にも同じ状態がある
provider.currentPartDetail
provider.isLoading
```

**修正方針**: ローカル状態を削除して `Consumer<PartRecommendationProvider>` に一本化。

---

### BUG-2: `toggleLike` レースコンディション

**場所**: `lib/providers/post_provider.dart` → `toggleLike()`

**問題**: 高速連続タップ時、楽観的更新のロールバックが競合してカウントがずれる。

**修正方針**: `_pendingLikes = Set<String>()` でdebounce管理。タップ中は追加タップを無視。

---

## 次セッションでやること（優先順）

### P0（バグ修正 - リリース前必須）
- [ ] BUG-1: `part_detail_screen.dart` 状態二重管理を修正
- [ ] BUG-2: `toggleLike` レースコンディションを修正

### P1（ローンチ必須 - 人間対応）
- [ ] **Firebase Console**: iOSアプリのBundle IDを `jp.trustcar.app` に更新
- [ ] **Firebase Console**: AndroidアプリのapplicationIdを `jp.trustcar.app` に更新
- [ ] `google-services.json` 再ダウンロード → `android/app/` に配置
- [ ] `GoogleService-Info.plist` 再ダウンロード → `ios/Runner/` に配置
- [ ] Firestore security rules 修正（drive_waypoints / shops / inquiries/messages）
- [ ] プライバシーポリシー画面追加（App Store必須）

### P2（ストア申請前）
- [ ] App Store Connect / Google Play Console アカウント開設
- [ ] スクリーンショット準備（iPhone 6.7", iPad、Android）
- [ ] iOS コード署名 / TestFlight 設定（Mac必要）
- [ ] リリースビルド動作確認

### P3（β公開後）
- [ ] ドライブログ GPS記録機能実装
- [ ] コメント機能（SNS）実装
- [ ] プッシュ通知のいいね・コメント通知連携
- [ ] アナリティクスダッシュボード

---

## ファイル構成（重要ファイル）

```
lib/
  main.dart                           ← PostProvider / DriveLogProvider を MultiProvider に追加済み
  injection.dart                      ← DI登録場所（21サービス）
  providers/
    post_provider.dart                ← いいね楽観的更新・ページネーション
    drive_log_provider.dart           ← ドライブログ一覧・削除
    part_recommendation_provider.dart ← loadPartDetail / currentPartDetail 追加済み
    shop_provider.dart
  screens/
    home_screen.dart                  ← 5タブ構成
    sns/
      sns_feed_screen.dart
      post_create_screen.dart
    marketplace/
      part_detail_screen.dart         ← ⚠️ BUG-1: 状態二重管理あり
      part_list_screen.dart
      shop_list_screen.dart
      shop_detail_screen.dart
      inquiry_screen.dart
    drive/
      drive_log_screen.dart
  models/
    post.dart                         ← PostCategory(9種), PostVisibility, PostMedia
    drive_log.dart                    ← startTime（startedAtではない）
    part_listing.dart
    vehicle_spec.dart                 ← makerId/modelId（makerName/modelNameではない）
  services/
    post_service.dart
    drive_log_service.dart
firestore.indexes.json                ← 約30件定義済み（2026-03-13更新）
firestore.rules                       ← ⚠️ セキュリティ修正未適用
docs/
  ARCHITECTURE.md                     ← 保守用設計書
  LAUNCH_CHECKLIST.md                 ← ローンチ前チェックリスト（2026-03-13作成）
  DEPLOY_READINESS_REPORT.md          ← デプロイ準備評価レポート
  FEATURE_SPEC.md
```

---

## テスト状況

- **合計**: 約1,073件（unit: ~940, widget: ~133）
- 実行コマンド: `flutter test 2>&1 | tail -5`
- 統合テスト: Firebase Emulator依存（CI未実行）

---

## 4月ローンチ計画（週次）

| 週 | 目標 |
|----|------|
| Week 1（3/13〜）| Firebase設定・Bundle ID完了・セキュリティ修正 |
| Week 2（3/20〜）| ビルド検証・TestFlight β配布 |
| Week 3（3/27〜）| β期間・フィードバック反映 |
| Week 4（4/3〜）| ストア審査申請 |
| **4/中旬** | **公開** |
