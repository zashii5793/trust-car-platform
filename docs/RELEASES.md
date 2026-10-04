# 本番への反映の記録（デプロイ台帳）

**本番（Firebase `trust-car-platform`・ストア）に何を・いつ・どのコミットから入れたかを、1回1行で残す。**

## なぜ要るか

2026-09-30 に、**ウェブ版が 2026-08-24 から5週間、古いまま公開されていた**ことが分かった。
main には顧客台帳などが入っていたのに、ウェブ版には入っておらず、店主に言われるまで誰も気づかなかった。
同じ時期、Cloud Functions も本番に1つも無く、退会後のデータ削除が動いていなかった。

どちらも「main に入った ＝ 本番に出た」と思い込める状態だったのが原因。
**この台帳で「いま本番に何が出ているか」を記録から答えられるようにする。**
（`docs/MAINTENANCE_OPS_REVIEW_2026-09-30.md` 項目11）

## 書き方

- **本番に何かを入れたら、その日のうちに一番上へ1行足す。** AI が入れたときは AI が足す
- 「コミット」は、反映したときの `git rev-parse --short HEAD`
- 反映したのに台帳に無いものを見つけたら、分かる範囲で足し、「後から記録」と書く

| 対象 | 反映のしかた |
| --- | --- |
| ウェブ | `./scripts/deploy_web.sh`（= `flutter build web --release` → `firebase deploy --only hosting`） |
| Functions | `firebase deploy --only functions` |
| ルール・索引 | `firebase deploy --only firestore:rules,firestore:indexes`（先に `cd test/rules && npm test`） |
| Storage のルール | `firebase deploy --only storage` |
| Remote Config | `firebase deploy --only remoteconfig`（`remoteconfig.template.json`） |
| Android / iOS | ストアへの提出（まだ一度も無い） |

## 今どこに何が出ているか（2026-10-04 時点）

| 対象 | 本番の版 | 反映日 |
| --- | --- | --- |
| ウェブ | `64c6271f` | 2026-10-02 |
| Functions（15個） | `e4afce51`（`opsHealthCheck` だけ `d5c9c19c`） | 2026-10-04 |
| Firestore のルール | `e4afce51` | 2026-10-02 |
| Firestore の索引・TTL | `d5c9c19c` | 2026-10-04 |
| Storage のルール | 不明（後から記録） | 2026-09-06 |
| Remote Config | `4b01c936`（5フラグとも `false`） | 2026-10-01 |
| Android / iOS | 未公開 | — |

## 記録（新しい順）

