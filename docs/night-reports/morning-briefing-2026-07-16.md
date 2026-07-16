# Morning Briefing — 2026-07-16

**セッション**: claude/night-20260716  
**実行時間**: 2026-07-16 (自動ナイトセッション)  
**担当ブランチ**: `claude/night-20260716`

---

## 完了タスク

### Issue #29 Phase 1 — AlertDialog直書き → AppDialog統一

**概要**: `lib/core/ui/app_dialog.dart` の共通ダイアログコンポーネントを、各画面で直接 `AlertDialog` / `showDialog` を使っていた箇所に適用。

**変更ファイル一覧** (8ファイル、194行削除 → 72行):

| ファイル | 変換内容 |
|---------|---------|
| `lib/screens/profile/profile_screen.dart` | ①アップグレード案内→`showInfo` ②ログアウト確認→`showLogoutConfirm` ③車両選択→`showSelection` |
| `lib/screens/fleet/fleet_member_screen.dart` | メンバー削除確認→`showConfirm(isDestructive:true)` |
| `lib/screens/newsletter/newsletter_list_screen.dart` | 下書き削除確認→`showConfirm(isDestructive:true)` |
| `lib/screens/marketplace/case_study_management_screen.dart` | 施工事例削除確認→`showConfirm(isDestructive:true)` |
| `lib/screens/add_maintenance_screen.dart` | 変更破棄確認→`showConfirm(isDestructive:true)` |
| `lib/screens/home_screen.dart` | ①アップグレード案内→`showInfo` ②サインアウト確認→`showLogoutConfirm` |
| `lib/screens/drive/drive_log_screen.dart` | ドライブログ削除確認→`showDeleteConfirm` |
| `lib/screens/marketplace/shop_plan_screen.dart` | プランダウングレード確認→`showConfirm(isDestructive:true)` |

**スキップした箇所と理由**:
- `FilledButton`を使うダイアログ（`newsletter_list_screen.dart` の配信確認など）: AppDialog は TextButton 系のみ対応。視覚的ヒエラルキーを壊すためスキップ
- カスタムコンテンツダイアログ（TextField付き、チェックリスト付きなど）: AppDialog の API では表現不可
- テストでウィジェットキーを参照しているダイアログ（`showcase_detail_screen.dart`）: キーが消えるとテストが壊れるためスキップ

**品質確認**:
- `flutter analyze lib/`: No issues found ✅
- `flutter test --exclude-tags emulator`: 3447 tests passed ✅

**コミット**:
1. `5041405` — profile/fleet/newsletter/case_study/add_maintenance (5ファイル)
2. `3a4f518` — home_screen
3. `42cb0ab` — drive_log/shop_plan

---

## 残課題（Phase 2以降）

以下のファイルにまだ `AlertDialog` 直書きが残っている。次セッションで対応を検討:

- `lib/screens/drive/create_drive_log_screen.dart` — 破棄確認ダイアログ
- `lib/screens/fleet/fleet_screen.dart` — フリート削除確認
- `lib/screens/marketplace/inquiry_list_screen.dart` — ステータス変更（FilledButton使用のためスキップ候補）
- `lib/screens/marketplace/retired_vehicles_screen.dart` — 復元確認（FilledButton使用のためスキップ候補）
- `lib/screens/showcase/showcase_detail_screen.dart` — 通報ダイアログ（テストキー参照あり、カスタム内容のためスキップ候補）
- `lib/screens/settings/settings_screen.dart` — 表示名変更（TextField付き、AppDialog非対応）

---

## PRレビューで確認してほしい点

1. **`showDeleteConfirm` の引数**: `drive_log_screen.dart` で `itemName: 'ドライブログ'` と `message` を両方渡しているが、`showDeleteConfirm` の `message` パラメータが意図通り使われているか確認
2. **`profile_screen.dart` の `showSelection`**: 車両選択ダイアログが `SimpleDialog` から `AlertDialog`+`ListTile` スタイルに変わるが、UX上問題ないか目視確認を推奨

---

## ブロッカーなし

特になし。全テストグリーン、解析クリーン。
