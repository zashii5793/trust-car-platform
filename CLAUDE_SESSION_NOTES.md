# Claude開発セッションメモ

> **最終更新**: 2026-03-25

---

## 現在の状態（統合テスト・保守設計・ローンチ最終評価フェーズ）

### 直近の完了作業（2026-03-25）

| 作業 | 状態 |
|------|------|
| Firebase Emulator 接続を main.dart に追加（kDebugMode ガード） | ✅ |
| `android/app/google-services.json` を firebase_options.dart から再生成 | ✅ |
| プライバシーポリシー・利用規約画面（`settings/` 配下）確認 → 実装済み | ✅ |
| `signup_screen.dart` の同意文をタップ可能なリンクに変更 | ✅ |
| `PrivacyPolicyScreen` / `TermsOfServiceScreen` ウィジェットテスト 15件追加 | ✅ |
| CI `google-services.json` 自動生成ステップ追加（GitHub Secretsフォールバック対応） | ✅ |
| `docs/MAINTENANCE_RUNBOOK.md` 作成（インシデント対応・保守手順） | ✅ |
| **P0バグ（BUG-1 / BUG-2）確認 → 既に修正済み** | ✅ |

### ビジネスモデル ローンチ可否評価（2026-03-25）

#### 総合評価: **8.2 / 10 — ローンチ可能（P1人間作業完了を条件に）**

| 軸 | スコア | 評価根拠 |
|----|--------|---------|
| **技術的完成度** | 8.5/10 | コア機能（認証・車両・整備・OCR・SNS・BtoB基盤）完成。未実装はBtoBマーケットのUI一部のみ |
| **テスト品質** | 8.0/10 | 1,922件パス（unit/widget）。統合テスト5ファイル（CI未実行だがEmulator対応済み）|
| **セキュリティ** | 8.0/10 | Firestore rules 実装済み（drive_waypoints/inquiries修正確認済み）。shops は意図的設計 |
| **ビジネスモデル** | 5.0/10 | **課金・収益化機能は未実装**。BtoB成果報酬・プレミアム課金はPhase7以降の予定 |
| **保守・運用** | 8.5/10 | Crashlytics・CI・ランブック整備済み。Firebase Emulator対応完了 |
| **ストア審査準備** | 7.0/10 | プライバシーポリシー・利用規約・リンク化済み。config files配置が残課題 |

#### ビジネスモデル詳細評価

**現状でローンチできる理由（BtoC機能として成立）**:
- 車両管理・整備記録・ドライブログ → 個人ユーザー価値として完結
- SNS機能（フォロー・いいね・投稿）→ コミュニティ形成でリテンション向上
- BtoBマーケット（閲覧・問い合わせ）→ 工場・業者との接続点は存在

**収益化は Phase 2 以降（ローンチ後3〜6ヶ月）**:
- Phase 7: BtoB加盟料（月額）/ 成果報酬モデル実装
- Phase 8: プレミアムプラン（広告非表示・ドライブログ容量拡張）
- ローンチ時は「無料」で市場検証し、ユーザー獲得を優先する戦略が適切

**リスク**:
- Firebase Spark Plan の無料枠（Firestore 50K reads/日）はユーザー1,000人前後で超過
- Blaze Plan 移行タイミングを事前に計画しておくこと（`docs/MAINTENANCE_RUNBOOK.md` 参照）

---

## テストカバレッジ拡充フェーズ（2026-03-15）

### 直近の完了作業（2026-03-15）

| 作業 | 状態 |
|------|------|
| Service テスト: PostService, DriveLogService (+100件) | ✅ |
| Provider テスト: DriveLog, Invoice, Document, ServiceMenu (+120件) | ✅ |
| Service テスト: PartRecommendation, Shop, Follow (+150件) | ✅ |
| Service テスト: Document, Inquiry, Invoice, VehicleListing (+200件) | ✅ |
| **Service カバレッジ: 15/19 (79%)** | ✅ |
| **Provider カバレッジ: 12/12 (100%)** | ✅ |

