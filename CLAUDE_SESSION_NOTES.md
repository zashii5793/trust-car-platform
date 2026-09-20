# Claude Session Notes

> 新しい記録は**先頭**（この下）に追加。古い記録は `docs/archive/CLAUDE_SESSION_NOTES_2026-09-06以前.md` に移す（目安：本ファイル 300 行以内）。

最終更新: 2026-09-20

---

## ペルソナテストを1年分通した — 店側の画面が一度も開けていなかった（2026-09-20）

**ブランチ**: `claude/year-of-use`

「1年間利用分でペルソナテストを通して、不具合があれば直す。店舗とお客様の
チャットのやりとりも残す」という指示で進めた。

### いちばん大きかったもの: 店主の uid が店の文書IDとずれていた

アプリは `ShopService.getMyShop(uid)` で **`shops/{uid}` を直接引く**。
`firestore.rules` も `isShopOwner(shopId)` / `isInquiryParticipant()` を
`request.auth.uid == shopId` で判定する。つまり**店の文書ID = 店主の uid** が
このスキーマの前提。

ところが `seed_shop_owner.js` は:

```
 shops/shop_takaya_motor_okayama   ← 店の文書
 auth  uid = shop-owner-takaya     ← 店主
```

で作っていた。`getMyShop('shop-owner-takaya')` は `shops/shop-owner-takaya` を
見に行って**見つからない**。店主でログインしても自分の店が無く、問い合わせ一覧も
チャットもルールに弾かれる。**店側の画面は一度も実データで開けていなかった。**

`OWNER_UID = SHOP_ID` に直した。旧 uid のユーザーが残っていると古い方で
ログインしてしまうので、メールから引いて消してから作り直すようにしてある。

**ルールを変えるのではなく、シードを直した。** ルール側を `ownerId` 参照に
変えると、当事者判定のたびに店の文書を `get()` することになり、list クエリの
静的検証も通らなくなる（コメントに残っている「チャットが常に空になった」のが
まさにその形）。

### 店舗とお客様のチャットを1年ぶんにした

`seed_year_of_use.js` に問い合わせ8スレッド・26通を足した（545 → 579 件）。
相手は主にタカヤモーターにしてある。**店の文書ID = 店主の uid なので、
同じ会話を店側からも開ける**（fx-shop-* には Auth ユーザーが無く、
お客様側からしか見えない）。

会話の中身は `MAINTENANCE` の整備記録と噛み合わせた（見積もり → 入庫 → 完了 →
次回の案内）。整備履歴とチャットが別々の作り話だと、突き合わせたときに崩れる。

直近1件は**お客様側が未読**、いちばん新しい1件は**店舗が未返信**にしてあるので、
両側のバッジと「未対応」の見え方がそのまま確認できる。

`--delete` は `messages` サブコレクションも消す。親だけ消すとメッセージが
孤児として残り、流し直したときに古い会話が混ざる。

### 直した不具合

| どこ | 何が起きていたか | 直し |
|---|---|---|
| `seed_shop_owner.js` | 上記。店側の画面に入れない | `OWNER_UID = SHOP_ID` |
| `fleet_service.getMaintenanceSummaries` | `vehicleId` だけで絞っており、ルールが要求する `userId` を静的に満たせず **list ごと permission-denied**。フリートCSVの整備欄が本番で常に空だった | クエリに `userId` を足し、呼び出し側からログイン中の uid を渡す。複合インデックスは既存のもので足りた |
| `inquiry_service` の2つの件数取得 | 未読数・今月の問い合わせ数を、**問い合わせ文書を全部読んでから `length`** で数えていた。1年使うと開くたびに件数ぶん読む | `count()` 集計クエリに置換（読み取り1回）。集計クエリもルール検証を受けるので、通ることを実機で確認した |

### 新しく足した道具: `scripts/verify_personas.js`

**Auth エミュレータで実際にログインして、本物のルール越しにクエリを流す**
スクリプト。確認30件、NGが1件でもあれば終了コード1。

Dart のペルソナテスト97件は `FakeFirebaseFirestore` で動くので、**ルールを
評価しない**。「テストは緑なのに本番では1件も返らない」型の不具合は、原理的に
あの層では見つからない（2026-09-08 に14件見つかったのは全部この型）。

拒否されるべきものが拒否されることも見ている（他人の会話・他人の整備記録・
ルールに合わない形のクエリ）。**通ってしまったら NG** にしてあるので、
ルールが緩む向きの壊れ方も拾える。

