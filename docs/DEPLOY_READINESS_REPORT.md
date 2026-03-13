# Trust Car Platform - デプロイ・商品化 準備評価レポート

> **作成日**: 2026-03-06
> **最終更新**: 2026-03-13
> **評価者**: Claude Code (Sonnet 4.6)
> **ブランチ**: `claude/continue-development-WYZZp`
> **総合評価**: ⚠️ **デプロイ不可（重大ブロッカー残り2件）**

---

## 総合評価サマリー

```
商品化準備度スコア: 7.0 / 10  (前回 5.5 → 改善)

コード品質:       ████████░░  8.5/10  ✅
テストカバレッジ:  ████████░░  8.0/10  ✅（1073件）
セキュリティ:     ██████░░░░  6.0/10  ⚠️
デプロイ設定:     ██████░░░░  6.0/10  🔶（Bundle ID解消済み）
```

**verdict**: Bundle IDとFirestoreインデックスが解消された。
残るブロッカーはFirebase設定ファイル（人間作業）のみ。
セキュリティルールの修正が残っているが、コアロジックは商品レベル。

---

## 1. 重大ブロッカー（P0 - リリース前に必須対応）

### 🔴 B-1: `google-services.json` が存在しない（人間作業）

| 項目 | 詳細 |
|------|------|
| ファイル | `android/app/google-services.json` |
| 状態 | **ファイル未存在** |
| 影響 | Android ビルドが完全に失敗 |
| 対応 | Firebase Console → プロジェクト設定 → Androidアプリ → Bundle ID `jp.trustcar.app` で登録 → ダウンロード |

### 🔴 B-2: `GoogleService-Info.plist` が存在しない（人間作業）

| 項目 | 詳細 |
|------|------|
| ファイル | `ios/Runner/GoogleService-Info.plist` |
| 状態 | **ファイル未存在** |
| 影響 | iOS ビルドが完全に失敗 |
| 対応 | Firebase Console → プロジェクト設定 → iOSアプリ → Bundle ID `jp.trustcar.app` で登録 → ダウンロード |

### ✅ B-3: Bundle ID 変更済み（2026-03-13 完了）

| 項目 | 詳細 |
|------|------|
| Android | `jp.trustcar.app` |
| iOS | `jp.trustcar.app` |
| macOS | `jp.trustcar.app` |
| Linux | `jp.trustcar.app` |
| firebase_options.dart | `jp.trustcar.app` |

### ✅ B-4: Firestoreインデックス定義済み（2026-03-13 完了）

約30件の複合インデックスを `firestore.indexes.json` に定義。
`firebase deploy --only firestore:indexes` で適用可能。

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

### ⚠️ S-2: `drive_waypoints` のオーナーチェック欠落（プライバシーリスク高）

```javascript
// firestore.rules L306 - 現在（問題あり）
allow read, write: if isAuthenticated();  // 他ユーザーのウェイポイントも読み書き可

// 推奨
allow read, write: if isAuthenticated() && resource.data.userId == request.auth.uid;
```

**リスク**: 他ユーザーの位置情報（GPS軌跡）にアクセス可能。個人情報保護法対応必須。

### ⚠️ S-3: `inquiries/messages` の親コレクション認可チェック欠落

```javascript
// firestore.rules L143-148 - 現在（問題あり）
match /messages/{messageId} {
  allow read: if isAuthenticated();  // 問い合わせ当事者以外も読める
```

**リスク**: 第三者が他ユーザーの商談メッセージを閲覧可能。

### ℹ️ S-4: Firebase API キーはソースコードに含まれる（許容範囲）

`lib/firebase_options.dart` の `apiKey` はクライアント配布前提。
ただし Firebase Console でのドメイン制限・API制限を設定すること。

---

## 3. P0バグ（コード修正必要）

### 🔴 BUG-1: `part_detail_screen.dart` 状態二重管理

**場所**: `lib/screens/marketplace/part_detail_screen.dart`

**問題**: Screen内のローカル状態（`_isLoading`, `_errorMessage`, `_detail`）と
`PartRecommendationProvider`の状態が二重管理されている。

**修正方針**: ローカル状態を削除して `Consumer<PartRecommendationProvider>` に一本化。

### 🔴 BUG-2: `toggleLike` レースコンディション

**場所**: `lib/providers/post_provider.dart` → `toggleLike()`

**問題**: 高速連続タップ時、楽観的更新のロールバックが競合してカウントがずれる。

**修正方針**: `_pendingLikes = Set<String>()` でdebounce管理。

---

## 4. 運用設定の問題（P2）

### 🔶 O-1: アプリバージョン管理

CI/CDでversionCodeを自動インクリメントする仕組みが未整備。

### 🔶 O-2: 統合テストの CI 未実行

`test/integration/` は Firebase Emulator 依存。CI未実行。

### 🔶 O-3: iOS コード署名設定なし

TestFlight / App Store 申請には署名設定が必要（Mac環境で実施）。

---

## 5. テスト評価

