# Trust Car Platform

Flutter製車両管理アプリ。Firebase（Auth, Firestore, Storage）バックエンド。

## 基本方針

- 必ず日本語で応対してください
- 調査やデバッグには**サブエージェント**を活用してコンテキストを節約してください
- 重要な決定事項は `CLAUDE_SESSION_NOTES.md` に記録してください
- いきなりコードを書かず、**計画→テスト→実装**の順序を意識してください

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
- **テスト**: 変更時は必ずテスト実行、全件パス維持
- **静的解析**: `flutter analyze` クリーン維持
- **言語**: UIテキストは日本語、コード・コメントは英語

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
