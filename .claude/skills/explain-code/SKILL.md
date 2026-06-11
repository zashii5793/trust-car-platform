---
name: explain-code
description: コードをMermaid図・処理フロー・実世界アナロジーで自動ドキュメント化する。「このコード説明して」「図にして」「ドキュメント化して」「アーキテクチャ説明して」などのキーワードで起動。
---

# explain-code

## 役割

指定されたコードやファイルを読み解き、以下の形式でドキュメント化する。

## 出力フォーマット

### 1. 概要（1〜2文）
何をするコードか一言で説明する。

### 2. Mermaid 図

クラス図・シーケンス図・フローチャートのうち最も適切なものを選ぶ。

```mermaid
graph TD / sequenceDiagram / classDiagram
```

### 3. 処理フロー（箇条書き）

主要な処理を番号付きで説明する。
- 入力値と出力値を明示
- 条件分岐・エラーハンドリングのポイントを記載

### 4. 実世界アナロジー

技術的でない言葉で例える（例:「このProviderはコンビニの在庫管理システムのようなもので...」）

### 5. 注意点・拡張ポイント

- 既知の制約
- 変更時に影響を受ける箇所
- 改善余地のある部分

## このプロジェクト固有の説明パターン

### Provider の説明
```
Provider = UIとServiceの橋渡し役
- initState / listenTo でデータ取得開始
- notifyListeners() でUIに更新通知
- Result<T, AppError> でエラーを型安全に処理
```

### Service の説明
```
Service = Firestoreとの直接通信窓口
- すべてのメソッドが Result<T, AppError> を返す
- エラーは AppError に変換して上位に伝える
```

### Screen の説明
```
Screen = UIの描画のみ担当
- Provider を Consumer/context.watch で購読
- ビジネスロジックは持たない
```
