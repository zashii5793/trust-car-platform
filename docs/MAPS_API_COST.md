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

## 4. コストより先に直すべきこと（コード側）

課金の心配は要りませんが、**キーの注入経路に穴が2つあります。**

### (a) iOS はキーが注入されていません

`ios/Runner/AppDelegate.swift:14-17` は `Info.plist` の `MapsApiKey` を読んで
`GMSServices.provideAPIKey` に渡す作りですが、**`ios/Runner/Info.plist` に
`MapsApiKey` のキーが存在しません**（xcconfig にもなし）。

→ **iOS ではキーを発行しても地図が出ません。** Info.plist への追加が要ります
（AI 側で対応可能）。

### (b) ドライブログ詳細に `MapsConfig` のガードがありません

`drive_log_detail_screen.dart` は `maps_config.dart` を import しておらず、
**キーが無くても `GoogleMap` を生成します。** Android では灰色のタイルと
`InvalidKey` のログ、Web ではレンダリング失敗になります。

→ 工場一覧と同じようにガードして、キーが無いときは「経路の地図は表示できません」
と出すのが筋です（AI 側で対応可能）。

### (c) 経路プレビューは Lite Mode に落とせます

`drive_log_detail_screen.dart:492` は `liteModeEnabled: false` です。
経路を眺めるだけの静止プレビューなので、Android では Lite Mode（静止画相当）に
できます。スクロールでの再生成コストも下がります。

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
   - iOS: **先に (a) の Info.plist 対応が要ります**
   - CI: GitHub Secrets の `GOOGLE_MAPS_API_KEY`
5. 予算アラートは念のため設定（月$1で十分。超えたら想定外が起きている合図）

**やらなくていいこと**: Places API の有効化、コスト最適化のためのキャッシュ設計、
1商圏に絞る運用。どれも Places を使う前提の話でした。

**所要時間**: 30分（HUMAN_TASKS の「1〜2時間」は Places の判断込みの見積もりでした）
