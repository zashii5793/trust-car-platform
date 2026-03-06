# Trust Car Platform - デプロイ・商品化 準備評価レポート

> **作成日**: 2026-03-06
> **評価者**: Claude Code (Sonnet 4.6)
> **ブランチ**: `claude/continue-development-WYZZp`
> **総合評価**: ⚠️ **デプロイ不可（重大ブロッカーあり）**

---

## 総合評価サマリー

```
商品化準備度スコア: 5.5 / 10

コード品質:       ████████░░  8.5/10  ✅
テストカバレッジ:  ███████░░░  7.0/10  🔶
セキュリティ:     ██████░░░░  6.0/10  ⚠️
デプロイ設定:     ███░░░░░░░  3.0/10  🔴
```

**verdict**: Firebase設定ファイルが未存在のため、現時点では**ビルドすら不可能**。
コアロジックとテストの品質は高く、設定問題を解消すれば商品化ラインに乗れる水準。

---

## 1. 重大ブロッカー（P0 - リリース前に必須対応）

### 🔴 B-1: `google-services.json` が存在しない

| 項目 | 詳細 |
|------|------|
| ファイル | `android/app/google-services.json` |
| 状態 | **ファイル未存在** |
| 影響 | Android ビルドが完全に失敗 |
| 対応 | Firebase Console → プロジェクト設定 → Android アプリ → ダウンロード |

### 🔴 B-2: `GoogleService-Info.plist` が存在しない

| 項目 | 詳細 |
|------|------|
| ファイル | `ios/Runner/GoogleService-Info.plist` |
| 状態 | **ファイル未存在** |
| 影響 | iOS ビルドが完全に失敗 |
| 対応 | Firebase Console → プロジェクト設定 → iOS アプリ → ダウンロード |

### 🔴 B-3: Android アプリケーション ID がデフォルト値

| 項目 | 詳細 |
|------|------|
| ファイル | `android/app/build.gradle.kts` |
| 現在値 | `applicationId = "com.example.trust_car_platform"` |
| 問題 | Play Store に `com.example.*` で申請不可 |
| 対応 | プロダクション用 ID に変更（例: `jp.trustcar.platform`） |

### 🔴 B-4: CI/CD ブランチ設定不整合

| 項目 | 詳細 |
|------|------|
| ファイル | `.github/workflows/ci.yml` |
| 現在設定 | `branches: [main, develop]` |
| 問題 | 開発ブランチ `claude/continue-development-WYZZp` でCI未実行 |
| 対応 | `claude/**` を追加またはPR時に `main`/`develop` をターゲットにする運用を明確化 |

---

## 2. セキュリティ問題（P1 - リリース前推奨）

### ⚠️ S-1: Firestore ルール - shops コレクションへの無制限作成

```javascript
// firestore.rules L109 - 現在（問題あり）
allow create: if isAuthenticated();  // 認証ユーザーなら誰でも店舗作成可能

// 推奨
allow create: if isAdmin();  // 管理者ロールを追加
```

**リスク**: 悪意あるユーザーが無制限に店舗データを作成可能。
**影響コレクション**: `shops`, `service_menus`

### ⚠️ S-2: `drive_waypoints` のオーナーチェック欠落

```javascript
// firestore.rules L306 - 現在（問題あり）
allow read, write: if isAuthenticated();  // 他ユーザーのウェイポイントも読み書き可

// 推奨
allow read, write: if isAuthenticated() && resource.data.userId == request.auth.uid;
```

**リスク**: 他ユーザーの位置情報（GPS軌跡）にアクセス可能。
**プライバシー**: 位置情報は個人情報として最高レベルの保護が必要。

### ⚠️ S-3: `inquiries/messages` の親コレクション認可チェック欠落

```javascript
// firestore.rules L143-148 - 現在（問題あり）
match /messages/{messageId} {
  allow read: if isAuthenticated();  // 問い合わせ当事者以外も読める
  allow create: if isAuthenticated();
```

**リスク**: 第三者が他ユーザーの商談メッセージを閲覧可能。

### ℹ️ S-4: Firebase API キーがソースコードに含まれる（許容範囲）

`lib/firebase_options.dart` に `apiKey: 'AIzaSy...'` が含まれるが、これは Flutter/Firebase の標準的な実装方法であり、**Firebase のクライアント API キーはクライアント配布が前提**。
ただし Firebase Console でのドメイン制限・API 制限を設定すること。

---

## 3. 運用設定の問題（P2 - 初回リリース前推奨）

### 🔶 O-1: アプリバージョン管理

| 項目 | 詳細 |
|------|------|
| 現在 | `version: 1.0.0+1` |
| 問題 | versionCode(+1) が Play Store / App Store で一意である必要あり |
| 対応 | CI/CD でバージョンコードを自動インクリメントする仕組みを用意 |

### 🔶 O-2: 統合テストの CI 未実行

```yaml
# test/integration/ のテストは firebase emulator が必要
# 現在のci.ymlでは firebase emulators:start を実行していない
```

**対応案**:
```yaml
- name: Start Firebase Emulators
  run: firebase emulators:start --only firestore,auth &
  env:
    FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
- name: Wait for emulators
  run: sleep 10
- name: Run integration tests
  run: flutter test test/integration/ --tags emulator
```

### 🔶 O-3: iOS コード署名設定なし

`ci.yml` は `--no-codesign` でビルドしており、実機テスト・TestFlight 配布・App Store 申請には署名設定が必要。

---

## 4. テスト評価

### テスト全体

| 項目 | 数値 |
|------|------|
| テストファイル数 | 47ファイル |
| テストケース数 | **953件**（unit + widget） |
| コード規模 | 14,170行（テストコード） |