| 項目 | 数値 |
|------|------|
| テストファイル数 | 50+ファイル |
| テストケース数 | **約1,073件**（unit + widget） |
| 前回比 | 953件 → 1,073件（+120件） |

### 層別カバレッジ状況

| 層 | カバレッジ | 備考 |
|----|-----------|------|
| `core/` (Result/AppError等) | ✅ 充実 | 67件 |
| `models/` | ✅ 充実 | 全主要モデル対応 |
| `services/` | ✅ 充実 | 21サービス対応 |
| `providers/` | ✅ 良好 | PostProvider 30件、DriveLogProvider含む |
| `screens/marketplace` | ✅ 良好 | PartDetail 23件追加済み |
| `screens/sns` | ✅ 良好 | SnsFeed 20件、PostCreate 20件 |
| `screens/drive` | 🔶 未着手 | DriveLogScreen テスト未作成 |
| `integration/` | 🔶 条件付き | エミュレータ依存（CI未実行） |

---

## 6. 実装済み機能の完成度

| 機能領域 | 完成度 | 備考 |
|---------|--------|------|
| 認証（Email/Google） | ✅ 95% | 本番運用可能 |
| 車両管理 CRUD | ✅ 95% | バリデーション含む |
| 整備記録 | ✅ 95% | タイムライン・22種類 |
| 車検証 OCR | ✅ 85% | ML Kit、実機テスト推奨 |
| アラート/通知 | ✅ 90% | Push通知設定あり |
| BtoBマーケット（工場） | 🔶 75% | UI完成、取引フロー未実装 |
| BtoBマーケット（パーツ） | 🔶 70% | 詳細画面完成、購入フロー未実装 |
| SNS/コミュニティ | ✅ 75% | 投稿・いいね完成、コメント未実装 |
| ドライブログ | 🔶 50% | 一覧画面完成、GPS記録未実装 |

---

## 7. 商品化チェックリスト

### 必須（人間作業 - Claude不可）

- [ ] Firebase Console で Bundle ID `jp.trustcar.app` に更新（iOS/Android）
- [ ] `google-services.json` 生成・配置 → `android/app/`
- [ ] `GoogleService-Info.plist` 生成・配置 → `ios/Runner/`
- [ ] App Store Connect アカウント開設・アプリ登録
- [ ] Google Play Console アカウント開設・アプリ登録

### 必須（コード修正 - Claude対応可）

- [ ] BUG-1: `part_detail_screen.dart` 状態二重管理を修正
- [ ] BUG-2: `toggleLike` レースコンディションを修正
- [ ] Firestore rules: `drive_waypoints` オーナーチェック追加
- [ ] Firestore rules: `shops` 管理者ロールチェック追加
- [ ] Firestore rules: `inquiries/messages` 認可追加
- [ ] プライバシーポリシー画面（App Store審査必須）

### ✅ 完了済み

- [x] Bundle ID `jp.trustcar.app` に変更（2026-03-13）
- [x] Firestore 複合インデックス約30件定義（2026-03-13）
- [x] SNS機能（投稿・いいね・カテゴリフィルタ）実装
- [x] ドライブログ一覧画面実装
- [x] パーツ詳細画面実装
- [x] テスト約1,073件（unit + widget）

---

## 8. リリースまでのロードマップ（4月公開目標）

```
Week 1（3/13〜3/19）: Firebase設定・セキュリティ修正
  └─ Firebase Console Bundle ID更新（人間）
  └─ google-services.json / GoogleService-Info.plist 配置（人間）
  └─ Firestore rules 修正（Claude可）
  └─ P0バグ修正（Claude可）

Week 2（3/20〜3/26）: ビルド検証・β配布準備
  └─ Android release ビルド確認
  └─ iOS debug ビルド確認（Mac必要）
  └─ TestFlight / Firebase App Distribution 設定

Week 3（3/27〜4/2）: β テスト期間
  └─ 実ユーザーフィードバック
  └─ クラッシュ・バグ修正
  └─ スクリーンショット・説明文準備

Week 4（4/3〜4/9）: ストア審査申請
  └─ App Store 審査申請
  └─ Google Play 審査申請
  └─ 審査期間 3〜7日

4月中旬: 🚀 公開
```

---

## 9. 結論

### できていること
- コアロジックの品質は商品レベル（Result型・AppError・DI一貫性）
- 1,073件のテストで主要ロジックを保護
- Bundle ID を本番値 `jp.trustcar.app` に変更済み
- Firestoreインデックス約30件が定義済み
- Crashlytics・Performance・Push通知の基盤が整備済み

### できていないこと（今すぐ対処が必要）
1. **Firebase設定ファイル未配置** → ビルド不可（人間作業）
2. **Firestore security rules に脆弱性** → 位置情報漏洩リスク
3. **P0バグ** → part_detail 二重状態、toggleLike レースコンディション
4. **プライバシーポリシー画面** → App Store審査必須

---

> **このレポートの有効期限**: Firebase設定ファイル配置後に再評価推奨
> **次回評価推奨時期**: Firestore rules修正・P0バグ修正後
