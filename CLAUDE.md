# Trust Car Platform

Flutter製車両管理アプリ。Firebase（Auth, Firestore, Storage）バックエンド。

## 基本方針

- 必ず日本語で応対してください
- 調査やデバッグには**サブエージェント**を活用してコンテキストを節約してください
- 重要な決定事項は `CLAUDE_SESSION_NOTES.md` に記録してください
- いきなりコードを書かず、**計画→テスト→実装**の順序を意識してください

## セッション開始時（必須チェック）

**新しいセッションを始める前に、必ず以下を確認する：**

```bash
# オープンなClaudeタスクIssueを確認
gh issue list --label "claude-task" --state open

# Issueがある場合 → 詳細を読む
gh issue view <番号> --comments
```

Issueがある場合の対応手順：
1. `priority: high` ラベルのIssueを優先して選ぶ
2. Issue内容（やること・受け入れ条件）を把握する
3. 作業開始をコメントで宣言する：
   ```bash
   gh issue comment <番号> --body "作業を開始します。設計後に実装します。"
   ```
4. EnterPlanMode → 実装 → テスト
5. 完了時にPRを作成してIssueを参照する：
   ```bash
   gh pr create --title "feat: <タスク名>" --body "Closes #<番号>"
   ```

Issueがない場合 → ユーザーの指示を待つ。

## アーキテクチャ方針（最重要 - 必ず従う）

```
main.dart → Injection.init() → ServiceLocator
                                    ↓
Provider（コンストラクタ注入） ← Service（Result<T,AppError>）
    ↓                                ↓
  UI層（screens/）              Firebase SDK
```

- **Service層が正**: `lib/services/` にFirebase操作を集約
- **domain/data層は存在しない**: 過去に削除済み。DDD層を新たに作らない
- **DIはServiceLocator**: Provider内で`new`せず、コンストラクタ注入を使う
- **新しいServiceを追加する場合**: `injection.dart`に登録し、Providerのコンストラクタで受け取る

## コンテキスト（段階的に参照）

| 目的 | 参照先 |
|------|--------|
| 機能仕様・要望リスト | `docs/FEATURE_SPEC.md` |
| 開発ワークフロー | `docs/DEVELOPMENT_WORKFLOW.md` |
| セッション状態 | `CLAUDE_SESSION_NOTES.md` |
| AI開発レポート | `docs/REPORT_AI_DEV_STATUS.md` |

## コーディング規約（必須）

- **エラーハンドリング**: `Result<T, AppError>` パターン（Service層）
- **状態管理**: Provider（コンストラクタでService注入）
- **DI**: `ServiceLocator` 経由。Provider内で直接`new`しない
- **テスト**: 変更時は必ずテスト実行、全件パス維持（TDDルール参照）
- **静的解析**: `flutter analyze` クリーン維持
- **言語**: UIテキストは日本語、コード・コメントは英語

## TDDルール（必須）

### RED → GREEN → REFACTOR サイクル

1. **RED** — 失敗するテストを先に書く（実装前に `flutter test` が赤になることを確認）
2. **GREEN** — テストが通る最小限の実装を書く
3. **REFACTOR** — テストを維持しながらコードを整理する

**サイクルの省略禁止**: いきなりGREENから始めない。REDを確認してから実装する。

### エッジケーステスト（必須項目）

新しいServiceメソッドやロジックを追加する際は、以下のエッジケースを必ずテストに含める：

| カテゴリ | テスト例 |
|---------|---------|
| 空値・null | 空文字 `''`、null、空リスト `[]` を渡したときの挙動 |
| 境界値 | 0値、負数（`-1`）、最大値（`int.maxFinite`）、範囲上限の超過 |
| 超長文字 | 10,000文字を超えるテキスト入力 |
| 矛盾状態 | `endDate < startDate`、`rating: 0`（有効範囲外）など |
| 存在しないID | 削除済みリソースへのアクセス、不正なID形式 |
| 権限違反 | 他ユーザーのリソースへの操作（permission errorを期待） |

各テストグループに `group('Edge Cases', ...)` を追加する形で整理する。

### 承認フロー

- Claudeが計画・変更案を提示したとき、承認は **`y`** のみでOK
- NOの場合は曖昧にせず**具体的な対案**を提示すること（「〜ではなく〜にしてほしい」）
- 承認なしに実装を開始しない（EnterPlanMode→承認→実装の順序を厳守）

## Gitコミットルール（重要）

- **改修前にコミット**: 新しい改修を始める前に、現在の変更をコミットする
- **小さな単位でコミット**: 1つの機能・修正ごとにコミット
- **コミットメッセージ形式**:
  ```
  <type>: <short description>

  [optional body]

  Co-Authored-By: Claude <noreply@anthropic.com>
  ```
- **type**: feat, fix, test, docs, refactor, perf, ci
- **プッシュ**: コミット後は必ず `git push origin main`

## GitHub Issue/PRワークフロー（セッション引き継ぎ）

### 作業開始時（必須）