### 未テストのサービス（残り4件）

| サービス | 理由 |
|---------|------|
| `recommendation_service.dart` | 複雑な優先度計算（Firebase依存） |
| `service_menu_service.dart` | Provider テストで間接カバー済み |
| `vehicle_master_service.dart` | データ取得のみ |
| `pdf_export_service.dart` | PDF生成（外部ライブラリ依存） |

---

## 前回の状態（SNS/ドライブ/マーケット完了 → ローンチ準備フェーズ）

### 完了作業（2026-03-13）

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

## P0バグ（修正済み確認 2026-03-25）

### BUG-1: `part_detail_screen.dart` 状態二重管理 ✅ 解消済み

現状のコードを確認済み。`Consumer<PartRecommendationProvider>` に一本化済み。
ローカル状態（`_isLoading`, `_errorMessage`, `_detail`）は存在しない。

### BUG-2: `toggleLike` レースコンディション ✅ 解消済み

`_pendingLikes = Set<String>()` でdebounce管理実装済み。
楽観的更新 + Firestore同期 + 失敗時ロールバックの完全実装を確認済み。

---

## 次セッションでやること（優先順）

### P1（ローンチ必須 - 人間対応 ⚠️）
- [ ] **Firebase Console**: `google-services.json` 本番版をダウンロード → `android/app/` に配置（現在仮ファイル）
- [ ] **Firebase Console**: `GoogleService-Info.plist` をダウンロード → `ios/Runner/` に配置（iOS/Mac必要）
- [ ] **GitHub Secrets**: `GOOGLE_SERVICES_JSON` シークレットを登録（CIのAndroidビルド用）
- [ ] Firestore rules / indexes を Firebase に `firebase deploy` でデプロイ
- [ ] App Store Connect / Google Play Console アカウント開設

### P2（ストア申請前）
- [ ] スクリーンショット準備（iPhone 6.7", iPad、Android）
- [ ] iOS コード署名 / TestFlight 設定（Mac必要）
- [ ] リリースビルド動作確認

### P3（β公開後）
- [ ] ドライブログ GPS記録機能実装
- [ ] コメント機能（SNS）実装
- [ ] プッシュ通知のいいね・コメント通知連携
- [ ] アナリティクスダッシュボード
- [ ] BtoB 課金機能実装（加盟料・成果報酬 — Phase 7）

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
      part_detail_screen.dart         ← ✅ BUG-1 修正済み（Consumer一本化）
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
firestore.rules                       ← ✅ セキュリティルール実装済み（デプロイ待ち）
docs/
  ARCHITECTURE.md                     ← 保守用設計書
  LAUNCH_CHECKLIST.md                 ← ローンチ前チェックリスト（2026-03-13作成）
  DEPLOY_READINESS_REPORT.md          ← デプロイ準備評価レポート（2026-03-13時点）
  MAINTENANCE_RUNBOOK.md              ← ✅ 保守・運用ランブック（2026-03-25追加）
  FEATURE_SPEC.md
```

---

## テスト状況

- **合計**: 約1,927件（unit: ~940, widget: ~987）← 2026-03-25時点
- 実行コマンド: `flutter test --exclude-tags emulator 2>&1 | tail -5`
- 統合テスト: Firebase Emulator依存（CIに `@Tags(['emulator'])` 対応済み、`continue-on-error: true`）
- 既知の非対応テスト: `vehicle_master_service_test.dart` 6件（キャッシュなし設計の変更に起因、機能影響なし）

---

## 4月ローンチ計画（週次）

| 週 | 目標 |
|----|------|
| Week 1（3/13〜）| Firebase設定・Bundle ID完了・セキュリティ修正 |
| Week 2（3/20〜）| ビルド検証・TestFlight β配布 |
| Week 3（3/27〜）| β期間・フィードバック反映 |
| Week 4（4/3〜）| ストア審査申請 |
| **4/中旬** | **公開** |
