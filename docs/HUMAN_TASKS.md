# 人間が実施すべきタスク一覧

**最終更新**: 2026-09-03
**前提**: AIが実装・テスト・コードプッシュまで完了済み。以下は **AIでは代替できない** 操作、および **人間の意思決定が必要な事項** のみ。
**出荷目標**: 2026年8月ソフトローンチ（逆算計画は `docs/LAUNCH_PLAN.md`）。

> **来週テストユーザーに触ってもらう分だけを知りたい場合は、
> `docs/TESTUSER_ROLLOUT_2026-08.md` を先に読んでください。**
> このドキュメントはストア公開までの全量です。テスト配布に不要な項目も含みます。

## このドキュメントの読み方

各項目に **検証状態** を付けています。

| 表記 | 意味 |
|---|---|
| `[コード検証済]` | リポジトリのコードを読んで、未対応であることをAIが確認した |
| `[実測]` | 実際に動かして確認した |
| `[要確認]` | Firebase Console / Apple Developer など、AIから見えない領域。人間の確認が必要 |

---

## P0 — リリースブロッカー

### 1. Android リリース署名の設定 `[実測: android/key.properties が存在しません]`

**状態**: **コード側は対応済み。残るのはキーストアの生成だけです。**

`android/app/build.gradle.kts` は `android/key.properties` を読む `signingConfigs`
を持っており、鍵が無いまま release タスクを叩くとビルドが明示的に止まります
（debug 署名の AAB が「リリースのつもり」で出来上がるのを防ぐため）。

```
android/key.properties not found. A release build needs
storeFile / storePassword / keyAlias / keyPassword.
```

debug ビルドには影響しません。**人間の作業はキーストアの生成と `key.properties`
の作成の2つで、AI 側の実装作業はもう残っていません。**

**手順**:

```bash
# 1. キーストア生成（1回だけ・紛失するとアプリ更新が永久に不可能）
keytool -genkey -v -keystore ~/trustcar-release.keystore \
  -alias trust-car-platform \
  -keyalg RSA -keysize 2048 -validity 10000
```

2. `android/key.properties` を作成（`.gitignore` 対象）:
```properties
storePassword=<パスワード>
keyPassword=<パスワード>
keyAlias=trust-car-platform
storeFile=/Users/<ユーザー名>/trustcar-release.keystore
```

3. 検証: `flutter build appbundle --release` → `jarsigner -verify -verbose build/app/outputs/bundle/release/app-release.aab`

**所要時間**: 30分
**重要**: キーストアと `key.properties` はパスワードマネージャ等に厳重保管。**Google Play App Signing に登録すれば紛失リスクは緩和できる**ため、初回アップロード時に有効化を推奨。

---

### 2. Firestore セキュリティルール・インデックスのデプロイ `[完了: 2026-09-03]`

**状態**: **2026-09-03 に反映済みです。** 以降にルールを変えたときは、また同じ
手順が要ります（変更のたびにデプロイが必要）。

**なぜ必要**: 未デプロイだと該当機能の読み書きが全てルールで弾かれます。

**2026-09-01 追記**: 車検満了日の共有（`shop_customers` の
`inspectionExpiries` / `vehicleCount` / `sharesInspectionExpiry` の検証）を
足しました。**未デプロイだと、顧客側の共有が全て弾かれます。**

現在 `firestore.rules` は789行あり、以下を含みます（前回デプロイ以降の追加分は Console のバージョン履歴で要確認）:
- `fleet_members`, `accessory_showcases`, `car_purchase_inquiries`, `safety_tips`, `shop_chains`
- `community_maintenance_trends`（読み取り=認証済み、書き込み=AdminSDKのみ）
- `accessory_showcases/{id}/comments` サブコレクションと `comment_reports/{reportId}`
- `vehicle_sharing_permissions`（#76）

複合インデックス:
- `safety_tips`: `isActive + publishedAt`, `isActive + category + publishedAt`
- `inquiries`: `shopId + createdAt`（工場ダッシュボードの月次レポート #39 の前提）

