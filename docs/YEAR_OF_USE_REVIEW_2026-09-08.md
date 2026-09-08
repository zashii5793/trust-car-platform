# 1年使ったデータで見直す（2026-09-08）

ブランチ: `claude/year-of-use`

## なぜやったか

これまでの確認は、機能ごとに数件のデータを置いて「動くこと」を見るものだった。
**1年使った人の画面は、そこには写らない。**

- ドライブログは直近1か月に6件しかなく、200件並んだときの見え方が分からない
- 給油記録は1件も無く、燃費が出るかどうかを画面で確かめられない
- 整備記録は 2026-05 で止まっていて、「最近の記録」が4か月前だった

そこで、**ペルソナA（persona.a@example.com）が1年間アプリを使い続けた状態**を
作り、その上でホームを見直した。

## 作ったデータ

`scripts/seed_year_of_use.js`（545ドキュメント・冪等）

| 内容 | 件数 |
|---|---|
| ドライブログ（通勤・仕事・週末・家族の遠出） | 198 |
| 経路（drive_waypoints。直近12件ぶん） | 252 |
| 給油記録 | 75 |
| 整備記録（rich_history 以降を補う） | 12 |
| アクセサリーのクチコミ | 4 |

既存シードと合わせた、ログイン後に見える数字（エミュレータで実測）:

```
 車両                4台（ハイエース45,000km / アルファード30,000km /
                        ノート15,000km / ロードスター22,000km）
 たびの記録          204回 / 10,298km（この1年）
 給油                75件 / 536,318円
 整備記録            177件 / ¥2,772,597（全期間）
 アクセサリー        クチコミ4件
```

## 見つかったこと

### 1. 「合計」が、読み込んだ1ページ分の合計だった 〔直した〕

ホームの「たびの記録」は `DriveLogProvider.logs`（1ページ＝20件）を足していた。

```
 実際      204回 / 10,298 km
 画面      20回  /  1,259 km   ← 8分の1
```

**件数が少ないうちは正しく見える**ので、使い込むほど数字が外れていく。
集計クエリ（count / sum）に置き換えた。ドキュメントは読まないので、
ホームを開くたびに200件を読むことにもならない。

同じ理由で「メンテナンスの記録」も直近3件の合計をやめ、**この1年**の件数と
金額を出すようにした。

### 2. 本番で1件も返らないクエリが14件あった 〔4件直した〕

`firestore.rules` が所有者（`resource.data.userId == request.auth.uid`）を
read の条件にしているのに、クエリが関連ID（vehicleId など）でしか絞って
いないもの。**Firestore はクエリがルールを満たすことを静的に証明できないと
list ごと弾く**ため、本番では 1件も返らない。

`fake_cloud_firestore` はルールを評価しないので、**テストは緑のまま**だった。
エミュレータで permission-denied を実測して確認した。

直したもの:

| 場所 | 症状 |
|---|---|
| `fuel_service.dart` `recordsFor` | 給油履歴が読めない。**保存直後に燃費も出ない**（この機能の要が動いていない） |
| `drive_log_service.dart` `addWaypoint` | userId を書いていないので**経路が1点も保存されない** |
| `drive_log_service.dart` `getWaypoints` | 読み取りも弾かれる。**ドライブログ詳細の地図が出ない** |
| `document_service.dart` / `invoice_service.dart`（5メソッド） | 車両・整備記録に紐づく書類／請求書が出ない |

必要な複合インデックスを `firestore.indexes.json` に追加し、「直す前の形は
弾かれ、直した形は通る」を `test/rules/firestore.rules.test.js` に固定した。

**残り10件は未着手**（下の「残っている課題」参照）。

### 3. 追加読み込みが、毎回いちから読み直していた 〔直した〕

`DriveLogProvider.loadMore` は「件数を増やして取り直す」作りで、
20 → 40 → 60 … と読み直していた。1年ぶん（198件）を末尾までたどると
**読み取りが1,000件を超える**。最後の1件からのカーソル方式にした。

### 4. ドライブログとパーツ提案の入口が奥にあった 〔直した〕

- たびの記録 … プロフィール →「アカウント」セクションの中
- パーツ提案 … 車両詳細を開いて、右上のアイコンに気づいた人だけ
- 給油 …… 車両詳細を開いて、スクロールした先

どれも**毎月やること**なのに、毎月たどり着けない位置にあった。