### 層別カバレッジ状況

| 層 | カバレッジ | 備考 |
|----|-----------|------|
| `core/` (Result/AppError等) | ✅ 充実 | 67件 |
| `models/` | ✅ 充実 | 全主要モデル対応 |
| `services/` | ✅ 充実 | OCR/Auth/Firebase/Push/Notification |
| `providers/` | ✅ 良好 | 7プロバイダ、loadBrowseParts 10件追加済 |
| `screens/` (core) | 🔶 部分的 | home/login/vehicle/add_maintenance |
| `marketplace screens/` | ❌ **未カバー** | 4画面 × バリデーション未テスト |
| `integration/` | 🔶 条件付き | エミュレータ依存（CI未実行） |

### カバレッジ未達の重要箇所

| 対象 | 優先度 | 推定テスト工数 |
|------|--------|--------------|
| `shop_list_screen.dart` フィルタ動作 | 高 | 中（10ケース程度） |
| `inquiry_screen.dart` フォームバリデーション | 高 | 中（8ケース程度） |
| `part_list_screen.dart` 検索・フィルタ | 中 | 中（8ケース程度） |
| `shop_detail_screen.dart` 営業時間表示 | 低 | 小（4ケース程度） |

---

## 5. コード品質評価

### アーキテクチャ

```
✅ DI一貫性: 全21サービスが ServiceLocator に登録済み
✅ Result<T,AppError>: Service層全体に適用
✅ Provider構造: コンストラクタ注入（new禁止）を厳守
✅ Firestore複合インデックス: 15件定義済み（今回追加）
⚠️ Screen内の直接new: OCR/PDF系サービスが一部Screen内でinstantiate
```

### 実装済み機能の完成度

| 機能領域 | 完成度 | 備考 |
|---------|--------|------|
| 認証（Email/Google） | ✅ 95% | 本番運用可能 |
| 車両管理 CRUD | ✅ 95% | バリデーション含む |
| 整備記録 | ✅ 95% | タイムライン・22種類 |
| 車検証 OCR | ✅ 85% | ML Kit、実機テスト推奨 |
| アラート/通知 | ✅ 90% | Push通知設定あり |
| BtoBマーケット（工場） | 🔶 70% | UI完成、取引フロー未実装 |
| BtoBマーケット（パーツ） | 🔶 65% | UI完成、購入フロー未実装 |
| SNS/コミュニティ | 🔶 50% | モデル・Service完成、画面未着手 |
| ドライブログ | 🔶 40% | モデル完成、GPS機能未実装 |

---

## 6. 商品化チェックリスト

### 必須（リリース不可ブロッカー）

- [ ] `google-services.json` 生成・配置
- [ ] `GoogleService-Info.plist` 生成・配置
- [ ] Android applicationId を本番値に変更
- [ ] iOS Bundle Identifier を本番値に変更
- [ ] App Store Connect / Google Play Console アカウント準備

### セキュリティ（リリース前推奨）

- [ ] `shops` create ルールに管理者ロールチェック追加
- [ ] `drive_waypoints` にオーナーチェック追加
- [ ] `inquiries/messages` に親コレクション認可追加
- [ ] Firebase Console で API キーのドメイン制限設定

### 品質（リリース後OK、改善推奨）

- [ ] marketplace screens のウィジェットテスト追加
- [ ] CI に Firebase Emulator 統合テスト追加
- [ ] iOS コード署名・TestFlight 配布設定
- [ ] バージョンコード自動インクリメント設定

---

## 7. リリースまでのロードマップ

```
Phase 0: 設定修正（1〜2日）
  └─ Firebase 設定ファイル配置
  └─ Bundle ID / applicationId 変更
  └─ Firestore security rules 修正

Phase 0.5: ビルド検証（1〜2日）
  └─ Android debug/release ビルド確認
  └─ iOS debug ビルド確認（Mac必要）
  └─ 実機接続テスト

Phase 1: ストア申請準備（3〜5日）
  └─ スクリーンショット・説明文準備
  └─ iOS プライバシーポリシー（位置情報使用のため必須）
  └─ コード署名・プロビジョニング設定
  └─ TestFlight / Firebase App Distribution 配布

Phase 2: MVP公開（目安 1〜2週間後）
  └─ 認証・車両管理・整備記録の core 機能のみでβ公開
  └─ BtoBマーケットは次バージョンで拡充
```

---

## 8. 結論

### できていること
- コアロジックの品質は商品レベル（Result型・AppError・DI一貫性）
- 953件のテストで主要ロジックを保護
- Crashlytics・Performance・Push通知の基盤が整備済み
- CI/CD（analyze + test + build）のパイプラインが定義済み

### できていないこと（今すぐ対処が必要）
1. **Firebase設定ファイル未配置** → ビルド不可
2. **Bundle ID がプレースホルダー** → ストア申請不可
3. **Firestore security rules に脆弱性** → 位置情報漏洩リスク
4. **統合テストがCIで未実行** → 品質保証の穴

### 推奨アクション（優先順）
1. Firebase Console から google-services.json / GoogleService-Info.plist をダウンロード
2. Bundle ID を本番値に変更（`jp.trustcar.platform` 等）
3. Firestore rules を今セッションで修正（drive_waypoints・shops）
4. Firestore rules をデプロイ: `firebase deploy --only firestore:rules`
5. 動作確認後、`main` ブランチへのPRを作成してCI確認

---

> **このレポートの有効期限**: コードベースが変わり次第、再評価が必要
> **次回評価推奨時期**: Firebase 設定ファイル配置後・Firestore rules 修正後
