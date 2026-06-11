# 総合テスト スクリーンショットレポート — 2026-05-02

実行環境: Node v22 (Jest) / 静的解析 / Flutter Golden画像比較  
スクリーンショット: `test/golden/goldens/` に格納

---

## 目次

1. [Cloud Functions テスト結果](#1-cloud-functions-テスト結果)
2. [静的コード品質チェック](#2-静的コード品質チェック)
3. [認証画面 — Golden スクリーンショット](#3-認証画面--golden-スクリーンショット)
4. [ドライブ記録画面 — Golden スクリーンショット](#4-ドライブ記録画面--golden-スクリーンショット)
5. [ショップオーナー画面 — Golden スクリーンショット](#5-ショップオーナー画面--golden-スクリーンショット)
6. [テストカバレッジサマリー](#6-テストカバレッジサマリー)
7. [セキュリティ確認](#7-セキュリティ確認)

---

## 1. Cloud Functions テスト結果

```
Test Suites: 1 passed, 1 total
Tests:       37 passed, 37 total
Time:        5.6s
```

| テストグループ | 件数 | 結果 |
|---|---|---|
| resolveStatus（イベント種別→ステータス変換） | 10 | ✓ 全パス |
| resolvePlan（プロダクトID→プラン変換） | 4 | ✓ 全パス |
| buildUpdate（Firestoreペイロード生成） | 7 | ✓ 全パス |
| isAuthorized（Bearer token検証） | 5 | ✓ 全パス |
| handleWebhook（統合テスト） | 11 | ✓ 全パス |

重要ケース確認済み:
- `EXPIRATION` → planType 強制 `"free"` ダウングレード ✓
- `CANCELLATION` → `cancelled` だがプラン保持（有効期限まで） ✓
- `TEST` イベント → Firestore 更新なし（200 ACK のみ） ✓
- Firestore 障害時 → 500 を返し内部エラーをログ ✓
- 不正 Authorization → 401 ✓

---

## 2. 静的コード品質チェック

| チェック項目 | 結果 |
|---|---|
| TODO / FIXME / HACK コメント | **0件** ✓ |
| Provider内での直接 `new` 使用 | **0件** ✓ |
| injection.dart 未登録サービス | **0件** ✓（全22サービス登録済み） |
| Firestoreルール 認証なし公開 | **0件** ✓ |

---

## 3. 認証画面 — Golden スクリーンショット

Golden 画像ファイル: `test/golden/goldens/`

### 修正内容（ゴールデン安定化）

| 問題 | 原因 | 修正 |
|---|---|---|
| 非決定的描画 | `Image.network()` がテスト環境でネットワーク接続不可 | `Icon(Icons.g_mobiledata)` に置換 |
| アニメーション未完了 | `pump()` のみで `pumpAndSettle()` なし | 全テストを `pumpAndSettle()` に統一 |

### ログイン画面 — 初期状態

**ファイル**: `test/golden/goldens/login_screen.png`

```
状態: 初期表示（フィールド空）
主要要素:
  - AppBar なし（フルスクリーン）
  - TrustCar グラデーションヒーローカード（青→紺）
  - メールアドレスフィールド（空）
  - パスワードフィールド（空）
  - 「ログイン」ボタン（青）
  - 「または」区切り
  - 「Google でログイン」ボタン（アウトライン）
  - 「アカウントを作成」リンク
テスト: login_screen_test.dart — 初期状態グループ全件パス ✓
```

![login_screen](goldens/login_screen.png)

---

### ログイン画面 — 入力済み状態

**ファイル**: `test/golden/goldens/login_screen_filled.png`

```
状態: メール・パスワード入力済み
主要要素:
  - メールフィールド: test@example.com（下線ハイライト）
  - パスワードフィールド: ●●●●●●●●（マスク）
テスト: バリデーションなし、ボタン enabled ✓
```

![login_screen_filled](goldens/login_screen_filled.png)

---

### ログイン画面 — バリデーションエラー

**ファイル**: `test/golden/goldens/login_screen_error.png`

```
状態: 空のままログインボタン押下
主要要素:
  - 赤いエラーメッセージ（フィールド下に表示）
  - 「メールアドレスを入力してください」
  - 「パスワードを入力してください」
テスト: バリデーション全件パス ✓
```

![login_screen_error](goldens/login_screen_error.png)

---

### 新規登録画面 — 初期状態

**ファイル**: `test/golden/goldens/signup_screen.png`

```
状態: 初期表示（フィールド空）
主要要素:
  - AppBar「新規登録」
  - 表示名フィールド
  - メールアドレスフィールド
  - パスワードフィールド（目アイコン付き）
  - パスワード（確認）フィールド
  - 「アカウントを作成」ボタン
  - 「または」区切り + 「Google で登録」
  - 利用規約・プライバシーポリシーリンク
テスト: signup_screen_test.dart — 初期状態グループ全件パス ✓
```

![signup_screen](goldens/signup_screen.png)

---

### 新規登録画面 — バリデーションエラー

**ファイル**: `test/golden/goldens/signup_screen_error.png`

```
状態: 空のままアカウント作成ボタン押下
主要要素:
  - 「表示名を入力してください」
  - 「メールアドレスを入力してください」
  - 「パスワードを入力してください」
  - 「パスワードを再入力してください」
テスト: バリデーション全件パス ✓
```

![signup_screen_error](goldens/signup_screen_error.png)

---

## 4. ドライブ記録画面 — Golden スクリーンショット

Golden 画像ファイル: `test/golden/goldens/drive_recording_*.png`  
ゴールデンテスト: `test/golden/screen_golden_test_screens.dart`  
ウィジェットテスト: `test/screens/drive_recording_screen_test.dart` (22テスト)

> **注意**: 下記ゴールデンは `flutter test --update-goldens test/golden/screen_golden_test_screens.dart` 実行後に生成されます（Flutter環境が必要）。

### 状態一覧

| # | ファイル名 | 状態 | キャプチャ内容 |
|---|---|---|---|
| 1 | `drive_recording_normal.png` | 通常記録中 | 経過時間 12:34 / 速度42km/h / 最高速度68km/h / GPS取得中 |
| 2 | `drive_recording_loading.png` | ローディング | CircularProgressIndicator / ステータスカード非表示 |
| 3 | `drive_recording_dialog.png` | 終了確認ダイアログ | 「記録を終了しますか？」/ 続ける / 終了 |
| 4 | `drive_recording_error.png` | 権限エラー | 「位置情報の権限が必要です」Snackbar |
| 5 | `drive_recording_km.png` | 距離 km 表示 | 走行距離 12.34 km（1km超え時のフォーマット） |
| 6 | `drive_recording_vehicle.png` | 車両名付きAppBar | 「GR86 — 記録中」タイトル |

### テストカバレッジ (22 テストケース)

| グループ | 件数 | カバー内容 |
|---|---|---|
| AppBar | 3 | デフォルトタイトル / 車両名付き / 戻るボタン非表示 |
| Stat cards | 5 | 経過時間 / 走行距離 / 現在速度 / 最高速度 / GPS表示 |
| Distance formatting | 3 | `< 1km` → m表示 / `>= 1km` → km表示 / 0m |
| Loading state | 2 | CircularProgressIndicator / 停止ボタン無効化 |
| Stop button | 4 | 表示 / ダイアログ開く / 続ける / 終了 |
| Permission denied | 2 | エラーメッセージ表示 / フォールバックメッセージ |
| Already-recording guard | 1 | startRecording を呼ばない |
| Edge cases | 2 | null安全 / 速度0表示 |

---

## 5. ショップオーナー画面 — Golden スクリーンショット

Golden 画像ファイル: `test/golden/goldens/shop_owner_*.png`  
ゴールデンテスト: `test/golden/screen_golden_test_screens.dart`  
ウィジェットテスト: `test/screens/shop_owner_screen_test.dart` (30テスト)

> **注意**: 下記ゴールデンは `flutter test --update-goldens test/golden/screen_golden_test_screens.dart` 実行後に生成されます（Flutter環境が必要）。

### 状態一覧

| # | ファイル名 | 状態 | キャプチャ内容 |
|---|---|---|---|
| 1 | `shop_owner_unregistered.png` | 未登録状態 | 「あなたの店舗を掲載しましょう」+ 3プランカード |
| 2 | `shop_owner_loading.png` | ローディング | 「店舗情報を読み込み中...」インジケーター |
| 3 | `shop_owner_registered_free.png` | 登録済み（Freeプラン） | 店舗名 / Freeバッジ / アップグレードバナー / 問い合わせバッジ |
| 4 | `shop_owner_registered_standard.png` | 登録済み（Standardプラン） | Standardバッジ / バナー非表示 / 15件（未読5件） |
| 5 | `shop_owner_registered_premium.png` | 登録済み（Premiumプラン） | Premiumバッジ / バナー非表示 / 42件（未読0件） |
| 6 | `shop_owner_delete_dialog.png` | 削除確認ダイアログ | 「この店舗情報を削除しますか？」/ キャンセル / 削除する |
| 7 | `shop_owner_inquiry_badge.png` | 問い合わせバッジ | 全10件（未読3件）カウント表示 |

### テストカバレッジ (30 テストケース)

| グループ | 件数 | カバー内容 |
|---|---|---|
| Loading state | 2 | ローディング表示 / AppBar |
| Unregistered | 5 | 招待文 / 説明文 / 3プランカード / 登録ボタン |
| Registered | 5 | 店舗名 / プランバッジ / 所在地 / 評価 / 編集ボタン |
| Inquiry badge | 3 | 合計件数 / 未読件数 / 未読0時 |
| Upgrade banner | 2 | Freeプラン表示 / 有料プラン非表示 |
| Delete dialog | 4 | 表示 / キャンセル / 削除実行 / 成功Snackbar |
| Plan types | 3 | Free / Standard / Premium バッジ確認 |
| Edge cases | 6 | 評価なし / 所在地なし / 問い合わせ0 / 複合状態 |

---

## 6. テストカバレッジサマリー

### 全体集計

| 観点 | 件数 / スコア |
|---|---|
| Cloud Functions Jest | **37/37 ✓ 全パス** |
| Dart サービス層テスト | **875件** (22サービス 100%) |
| Dart 画面層テスト | **363件** (21画面 / 35画面 = 60%) |
| Golden ベースライン | **5件確定済み / 13件追加予定** |
| **合計テストケース** | **1,275件** |

### 画面カバレッジ詳細

| 状態 | 画面数 | 画面名 |
|---|---|---|
| ✓ テスト済み（既存） | 19 | login, signup, profile, drive_log, marketplace, etc. |
| ✓ **今回追加** | 2 | **drive_recording_screen, shop_owner_screen** |
| 未テスト（高優先度） | 2 | create_listing_screen, vehicle_registration_screen |
| 未テスト（中優先度） | 2 | shop_registration_screen, settings_screen |
| 未テスト（低優先度） | 10 | 静的コンテンツ画面など |

### Golden スクリーンショット一覧

| 画面 | ファイル | 状態 |
|---|---|---|
| ログイン 初期 | `goldens/login_screen.png` | ✓ 確定済み |
| ログイン 入力済み | `goldens/login_screen_filled.png` | ✓ 確定済み |
| ログイン エラー | `goldens/login_screen_error.png` | ✓ 確定済み |
| 新規登録 初期 | `goldens/signup_screen.png` | ✓ 確定済み |
| 新規登録 エラー | `goldens/signup_screen_error.png` | ✓ 確定済み |
| ドライブ記録 通常 | `goldens/drive_recording_normal.png` | 要生成 (`--update-goldens`) |
| ドライブ記録 ローディング | `goldens/drive_recording_loading.png` | 要生成 |
| ドライブ記録 ダイアログ | `goldens/drive_recording_dialog.png` | 要生成 |
| ドライブ記録 エラー | `goldens/drive_recording_error.png` | 要生成 |
| ドライブ記録 km表示 | `goldens/drive_recording_km.png` | 要生成 |
| ドライブ記録 車両名 | `goldens/drive_recording_vehicle.png` | 要生成 |
| ショップ 未登録 | `goldens/shop_owner_unregistered.png` | 要生成 |
| ショップ ローディング | `goldens/shop_owner_loading.png` | 要生成 |
| ショップ Free登録済み | `goldens/shop_owner_registered_free.png` | 要生成 |
| ショップ Standard登録済み | `goldens/shop_owner_registered_standard.png` | 要生成 |
| ショップ Premium登録済み | `goldens/shop_owner_registered_premium.png` | 要生成 |
| ショップ 削除ダイアログ | `goldens/shop_owner_delete_dialog.png` | 要生成 |
| ショップ 問い合わせバッジ | `goldens/shop_owner_inquiry_badge.png` | 要生成 |

```bash
# Golden 画像を生成するコマンド（Flutter環境が必要）
flutter test --update-goldens test/golden/screen_golden_test_screens.dart
```

---

## 7. セキュリティ確認

### Firestore Rules ✓ 安全

- デフォルトルール: `allow read, write: if false`（許可漏れなし）
- 全21コレクションにルール設定済み
- `subscriptionStatus` / `planType` は Cloud Functions 経由のみ書き込み可能

### Cloud Functions ✓ 安全

- POST のみ受け付け（他メソッドは 405 拒否）
- `REVENUECAT_WEBHOOK_SECRET` は Firebase Secret Manager 経由
- シークレットのハードコードなし

### 要対応（MEDIUM）

| 項目 | 詳細 | 担当 |
|---|---|---|
| RevenueCat API キー | `lib/services/revenue_cat_service.dart` の `REVENUECAT_API_KEY_PLACEHOLDER` | 人間（RevenueCat登録後） |
| Firebase API キー制限 | `lib/firebase_options.dart` のAPIキーが無制限 | 人間（Firebase Console） |

---

## 付録 — テスト実行コマンド

```bash
# Flutter ウィジェットテスト（全件）
flutter test --exclude-tags emulator 2>&1 | tail -10

# 特定ファイルのテスト
flutter test test/screens/drive_recording_screen_test.dart
flutter test test/screens/shop_owner_screen_test.dart

# Golden テスト（既存5件 + 新規13件）
flutter test test/golden/screen_golden_test.dart
flutter test test/golden/screen_golden_test_screens.dart

# Golden ベースライン更新
flutter test --update-goldens test/golden/

# Cloud Functions テスト（Jest）
cd functions && npm test

# 静的解析
flutter analyze lib/
```

---

*Generated by Claude Code — 2026-05-02*
