# Claude Session Notes

最終更新: 2026-06-09

---

## 現在の状態

**ブランチ**: `claude/continue-development-WYZZp`
**ベース**: `main`（140 コミット先行）

---

## 今セッション（2026-06-09）の成果

### セキュリティ強化
- `functions/src/askCarAi.ts`: TOCTOU 脆弱性を Firestore `runTransaction` で修正
  - 入力長上限: `MAX_USER_MESSAGE_LENGTH = 500`, `MAX_HISTORY_MESSAGE_LENGTH = 500`
  - 履歴件数上限: `MAX_HISTORY_MESSAGES = 20`

### 機能追加
- **AIチャット履歴永続化**: `SharedPreferences` で最大20件保存（`ai_chat_history` キー）
  - `AiChatProvider.loadHistory()` / `_saveHistory()` 追加
  - `AiChatScreen.initState()` で `addPostFrameCallback` 経由ロード

### UI/UX 改善（Material Design 3）

| ファイル | 変更 |
|---|---|
| `app_theme.dart` | `NavigationBarTheme` 追加（`WidgetStateProperty` でアイコン・ラベル色制御） |
| `home_screen.dart` | `NavigationBar` + `NavigationDestination` に移行、車両カードアクセントバー、AIセクションヘッダーピル |
| `vehicle_detail_screen.dart` | 整備タイムラインカード刷新（`IntrinsicHeight` + アクセントバー + `mileageAtService` 表示）、AI提案セクション + 詳細シート + 「今すぐ記録する」CTA |
| `ai_chat_screen.dart` | `_ChatBubble` に HH:mm タイムスタンプ表示 |
| `add_maintenance_screen.dart` | タイプ選択後 `AnimatedSwitcher` でカラープレビューバナー（`_buildTypePreview`） |
| `notification_list_screen.dart` | 詳細シートに「なぜ今なのか」reason セクション追加 |
| `profile_screen.dart` | `_StatsSection`（登録車両数・整備記録数・総走行距離）をプロフィールヘッダー直下に追加 |

### テスト追加
- `notification_list_screen_test.dart`: reason 表示あり/なし 2件
- `profile_screen_test.dart`: `_StatsSection` ラベル・初期値 2件

### 車両未登録オンボーディングガイド
- `home_screen.dart`: `_VehicleTab` の空状態を `AppEmptyState` から `_VehicleEmptyOnboarding` に刷新
  - ヒーローアイコン（96px 円形背景）
  - 3機能ハイライト（`_FeatureRow`）: 整備記録 / AI通知 / 工場連携
  - 大型 CTA「車両を登録する」ボタン → `VehicleRegistrationScreen` へ

---

## アーキテクチャ上の重要な決定事項

### `AppSpacing.borderRadiusFull` は存在しない
- `AppSpacing.radiusFull = 100.0`（double）のみ
- ピル形状には `BorderRadius.circular(AppSpacing.radiusFull)` を使う

### NavigationBar テーマ
- `bottomNavigationBarTheme` は削除済み → `navigationBarTheme` のみ
- `WidgetStateProperty.resolveWith` で選択/非選択の色を制御

### `_showSuggestionDetail` のコンテキスト
- `vehicle_detail_screen.dart` のトップレベル関数
- `vehicleId`, `vehicleMileage` を named parameter で受け取る
- `context.mounted` チェック後に `AddMaintenanceScreen` へプッシュ

---

## 未解決・人間が対応すべき事項

| 優先度 | タスク |
|---|---|
| P1 | `dart format lib test` をローカル実行し CI format チェックを通す |
| P1 | PR 作成: `gh pr create --title "feat(ui): UI/UX全面刷新" --base main --head claude/continue-development-WYZZp` |
| P1 | `google-services.json`（本番用）を Firebase Console からダウンロードして `android/app/` に配置 |
| P1 | `GoogleService-Info.plist`（本番用）を Firebase Console からダウンロードして `ios/Runner/` に配置 |
| P2 | CI 結果確認（GitHub Actions → `claude/continue-development-WYZZp` ブランチ） |

---

## 参照ファイル

| 目的 | パス |
|---|---|
| 機能仕様 | `docs/FEATURE_SPEC.md` |
| デザインシステム | `docs/DESIGN_SYSTEM.md` |
| 人間タスク | `docs/HUMAN_TASKS.md` |
| CI 設定 | `.github/workflows/ci.yml` |
| Cloud Functions | `functions/src/askCarAi.ts` |
