# 店のIDと店主を切り離す（設計）

2026-10-01。プロダクト評価（2026-09-29）の改善 #5「店のIDと店主を切り離す（複数拠点・担当交代）」。

## 1. 何が問題か

これまで、新しい店のドキュメントIDは**最初の店主の uid**だった（`shops/{uid}`）。
ルールの作成条件も `shopId == request.auth.uid` で、1人が作れる店は自分の uid の1つだけ。

2026-09-29 に「店主の引き継ぎ」（`ownerId` を名簿 `shops/{id}/members` の人に替える）が入り、
店主の判定は `ownerId` に寄った（ルールの `isShopOwnerOf`、アプリの `ShopService.getMyShop`）。
それでも次のことが残っていた。

- 店を引き継いで手放した人は、新しい店を作れない（`shops/{自分の uid}` は他人の店として残るため）
- 1人が2つ目の店（拠点）を持てない
- コードのあちこちに「店のID ＝ 店主の uid」を前提にした書き方・コメントが残っている

**本番には実際の店が1つある**（タカヤモーター。2026-09-30 に店主がアプリから登録したので、
IDは店主の uid）。**この店がそのまま動き続けることを最優先にする。**

## 2. 今の前提の洗い出し（どこが `shopId == uid` に頼っているか）

`lib/` `firestore.rules` `storage.rules` `functions/src` `scripts/` を全部見た（2026-10-01）。
テストは別に §2.6 にまとめた。

区分:
- **壊れる**: 店のIDが uid でない店（自動IDの店・引き継いだ店）で動かない
- **直した**: 段階1（この PR）で直した
- **コメント**: 動きには関係なく、説明だけが古い
- **問題なし**: 確かめたが `ownerId`・名簿・保存されている `shopId` で判定していて大丈夫

### 2.1 firestore.rules

| # | 場所 | 中身 | 区分 | どうしたか |
|---|------|------|------|-----------|
| R1 | `match /shops/{shopId}` の `allow create` | `shopId == request.auth.uid` でしか作れない | 壊れる → **直した** | 「uid、または自動IDの形（`isAutoShopId`）」に広げた。`ownerId == request.auth.uid` とプランはフリーだけ、は今まで通り |
| R2 | `match /members/{memberUid}` の `allow create`（店主） | `isShopOwnerOf` は**書く前**の店を見るので、店と名簿の owner を1回のバッチで書けない | 壊れる → **直した** | 「自分を owner として載せる・書いたあと（`getAfter`）の店の ownerId が自分」の節を足した |
| R3 | `actsAsAuthor(authorId)` | `exists(shops/{authorId})` で「店か人か」を見分ける。他人の uid のIDで店を作れると、その人のニュースレターを書けてしまう | 作成を広げると**危ない** → **直した** | `isAutoShopId` で、20文字の英数字（Firebase Auth が振る uid は28文字なので重ならない）・`users/{id}` がいないIDに限った |
| R4 | 先頭の MULTI-TENANT コメント | 「Each shop's ID equals the owner's Firebase Auth UID」 | コメント → 直した | |
| R5 | `isShopOwner` の上のコメント | 「In this schema, shopId == ownerId == request.auth.uid」 | コメント → 直した | |
| R6 | `service_menus` の create のコメント | 「shopId == 自分のUID」 | コメント → 直した | 判定は `isShopOwnerOf` で問題なし |
| R7 | `vehicle_sharing_permissions` のコメント | 「Schema invariant: shopId == shop owner's Firebase UID」 | コメント → 直した | 判定は `isShopStaff` で問題なし |
| R8 | `shop_inquiry_demands` のコメント | 「shopOwnerId を非正規化することでクロスコレクション参照不要」 | コメント（未修正） | 判定は `isShopOwnerOf(resource.data.shopId)` で問題なし |
| — | `isShopOwnerOf` / `isShopStaff` / `isInquiryParticipant` / `isInquiryShopStaff` / `plan_requests` / `private` / `customers` 他の台帳 / `shared_vehicles` / `caseStudies` / `shop_invites` / `shop_staff_invites` / `shop_staff` / `shop_monthly_reports` / `shop_analytics` | `ownerId`・名簿・保存された `shopId` で判定 | 問題なし | ルールのテストで自動IDの店でも確かめた（§5） |

### 2.2 storage.rules

| # | 場所 | 中身 | 区分 | どうしたか |
|---|------|------|------|-----------|
| S1 | `shops/{shopId}/caseStudies/...`（`ShopService.uploadCaseStudyImage`） | このパスのルールが無く、既定の拒否に当たる | **IDに関係なく、すでに全部の店で上がらない** | この PR では触らない。足すときは `request.auth.uid == shopId` ではなく Firestore の `ownerId` を見ること |

### 2.3 lib/

