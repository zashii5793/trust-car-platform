# Trust Car Platform

Flutter製車両管理アプリ。Firebase（Auth, Firestore, Storage）バックエンド。

## 基本方針

- 必ず日本語で応対してください
- 調査・デバッグには**サブエージェント**を使いコンテキストを節約してください
- 重要な決定は `CLAUDE_SESSION_NOTES.md` に記録してください
- **計画→テスト→実装**の順序を厳守してください
- **タスク完了後は次のアクション候補を3つ提案してください**

## 禁止事項（絶対厳守）

以下は取り返しのつかない操作のため、明示的に許可されない限り実行禁止：

- `git push origin main` / `main` ブランチへの直接push禁止（必ず `claude/` ブランチ経由）
- `git reset --hard` / `git push --force` の無断実行禁止
- `firebase_options.dart` の無断書き換え禁止（APIキー・Bundle IDが含まれる）
- Firebase Console・Firestore への直接データ操作禁止
- `.env` ファイル・`*.keystore` ファイルの編集・削除禁止
- `google-services.json` / `GoogleService-Info.plist` のコミット禁止（`.gitignore` 対象）
- シークレット・APIキーをコードにハードコード禁止（必ず環境変数経由）

## セッション開始時（必須チェック）

```bash
gh issue list --label "claude-task" --state open
gh project item-list 1 --owner zashii5793 --format json
```

Issueがある場合: `priority: high` を優先 → 作業開始コメント → EnterPlanMode → 実装 → PR作成
Issueがない場合: `/next` コマンドで次タスクを提案

## コマンド早見表

```bash
# テスト（全件）
flutter test --exclude-tags emulator 2>&1 | tail -5

# テスト（特定ファイル）
flutter test test/services/post_service_test.dart

# 静的解析
flutter analyze lib/

# デバッグビルド（Emulator接続）
flutter run                          # kDebugMode=true → エミュレーターに自動接続

# リリースビルド ⚠️ 本番Firebase接続・要確認
flutter build apk --release          # Android
flutter build ios --release          # iOS（Mac必要・要確認）

# Firebase Emulator起動（ローカル開発）
firebase emulators:start --only auth,firestore

# Firestoreルール・インデックスデプロイ ⚠️ 本番反映・要確認
firebase deploy --only firestore:rules,firestore:indexes
```

## アーキテクチャ方針（変更禁止）

```
main.dart → Injection.init() → ServiceLocator
                                    ↓
Provider（コンストラクタ注入） ← Service（Result<T,AppError>）
    ↓                                ↓
  UI層（screens/）              Firebase SDK
```

- **Service層が正**: `lib/services/` にFirebase操作を集約
- **domain/data層は存在しない**: 再作成禁止
- **DIはServiceLocator**: Provider内で `new` 禁止
- **新Service追加時**: `injection.dart` に登録 → Providerのコンストラクタで受け取る

## コーディング規約

- **エラーハンドリング**: Service層は必ず `Result<T, AppError>` パターンを使う
- **状態管理**: Provider（コンストラクタでService注入）
- **言語**: UIテキストは日本語、コード・コメントは英語

## セキュリティ方針

- APIキー・パスワード・トークンはコードに直書き禁止（環境変数または GitHub Secrets）
- `firebase_options.dart` の値は公開設定だが、意図せず変更しない
- Firestoreルールは必ず `firestore.rules` で管理し、Console直接編集しない
- 新しいコレクション追加時は必ずセキュリティルールを同時に定義する

## TDDルール（必須）

**RED → GREEN → REFACTOR** サイクル厳守。いきなりGREENから始めない。

新しいServiceメソッド追加時の必須エッジケース:

| カテゴリ | テスト例 |
|---------|---------|
| 空値・null | `''`、null、`[]` |
| 境界値 | `0`、`-1`、`int.maxFinite` |
| 存在しないID | 削除済みリソース、不正ID形式 |
| 権限違反 | 他ユーザーのリソース操作 |

各グループに `group('Edge Cases', ...)` を追加する。

承認フロー: 計画提示 → **`y`** で承認 → 実装開始。承認前の実装開始禁止。

## Gitコミットルール

```
<type>: <short description>

Co-Authored-By: Claude <noreply@anthropic.com>
```

type: `feat` / `fix` / `test` / `docs` / `refactor` / `perf` / `ci`

## GitHub Issue/PRワークフロー

### Issueラベル規則

| ラベル | 用途 |
|--------|------|
| `bug` | 不具合修正 |
| `enhancement` | 新機能・改善 |
| `test` | テスト追加のみ |
| `docs` | ドキュメントのみ |
| `claude-task` | AIセッションで対応するタスク |
| `priority: high` | 今週中に対応必須 |
| `pm-report` | 週次PMレポート（自動生成） |

### Issue作成テンプレート

```bash
gh issue create \
  --title "feat: <機能名>" \
  --body "## 目的\n\n## 実装方針\n\n## チェックリスト\n- [ ] RED確認\n- [ ] 実装\n- [ ] flutter analyze\n- [ ] flutter test" \
  --label "enhancement,claude-task"
```

### PR作成

```bash
gh pr create --title "feat: <機能名>" --body "Closes #<番号>" --base main
```

## 効率化ルール

| エージェント | 用途 |
|-------------|------|
| **Explore** | コードベース探索・キーワード検索 |
| **Plan** | 設計方針策定・トレードオフ分析 |

- `Read`: offset/limitで必要な行だけ読む
- `Grep`: まず `files_with_matches` でファイル特定してから内容確認

## 協業レベル

| レベル | 対象 | 進め方 |
|--------|------|--------|
| **Delegate** | テスト・バグ修正・リファクタ | AI単独→PRレビュー |
| **Inquire** | 新機能・画面追加 | AI実装→人間レビュー |
| **Agree** | アーキテクチャ・DB設計変更 | 計画合意→段階実装 |
| **Consult** | 要件定義・優先順位 | 人間主導・AI助言 |

## 品質チェック（Phase完了時）

- [ ] `flutter test --exclude-tags emulator` 全件パス
- [ ] `flutter analyze lib/` クリーン
- [ ] Provider内で直接 `new` していない
- [ ] `CLAUDE_SESSION_NOTES.md` に進捗記録

## コンテキスト参照先

| 目的 | 参照先 |
|------|--------|
| 機能仕様 | `docs/FEATURE_SPEC.md` |
| セッション状態 | `CLAUDE_SESSION_NOTES.md` |
| 保守・運用手順 | `docs/MAINTENANCE_RUNBOOK.md` |
| 人間タスク一覧 | `docs/HUMAN_TASKS.md` |

## GitHub Projects / MCP

**Project**: `github.com/users/zashii5793/projects/1`（Backlog→Ready→In Progress→Done）

スラッシュコマンド:
- `/next` — 次に着手すべきタスクを1件提案
- `/minutes <テキスト>` — 議事録からIssue自動作成

MCP（有効な場合）: Context7（最新ドキュメント）/ Playwright（E2E）/ GitHub / Sentry
