# Claude Session Notes（2026-09-07〜2026-09-10）

> `CLAUDE_SESSION_NOTES.md` が300行を超えたため、2026-09-27 に移した。

---

## 夜間の自走: 本番で弾かれるクエリ・CI の取り残し・Functions ランタイム（2026-09-10）

**ブランチ**: `claude/happy-meitner-gvvv6t`（PR #189 に積んだ）

「開発が残っているものを進めて、テストも回して、不具合は起票して直す」という
指示で、人間が寝ている間に進めた。判断が要るものは Issue に切り出して止めた。

### 直したもの（Issue → 修正）

| Issue | 何が起きていたか | 直し |
|---|---|---|
| #190 | 店舗オーナーの需要通知カードが本番で常に非表示。`shop_inquiry_demands` を `shopId` だけで list しており、ルール（`shopOwnerId == uid`）を静的に満たせず list ごと拒否 | クエリに `shopOwnerId` を足し、複合インデックス追加。旧形は弾かれ新形は通ることをルールテストで固定 |
| #191 | `faqs` / `faq_answers` / `faq_helpful_votes` に match ブロックが無く既定拒否。画面が無いので露見していなかった | ルール追加（本人名義・カウンタは +1 のみ・ベストアンサーは質問作者のみ・投票 ID は `<answerId>_<uid>`）。ルールテスト 16 件 |
| #193 | `screenshots.yml` の google-services.json が 8/23 再登録前の旧 Android App ID と Web 用 API キーのまま。`firebase.json` の `flutter.platforms` も旧 ID | `android/ci/google-services.ci.json` に 1 か所化して 3 本のワークフローで共用。firebase.json を現行 ID に |
| #194 | 週次 PM レポートのテスト欄が毎週「1 件パス / ? 件失敗」。golden を除外しておらず、件数もスタックトレースの `+1` を拾っていた | CI と同じ `"emulator \|\| golden"` 除外、進捗行の最後の 1 行だけから読む |
| — | Functions の Node.js 20 が 10/30 に廃止 | `engines.node` 22、`@types/node` 22。tsc / jest 66 件パス |
| — | dependabot のネイティブ依存更新が Build iOS を素通り（9/3 に main を壊した形） | PR の diff に pubspec.lock / pubspec.yaml / ios/ が含まれれば `ios` ラベル無しでも build-ios を走らせる `ios-changes` ジョブ |
| — | #190 の直しで `shop.ownerId` が null の店は需要カードが消えていた（全テストで 2 件失敗して判明） | この画面はオーナー本人の店しか出ないので、ログイン中の uid にフォールバック。uid が渡ることをテストで固定 |

### 進めた開発（残っていたもの）

- **パーツ推薦の「理由」と「注意点」**（`docs/FEATURE_SPEC.md` の方針: 1 位を決めない・理由は複数・広告は明示）。
  `PartRecommendation` に `reasons` / `cautions` / `confidenceScore` を足し、Service で
  適合度・レビュー数・pros/cons から組み立てる。掲載枠は理由に入れず注意点で「広告」と出す。
  画面はカードと詳細シートで recommendation 側の文言を優先（無ければ従来の pros/cons）

### 起票して止めたもの（設計判断が要る）

#192: ルールとクエリが食い違う残り 6 件（法人の整備記録の見せ方・ニュースレター解除の
Cloud Function 化・followers 投稿の可視性・spots の切り分け）。

### 検証

- Firestore / Storage ルールテスト: エミュレータで 168 件全パス（新規 20 件含む）
- functions: jest 66 件・tsc クリーン（Node 22）
- actionlint: 変更した ci.yml / test_apk.yml / screenshots.yml / pm_report.yml 指摘なし
- Flutter 側（Flutter 3.44.2 をこのセッションに入れて CI と同じコマンドで実行）:
  `flutter test --exclude-tags "emulator || golden"` 4,416 件パス（上の 2 件失敗を直して再実行）、
  `flutter analyze --fatal-infos` No issues、`dart format --set-exit-if-changed lib test` 差分なし
- 注意: この環境で `flutter pub get` を打つと pubspec.lock が 5 件ダウングレード（intl 0.20.3→0.20.2 など）した。
  環境側の解決結果なので**コミットしていない**。手元で同じことが起きたら CLAUDE.md の「バージョンを揃える」を参照

---

## テスター配布を iPhone / Android の両方で（2026-09-09）

**ブランチ**: `claude/happy-meitner-gvvv6t`

今週末にテスターへ配る。8月の配布で残っていた2つの穴を塞いだ。

```
 8月                                   9月
 公開は手元 Mac で publish_test_build   Actions「Test Distribution」ボタン1回
 iOS は「間に合わない」で見送り          ブラウザ版（ホーム画面に追加）を即日
                                        + TestFlight ワークフロー（Apple 承認済みなら1日）
```

### 判断したこと

- **配布 URL は `download.html` の1本に寄せる。** ページが端末を見て Android には APK、
  iPhone にはブラウザ版（TestFlight のリンクがあればそれも）を出す。テスターに端末別の URL を
  送り分けると、間違った方を開いた人の問い合わせが必ず来る
