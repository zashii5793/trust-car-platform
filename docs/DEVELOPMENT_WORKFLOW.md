# 開発ワークフロー

## 責務分離パイプライン

各タスクは以下のフェーズを順に通過する:

```
1. コンテキスト収集 → 2. 計画・設計 → 3. 実装 → 4. レビュー → 5. QA
```

### フェーズ詳細

#### 1. コンテキスト収集
- `CLAUDE_SESSION_NOTES.md` で現在の状態確認
- `docs/FEATURE_SPEC.md` で仕様確認
- 関連コードをGrep/Readで最小限に収集

#### 2. 計画・設計
- TodoWriteで作業項目を洗い出し
- 協業レベルに応じてユーザーに確認
- Agreeレベル以上は必ず計画を提示してから実装

#### 3. 実装
- コーディング規約に従う（CLAUDE.md参照）
- 小さなコミット単位で進行
- 既存パターンに合わせる

#### 4. レビュー
- `flutter analyze` クリーン確認
- 否定形ルールチェック:
  - Service層でtry-catchを使わずResultを返しているか
  - Provider層でAppErrorを適切にハンドリングしているか
  - UIで日本語テキストが使われているか

#### 5. QA
- `flutter test` 全パス確認
- 新機能には対応テスト追加
- 回帰テストで既存機能の破壊がないことを確認

---

## コミットルール

```
<type>: <概要（日本語可）>

type:
  feat:     新機能
  fix:      バグ修正
  refactor: リファクタリング
  test:     テスト追加・修正
  docs:     ドキュメント
  chore:    設定・CI等
```

---

## セッション管理

### セッション開始時
1. `CLAUDE_SESSION_NOTES.md` を読む
2. 前回の状態と次回やることを確認
3. TodoWriteで本セッションのタスクを設定

### セッション終了時
1. `CLAUDE_SESSION_NOTES.md` を更新
2. 未完了タスクを記録
3. 品質スコアを更新

---

## ファイル構成ガイド

### 新しいモデル追加時
```
lib/models/<model_name>.dart
test/models/<model_name>_test.dart
```

### 新しい画面追加時
```
lib/screens/<screen_name>_screen.dart
lib/providers/<feature>_provider.dart（必要に応じて）
```

### 新しいサービス追加時
```
lib/services/<service_name>.dart        # Result<T, AppError>を返す
test/services/<service_name>_test.dart
```

---

## 品質基準

| 項目 | 基準 |
|------|------|
| テスト | 全パス、新機能にはテスト追加 |
| 静的解析 | 警告0 |
| エラーハンドリング | Result<T, AppError>統一 |
| バリデーション | 入力境界でチェック |
| 型安全 | dynamic禁止、sealed class活用 |
