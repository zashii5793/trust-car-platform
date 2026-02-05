# Trust Car Platform

Flutter製車両管理アプリ。Firebase（Auth, Firestore, Storage）バックエンド。

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
- **テスト**: 変更時は必ずテスト実行、214件全パス維持
- **静的解析**: `flutter analyze` クリーン維持
- **言語**: UIテキストは日本語、コード・コメントは英語

## 効率化ルール

- `Read`: offset/limitで必要な行だけ
- `Grep`: まず `files_with_matches` でファイル特定
- テスト: `flutter test 2>&1 | grep -oE '\+[0-9]+' | sort -t+ -k2 -n | tail -1`
- 大規模探索はExploreエージェント使用

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
