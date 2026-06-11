以下の議事録テキストからアクションアイテムを抽出し、GitHub Issueを作成してProjectカンバン（Backlog）に追加してください。

$ARGUMENTS

## 処理手順

### 1. アクションアイテムの抽出
議事録から以下を日本語で識別する:
- **やること / TODO / 宿題** → Issue化する
- **決定事項** → 関連IssueのコメントまたはCLAUDE_SESSION_NOTES.mdに記録
- **継続検討** → Backlogとして追加

### 2. Issue作成（各アクションアイテムごと）
```bash
gh issue create \
  --title "<アクションアイテムのタイトル>" \
  --body "## 背景\n<議事録から抽出した文脈>\n\n## やること\n- [ ] <具体的なタスク>\n\n## 出典\n議事録（$(date '+%Y-%m-%d')）" \
  --label "enhancement"
```

### 3. ProjectカンバンのBacklogに追加
```bash
gh project item-add 1 --owner zashii5793 --url <issue-url>
```

### 4. 結果報告
- 作成したIssue一覧（番号・タイトル・URL）を箇条書きで表示
- カンバンへの追加結果を確認

## 注意事項
- PROJECT_NUMBER は 1（変更時はCLAUDE.mdを参照）
- Issueタイトルは「動詞+名詞」形式（例: 「タイムライン画面にフィルター機能を追加」）
- 1つの議事録から最大10件まで。それ以上は優先度の高いものを選択してユーザーに確認
- 担当者の指定は省略（ユーザーが後から割り当て）
