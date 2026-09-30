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

## 今どこに何が出ているか（2026-09-30 時点）

| 対象 | 本番の版 | 反映日 |
| --- | --- | --- |
| ウェブ | `562a0155` | 2026-09-30 |
| Functions（7つ） | `0dc5ce50` | 2026-09-30 |
| Firestore のルール・索引 | `e3478bca` | 2026-09-29 |
| Storage のルール | 不明（後から記録） | 2026-09-06 |
| Remote Config | テンプレートと一致（4フラグとも `false`） | 2026-09-03 |
| Android / iOS | 未公開 | — |

## 記録（新しい順）

| 日付 | 対象 | コミット | 内容 | 誰 |
| --- | --- | --- | --- | --- |
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