| # | 場所 | 中身 | 区分 | どうしたか |
|---|------|------|------|-----------|
| L1 | `ShopService.createMyShop` | 渡された `shop.id`（＝画面が入れた uid）で `doc(id).set` | 頼っている → **直した** | id が空なら自動ID＋名簿の owner を1回のバッチ。古いルールの本番では uid の形で作り直す（§4） |
| L2 | `ShopService.getMyShop` | まず `shops/{uid}` を直接引く | 頼っている → **直した** | `ownerId == uid` のクエリだけで探す。複数あれば ID＝uid の店 → 作った日の古い順 |
| L3 | `ShopRegistrationScreen._submit` | `id: existingShop?.id ?? uid` | 頼っている → **直した** | 新しい店は `''`（自動ID）。直すときは今の店のID |
| L4 | `ShopOwnerScreen` の `_StaffEntryCard._openLedger` | 店が引けないとき「店のID ＝ 店主の uid」として台帳に渡していた | 自動IDの店で**間違った店主が招待に書かれる** → **直した** | 引けなければ null（招待を出すボタンが出ないだけ） |
| L5 | `shop_inquiry_list_screen.dart` の `senderId: uid ?? inquiry.shopId`（2箇所） | ログインしていないとき店のIDを送り手にする | 使われない（`sendMessage` がログイン中の uid と一致しないと止める） | 触らない。コメントだけ直した |
| L6 | `RevenueCatService.configure`（`appUserID = uid`）と `ShopPlanScreen` | アプリ内課金の利用者 ＝ uid。Functions 側（F1）で uid を店のIDとして使う | 自動IDの店で**壊れる** | **アプリ内課金は止めてある**（`shop_in_app_purchase` は false。店舗プランは請求書払い）。段階3で直す |
| L7 | `ShopStaffService` の `StaffShopLink`・`transferOwnership` のコメント | 「店のドキュメントIDは店主の uid」 | コメント → 直した | |
| L8 | `ShopProvider.sendInquiryMessage` のコメント | 「senderId should be the shop owner's UID」 | コメント（未修正） | 実際はログイン中の人（スタッフも） |
| L9 | `ShopDemandService` のコメント | 「shopOwnerId == request.auth.uid のときだけ読める」 | コメント（未修正） | |
| — | `ShopChainService` / `VehicleHistorySharingService` / `ShopSubscriptionService` / `ShopInvite`（`shopOwnerId`） / `ShopOwnerScreen` の他の箇所（`shop.id`・`shop.ownerId`） | 実際の店のIDと `ownerId` を使う | 問題なし | |

### 2.4 functions/src

| # | 場所 | 中身 | 区分 | どうしたか |
|---|------|------|------|-----------|
| F1 | `webhook.ts` | `const shopId = body.event.app_user_id`（「app_user_id は uid ＝ shopId」） | 自動IDの店・引き継いだ店で**壊れる**（`shops/{uid}` が無いので update が失敗し、RevenueCat が再送し続ける） | L6 と同じ。アプリ内課金を開ける前に段階3で直す |
| F2 | `index.ts` の `updateShopSubscription` | `shops/{shopId}` を update | F1 経由で壊れる | 同上 |
| F3 | `types.ts` のコメント | 「Firebase Auth UID of the shop owner — set as RevenueCat appUserID」 | コメント（未修正） | |
| — | `onPlanRequestCreated`・`notifyPlanRequest.ts`・`purgeExpiredShares`・`aggregateModelCosts`・`sendNewsletter.ts`・`purgeDeletedAccounts.ts` | `event.params.shopId` / `shop.id` を使う。`users/{shopId}` を引くところは無い | 問題なし | |

### 2.5 scripts/

| # | 場所 | 中身 | 区分 | どうしたか |
|---|------|------|------|-----------|
| P1 | `seed_shop_owner.js` | `OWNER_UID = SHOP_ID`。コメント「店主の uid は店の文書IDと同じでなければならない…ルールも `request.auth.uid == shopId`」 | コメント（動きは問題なし） | 未修正。シードは今の形のままで良い |
| P2 | `seed_all.sh` | 「shops/{uid} と uid を揃える」 | コメント（未修正） | |
| P3 | `verify_personas.js` | `getDoc(shops/{uid})`、`where('shopId', '==', uid)` | シードを変えたら**壊れる** | 未修正。シードが ID ＝ uid のままなので今は通る |
| P4 | `seed_year_of_use.js`・`seed_full_experience.js` | 店のメッセージの `senderId` に店のIDを入れる | 見た目だけ（Admin SDK で書く。表示は `isFromShop`） | 未修正 |

### 2.6 テスト