| 日付 | 対象 | コミット | 内容 | 誰 |
| --- | --- | --- | --- | --- |
| 2026-10-04 | Firestore の TTL | `d5c9c19c` | `client_errors`（90日）・`ops_health_history`（30日）・`ops_reports`（180日）の `expireAt` に TTL。本番の設定で3つとも有効を確認 | AI |
| 2026-10-04 | Functions（`opsHealthCheck`） | `d5c9c19c` | 記録が無いまま 48 時間を過ぎた定期ジョブを NG にする（起点は次の実行から） | AI |
| 2026-10-02 | Functions | `e4afce51` | **15個**（新規8：`onPlanRequestCreated`・`onInspectionNoticeCreated`・`unsubscribeNewsletter`・`onMaintenanceRecordWritten`・`onVehicleWrittenForFleetSummary`・`opsHealthCheck`・`opsHealth`・`opsDailyReport`／更新7）。`OPERATOR_EMAIL` を設定後。再試行の設定があるため `--force`（本番の関数はすべてコードにあることを確かめてから） | AI |
| 2026-10-02 | Firestore のルール・索引 | `e4afce51` | `ops_*` の読み書き禁止、滞留を数える collectionGroup の索引3つ（ルールのテスト 443件・Functions 303件パス後） | AI |
| 2026-10-02 | Firestore（復元の練習） | — | 2026-10-01T14:41Z のバックアップを新しい DB `restore-drill-20261002` に復元。Console で本番と同じコレクション・文書が戻っていることを確認（手順書 §0-6 が通る）。確認後、削除保護を外して削除した（本番の `(default)` の削除保護・PITR は有効のまま） | AI |
| 2026-10-02 | ウェブ | `64c6271f` | PR #237〜#245 を反映（地図・維持費の比較・明細のまとめ送り・車検案内のプッシュの画面・店 ID の切り離し段階1 ほか）。見張りで main と差なしを確認 | AI |
| 2026-10-02 | Firestore のルール | `64c6271f` | 法人の整備集計・車検案内の依頼・FCM トークン・店の自動 ID・スポットの読み方など（ルールのテスト 427件パス後） | AI |
| 2026-10-02 | Functions | — | **出せていない。** `OPERATOR_EMAIL`（#235）を宣言しているため、どの関数を出すときも値が要る。値が入るまで、車検案内のプッシュ・法人の整備集計・配信停止・申し込みメールは本番で動かない | — |
| 2026-10-01 | GitHub（main） | — | ブランチ保護：PR 必須（承認0）・CI 4つ必須（Analyze & Test／Rules／Functions／Build Android）・force push と削除を禁止 | AI |
| 2026-10-01 | Firestore（DB 設定） | — | 削除保護を有効、Point-in-Time Recovery を有効（最古の復元点 2026-10-01T00:52Z） | AI |
| 2026-10-01 | ウェブ | `4b01c936` | PR #224〜#233 を反映。請求書払いの申し込み・台帳の CSV 書き出し・最初の7日の記録・ウェブのエラー収集。版の目印 `build_info.json` が付いた（見張りで main と差なしを確認） | AI |
| 2026-10-01 | Remote Config | `4b01c936` | `shop_in_app_purchase`（false）を追加 | AI |
| 2026-10-01 | Firestore のルール | `4b01c936` | **店主が `planType` を書き換えて支払いなしで有料になれた穴を塞いだ**（#232）・`plan_requests`・`client_errors`・台帳の案内日（ルールのテスト 340件パス後） | AI |
| 2026-09-30 | ウェブ | `562a0155` | 8/24 以来の再公開。顧客台帳・メーカーのロゴ・輸入車20社・店舗プランの料金（9,800円 / 29,800円 / 個別見積もり）・特商法の更新 | AI |
| 2026-09-30 | Functions（ビルドイメージ） | — | `asia-northeast1` に自動削除のポリシー（1日）を設定 | AI |
| 2026-09-30 | Functions | `0dc5ce50` | 初めての本格デプロイ。`purgeDeletedAccounts`・`purgeExpiredShares`・`askCarAi`・`onRevenueCatWebhook`・`onNewsletterSend`・`onCommentReportCreated` を新規作成（後の2つは権限の反映待ちで1回失敗し、約5分後に再デプロイで成功）。`aggregateModelCosts` は既にあったため変更なし | AI |
| 2026-09-30 | Firebase（Android アプリ） | — | リリース鍵の SHA-1 / SHA-256 を登録。Android 用の OAuth クライアントができた | AI |
| 2026-09-29 | Firestore のルール・索引 | `e3478bca` | 店の顧客台帳・操作の記録・店主の引き継ぎ・工場から受け取った記録の改ざん防止（ルールのテスト 290件パス後） | AI |
| 2026-09-29〜30 | Functions | 不明 | `aggregateModelCosts` が作成されていた（9/29 朝の実測では Functions 0個。誰がいつ入れたかは記録が無い・後から記録） | 不明 |
| 2026-09-06 | Storage のルール | 不明 | 写真のアップロードのルール（後から記録） | 不明 |
| 2026-09-03 | Firestore のルール・索引 | 不明 | 前回のルール（後から記録） | 不明 |
| 2026-09-03 | Remote Config | 不明 | `c2c_parts_marketplace` などのフラグを作成（後から記録） | 不明 |
| 2026-09-03 | Firestore のバックアップ | — | 毎日・30日保持のスケジュールを作成（後から記録） | 不明 |
| 2026-08-24 | ウェブ | 不明 | 前回の公開（後から記録） | 不明 |
