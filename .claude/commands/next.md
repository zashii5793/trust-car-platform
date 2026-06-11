GitHub ProjectsカンバンとオープンIssueを確認し、次に着手すべきタスクを1つ提案してください。

手順:
1. 以下を実行してProjectカンバンの状態を取得する:
   ```bash
   gh project item-list 1 --owner zashii5793 --format json
   ```
2. Readyステータスのアイテムを抽出する（なければBacklogから候補を提示）
3. priority:high ラベルのIssueを優先しつつ、依存関係・実装順序を考慮して最優先の1件を選ぶ
4. 選んだタスクの概要・受け入れ条件・推定難易度を日本語で提示する
5. 作業開始コメントをIssueに投稿するか、ステータスをIn Progressに変更するか確認する

注意:
- PROJECT_NUMBER は 1（作成後に更新される場合はCLAUDE.mdを参照）
- OWNER は zashii5793
- 提案は必ず1件に絞る（複数候補がある場合はトップ3を列挙した上で最優先を推奨）