**デプロイ手順チェックリスト**（2026-09-03 実施済み）:
- [x] ローカル検証: `cd test/rules && npm install && npm test` — 148件パス
- [x] `firebase login`（`hideki.ishizashi@gmail.com`）
- [x] ドライラン: `firebase deploy --only firestore:rules --dry-run` — コンパイル成功
- [x] 本番反映: `firebase deploy --only firestore:rules` — released
- [x] 本番反映: `firebase deploy --only firestore:indexes` — deployed
- [ ] Firebase Console → Firestore → ルール → バージョン履歴で反映時刻を確認（人間の目視）

**所要時間**: 5分（インデックス構築は数分〜数十分かかる場合あり）

---

### 3. Google Maps API キーの設定 `[実測: 未設定。ただしコストはほぼゼロと判明]`

**詳細と試算: `docs/MAPS_API_COST.md`**

**2026-09-03 に調べ直しました。Places API は使っていません**（`lib/` `functions/`
`web/` を全文検索してヒット0）。Geocoding も Directions も未使用で、距離は
Haversine のローカル計算です。**課金対象は地図の表示だけ**で、地図を出すのは
2画面（近隣工場マップ・ドライブログの経路プレビュー）に限られます。

ソフトローンチ規模（20人）で **月140ロード程度**、無料枠の 1.4% です。
さらに **Android / iOS のネイティブ地図は現行の価格体系では無料**で、課金される
Web は `MAPS_API_KEY` を渡していないため**現状ロード数0**です。

**やること**（30分）:

1. Google Cloud Console でAPIキーを発行
2. 有効化: **Maps SDK for Android / Maps SDK for iOS のみ**（Places は不要）
3. キー制限: Android はパッケージ名 `jp.trustcar.app` ＋ SHA-1、iOS は Bundle ID
4. 渡し方: `android/local.properties` に `MAPS_API_KEY=...` / CI は GitHub Secrets
5. 予算アラート（月$1で十分）

**先に直すべきコード側の穴が2つあります**（AI 側で対応可能）:

- **iOS はキーが注入されません。** `AppDelegate.swift` は `Info.plist` の
  `MapsApiKey` を読みますが、**そのキーが Info.plist にありません**
- **ドライブログ詳細に `MapsConfig` のガードがありません。** キーが無くても
  地図を作ろうとして、灰色のタイルが出ます

---

### 4. Firebase Authentication の本番設定 `[要確認]`

**詳細な手順: `docs/SETUP_AUTH_CONSOLE.md`**

**2026-09-03 追記: `android/app/google-services.json` に Android 用の OAuth
クライアント（SHA-1 付き）がありません。** このままでは Android の Google ログインが
`ApiException: 10` で失敗します。**SHA-1 の登録と `google-services.json` の
取り直しが要ります**（登録するのは P0-1 のリリース鍵の SHA-1。この開発機には
Android SDK が無く、debug の SHA-1 は取れません）。

**手順**:
1. Firebase Console → Authentication → Sign-in method
2. 以下を有効化:
   - **メール / パスワード**（本番にテストユーザーが存在するため、有効化済みの可能性が高い。要確認）
   - **Google**: SHA-1 フィンガープリントを追加（Android）
   - **Apple**: iOS のガイドライン4.8対応。`SignInWithAppleButton` は実装済み
3. 承認済みドメインに本番ドメインを追加（Web版 = `zashii5793.github.io`）

**所要時間**: 15分

---

## P1 — ローンチ前必須

### 5. iOS: Apple Developer Account でのApp ID・証明書設定 `[要確認]`

**状態**: Apple Developer Program の承認状況を要確認（前回記録では申請済み・承認待ち）。