新しい機能・修正を始めるとき、最初にIssueを作成してセッションのコンテキストを記録する：

```bash
# Issue作成（作業開始前）
gh issue create \
  --title "feat: <機能名>" \
  --body "## 目的\n<何をなぜ変えるか>\n\n## 実装方針\n<設計メモ>\n\n## チェックリスト\n- [ ] テスト作成（RED確認済み）\n- [ ] 実装\n- [ ] flutter analyze\n- [ ] flutter test" \
  --label "enhancement"
```

### セッション引き継ぎ（コンテキスト復元）

新しいセッションで前回の作業を再開するとき：

```bash
# 前回のIssueとPRを確認
gh issue list --state open
gh pr list --state open

# 特定IssueのコメントでコンテキストをAIが読む
gh issue view <番号> --comments
```

### 作業完了時

```bash
# PR作成
gh pr create \
  --title "feat: <機能名>" \
  --body "## 概要\n- <変更内容>\n\n## テスト\n- [ ] 単体テスト追加\n- [ ] エッジケース確認\n- [ ] flutter analyze クリーン\n\nCloses #<issue番号>" \
  --base main

# IssueにAI作業ログを残す（次セッション引き継ぎ用）
gh issue comment <番号> --body "## セッション記録 $(date '+%Y-%m-%d')\n\n### 完了\n- <完了したこと>\n\n### 次のセッションで継続\n- <未完了タスク>\n\n### 重要な判断事項\n- <設計上の決定記録>"
```

## AIクロスレビュー（オプション）

Claudeのレビューに加えて外部AIツールでのセカンドオピニオンを取得できる：

```bash
# Codex CLI使用可能な場合（要: npm install -g @openai/codex）
codex "Review this Flutter service for bugs and edge cases" < lib/services/post_service.dart

# GitHub Copilot CLI使用可能な場合
gh copilot suggest "What edge cases am I missing in this Dart code?"
```

注意: クロスレビューはオプション。必須ではない。

## 効率化ルール（コンテキスト節約）

### サブエージェントの活用（重要）

調査・探索タスクはサブエージェントに委任し、要約だけメインセッションに返す：

| エージェント | 用途 | 使用例 |
|-------------|------|--------|
| **Explore** | コードベース探索 | ファイル検索、キーワード検索、アーキテクチャ調査 |
| **Plan** | 実装計画 | 設計方針の策定、トレードオフ分析 |
| **Bash** | コマンド実行 | git操作、ビルド、テスト実行 |

```
# 悪い例：メインセッションで大量のGrepを繰り返す
# 良い例：Exploreエージェントに「認証フローを調査して」と依頼

# 悪い例：複雑な実装にいきなり着手
# 良い例：Planエージェントで設計を固めてから実装
```

### ツール使用の最適化

- `Read`: offset/limitで必要な行だけ
- `Grep`: まず `files_with_matches` でファイル特定
- テスト結果確認: `flutter test 2>&1 | tail -10`
- 並列可能なタスクは**同時に実行**

## 開発ワークフロー

### 計画→テスト→実装の順序

1. **ブレインストーミング** — いきなりコードを書かず、要件を対話で深掘り
2. **設計・計画** — PlanエージェントまたはEnterPlanModeで設計を固める
3. **テスト作成** — TDD：先にテストを書く
4. **実装** — テストが通るように実装
5. **レビュー・検証** — flutter analyze + flutter test

### 非自明なタスクの進め方

```
ユーザー要求
    ↓
EnterPlanMode（計画モード）
    ↓
Explore/Planエージェントで調査
    ↓
実装計画をExitPlanModeで提示
    ↓
ユーザー承認
    ↓
実装（TodoWriteで進捗管理）
    ↓
テスト・検証
    ↓
コミット・プッシュ
```

## 協業レベル（タスク別）

| レベル | 対象タスク | 進め方 |
|--------|-----------|--------|
| **Delegate** | テスト追加、バグ修正、リファクタ | AI単独→PRレビュー |
| **Inquire** | 新機能実装、画面追加 | AI実装→人間レビュー |
| **Agree** | アーキテクチャ変更、DB設計 | 計画合意→段階実装 |
| **Consult** | 要件定義、優先順位決定 | 人間主導、AI助言 |

## 品質チェック（各Phase完了時）

- [ ] テスト層別カバレッジ確認（core/models/services/providers/screens）
- [ ] `flutter analyze` クリーン
- [ ] DI使用（Provider内で直接`new`していないか）
- [ ] 死んだコードがないか
- [ ] `CLAUDE_SESSION_NOTES.md` に進捗を記録

## MCP連携（利用可能な場合）

プロジェクトで有効なMCPサーバーがある場合は積極的に活用：

| MCP | 用途 |
|-----|------|
| **Context7** | Flutter/Firebase等の最新ドキュメント参照 |
| **Playwright** | E2Eテスト自動化、スクリーンショット |
| **GitHub** | PR作成、Issue管理 |
| **Sentry** | エラー監視・分析 |