### 積み残しの確認結果（2026-09-08 のレビューで「未着手」だったもの）

実際に投げて確かめた。**3件中2件は問題なかった**:

- `post_service.getUserPosts` — 自分向け・他人向け（公開のみに絞る形）とも通る
- `drive_log_service.getUserFavoriteSpots` — `documentId in [...]` は文書単位で
  評価されるため拒否されない
- `fleet_service.getMaintenanceSummaries` — **本物の不具合だった**（上の表）

「ルールに合わないかもしれない」と机上で挙げたものは、**投げてみないと分からない**。

### 検証

- `flutter test --exclude-tags "emulator || golden"` 全件パス（着手前の 4,469 件が
  基準。今回の追加ぶんを含めて再実行）
- `flutter analyze --fatal-infos` No issues
- `dart format --set-exit-if-changed lib test` 差分なし
- `test/rules`（jest + エミュレータ）175 件パス
- `node scripts/verify_personas.js` 30 件すべて OK

### 残っているもの

- `integration_test/year_of_use_app_test.dart` は macOS で動かないまま
  （CocoaPods の spec が古く `Firebase/Crashlytics` を解決できない。`pod repo update` が要る）。
  実アプリの画面は今回も目視できていない
- `newsletter_service.unsubscribeByToken` は Cloud Function 向きのまま（#192）

---

## push で開いた画面から戻れなかった（2026-09-14）

**ブランチ**: `claude/year-of-use`

通知一覧は HomeScreen の AppBar に body として差し込む前提で書かれていたので
`Scaffold` を持たない。2026-09-07 にタブから外してベルから `Navigator.push`
するよう変えたとき、この画面は **AppBar の無い全画面** として積まれた。
AppBar が無い＝戻るボタンが無い。

既存のテストは「ベルを押すと通知一覧が開く」ことだけを見ていたので、
**開いたきり戻れない**ことに気づけなかった。Android の戻るキーや iOS の
スワイプバックがある端末では詰まないが、**Web ではブラウザバック以外に
戻る手段が無い**。

### 直したもの

- `NotificationListScreen` に `Scaffold` + `AppBar`（タイトル「通知」）を持たせた
- 問い合わせ詳細シートに、ドラッグハンドルと並べて閉じるボタンを置いた
  （ハンドルだけだと、下ろせることを知らない人には閉じ方が分からない）
- 通知一覧のゴールデンを撮り直した（AppBar の追加分）

### 次から機械が拾う

`test/ux/back_navigation_test.dart` を足した。`lib/` の中で
`Navigator...push(...)` に渡される `MaterialPageRoute` の行き先クラスを集め、
その宣言ファイルが `AppBar(` を持つかを見る。`pushReplacement` と
`pushAndRemoveUntil` は前の画面を積まないので対象外。

AppBar があることは戻れることの必要条件でしかない（`automaticallyImplyLeading:
false` のような潰し方は拾えない）。**画面を push で開くようにしたら、一度は
自分で開いて閉じること。**

### 手元のゴールデン3枚が赤い（この修正とは無関係）

`screen_vehicle_detail_light` / `_dark` / `screen_home_year_of_use` が
0.12%・約3,585px の差で落ちる。差分は**文字のラスタライズのみ**で、HEAD だけに
戻しても同じ3枚が落ちる（別環境で撮った画像との食い違い）。`tags: 'golden'` 付き
なので CI の対象外。撮り直しは保留。

### 検証

- `flutter test --exclude-tags "emulator || golden"` 4,447件パス
- `flutter analyze --fatal-infos` クリーン
- `dart format --set-exit-if-changed lib test` 差分なし

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

## アーキテクチャ注意事項

- `AppSpacing.radiusFull = 100.0`（`borderRadiusFull` は存在しない）
- `Expanded` は `Row/Column/Flex` の直接の子でなければならない（`Semantics` で挟まない）
- `testWidgets` 内で `Future.delayed` → FakeAsync でハング（同期ストリーム使用）
- 無限アニメ画面で `pumpAndSettle` → ハング（有界 `pump` を使う）
- `ElevatedButton.icon` は `find.bySubtype<ElevatedButton>()` で探す

---

## 参照ファイル

| 目的 | パス |
|---|---|
| 機能仕様 | `docs/FEATURE_SPEC.md` |
| デザインシステム | `docs/DESIGN_SYSTEM.md` |
| 人間タスク | `docs/HUMAN_TASKS.md` |
| CI 設定 | `.github/workflows/ci.yml` |
