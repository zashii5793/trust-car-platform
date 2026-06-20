# APIキー設定 & リリース手順書（オーナー実施版）

> 最終更新: 2026-06-20
> 対象読者: プロジェクトオーナー（zashii5793）
> 目的: **AIでは代替できない、人間がコンソールで行う「鍵・設定・申請」作業** を、
> 取得元〜配置先〜実施順までこの1枚で完結させる。

このドキュメントは「何を・どこで取得し・どこに置くか」をまとめた **作業台帳** です。
- 「なぜ必要か」の背景 → [`HUMAN_TASKS.md`](./HUMAN_TASKS.md)
- ビルド/署名/ストア掲載文の細部 → [`SETUP_AND_STORE_GUIDE.md`](./SETUP_AND_STORE_GUIDE.md)

---

## 0. 前提となる基本情報

| 項目 | 値 |
|------|-----|
| Firebase Project ID | `trust-car-platform` |
| アプリ表示名 | `TrustCar` |
| Bundle ID / applicationId（iOS・Android共通） | **`jp.trustcar.app`** |
| Messaging Sender ID | `31421119456` |
| 対応プラットフォーム | iOS 16.0+ / Android / Web |

> ⚠️ **Bundle ID は必ず `jp.trustcar.app`**。Apple Developer / Google Play / Firebase の
> すべてでこの文字列を使う（過去ドキュメントに `com.trustcar.platform` の誤記があったが無効）。

---

## 1. 鍵・シークレット一覧（マスター台帳）

「あなたが取得して、どこに置くか」の全量。**値そのものは絶対にこのファイルに書かない**こと。

### 1-A. 必須（これが無いとローンチできない）

| # | 鍵・シークレット | 取得元 | 配置先 | コミット |
|---|-----------------|--------|--------|:-------:|
| 1 | `google-services.json` | Firebase Console → 設定 → Android アプリ | `android/app/google-services.json` | ❌ |
| 2 | `GoogleService-Info.plist` | Firebase Console → 設定 → iOS アプリ | `ios/Runner/GoogleService-Info.plist` | ❌ |
| 3 | Firebase デプロイ権限 | `firebase login`（自分のGoogleアカウント） | ローカルのみ | — |
| 4 | `ANTHROPIC_API_KEY` | console.anthropic.com → API Keys | **Firebase Functions Secret** | ❌ |
| 5 | `REVENUECAT_WEBHOOK_SECRET` | RevenueCat Dashboard → Webhooks | **Firebase Functions Secret** | ❌ |
| 6 | RevenueCat Public API Key（iOS / Android） | RevenueCat Dashboard → API Keys | `--dart-define` で注入（後述・要コード対応） | ❌ |
| 7 | APNs認証キー `.p8` | Apple Developer → Keys（Push有効） | **Firebase Console** にアップロード | ❌ |
| 8 | iOS 配布証明書 / Provisioning Profile | Apple Developer → Certificates, Identifiers & Profiles | Xcode（自動署名なら自動） | ❌ |
| 9 | Android リリース用 keystore | 自分で `keytool` 生成 | ローカル `release.keystore` + `android/key.properties` | ❌ 厳禁 |
| 10 | Firebase サービスアカウント JSON | Firebase Console → 設定 → サービスアカウント | ローカルのみ（シード投入時に使用） | ❌ |

### 1-B. CI/CD用 GitHub Secrets（任意・自動化する場合のみ）

| # | Secret 名 | 取得元 | 用途 |
|---|-----------|--------|------|
| 11 | `FIREBASE_TOKEN` | `firebase login:ci` | GitHub Actions から Firebase デプロイ |
| 12 | `CODECOV_TOKEN` | codecov.io にリポジトリ登録 | カバレッジ送信（任意） |
| 13 | `GOOGLE_SERVICES_JSON` | 上記#1 を Base64 化 | CI の Android ビルド用（任意） |
| 14 | `GOOGLE_SERVICES_PLIST` | 上記#2 を Base64 化 | CI の iOS ビルド用（任意） |

> 登録場所: GitHub → リポジトリ → Settings → Secrets and variables → Actions → New repository secret

### 1-C. ⚠️ 絶対にコミットしてはいけないファイル（.gitignore 済みを確認）

```
google-services.json / GoogleService-Info.plist
release.keystore / *.jks / *.keystore
android/key.properties        ← パスワード平文
serviceAccount*.json          ← DB全権限
*.p8 / *.p12 / *.mobileprovision
.env / .env.*
```

> 本手順書の作成時に `android/key.properties` と `serviceAccount*.json`、`*.p8`、
> `*.mobileprovision` を `.gitignore` に追加済み。新しい鍵ファイルを足すときは
> 必ず `.gitignore` を先に更新してから作成すること。

---

## 2. 実施手順（この順番で進める）