- **iOS の署名は自動署名 + App Store Connect API キー。** 証明書 .p12 と Provisioning Profile を
  人間が作って Secret に貼る方式は取らなかった。手順が3つ減り、期限切れの更新作業も消える。
  代わりに API キーの役割は Admin が要る
- **TestFlight ワークフローは Secret が揃うまで macOS を起動しない。** ubuntu の preflight で
  4つの Secret を先に見る。macOS は10倍課金で、Secret 不足で落ちる回に払う理由が無い
- **Sign in with Apple とプッシュ通知の iOS 設定は入れていない。** entitlements と pbxproj の
  変更を Xcode 無しで手で入れるのは、白画面の一件（Bundle ID 不一致）と同じ形の壊れ方を
  しうる。テスターには「iPhone はメール/パスワードで」と案内する
- **web_preview.yml の Pages デプロイを止めた。** Pages は 8/25 に停止済みで、以後 main への
  push のたび deploy ジョブが赤くなっていた（9/6 も failure）。ビルド検証だけ残した
- **ci.yml にあった iOS plist のフォールバックを `ios/ci/GoogleService-Info.ci.plist` に出した。**
  testflight.yml でも同じ値が要る。2か所に書くと、App ID を直したときに片方だけ古いままになる
  （それが 8月の白画面だった）

### 人間の作業（`docs/TESTUSER_ROLLOUT_2026-09.md`）

```
 §1  Secret FIREBASE_SERVICE_ACCOUNT を1つ登録（15分）← これが無いと公開で止まる
 §2  Actions → Test Distribution → Run workflow → download.html を配る
 §4  iPhone アプリ版: Apple 承認確認 → App ID → ASC アプリ → API キー → Secret 4つ → TestFlight
```

Storage ルールは 9/6 に本番反映済み。Test Distribution の `deploy_storage_rules` は
今後ルールを変えたときに同じ鍵で反映するためのもので、既定はオフ。

### 検証

- actionlint 1.7.7: 変更した5本のワークフローすべて指摘なし
- `download.html` の組み立て（APK あり/なし × TestFlight あり/なし）を sed で通し、プレースホルダ残りなし
- plist 3本を plistlib でパース
- Dart コードは触っていない（flutter analyze / test の対象変更なし）
- **CI では確かめられないこと**: Firebase Hosting への実デプロイ、xcodebuild の自動署名、altool の
  アップロード。いずれも Secret と Apple 側の状態に依存する。初回は人間がワークフローを回して
  ログを見る必要がある

---

## 1年使ったデータで見直した（2026-09-08）

**ブランチ**: `claude/year-of-use` ／ 詳細は `docs/YEAR_OF_USE_REVIEW_2026-09-08.md`

「1年近くアプリを使ったデータをもとに評価する」という指示で、
**ペルソナAが1年使い続けた状態**（`scripts/seed_year_of_use.js`・545件）を
作ってから、ホームを見直した。

### 溜めてはじめて見えたこと

```
 たびの記録の「合計」   実際 204回 10,298km → 画面は 20回 1,259km
                        （1ページ分＝20件の合計を「合計」と書いていた）
 追加読み込み           20→40→60… と読み直す作り。末尾まで見ると
                        読み取りが1,000件を超える
```

どちらも**件数が少ないうちは正しく見える**ので、既存のテストでは出ない。

### 本番で1件も返らないクエリが14件あった（4件修正）

`firestore.rules` が所有者を read の条件にしているのに、クエリが関連IDでしか
絞っていないもの。Firestore は list ごと弾く。**fake_cloud_firestore は
ルールを評価しないので、テストは緑のまま**だった。

```
 fuel_records      給油履歴が読めない → 保存直後の燃費も出ない
 drive_waypoints   userId を書いていない → 経路が1点も保存されない（地図が出ない）
 documents         車両・整備記録に紐づく書類が出ない
 invoices          同上（請求番号の採番も落ちる）
```

インデックスを追加し、ルールテストに「直す前の形は弾かれる」を固定した。
**残り10件（faqs にルールが無い件を含む）はレビュー参照。**

### ホームに出したもの

- クイック導線（たびの記録 / パーツを探す / 給油を記録 / 整備を記録）
- おすすめパーツ（適合するもの3件・適合度を色分け）
- たびの記録・メンテナンスの記録を、**この1年**の集計に
- 1年の数字をタップ → この1年のふりかえり（車両詳細の奥にあったもの）

見え方は `test/golden/goldens/screen_home_year_of_use.png`。

### 給油の記録を見る画面を足した

記録の入口しかなく、**溜めた75件がどこからも見えなかった**。
`FuelHistoryScreen`（回数・平均燃費・給油代・1kmあたり ＋ 1行ごとの燃費）。
満タン法の計算は `FuelEfficiency.history` / `FuelSummary.of` に純関数で置いた。
見え方は `test/golden/goldens/screen_fuel_history.png`。

### 次にやるなら

1. 残り10件のクエリ／FAQ のルール（レビューの表を参照）
2. 給油の推移をグラフに（季節の燃費差は並べただけでは読めない）
3. パーツの実データ仕入れ（いまは架空ブランド300件のデモ）

---
