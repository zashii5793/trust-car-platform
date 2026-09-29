# Claude Session Notes

> 新しい記録は**先頭**（この下）に追加。古い記録は `docs/archive/CLAUDE_SESSION_NOTES_2026-09-06以前.md` に移す（目安：本ファイル 300 行以内）。

最終更新: 2026-09-27

---

## 評価 #11・#10・#9・#5（前半）・#1 を実装（2026-09-29）

**ブランチ**: `claude/sales-readiness`（#215 の上）。評価は非公開リポジトリ `docs/PRODUCT_REVIEW_2026-09-29.html`

- #11 FEATURE_SPEC に「事業の芯」（払う人・KPI・販売版の構成・個人プランの線引き）、docs/README.md を資料の入口に
- #10 操作の記録（`shops/{id}/audit_logs`、店主だけが読める、書き換え不可）／規約の条項（第15条の2・3、
  プライバシー9の2〜4）／**アプリ内の規約は web/*.html から生成**（`tool/gen_policy_texts.dart`・ずれたらテストが落ちる）／App Check（監視だけ）
  - 見つけた食い違い: 規約第12条とアプリ内の規約が「退会後30日保持」のままだった
- #9 AI チャットを既定オフ（本番に Functions が無く動かない）。販売版の構成をテストで固定
- #1 車検の取りこぼし（率・月ごと・声をかける相手。取込が30日より古ければ率を出さない）
- #5 前半: **店主の引き継ぎ**。ルールの「uid == 店のID」判定をすべて ownerId・スタッフ名簿に置き換え
  （旧ルールでは引き継ぎのテスト6件が落ちることを確認）。1人が複数の店・課金の単位は**判断待ち**
  （RevenueCat の app_user_id が店主の uid ＝ 店のID という前提）

---

## 操作の流れを通すテスト（test/flows/）（2026-09-28〜29）

**ブランチ**: `claude/staff-and-invoice-import`（PR #215）

「ユーザー操作を通しで確かめる層が無い」という指摘で、主要な流れ3〜5本を
本物の画面・本物のサービス・メモリ上の Firestore で通す層を作り始めた。
PR ごとの CI（flutter test）で回る。土台は `test/flows/flow_harness.dart`。

- [x] 店が名簿を入れ、お客さんとつながり、明細を届ける（`shop_delivers_detail_flow_test.dart`）
  → **つなぎ目の不具合を発見・修正**: 店から開いたスレッドには車の ID が無く、
  お客さんが「記録に追加」できなかった
- [x] 中古車を登録した日に過去記録を移す（`used_car_first_day_flow_test.dart`）
  → **不具合を発見・修正**: 「移しますか？」の裏で保存中の表示が回り続けていた。
  それまでの通しテストは登録を最後まで保存したことが無かった
- [x] 初めて行く店に共有する → 店が台帳に登録（`share_to_new_shop_flow_test.dart`）
- [x] スタッフが参加して台帳から明細を送る（`staff_joins_flow_test.dart`）

注意（書き方）: 読み取り専用の入力欄はカーソルが点滅し続けるので、押したあとは
pumpAndSettle ではなく pump(時間) で進める。ログイン状態を待つ読み方
（getUserVehicles）はテストの外側では待ち続けるので、確認は Firestore を直接読む。

次: デプロイ（#212 → #213 → #215 の順にマージ、
ルール・索引 → シークレット → Functions）。デプロイは本番なので一手ずつ確認を取る。

---

## 続き: 過去記録の移管・スタッフ・台帳から明細・愛車ページのフォロー（2026-09-28）

**ブランチ**: `claude/shop-staff-and-feed`（`claude/model-cost-report` = PR #212 の上に積んである）

- **過去の整備記録の移管**: アプリが記入用フォーマット（CSV・BOM付き）を渡し、
  記入して戻してもらう。車両登録の直後（新車でなさそうなとき）と車両メニューから。
  「#」で始まる記入例は取り込まない。同じ行は同じIDで二重にならない
- **スタッフ**: 店主がコードを発行（1回限り・7日）、スタッフが掲載管理から参加。
  `shops/{id}/members` と `shop_staff/{uid}`（どの店のスタッフかの札）
- **台帳とアプリをつなぐ**: 顧客専用コード → 札に customerId。ルールで
  「その顧客宛ての招待を使ったときだけ」に縛る（別人に明細が届かないように）
- **台帳から明細**: 店からスレッドを開き（`openedByShop`）、既存の明細送付を使う
- **愛車ページのフォロー**: `vehicle_follows`、同じ車種の一覧、フィード上部の並び
- 訂正: 「同じ車種のフィードに新しい投稿が出ない」は、アプリがメーカーで
  絞っていなかったため表には出ていなかった（makerId は書くようにした）

---

## 店の顧客台帳・新しい店への共有・車種別の維持費レポート（2026-09-27）

**ブランチ**: `claude/model-cost-report`（設計: `docs/SHOP_CRM_DESIGN_2026-09-27.md`）

「多くのユーザーが請求書データを記録すれば、車種ごとのレポートが価値になる」
「店から顧客管理ができるといい」「新しい店に車両・整備記録を共有したい」
「タカヤは法人100社・個人4000人。それに耐える設計に」という指示で進めた。

### 決めたこと
- **ユーザーの「自分の車」と、店の「お客さんとその車」は別々に持つ。**
  つなぐのはユーザーが同意したときだけ（招待コードの札・写しの共有）
- 顧客台帳は `shops/{id}/customers` と `customer_vehicles`（車両は店の直下に平らに。
  顧客をまたいで車検順に並べるため）。20件ずつ・件数は `count()`
- 新しい店への共有は**写しを渡す**（`shops/{id}/shared_vehicles`）。生の
  `vehicles` / `maintenance_records` を店に開けない
- 車種レポートは Cloud Functions で毎晩。**持ち主5人未満は出さない・持ち主単位で
  数える・1年未満の車は年あたりに使わない**。店の実績は `allowsStatistics` の同意制

### 途中で見つけて直したもの（重要度順）
1. **9/22 のルールをデプロイすると、整備記録の追加・編集が全部拒否される**
   （`verificationSource` を持つ書き込みを拒否していたが、アプリは常に書く）
2. **整備記録を編集すると内訳と出所の印が消える**（編集画面が記録を作り直していた）
3. 工場から受け取った記録の金額を本人が書き換えられた
4. `shop_customers` / `vehicle_sharing_permissions` を誰でも一覧できた
5. 退会しても給油記録・かかりつけ店の札が消えていなかった
6. `community_maintenance_trends` は本番で1件も集まっていなかった（ルールで拒否＋握りつぶし）

### フェーズ6（愛車ページ）
- `vehicle_profiles/{vehicleId}` を本人が公開を選んだときだけ作る。車両は非公開のまま
- 投稿の車の札（`vehicleTag`）が表示されていなかったのをチップで出し、愛車ページへ
- パーツのレビューが常に1台目の車に紐づいていたのを、選べるようにした

### 次にやること
- 愛車ページのフォロー・同じ車種の愛車ページ一覧
- 投稿作成が `vehicleTag.makerId` を書いていない（同車種フィードが makerId で絞るので新しい投稿が出ない）
- `test/screens/home_screen_test.dart` のゴールデンが main の時点で 0.05% ずれている（フォントの揺れ。撮り直すか判断）
- 店が台帳から明細を送る導線（出所保証の「工場発行」を増やす入口）
- 整備管理ソフトの製品名が分かったら、取込の列名の候補を足す

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

### ゴールデンは全部緑に戻っていた

2026-09-14 に「`screen_vehicle_detail_light` / `_dark` / `screen_home_year_of_use`
の3枚が 0.12% の差で赤い」と書いたが、**この環境では 25 件すべて通った**。
差は文字のラスタライズだけで、撮った環境に依存する（CI の対象外なのは変わらない）。

### macOS が動かなかった原因は spec ではなくロックだった

`flutter build macos` が「CocoaPods's specs repository is too out-of-date」で
止まり、2026-09-08 から `year_of_use_app_test.dart` を動かせずにいた。
メッセージは spec リポジトリが古いと言うが、**`pod repo update` では直らない**
（spec は新しかった）。本当の原因は `macos/Podfile.lock` が pubspec に対して
古かったこと:

```
 Podfile.lock   firebase_messaging 16.1.1 → Firebase/Messaging 12.8.0 固定
 pubspec.lock   firebase_messaging 16.6.0 → Firebase/Messaging ~> 12.18.0
```

`pod update Firebase` でロックを解き直して通った（Firebase 系 59 pods が
12.18.0 に揃う）。**エラーメッセージの言うとおりに直そうとすると直らない**類。

### そのテストは、落ちない作りだった

macOS が通るようになったので `year_of_use_app_test.dart` を走らせたら
**「All tests passed」と出た。ところが撮れていたのはログイン画面だった。**

手順がすべて `if (見つかったら) { 押す }` で囲われていて、ログインできな
くても素通りしていた。expect が1つも無いので、**構造上ぜったいに落ちない。**
2026-09-08 のレビューで「macOS で動かせていない」と書いたときも、実際には
動いてはいて、ログインできずに終わっていた可能性がある。

入力欄・ボタン・ログイン後の遷移を expect で確かめるように直した。落ちた
ときは画面に出ている文字を添える。

**落ちないテストは、無いのと同じどころか悪い。** 確かめた気にさせるぶん、
「ここは見た」と判断してしまう。

### 残っているもの

- `year_of_use_app_test.dart` は**ビルドと起動までは通るようになった**が、
  このセッション（GUI セッション無し）からはログインが完了せず落ちる。
  `Failed to foreground app; open returned 1` のあと、60秒待っても
  ログイン画面のまま。最前面に出せないアプリは macOS に抑制されるため。
  **人が自分の Mac で打つぶんには通るはず。** 実アプリの画面は今回も
  目視できていない（ここだけは人の手が要る）
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