| 場所 | 中身 |
|------|------|
| `test/flows/flow_harness.dart` の `createShop` | uid の形でしか作れなかった → **両方の形で作れるようにした**（`ShopIdForm`） |
| `test/flows/*`（4本） | 店のIDに `owner.uid` を使っていた → **両方の形で同じ流れを通すようにした** |
| `test/rules/firestore.rules.test.js` | 店の作成は uid の形だけだった → **自動IDの形・名簿の owner・好きなIDで作れないこと**を足した |
| `functions/__tests__/webhook.test.ts` | `app_user_id` ＝ shopId を前提にしている（F1 と一緒に段階3で直す） |
| `integration_test/shop_flow_web_test.dart` | コメントと失敗時の文言が「`shops/{uid}`」 |

### 2.7 まとめ

本番で使うコード（テストを除く）で **「店のID ＝ uid」に頼っていた箇所は 24**
（表の R1–R8・L1–L9・F1–F3・P1–P4。S1 はIDと関係なく壊れているので数えない）:

| | 数 | 内訳 |
|-|----|------|
| 動きが壊れる・壊れ得る | 11 | R1 R2 R3 L1 L2 L3 L4 L6 F1 F2 P3 |
| 　うち段階1で直した | 7 | R1 R2 R3 L1 L2 L3 L4 |
| 　うち残した | 4 | L6 F1 F2（アプリ内課金。フラグで止めてあるので今は通らない → 段階3）、P3（シードが今の形なら通る → 段階3） |
| 使われないコード | 1 | L5（触らない） |
| 説明だけが古い | 12 | R4–R8、L7–L9、F3、P1、P2、P4 |
| 　うち直した | 5 | R4–R7、L7（ほかに L5 の近くのコメントも直した） |

## 3. 段階ごとの計画

### 段階1（この PR）: 新しい店は自動IDで作れる

- ルール: 店の作成を「`ownerId == request.auth.uid`、かつ IDは uid か自動IDの形」に広げる（R1・R3）
- ルール: 店を作るバッチで、作った人を名簿の owner として載せられる（R2）
- アプリ: 店を登録すると自動IDで作り、作った人を `ownerId` と名簿の owner にする（L1・L3）
- アプリ: 自分の店は `ownerId` で探す。`shops/{uid}` を直接引かない（L2）
- アプリ: スタッフの入口で、店のIDを店主の uid として使わない（L4）
- **1人1店のまま。** 店を持っている人には登録の入口が出ない（今まで通り）
- **既存の店は移行しない。** IDも名簿もそのまま（§4）

これで、引き継いで手放した人も新しい店を作れるようになる。

### 段階2: 1人が複数の店（拠点）を持てる

- アプリ: 「自分の店」を1つから一覧にする（`getMyShops`）。掲載管理の上で店を切り替える
- アプリ: スタッフの札 `shop_staff/{uid}` は1人1店の形なので、`shop_staff/{uid}/shops/{shopId}` などに広げる
  （または `members` のコレクショングループクエリ。インデックスとルールの `list` の書き方が要る）
- ルール: 1人が作れる店の数を縛る（§6.2）。ルールだけでは数えられないので、作成を Cloud Functions
  （callable）に寄せるか、`shop_owners/{uid}` に数を持たせて店と同じバッチで増やす
- チェーン（`shop_chains`）との関係を決める（拠点 ＝ 店、チェーン ＝ 店の束）
- 既存の店の名簿に owner の行を足すかを決める（ルールはすでに許している。§5「段階2の準備」）

### 段階3: 店と課金・外部の識別子を切り離す

- RevenueCat の `appUserID` を店のIDにする、または webhook で `ownerId == app_user_id` の店を探す（L6・F1・F2）。
  **アプリ内課金（`shop_in_app_purchase`）を開ける前に必ずやる**
- `shop_invites.shopOwnerId` のような、店主を書き写している項目をやめる（引き継ぐと古くなる）
- 施工事例の画像（S1）に Storage のルールを足す（`ownerId` を Firestore から引く）
- シードと検証スクリプト（P1–P4）を `ownerId` で引く形にし、シードにも自動IDの店を入れる

## 4. 既存の店の扱い

**移行しない。** タカヤモーター（`shops/{店主の uid}`）は、IDも中身も名簿もそのまま。

- 店主の判定は以前から `ownerId`。この店の `ownerId` は店主の uid なので、
  `getMyShop` を `ownerId` のクエリに替えても同じ店が見つかる
- 名簿に owner の行が無くても、`isShopStaff` は `ownerId` でも店主を通す（今まで通り）
- 台帳・問い合わせ・招待・明細・プランの申し込みは、すべて今の店のIDにぶら下がったまま

移行しない理由: 店のIDは台帳（サブコレクション）・問い合わせ（`inquiries.shopId`）・
招待・車の写し（`vehicle_sharing_permissions/{vehicleId}_{shopId}`）・プランの申し込みなど
多くの場所に書き写されている。IDを替えるには全部を書き換える必要があり、途中で止まると
店が2つに割れる。得られるもの（IDの見た目が揃う）に対して危険が大きすぎる。

