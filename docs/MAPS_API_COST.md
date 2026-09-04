# Google Maps API のコスト試算と、いま必要な作業（P0-3）

**作成**: 2026-09-03
**対象**: `docs/HUMAN_TASKS.md` P0-3
**結論**: **Maps のコストは事実上ゼロです。** ただし課金の心配より先に、
**iOS でキーが注入されていない**ことと、**ドライブログ詳細にガードが無い**ことを
直す必要があります。

---

## 1. 何に課金されるか

コードを読んで確認しました。**課金対象は「地図の表示（Dynamic Maps）」だけ**です。

| API | 利用 | 根拠 |
|---|---|---|
| Places（近隣検索・オートコンプリート） | **未使用** | `lib/` `functions/src/` `web/` を全文検索して `maps.googleapis.com` / `nearbysearch` / `autocomplete` のヒット 0。工場検索は Firestore クエリで完結 |
| Geocoding（住所↔座標） | **未使用** | `geocoding` パッケージが `pubspec.lock` に無い。ドライブログの住所はユーザーの手入力 |
| Directions / Distance Matrix / Roads | **未使用** | 経路は記録済み GPS 点列を `Polyline` で結ぶだけ。距離は Haversine のローカル計算（`shop_provider.dart:187-230` ほか3箇所） |
| Dynamic Maps（地図表示） | **使用** | 下記2箇所のみ |

**HUMAN_TASKS には「Places は従量課金が高いため要判断」と書いてありましたが、
そもそも使っていません。** 判断は不要です。

## 2. 地図を出しているのは2箇所だけ

| # | 画面 | 表示のきっかけ | 1回の表示で | ガード |
|---|---|---|---|---|
| A | 近隣工場マップ<br>`nearby_shops_map_screen.dart:100` | 工場一覧の「地図で見る」を**押したときだけ** | 1ロード | `MapsConfig.isConfigured` あり（`shop_list_screen.dart:69`） |
| B | ドライブログ詳細の経路プレビュー<br>`drive_log_detail_screen.dart:475` | 詳細画面を開くと**自動**（経路2点以上のとき） | 1ロード。**下までスクロールして戻ると再生成され得る** | **なし** |

A は初期値が `_showMap = false`（`shop_list_screen.dart:61`）なので、
**マーケットプレイスを開いただけでは1回もロードされません。**

## 3. 試算

```
月間マップロード / ユーザー
 = 工場一覧を開く回数 × 地図を押す率 × 往復回数        … A
 + ドライブログ詳細を開く回数 × 経路2点以上の割合       … B
```

ソフトローンチの想定（テストユーザー20人・1人あたり月10回アプリを開く）で
多めに見積もっても:

```
 A  20人 × 月2回 地図を開く          =   40 ロード
 B  20人 × 月5回 ドライブログを見る   =  100 ロード
                                      ─────────
                                        140 ロード / 月
```

**Dynamic Maps の無料枠（月10,000ロード相当）に対して 1.4%** です。
ユーザーが100倍（2,000人）になっても枠内に収まります。

### さらに、モバイルは課金対象外です

**Android / iOS のネイティブ SDK の地図表示は、現行の Google Maps Platform の
価格体系では無料・無制限**です（要最新確認）。課金されるのは Web の
Maps JavaScript API で、**そちらは現状ロード数 0** です（次項）。

### Web では、いま地図が出ません

`scripts/deploy_web.sh:61` と `.github/workflows/web_preview.yml:95-96` の
`flutter build web` は `--dart-define=APP_BUILD_ID=...` しか渡しておらず、
**`MAPS_API_KEY` を渡していません。** そのため `MapsConfig.isConfigured == false`
となり、工場一覧の「地図で見る」導線自体が出ません。

`web/index.html:43-50` は Maps の JS を無条件で読み込みますが、
**JS のロード自体は課金対象外**です（課金は地図の生成時）。

---

## 4. コード側の穴は塞ぎました（2026-09-03）

調べる過程で、キーの注入経路に穴が2つ見つかったので直しました。

### (a) iOS にキーが渡るようにしました

`ios/Runner/AppDelegate.swift:14-17` は `Info.plist` の `MapsApiKey` を読む作り
でしたが、**そのキーが `Info.plist` に存在しませんでした**（xcconfig にもなし）。
キーを発行しても iOS では地図が出ない状態です。

**Android の `local.properties` と同じ形にしました。**

```
 ios/Runner/Info.plist        MapsApiKey = $(MAPS_API_KEY)
 ios/Flutter/Debug.xcconfig   #include? "Maps.xcconfig"
 ios/Flutter/Release.xcconfig #include? "Maps.xcconfig"
 ios/Flutter/Maps.xcconfig    MAPS_API_KEY = <実キー>   ← .gitignore 対象
```

**使い方**（キーを発行したら）:

```bash
cp ios/Flutter/Maps.xcconfig.example ios/Flutter/Maps.xcconfig
# MAPS_API_KEY = に発行したキーを書く
```

`#include?` は省略可能インクルードなので、**ファイルが無くてもビルドは通ります**
（キー無し扱いになるだけ）。

### (b) ドライブログ詳細にガードを入れました

`drive_log_detail_screen.dart` は `MapsConfig` を見ておらず、キーが無くても
`GoogleMap` を作っていました（実機では灰色のタイルが出るだけで、理由が分からない）。

工場一覧と同じようにガードし、キーが無いときは
**「地図を表示できません（地図の設定が未完了です）」**と出します。

副産物として、**テスト環境（キー未設定）では2点以上の経路でも GoogleMap を
組まなくなった**ので、これまで避けていた経路をテストできるようになりました
（`test/screens/drive_log_detail_screen_test.dart` に1件追加）。

### (c) Lite Mode は変えていません

`liteModeEnabled: true` にすると Android では静止画になり、**拡大縮小が
できなくなります**。コストが問題にならない以上、見え方を変えてまで軽くする
理由がないので、そのままにしました。

---

## 5. 結局、人間は何をすればいいか

**やること**（`docs/HUMAN_TASKS.md` P0-3 の手順のうち、実際に要るのはここだけ）:

1. [Google Cloud Console](https://console.cloud.google.com/) → APIとサービス → 認証情報 → APIキーを発行
2. 有効化する API: **Maps SDK for Android** と **Maps SDK for iOS** のみ
   （**Places API は有効化不要**。使っていません）
3. キーの制限（漏洩対策・必須）
   - Android: パッケージ名 `jp.trustcar.app` ＋ SHA-1（P0-1 の鍵）
   - iOS: Bundle ID `jp.trustcar.app`
   - 各キーで「使用する API のみ」に制限
4. キーを渡す
   - Android: `android/local.properties` に `MAPS_API_KEY=<実キー>`
   - iOS: `cp ios/Flutter/Maps.xcconfig.example ios/Flutter/Maps.xcconfig` して記入
   - CI: GitHub Secrets の `GOOGLE_MAPS_API_KEY`
5. 予算アラートは念のため設定（月$1で十分。超えたら想定外が起きている合図）

**やらなくていいこと**: Places API の有効化、コスト最適化のためのキャッシュ設計、
1商圏に絞る運用。どれも Places を使う前提の話でした。

**所要時間**: 30分（HUMAN_TASKS の「1〜2時間」は Places の判断込みの見積もりでした）
