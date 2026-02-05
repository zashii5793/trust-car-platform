# Trust Car Platform

Flutter製車両管理アプリ。Firebase（Auth, Firestore, Storage）バックエンド。

## コンテキスト（段階的に参照）

| 目的 | 参照先 |
|------|--------|
| 機能仕様・要望リスト | `docs/FEATURE_SPEC.md` |
| 開発ワークフロー | `docs/DEVELOPMENT_WORKFLOW.md` |
| セッション状態 | `CLAUDE_SESSION_NOTES.md` |

## コーディング規約（必須）

- **エラーハンドリング**: `Result<T, AppError>` パターン（Service層）
- **状態管理**: Provider
- **テスト**: 変更時は必ずテスト実行、191件全パス維持
- **静的解析**: `flutter analyze` クリーン維持
- **言語**: UIテキストは日本語、コード・コメントは英語

## 効率化ルール

- `Read`: offset/limitで必要な行だけ
- `Grep`: まず `files_with_matches` でファイル特定
- テスト: `flutter test 2>&1 | tail -5`
- 大規模探索はExploreエージェント使用

## 協業レベル（タスク別）

| レベル | 対象タスク | 進め方 |
|--------|-----------|--------|
| **Delegate** | テスト追加、バグ修正、リファクタ | AI単独→PRレビュー |
| **Inquire** | 新機能実装、画面追加 | AI実装→人間レビュー |
| **Agree** | アーキテクチャ変更、DB設計 | 計画合意→段階実装 |
| **Consult** | 要件定義、優先順位決定 | 人間主導、AI助言 |