## 5. 確かめ方

| 層 | ファイル | 確かめていること |
|----|---------|----------------|
| ルール | `test/rules/firestore.rules.test.js` の「shops — 店のIDと店主を切り離す（段階1）」 | 両方の形で作れる・アプリのバッチで作れる・好きなIDでは作れない・名簿の owner を他人に書けない・自動IDの店で台帳／招待／引き継ぎ／申し込み／ニュースレターが通る・これまでの形の店（名簿に owner の行が無い）が今まで通り動く |
| サービス | `test/services/shop_service_shop_id_test.dart` | 自動IDで作る・名簿の owner・古いルールの本番では uid の形で作り直す・`getMyShop` は `ownerId` で探す（これまでの形・自動ID・引き継いだ店・手放した店・2つあるとき） |
| 画面 | `test/screens/shop_registration_screen_test.dart` の 33b | 新しい店は id を空で渡す |
| 流れ | `test/flows/` の4本 | 引き継ぎ・スタッフの参加・明細を届ける・初めての店に車を渡す、を**両方の形**で通す |

## 6. 危険と戻し方

### 6.1 出す順番（本番の今の店に影響が出ないこと）

ルール（`firestore deploy`）とアプリ（ウェブ・ストア）は別々に出る。どちらを先に出しても良いようにした。

| 本番の状態 | 既存の店（タカヤ） | 新しく店を登録する人 |
|-----------|------------------|-------------------|
| どちらも出していない | 今まで通り | 今まで通り（`shops/{uid}`） |
| ルールだけ出した | 今まで通り（ルールは「広げた」だけで、既存の店に関わる条件は変えていない） | 古いアプリなので今まで通り（`shops/{uid}` の形はルールが引き続き許す） |
| アプリだけ出した | 今まで通り（`getMyShop` は `ownerId` で同じ店を見つける） | 自動IDのバッチが古いルールで弾かれる → **アプリが `shops/{uid}` で作り直す**（今まで通りの店ができる） |
| 両方出した | 今まで通り | 自動IDの店ができ、名簿に owner として載る |

おすすめはルール → アプリの順（アプリだけのときの作り直しは保険）。

### 6.2 危険

- **店の数に上限が無い。** ルールは「1人1店」を数えられない。これまでは ID ＝ uid なので1人1店に
  縛られていたが、自動IDの形なら1人が何店でも作れる（アプリは1人1店の画面のままだが、
  SDK を直接叩けば作れる）。店は `isActive` で一覧・検索に出るので、**店のなりすまし・荒らしの掲載**が
  増やせる。ただし:
  - 作れるのはフリーの店だけ（プランは運営者が切り替える）
  - 他人の店・台帳・問い合わせには触れない（店主の判定は `ownerId`）
  - アカウントを増やせば以前から同じことはできた
  - 対策は段階2（Cloud Functions に寄せる／数を持たせる）。それまでは運営者が
    `ownerId` ごとの店の数を見て消す
- **好きなIDで作れるわけではない。** IDの形は英数字20文字に限った。ルールからは「本当に自動で
  振られたか」は分からないので、20文字の好きな文字列は作れる（先に作って名前を取ることはできる）。
  Firebase Auth が振る uid（28文字）とは重ならないので、他人の uid の店を作ってニュースレターの書き手を乗っ取ることはできない。
  念のため `users/{id}` がいるIDも弾く
- **名簿に owner の行がある店と無い店が混ざる。** 新しい店は owner の行があり、既存の店は無い。
  画面の「いまのスタッフ」に、新しい店では店主が「店主」として1行出る（引き継いだ店では以前から出ていた）
- **古いルールの本番で作り直した店には名簿の owner の行が無い**（今の店と同じ形。動きは変わらない）
- **アプリ内課金（L6・F1・F2）は自動IDの店で動かない。** フラグで止めてあるので今は通らない。
  フラグを開ける前に段階3

### 6.3 戻し方

- **アプリを戻す**: 前の版を出し直す。自動IDで作られた店は、古いアプリの `getMyShop`
  （`shops/{uid}` → なければ `ownerId` のクエリ）でも `ownerId` で見つかるので、そのまま使える
- **ルールを戻す**: 前の `firestore.rules` を出し直す。既存の店・自動IDで作られた店はどちらも
  動き続ける（`ownerId` で判定しているため）。新しい店の作成は uid の形に戻り、
  新しいアプリは §6.1 の作り直しで uid の形で作る
- **自動IDで作られた店を消したいとき**: 店主がアプリの「掲載をやめる」で消せる
  （`deleteMyShop` は `ownerId` で探す）。運営者が消すなら Admin SDK で店と `members` を消す