**手順**:
1. [Apple Developer Console](https://developer.apple.com/account/) → Certificates, Identifiers & Profiles
2. App ID 登録: **`jp.trustcar.app`**（`[コード検証済]` iOS の `PRODUCT_BUNDLE_IDENTIFIER`、Android の `applicationId` ともに一致済み）
3. Distribution Certificate の作成
4. Provisioning Profile の作成（App Store Distribution用）
5. Xcode → Signing & Capabilities → Team 設定
6. **Sign in with Apple** の Capability を有効化（ガイドライン4.8対応で必須）

**所要時間**: 1〜2時間（初回）
**前提条件**: Apple Developer Program（年間$99）

---

### 6. FCM（Push通知）の設定 `[要確認]`

**手順**:
1. Firebase Console → プロジェクト設定 → Cloud Messaging
2. iOS: **APNs認証キー**（.p8）を Firebase Console にアップロード（Apple Developer Account が必要）
3. Android: 追加設定は基本不要（`google-services.json` に含まれる）
4. Xcode: Push Notifications / Background Modes（Remote notifications）の Capability を有効化

**所要時間**: 30分
**前提条件**: Apple Developer Account・Firebase Console オーナー権限

---

### 7. RevenueCat のAPIキー設定 `[コード検証済: 環境変数注入は実装済み]`

**状態**: #118 でハードコードを廃止し、`.env` / `--dart-define` 両対応済み。`.env.example` にテンプレートあり。**キーの値そのものは未設定**。

**手順**:
1. [RevenueCat Dashboard](https://app.revenuecat.com/) でアカウント作成
2. アプリを登録（iOS・Android）
3. Public SDK キーをコピー（**secret API キーではない**）
4. 設定（いずれか）:
   - ローカル: `cp .env.example .env` して `REVENUE_CAT_API_KEY_IOS` / `REVENUE_CAT_API_KEY_ANDROID` を記入
   - CI/リリース: `flutter build ... --dart-define=REVENUE_CAT_API_KEY_ANDROID=goog_xxx`
5. App Store Connect / Google Play Console でサブスクリプション商品を作成し、RevenueCat に紐付け

**所要時間**: 2〜3時間（商品作成含む）

---

### 8. GoogleService-Info.plist が別アプリのもの `[実測: iOS が起動しません]`

> **2026-08-21 に格上げ。** この項目は「新端末ビルド時に再配置が必要」と書いていましたが、
> **実態は「置いてあるファイルが別アプリのもの」**でした。**P0 相当です。**

**iOS シミュレータでアプリが起動しません。** 白画面のまま、UI が一度も描かれません。

```
Unhandled Exception: [core/duplicate-app] A Firebase App named "[DEFAULT]" already exists
  #2  main (package:trust_car_platform/main.dart:84:3)
```

`main()` の 1 行目で例外が出て、そこで止まっています。

**原因**: 設定が 2 か所で食い違っています。

| | `ios/Runner/GoogleService-Info.plist` | `lib/firebase_options.dart` |
|---|---|---|
| Bundle ID | **`com.example.trustCarPlatform`** | `jp.trustcar.app` |
| API Key | `AIzaSyBt0hMKqo…` | `AIzaSyDZQ4UK6I…` |

**実際の Bundle ID は `jp.trustcar.app`**（`ios/Runner.xcodeproj/project.pbxproj`）。
plist は **Flutter のテンプレート既定のまま**で、取り直されていません。

`firebase_core 4.9.0` は iOS でネイティブ側が先に plist から既定アプリを作ります。
そのあと Dart が別の設定で初期化しようとして衝突します。

**なぜ気づかれなかったか**

```
 CI            iOS を「ビルド」はするが「起動」はしない → 通る
 テスト3,988件  Firebase を差し替えたテストなので通る
 実機テスト      P1-9 が未実施
```

**ビルドが通ることは、起動することの保証ではありません。**

### 取り直すだけでは直りません（2026-08-21 実測）

`firebase apps:sdkconfig` で Console から取得し直しても、**同じ
`com.example.trustCarPlatform` が返ります。** ローカルのファイルが古いのではなく、
**Firebase に登録されている iOS アプリそのものの Bundle ID が間違っています。**

```
 firebase apps:list IOS
 → trust_car_platform (ios)  1:31421119456:ios:4320af5d1401f02c80c985  （1件のみ）
 → その BUNDLE_ID が com.example.trustCarPlatform
```

`firebase_options.dart` 側にも食い違いがあります。

```
 apiKey   web / android / ios / macos が **全部同じ鍵**（AIzaSyDZQ4UK6I…）
 実際の iOS アプリの鍵                    AIzaSyBt0hMKqo…（別物）
 iosBundleId                             jp.trustcar.app（登録と不一致）
```

**Firebase の iOS アプリは、あとから Bundle ID を変更できません。**
`jp.trustcar.app` の iOS アプリを**新規に登録**する必要があります。

**手順**:

1. Firebase Console → プロジェクト設定 → マイアプリ → **アプリを追加 → iOS**
2. バンドルIDに **`jp.trustcar.app`** を入れて登録
3. `GoogleService-Info.plist` をダウンロードし `ios/Runner/` に配置
4. `flutterfire configure` で `firebase_options.dart` を作り直す
   （**いまの値は iOS の鍵が Web のものになっています**）
5. **Android も同じ確認をする。** `google-services.json` の `package_name` が
   `jp.trustcar.app` かどうか
6. 確認: `flutter run` で最初の画面が出るか。**ビルドが通るだけでは足りません**

**所要時間**: 30分
**前提条件**: Firebase Console のオーナー権限
**注意**: 旧アプリ（`com.example.*`）は消さずに残すこと。消すと、そこに紐づく
既存データや設定の参照が切れる可能性があります。使わなくなるだけです。

---

### 9. 実機テスト（iOS / Android） `[未実施]`

**チェックシート: `docs/DEVICE_TEST_CHECKLIST.md`**（項目ごとの記入欄あり）

**2026-09-03 追記: 車検証OCRの元号変換にバグが見つかり、直しました。** ML Kit が
ラベルと値を別行で返すと**令和7年が1995年**になっていました（満了日が30年前に
なると、車検の案内が全部「切れている」と出ます）。実機で最初に確かめるべき項目です。

エミュレータや Web では再現しない領域の確認です。**特に以下の3つは Web で一切検証できません**。

#### 9-1. OCR（iOS/Android専用機能）

`google_mlkit_text_recognition` は**モバイル専用**で、`flutter test` でも Web でも動きません。現在のOCRテスト（`test/ocr/ocr_accuracy_test.dart`）は**合成テキストに対するパース精度のみ**を検証しており、実画像からの読み取り精度は未検証です。

- [ ] 車検証OCR: 実物の車検証を撮影 → 登録番号・車台番号・型式・満了日が正しく入るか
- [ ] 車検証OCR: 光の反射・斜め撮影・折れ目でどこまで劣化するか
- [ ] 請求書OCR: 実際の整備工場の請求書で、合計金額・日付・店舗名・明細が取れるか
- [ ] 請求書OCR: 手書き補足やレシート型（感熱紙）での挙動

#### 9-2. 位置情報

- [ ] GPS で近隣工場が距離順に並ぶ
- [ ] 走行記録（ドライブログ）の開始・停止・距離計算
- [ ] **`[コード検証済]` 走行記録中にアプリをバックグラウンドへ回す** — 下記「意思決定が必要な事項」参照

#### 9-3. その他

- [ ] Push通知が届く（FCM設定後）
- [ ] Google Sign-In / Sign in with Apple が動作する
- [ ] 画像アップロード（Firebase Storage）
- [ ] カメラ・フォトライブラリの権限ダイアログが日本語で適切に表示される
- [ ] 日付ピッカーが日本語表示になっている（2026-08-17 に `flutter_localizations` を導入済み）
- [ ] 整備記録の入力→保存→一覧表示
- [ ] 課金フロー（RevenueCat サンドボックス）

**所要時間**: 1日（iOS・Android 各1台以上）

---

### 10. Firestore バックアップ設定 `[完了: 2026-09-03]`

**Console を開かずに CLI から設定できます。** 2026-09-03 に設定済み。

```bash
firebase firestore:backups:schedules:create --recurrence DAILY --retention 30d
firebase firestore:backups:schedules:list   # 確認
```

```
 Name         projects/trust-car-platform/databases/(default)/backupSchedules/d7be24ef-...
 Recurrence   DAILY
 Retention    2592000s（30日）
```

Firestore のスケジュールバックアップは Google 側が保持するため、Cloud Storage
バケットの指定は要りません（手動エクスポートとは別の仕組み）。

**費用**: 目安 月〜$5

---

### 11. 本番データの初期投入 `[コード検証済: スクリプトは全て実装済み]`

すべて `scripts/` に実装済みです。実行には Firebase サービスアカウントキーが必要なため、AIからは実行できません。

```bash
cd scripts && npm install                                  # 初回のみ
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json

node seed_shops.js              # 整備工場（タカヤモーター + demo_* 6件）
node seed_safety_tips.js        # 安全運転情報 6件
node seed_community_trends.js   # コミュニティトレンド 5車種
```

**本番投入前の必須確認**:
- [ ] `demo_*` の架空店舗は**本番リリース前に削除または実店舗データへ差し替え**（実在の事業者ではないため）
- [ ] タカヤモーターの `phone` / `address` / `location` を正式情報で埋める

**ペルソナのデモデータについて**: `seed_personas.js` / `seed_fleet_year.js` / `seed_full_experience.js` は
**社内確認用**です。`--with-auth` を付けると `persona.a〜i@example.com` / `password123` の Auth ユーザーを
作成しますが、**パスワードが共通のため、本番に投入すると公開Webから誰でもログインできる状態になります**。
確認が終わったら必ず削除してください（詳細は `docs/TEST_DATA_GUIDE.md`）。

```bash
node seed_personas.js --delete-auth
node seed_full_experience.js --delete
node seed_fleet_year.js --delete
```

**ローカル確認だけなら本番投入は不要**です。Emulator に投入すれば同じ画面を確認できます。

**所要時間**: 15分

---

## P2 — 意思決定が必要な事項（AIでは判断できない）

### 12. 走行記録のバックグラウンド動作 `[コード検証済: 現在は停止する]`

**現状**: `drive_recording_provider.dart` は `Geolocator.getPositionStream()` で位置を追跡していますが、
**バックグラウンド実行の設定が入っていません**。

- iOS: `Info.plist` に `UIBackgroundModes`（location）の記述なし
- Android: `FOREGROUND_SERVICE` / `ACCESS_BACKGROUND_LOCATION` の権限なし

このため、**運転中に画面をロックする、または他アプリに切り替えると記録が止まります**。ドライブログ機能の
実用性に直結するため、リリース前に方針を決める必要があります。

**選択肢**:

| 方針 | 内容 | コスト |
|---|---|---|
| A. 現状のまま出す | 「アプリを開いたまま記録してください」と画面に明記。実装変更なし | なし |
| B. 前面固定で緩和 | 記録中は画面スリープを抑止（`wakelock`）。ロックし忘れ以外は救える | 小 |
| C. 正式対応 | iOS: Background Modes、Android: Foreground Service を実装 | 中〜大。**ストア審査で用途説明が必要**（特にiOSの常時位置情報は審査が厳しい） |

**判断のポイント**: Cは App Store の審査で「なぜ常時位置情報が必要か」の説明を求められ、リジェクトリスクが上がります。
ソフトローンチ時点では A または B で出し、利用実態を見てから C を検討するのが安全です。

---

### 13. Firebase App Check の有効化 `[コード検証済: 未導入]`

**状態**: `firebase_app_check` は依存にも実装にも入っていません。

Bot・不正アクセスから Firestore を保護します。本番運用では推奨ですが、**導入すると全リクエストに
アテステーションが必要になる**ため、設定漏れがあるとアプリが動かなくなります。ソフトローンチ後、
ユーザー数が増える前の導入が現実的です。

1. Firebase Console → App Check
2. Android: Play Integrity 有効化 / iOS: DeviceCheck 有効化
3. アプリコードに App Check 初期化を追加（**AIに依頼可**）
4. 一定期間「モニタリングのみ」で運用し、正当なリクエストが弾かれないことを確認してから強制に切り替え

**所要時間**: 1時間 + 監視期間

---

### 14. 規約ドラフトの確定（社長記入 ＋ 専門家確認） `[実測: 【要記入】は残り4項目]`

2026-09-01 にプライバシーポリシー・利用規約を改訂し、特定商取引法に基づく表示
（`web/tokushoho.html`）を追加しました。**2026-09-03 に、判断で決まる欄と
コードから確定できる欄をすべて埋めました。** 残っているのは、事業者本人でなければ
確定できない4項目だけです。

**社長でなければ埋められない欄**（すべて `web/tokushoho.html`）:

| 項目 | 補足 |
|---|---|
| 運営統括責任者 | 代表者または運営責任者の氏名 |
| 所在地 | 本店所在地。請求があれば遅滞なく開示する形にする場合は、その旨と条件も |
| 電話番号 | 同上 |
| 販売価格 | 各有料プランの価格。**P1-7 の RevenueCat 商品作成と同時に決まります**。App Store / Google Play のアプリ内課金画面の表示と一致させること |

加えて、公開時に**最終更新日**（現在は「2026年9月3日（ドラフト）」）を公開日に
直してください。

**`web/` と `docs/web/` は同一内容です**（両方を同じように直す必要があります）。

**2026-09-03 に決めたこと**:

| 論点 | 決定 |
|---|---|
| 退会後のデータ保持 | **猶予なしで削除**。`PURGE_AFTER_DAYS` を 30 → 0 に変更し、規約・UI・実装を揃えた。**誤って退会した場合の復旧はできません** |
| C2C の手数料 | 数字は書かず「本サービス上に表示するところによる」。**機能は停止中で、再開前に手数料率と表示事項を定めて表示する**と明記 |
| 返品・キャンセル | デジタルサービスのため、期間途中の解約でも未経過分の返金は原則なし（法令上の義務・当方の責による場合・サービス終了・ストアの返金ポリシーを除く） |
| fleet の個人情報 | 契約法人との法人向け契約で別途定める（規約本文には書き切らない） |

**専門家に見てもらう論点**:

- 個人情報保護法の遵守確認（特に車検証のOCRデータ）
- 位置情報の利用目的の明記（走行記録を含む）
- 整備工場への情報提供の同意文言（車検満了日の共有を含む）
- AIチャットで第三者の生成AIサービスへ送信することの説明
- C2C取引における当サービスの立場（仲介か販売か）と特商法上の表示義務
- 猶予なしの即時削除が、誤操作の救済という観点で問題にならないか
- データ削除リクエストへの対応ポリシー（`deleteAccount` は実装済み・#120 で purge 対応）

**所要時間**: 記入 30分 ＋ 専門家確認（弁護士費用の目安 3〜5万円）

---

### 15. C2C凍結フラグの Remote Config パラメータ作成 `[コード検証済: 実装は完了]`

`FeatureFlag.c2cPartsMarketplace` の再開判断を、**アプリ再リリースなし**で運用側から切り替えられます。

**実装済み**: `FirebaseRemoteFlagSource` ＋ `FeatureFlagService` を `injection.dart` に配線済み。
起動時に `sync()` で取得し `AppConfig` に反映。未設定・取得失敗時はローカル既定値（凍結）を維持。

**パラメータは 2026-09-03 に作成済み**（`false` = 凍結のまま）。**Console 手作業
ではなく、リポジトリの `remoteconfig.template.json` で管理する形にしました。**

```bash
firebase deploy --only remoteconfig   # テンプレートを反映
firebase remoteconfig:get             # 現在の内容を確認
```

**残るのは再開の判断だけ**です。再開するときは `remoteconfig.template.json` の
`defaultValue.value` を `"true"` にして deploy し、アプリ再起動でマーケットの
「パーツ」「マイ出品」タブが戻ることを確認します（Console から直接変えると、
リポジトリの内容と食い違うので避けてください）。

**注意**: 将来 `firebase_core` を上げる際は、`cloud_firestore` の iOS ネイティブと Firebase iOS SDK の
整合（CocoaPods）を必ず CI ビルドで確認すること（現在 `firebase_core` は 4.9.0 に固定）。

---

## P3 — ストア申請（ローンチ直前）

### 16. App Store Connect でのアプリ審査申請

1. App Store Connect → マイApp → 新バージョン追加
2. スクリーンショット追加（iPhone 6.7" / iPad 12.9"）
3. **プライバシー情報（Privacy Nutrition Label）**の入力 — 位置情報・カメラ・連絡先情報の申告が必要
4. 年齢制限の設定
5. **ガイドライン4.8対応の確認**: サードパーティログイン（Google）を提供する場合、Sign in with Apple の提供が必須。実装済み
6. 審査申請（通常3〜5営業日）

**所要時間**: 2〜3時間

---

### 17. Google Play Console でのアプリ申請

1. Google Play Console → アプリを作成
2. **AAB をアップロード**（P0-1 の署名設定が前提）
3. データセーフティフォームの入力（位置情報・写真・個人情報の収集を申告）
4. コンテンツレーティングのアンケート
5. ターゲット国の設定
6. 審査申請（通常3〜7営業日）

**所要時間**: 2〜3時間

---

## ローンチ前チェックリスト

**P0（これが揃わないと出せない）**
- [ ] P0-1: **Android リリース署名の設定** — コード側は対応済み。残るはキーストア生成と `android/key.properties` の作成（`[実測]` 未作成）
- [x] **P0-2: Firestore ルール・インデックスのデプロイ** — 2026-09-03 反映済み
- [ ] P0-3: Google Maps API キーの発行・設定（未設定でも動作はする／地図のみ無効）
- [ ] P0-4: Firebase Authentication の本番設定（メール/Google/Apple）

**P1（ローンチ前必須）**
- [ ] P1-5: iOS App ID・証明書・Sign in with Apple Capability
- [ ] P1-6: FCM / APNs 認証キー
- [ ] P1-7: RevenueCat の Public SDK キー設定と商品作成
- [x] **P1-8: GoogleService-Info.plist が別アプリのもの** — Firebase の再登録（人間・2026-08-27）とコード側の差し替え（AI・2026-09-01）は完了。**残るは起動確認**（`docs/IOS_FIREBASE_FIX.md` §4）
- [ ] P1-9: **実機テスト（特にOCRの実画像精度は完全に未検証）**
- [x] **P1-10: Firestore バックアップ設定** — 2026-09-03 設定済み（DAILY・30日保持）
- [ ] P1-11: 本番データ投入（工場・安全情報・トレンド）＋ `demo_*` 店舗の扱いを決定

**P2（判断が必要）**
- [ ] P2-12: 走行記録のバックグラウンド動作方針（A/B/C から選択）
- [ ] P2-13: App Check の導入時期
- [ ] P2-14: **規約ドラフトの確定** — 残り4項目（運営統括責任者・所在地・電話番号・販売価格）。すべて `web/tokushoho.html`。埋めないとアプリ内にそのまま出ます
- [x] **P2-15: Remote Config `c2c_parts_marketplace` の作成** — 2026-09-03 作成済み（`false`）。残るは再開の判断

**P3（申請）**
- [ ] P3-16: App Store 審査申請
- [ ] P3-17: Google Play 審査申請

---

## 参考: AI側で対応済み・対応可能なもの

以下は人間の作業ではありません。混同しないよう記載します。

| 項目 | 状態 |
|---|---|
| 日付ピッカーの日本語化 | 対応済み（2026-08-17、`flutter_localizations` 導入） |
| ナンバープレートの全角/半角正規化 | 対応済み（`core/utils/license_plate.dart`） |
| ログイン直後にデータが空になる不具合 | 対応済み（2026-08-17、`core/utils/auth_scoped_stream.dart`） |
| Web版がEmulatorに繋がらない問題 | 対応済み（2026-08-17、`--dart-define=USE_EMULATOR=true` / localhost 自動判定） |
| Android の署名設定コード | 対応済み（`key.properties` を読む `signingConfigs`。鍵が無いまま release ビルドすると明示的に停止） |
| App Check の初期化コード | 人間が Console で有効化後、AIが実装可能 |
| 走行記録のバックグラウンド対応 | 方針決定後、AIが実装可能 |

---

*実機・外部コンソールに関する記述は、AIから検証できないため `[要確認]` としています。コードから確認した内容には `[コード検証済]`、実際に動かして確認した内容には `[実測]` を付けています。*