ホームを次の並びにした。

```
 ダッシュボード（登録台数・要対応・注意）
 クイック導線     たびの記録 / パーツを探す / 給油を記録 / 整備を記録
 AI提案
 車両カード
 たびの記録       この1年で204回・合計10,298km ＋ 直近2件
 おすすめパーツ   適合するもの3件（完全対応 / 対応 / 条件付きを色分け）
 メンテナンスの記録 この1年で17件・合計 ¥288,400 ＋ 直近3件
 みんなのアクセサリー
 過去の車両
```

見え方は `test/golden/goldens/screen_home_year_of_use.png` に残した。

### 5. 直したついでに見つけた小さな壊れ方 〔直した〕

- `_RetiredVehiclesSection` が、返ってきたリストをその場で並べ替えていた
  （変更できないリストを返す実装だと落ちる）
- `seed_drive_logs_persona_a.js` が存在しない車両ID（`veh-a-roadster` など）を
  指していた。正しくは `veh-a-sports` / `veh-a-cargo` / `veh-a-lease`

## 残っている課題

### ルールに合わないクエリ（10件・未着手）

| 場所 | コレクション | 直し方の見当 |
|---|---|---|
| `fleet_service.dart:205` `getMaintenanceSummaries` | `maintenance_records` | 法人の整備記録をどう見せるかの設計が要る（ルール側の話） |
| `shop_demand_service.dart:106,125` | `shop_inquiry_demands` | 絞っているのが `shopId`、ルールが見るのは `shopOwnerId` |
| `newsletter_service.dart:149` `unsubscribeByToken` | `newsletter_subscriptions` | パス条件なので list では証明不能。Cloud Function 向き |
| `post_service.dart:272` `getUserPosts`（followers） | `posts` | `exists()` 依存で静的証明できない |
| `drive_log_service.dart:944` `getUserFavoriteSpots` | `spots` | documentId の whereIn だけで絞っている |
| `faq_service.dart:80,164,233` | `faqs` / `faq_answers` | **ルールに match ブロックが無く、既定拒否**。FAQ機能を出すならルールが要る |

### 機能の穴

- **給油履歴を見る画面が無い。** 記録は残るが、振り返る場所が無い
  （保存直後に燃費が1回出るだけ）。`docs/HABIT_DESIGN.md` が「唯一の
  月単位の接点」と位置づけている機能なので、一覧と推移は要る
- **この1年のふりかえり（YearInReviewScreen）が車両詳細の奥にある。**
  1年ぶんのデータが溜まった人にいちばん見せたい画面が、いちばん奥にある
- おすすめパーツの中身は**デモデータ**（`seed_parts.js` の架空ブランド300件）。
  実データの仕入れは `docs/PARTS_DATA_SOURCING.md` の課題のまま

## 再現の手順

```bash
firebase emulators:start --only auth,firestore

cd scripts
node seed_personas.js --emulator
node seed_full_experience.js --emulator
node seed_shops.js --emulator
node seed_safety_tips.js --emulator
node seed_community_trends.js --emulator
node seed_rich_history.js --emulator
node seed_drive_logs_persona_a.js --emulator
node seed_parts.js --emulator
node seed_year_of_use.js --emulator      # ← 1年ぶん

# 実機で見る（persona.a@example.com / password123）
flutter run
```

見え方だけを確かめるなら、ゴールデンで足りる。

```bash
flutter test test/screens/home_screen_test.dart          # 1年ぶんの並びを画像で
flutter test --update-goldens test/screens/home_screen_test.dart
```

## 品質チェック

```
 flutter test --exclude-tags "emulator || golden"   4,424件 全パス
 flutter analyze --fatal-infos lib test             No issues found
 dart format --set-exit-if-changed lib test         適用済み
 test/rules（jest + エミュレータ）                    129件 全パス
```

## 積み残し（この作業で片付かなかったもの）

- `integration_test/year_of_use_app_test.dart` を足したが、**macOS では動かせて
  いない**。CocoaPods の spec が古く `Firebase/Crashlytics (~> 12.18.0)` を
  解決できない（`pod repo update` が要る）。iOS シミュレータでは動くはず
- Web（`flutter run -d web-server`）では起動を確認したが、ブラウザ側の
  ウィンドウ操作が効かず、画面の撮影はゴールデンで代替した
