# Cloud Functions が本番に1つも無い（P0）

**作成**: 2026-09-06
**状態**: **未デプロイ。`firebase functions:list` の結果が `No functions found`。**

```
$ firebase functions:list
No functions found in project trust-car-platform.
```

---

## 何が動いていないか

| 関数 | 役割 | 動かないと何が起きるか |
|---|---|---|
| `purgeDeletedAccounts` | 退会後のデータ削除（日次） | **プライバシーポリシーに書いた削除が実行されない。** 退会マーカーだけが書かれ、車両・整備記録・投稿は残り続ける |
| `askCarAi` | AIチャットの応答 | アプリのAIチャットが使えない |
| `onRevenueCatWebhook` | 課金状態の同期 | ストアで課金・解約されてもアプリ側のプランが変わらない |
| `onCommentReportCreated` | 通報が閾値を超えたコメントを隠す | 通報しても何も起きない |
| `onNewsletterSend` | ニュースレター配信 | 配信されない |

**いちばん重いのは `purgeDeletedAccounts` です。** 規約（`web/privacy.html` 第9章）
に「退会手続きの完了時に削除します」と書いてあるのに、**削除する仕組みが本番に
ありません。**

## なぜデプロイできないか

`firebase deploy --only functions` が Secret Manager で止まります。

```
Error: Request to https://secretmanager.googleapis.com/v1/projects/
trust-car-platform/secrets/SENDGRID_API_KEY had HTTP Error: 403,
Secret Manager API has not been used in project trust-car-platform
before or it is disabled.
```

**関数を1つに絞っても同じです**（`--only functions:purgeDeletedAccounts` でも、
ソース解析の時点で全関数の `defineSecret` が評価されるため）。

要求されているシークレットは3つ:

| シークレット | 使う関数 | 値の入手先 |
|---|---|---|
| `ANTHROPIC_API_KEY` | `askCarAi` | [Anthropic Console](https://console.anthropic.com/) |
| `SENDGRID_API_KEY` | `onNewsletterSend` | SendGrid のダッシュボード |
| `REVENUECAT_WEBHOOK_SECRET` | `onRevenueCatWebhook` | RevenueCat の Webhook 設定（P1-7 と同時） |

---

## 手順

### 1. Secret Manager API を有効化する

**AI からはできません**（`gcloud` が開発機に無く、firebase CLI にも API を
有効化するコマンドがありません）。

https://console.developers.google.com/apis/api/secretmanager.googleapis.com/overview?project=trust-car-platform

「有効にする」を押すだけです。反映に数分かかることがあります。

### 2. シークレットを設定する

```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set SENDGRID_API_KEY
firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET
```

対話式で値を貼り付けます。**3つとも設定しないとデプロイが通りません。**

まだ値が無いもの（SendGrid の契約前など）は、**ダミー値を入れておけば
デプロイは通ります**（その関数だけ動かない状態になります）。
本番で使う前に必ず本物へ差し替えてください。

### 3. デプロイ

```bash
firebase deploy --only functions
```

初回は Artifact Registry / Cloud Build の API 有効化が走るので数分かかります。

### 4. 確認

```bash
firebase functions:list                                  # 5つ出るはず
firebase functions:log --only purgeDeletedAccounts       # 翌日以降
```

`purgeDeletedAccounts` は **毎日 03:17（JST）** に走ります
（`functions/src/index.ts:162`）。

---

## ついでに出た警告

```
functions: Runtime Node.js 20 was deprecated on 2026-04-30 and will be
decommissioned on 2026-10-30
functions: package.json indicates an outdated version of firebase-functions
```

**2026-10-30 以降は Node.js 20 でデプロイできなくなります。**
2026-09-10 に `functions/package.json` の `engines.node` を `22` に上げた
（`@types/node` も 22 系）。`tsc` と `jest`（66 件）は Node 22 で通っている。
次のデプロイからは Node.js 22 ランタイムで作られる。
