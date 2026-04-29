# Claude開発セッションメモ

> **最終更新**: 2026-04-29

---

## 現在の状態（Phase 7 BtoB課金基盤 + 品質修正完了）

### 直近の完了作業（2026-04-29）

| 作業 | 状態 |
|------|------|
| TODO 3件 解消（プロフィール編集ボトムシート・PDFエクスポート・カメラフラッシュ） | ✅ |
| Phase 7 BtoB課金基盤実装（ShopSubscriptionService・SubscriptionProvider・ShopPlanScreen） | ✅ |
| AppError に PlanLimitError 追加 | ✅ |
| ShopPlanType に enterprise tier 追加 + ShopSubscriptionStatus enum | ✅ |
| Shop モデルに subscriptionStatus / revenueCatUserId / trialStartedAt フィールド追加 | ✅ |
| ShopSubscriptionService テスト 32件（TDD） | ✅ |
| SubscriptionProvider テスト追加 | ✅ |
| shop_test.dart に enterprise / subscriptionStatus テスト追加 | ✅ |
| firestore.rules: subscriptionStatus を Cloud Functions のみ書き込み可に制限 | ✅ |
| auth_provider / auth_service の debugPrint を assert ブロック内に移動 | ✅ |
| PM評価レポート作成 → `docs/PM_EVALUATION_REPORT_2026-04-29.md` | ✅ |
| docs/web/（privacy.html / terms.html / index.html）GitHub Pages 用 HTML | ✅ |
| docs/STORE_METADATA.md（App Store / Google Play メタデータ） | ✅ |
| google-services.json / GoogleService-Info.plist 生成済み（gitignore対象） | ✅ |

### 総合評価: **8.6 / 10** （2026-04-29 PM評価より）

---

## ブランチ情報

- **開発ブランチ**: `claude/continue-development-WYZZp`
- **ベースブランチ**: `main`

---

## テスト状況（2026-04-29時点）

- **合計**: 約 1,900+ 件（unit/widget）
- **テストファイル数**: 82 ファイル
- **カテゴリ別**:
  - models: 386件（全19モデル + 新フィールドカバー）
  - services: 799件（全21サービス）
  - providers: 337+件（15中14 — subscription_provider 追加）
  - screens: 20件（35画面中12 — 薄い）
  - core: 146件
- **統合テスト**: Firebase Emulator依存（`@Tags(['emulator'])`）
- 実行コマンド: `flutter test --exclude-tags emulator 2>&1 | tail -5`

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

### Phase 7 BtoB課金設計

```
プランtier（価格/月）:
  free:        ¥0     — 問い合わせ5件/月, 写真3枚
  standard:    ¥3,980 — 問い合わせ無制限, 写真20枚
  premium:     ¥9,800 — 優先表示, 月次レポート
  enterprise:  ¥14,800 — 5店舗管理, 専任サポート

RevenueCat Webhook → Cloud Functions → Firestore
  shops/{shopId}.subscriptionStatus ← Cloud Functionsのみ書き込み可
  shops/{shopId}.planType
```

### モデルの注意点（ハマりやすい）

| モデル | 正しいフィールド名 | 間違えやすい例 |
|--------|-----------------|--------------|
| `VehicleSpec` | `makerId`, `modelId`, `yearFrom`, `yearTo` | `makerName`, `modelName` ❌ |
| `DriveLog` | `startTime` | `startedAt` ❌ |
| `PostService.createPost` | `media: List<PostMedia>` | `imageUrls`, `hashtags` ❌ |
| `Shop` | `subscriptionStatus` (ShopSubscriptionStatus enum) | `status` ❌ |

---

## フェーズ完了状況

| フェーズ | 内容 | 状態 |
|---------|------|------|
| Phase 1 | 認証（メール/パスワード） | ✅ |
| Phase 2 | 車両管理・OCR（車検証） | ✅ |
| Phase 3 | 整備記録・PDF・請求書OCR | ✅ |
| Phase 4 | GPSドライブログ | ✅ |
| Phase 5 | カーライフSNS（投稿・いいね・フォロー） | ✅ |
| Phase 6 | BtoBマーケット（店舗・問い合わせ・出品） | ✅ |
| Phase 7 | BtoB課金基盤 | 🟡 基盤実装済み・RevenueCat連携待ち |
| Phase 8 | 予約カレンダー・高精度AIパーツ推薦 | ⬜ ローンチ後 |

---

## 次にやること（AI対応）

### P1（今週中）
- [ ] **RevenueCat SDK 統合（Phase 7 Week 2）**: `purchases_flutter` を pubspec.yaml に追加
- [ ] **Cloud Functions: Webhook実装**: RevenueCat → Firestore 自動同期
- [ ] **inquiry_service に問い合わせ上限チェック組み込み**

### P2（来週以降）
- [ ] screens/ ウィジェットテストを強化（ShopPlanScreen・ProfileEditSheet 等）

---

## 人間タスク残件（HUMAN_TASKS.md より）

### P0（ブロッカー）
- [ ] **GitHub Secrets `GOOGLE_SERVICES_JSON` 登録**

### P1（ローンチ前必須）
- [ ] Firebase Authentication 有効確認
- [ ] Firebase Crashlytics 有効化
- [ ] GitHub Pages 有効化（Privacy/Terms URL公開）
- [ ] Apple Developer Program 登録（$99/年）
- [ ] Google Play Developer 登録（$25）
- [ ] App Store Connect / Google Play Console アプリ登録
- [ ] Android keystore 作成
- [ ] iOS 証明書・プロビジョニングプロファイル作成

---

## ファイル構成（重要ファイル）

```
lib/
  main.dart                              ← MultiProvider に SubscriptionProvider 追加済み
  core/
    di/injection.dart                    ← DI登録（22サービス）
    error/app_error.dart                 ← PlanLimitError 追加済み
    constants/firestore_collections.dart ← shops 定数追加済み
  providers/
    subscription_provider.dart           ← Phase 7 新規追加
    auth_provider.dart                   ← debugPrint を assert 内に移動済み
  services/
    shop_subscription_service.dart       ← Phase 7 新規追加
    auth_service.dart                    ← debugPrint を assert 内に移動済み
  screens/
    marketplace/
      shop_plan_screen.dart              ← Phase 7 プランUI新規追加
      shop_owner_screen.dart             ← プラン変更 → ShopPlanScreen に接続済み
    profile/
      profile_screen.dart                ← プロフィール編集・PDFエクスポート実装済み
    document_scanner_screen.dart         ← フラッシュ切り替え実装済み
  models/
    shop.dart                            ← enterprise tier / ShopSubscriptionStatus 追加済み
firestore.rules                          ← subscriptionStatus Cloud Functions のみ書き込み可
docs/
  PM_EVALUATION_REPORT_2026-04-29.md    ← 本日の評価レポート
  PHASE7_MONETIZATION_PLAN.md           ← Phase 7 設計書
  STORE_METADATA.md                     ← App Store/Google Play メタデータ
  MAINTENANCE_RUNBOOK.md                ← 保守・運用ランブック
  web/
    privacy.html / terms.html / index.html ← GitHub Pages 公開待ち
```