### フェーズ A: アカウント開設（先に申し込む＝審査待ち時間の確保）

| 作業 | 場所 | 費用 | 備考 |
|------|------|------|------|
| Apple Developer Program 加入 | developer.apple.com | **$99/年** | 法人は D-U-N-S 番号取得で数日かかる場合あり。**最優先で申込** |
| Google Play Developer 登録 | play.google.com/console | **$25（初回のみ）** | 本人確認に数日かかることあり |
| RevenueCat アカウント作成 | app.revenuecat.com | 無料（一定額まで） | 課金を使う場合 |
| Anthropic API アカウント | console.anthropic.com | 従量課金 | AIチャット機能（サーバー側）用 |

---

### フェーズ B: Firebase 設定ファイルの配置（ビルドの前提）

1. [Firebase Console](https://console.firebase.google.com) → `trust-car-platform` → ⚙️ プロジェクト設定
2. **Android**: 「マイアプリ」→ `jp.trustcar.app` → `google-services.json` を DL → `android/app/` に配置
3. **iOS**: 同じく `GoogleService-Info.plist` を DL → `ios/Runner/` に配置
4. （Google Sign-In を使うなら）Android の SHA-1 を登録 → 詳細は
   [`SETUP_AND_STORE_GUIDE.md` Part 6](./SETUP_AND_STORE_GUIDE.md)

✅ 確認: `flutter run` がビルド成功すればOK。

---

### フェーズ C: Firebase バックエンドの本番設定

```bash
# 1) ログイン（自分のGoogleアカウント・オーナー権限）
firebase login

# 2) セキュリティルール & インデックスのデプロイ（★未デプロイだと書き込みが全部弾かれる）
firebase deploy --only firestore:rules,firestore:indexes

# 3) Storage ルール
firebase deploy --only storage

# 4) サーバー側シークレットを登録（プロンプトで値を貼り付け）
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET

# 5) Cloud Functions をデプロイ
firebase deploy --only functions
```

**Firebase Console 側の操作（コンソールでしかできない）:**
- Authentication → Sign-in method → 「メール/パスワード」「Google」を有効化
- Cloud Messaging → APNs認証キー(.p8)をアップロード（フェーズEで生成）
- Firestore → バックアップとエクスポート → 毎日 / 保持30日
- （任意）App Check → Play Integrity（Android）/ DeviceCheck（iOS）を有効化

---

### フェーズ D: 初期シードデータ投入（画面を空にしないため）

```bash
# サービスアカウント鍵を環境変数に（#10で取得したJSON）
export GOOGLE_APPLICATION_CREDENTIALS=/絶対パス/serviceAccount.json

npm install firebase-admin            # 初回のみ

# まず --dry-run で内容確認 → 問題なければ本番投入
node scripts/seed_safety_tips.js
node scripts/seed_community_trends.js
node scripts/seed_shops.js
```

> ⚠️ `seed_shops.js` の `demo_*`（架空店舗）は **本番公開前に削除 or 実店舗データへ差し替え**。

---

### フェーズ E: iOS 署名・証明書（Mac + Xcode 必須）

1. [Apple Developer](https://developer.apple.com/account/) → Certificates, Identifiers & Profiles
2. **Identifiers**: App ID `jp.trustcar.app` を登録。Capabilities で **Push Notifications** を ON
3. **Keys**: 新規キー作成 → **Apple Push Notifications service (APNs)** を選択 → `.p8` をDL
   → Firebase Console の Cloud Messaging にアップロード（#7）
4. **Certificates**: Apple Distribution 証明書を作成
5. **Profiles**: App Store 用 Provisioning Profile を作成
6. Xcode で `ios/Runner.xcworkspace` を開く → Runner → Signing & Capabilities
   → Team 選択、Bundle ID = `jp.trustcar.app`、「Automatically manage signing」推奨

---

### フェーズ F: Android リリース署名

```bash
# keystore 生成（★1回だけ・紛失するとアプリ更新不可。クラウドにバックアップ）
keytool -genkey -v -keystore ~/trustcar-release.keystore \
  -alias trustcar -keyalg RSA -keysize 2048 -validity 10000
```

`android/key.properties` を作成（`.gitignore` 済み）:
```properties
storePassword=<キーストアのパスワード>
keyPassword=<キーのパスワード>
keyAlias=trustcar
storeFile=/絶対パス/trustcar-release.keystore
```

`android/app/build.gradle.kts` の署名設定（現状は debug 署名のまま）を release 署名へ。
→ 具体的な編集内容は [`SETUP_AND_STORE_GUIDE.md` Part 2-3](./SETUP_AND_STORE_GUIDE.md)。
**この .kts 編集はAIに依頼可**（鍵の値は不要なので）。

---

### フェーズ G: 課金（RevenueCat）

`lib/services/revenue_cat_service.dart` は **ハードコードを廃止済み**で、API キーは
ビルド時に `--dart-define` で注入します（未設定なら本番初期化が明示エラーで fail-fast）。
あなたは RevenueCat Dashboard の Public API Key を、ビルド時に渡すだけです。

```bash
# 鍵をビルド時に注入（プラットフォーム別）
flutter build appbundle --release \
  --dart-define=REVENUECAT_API_KEY_ANDROID=<Public API Key (Android)>
flutter build ipa --release \
  --dart-define=REVENUECAT_API_KEY_IOS=<Public API Key (iOS)>
```

あわせて App Store Connect / Google Play で **サブスクリプション商品** を作成し、
RevenueCat Dashboard に紐付けます。

---

### フェーズ H: 実機テスト（エミュレータで再現しない項目）

- [ ] 車検証OCRカメラが起動する
- [ ] GPSで近くの整備工場が距離順に並ぶ
- [ ] Push通知が届く（APNs/FCM設定後）
- [ ] Google Sign-In が動作する
- [ ] 画像アップロード（Storage）が動作する
- [ ] 車検証の内容が暗号化されている

---

### フェーズ I: ストア申請

#### iOS（App Store Connect）

1. [App Store Connect](https://appstoreconnect.apple.com) → マイApp → **+** で新規App
   - 名前: `TrustCar` / 主要言語: 日本語 / Bundle ID: `jp.trustcar.app` / SKU: 任意
2. ビルド: `flutter build ipa --release` → Xcode Organizer または Transporter でアップロード
3. ストア情報入力:
   - スクリーンショット（iPhone 6.7" / 6.5" 必須）
   - 説明文・キーワード・プロモーションテキスト
   - **プライバシーポリシー URL**（必須）
   - **App プライバシー（Nutrition Label）**: 位置情報・カメラ・個人情報の収集を申告
4. アプリ内課金（サブスク）を審査対象に含める（RevenueCat設定完了後）
5. 「審査へ提出」→ 審査 **通常24〜48時間**（初回は長め）

> リジェクト頻出ポイント: プライバシーポリシー不備 / ガイドライン4.2(機能不足) /
> 3.1.1(課金導線) → 詳細は [`SETUP_AND_STORE_GUIDE.md` Part 5-5](./SETUP_AND_STORE_GUIDE.md)

#### Android（Google Play Console）

1. アプリ作成 → AAB アップロード（`flutter build appbundle --release`）
2. コンテンツレーティング、対象国、データセーフティ、プライバシーポリシーURL を入力
3. 内部テスト → 本番トラックへ昇格 → 審査（数時間〜数日）

---

## 3. ローンチ前 最終チェックリスト

**P0（必須）**
- [ ] B: `google-services.json` / `GoogleService-Info.plist` 配置
- [ ] C: Firestore ルール・インデックス デプロイ済み
- [ ] C: Authentication（メール/Google）有効化

**P1（ローンチ前）**
- [ ] C: `ANTHROPIC_API_KEY` / `REVENUECAT_WEBHOOK_SECRET` を Functions Secret 登録 → Functions デプロイ
- [ ] E: APNs `.p8` を Firebase にアップロード
- [ ] E: iOS 証明書・Provisioning Profile 作成、Xcode署名設定
- [ ] F: Android keystore 生成・`key.properties`・release署名設定
- [ ] G: RevenueCat Public API Key をビルド時 `--dart-define` で注入（コードは対応済み）＋商品設定
- [ ] D: シードデータ投入（safety_tips / community_trends / shops）＋ `demo_*` 削除
- [ ] C: Firestore バックアップ設定
- [ ] H: 実機テスト一式

**P2（ローンチ後でも可）**
- [ ] I: App Store / Google Play 審査提出
- [ ] プライバシーポリシー・利用規約の法的レビュー
- [ ] C: Firebase App Check 有効化

---

## 4. 「AIに任せられること / あなたしかできないこと」早見表

| あなた（人間）だけが可能 | AIに依頼可能 |
|------------------------|-------------|
| 各種アカウント開設・課金 | `build.gradle.kts` の署名設定編集 |
| Console での鍵取得・設定値入力 | RevenueCat鍵の `--dart-define` 化改修 |
| 証明書/Provisioning/keystore作成 | App Check 初期化コード追加 |
| `firebase deploy`（オーナー権限） | Firestoreルール/インデックスの作成・修正 |
| ストア審査の提出・スクショ撮影 | ストア説明文の下書き作成 |

---

*このファイルはセットアップの「作業台帳」です。実際の鍵の値は記入せず、
進捗チェックのみ運用してください。背景・細部は HUMAN_TASKS.md / SETUP_AND_STORE_GUIDE.md を参照。*
