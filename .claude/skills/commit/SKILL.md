---
name: commit
description: git差分を解析してConventional Commits形式のコミットメッセージを自動生成しコミットする。「コミットして」「commitして」「変更を保存して」などのキーワードで起動。明示的に依頼された場合のみコミットを実行する。
---

# commit

## 役割

ステージされた変更またはワーキングツリーの差分を解析し、
このプロジェクトのルールに沿ったコミットメッセージを生成してコミットする。

## 手順

1. `git status` で変更ファイルを確認
2. `git diff` / `git diff --staged` で差分を確認
3. `git log --oneline -5` で直近のコミットスタイルを確認
4. 適切なファイルを `git add` でステージ（以下は除外）
   - `.claude/settings.local.json`
   - `macos/Podfile.lock`
   - `*.keystore`
   - `google-services.json` / `GoogleService-Info.plist`
5. コミットメッセージを生成してコミット
6. `git push origin <現在のブランチ>` を実行

## コミットメッセージ形式

```
<type>: <日本語で変更内容を簡潔に>

<任意: 詳細説明>

Co-Authored-By: Claude <noreply@anthropic.com>
```

### type 一覧

| type | 用途 |
|------|------|
| `feat` | 新機能追加 |
| `fix` | バグ修正 |
| `test` | テスト追加・修正 |
| `docs` | ドキュメントのみ |
| `refactor` | リファクタリング |
| `perf` | パフォーマンス改善 |
| `ci` | CI設定変更 |

## 禁止事項

- `git push origin main` の直接実行（必ず `claude/` ブランチ経由）
- `.env` / `*.keystore` / `google-services.json` のコミット
- `--no-verify` フラグの使用
- 明示的に依頼されていない場合のコミット実行
