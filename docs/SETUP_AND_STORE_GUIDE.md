# 開発環境セットアップ & ストア申請ガイド

> 最終更新: 2026-05-05
> 対象読者: 開発者・リリース担当者

---

## Part 1: ローカル開発環境セットアップ

### 1-1. 必要なツール

| ツール | バージョン | 用途 | インストール先 |
|--------|-----------|------|--------------|
| Flutter | 3.x以上 | アプリ本体 | https://docs.flutter.dev/get-started/install |
| Dart | 3.0以上 | 自動付属（Flutter同梱） | — |
| Xcode | 15以上 | iOS ビルド（Mac必須） | Mac App Store |
| Android Studio | 最新 | Android エミュレーター | https://developer.android.com/studio |
| Firebase CLI | 最新 | デプロイ・エミュレーター | `npm install -g firebase-tools` |
| Node.js | 18以上 | Cloud Functions | https://nodejs.org |

---

### 1-2. Flutter インストール確認

```bash
flutter doctor
```

以下がすべて ✓ になっていれば OK:
```
[✓] Flutter
[✓] Android toolchain
[✓] Xcode (iOS のみ・Mac必要)
[✓] Android Studio
[✓] Connected device
```

---

### 1-3. リポジトリ取得 & 依存インストール

```bash
git clone https://github.com/zashii5793/trust-car-platform.git
cd trust-car-platform

# Flutter パッケージ取得
flutter pub get

# Cloud Functions 依存取得
cd functions && npm install && cd ..
```

---

### 1-4. Firebase 設定ファイルの配置

**この手順は必須です。ファイルがないとビルドが失敗します。**

#### Android

1. [Firebase Console](https://console.firebase.google.com) → プロジェクト「trust-car-platform」
2. 歯車アイコン → プロジェクトの設定 → 全般タブ
3. 「マイアプリ」→ Android アプリ（`jp.trustcar.app`）→ `google-services.json` をダウンロード
4. ダウンロードしたファイルを以下に配置:

```
android/app/google-services.json   ← ここに配置
```

#### iOS（Mac のみ）

1. 同じ Firebase Console → iOS アプリ（`jp.trustcar.app`）→ `GoogleService-Info.plist` をダウンロード
2. 配置:

```
ios/Runner/GoogleService-Info.plist   ← ここに配置
```

> ⚠️ これらのファイルは `.gitignore` 対象です。コミットしないでください。

---

### 1-5. アプリの起動

```bash
# 接続済みデバイス / エミュレーターの確認
flutter devices

# 起動（デバッグモード・Firebase 本番接続）
flutter run

# 特定デバイスを指定する場合
flutter run -d <device_id>

# iOS シミュレーター（Mac のみ）
open -a Simulator
flutter run -d iPhone

# Android エミュレーター
# Android Studio → AVD Manager → エミュレーターを起動してから
flutter run -d emulator-5554
```

**デバッグモードでは Firebase 本番 DB に接続されます。**
テスト用データは本番 Firestore に書き込まれるので注意してください。

---

### 1-6. Firebase Emulator（推奨：ローカルテスト環境）

本番データを汚したくない場合はエミュレーターを使います。

```bash
# エミュレーター起動（Auth + Firestore）
firebase emulators:start --only auth,firestore

# 別ターミナルでアプリ起動
# kDebugMode=true のときは自動的にエミュレーターに接続される
flutter run
```

エミュレーター UI: http://localhost:4000

---

### 1-7. テスト実行

```bash
# 全テスト（約1,900件）
flutter test --exclude-tags emulator

# 特定ファイル
flutter test test/screens/shop_registration_screen_test.dart

# 静的解析
flutter analyze lib/
```

---

## Part 2: Android リリースビルド

### 2-1. 署名用 Keystore を作成（初回のみ）

```bash
keytool -genkey -v \
  -keystore ~/trustcar-release.keystore \
  -alias trustcar \
  -keyalg RSA -keysize 2048 -validity 10000
```

対話形式で以下を入力:
- 名前、組織、都市、国（任意）
- キーストアのパスワード（絶対に忘れないこと）
- キーのパスワード（同じで OK）

> ⚠️ このファイルを**絶対に紛失しないこと**。Google Play への更新にずっと必要です。
> クラウドストレージ（iCloud 等）にバックアップ推奨。

### 2-2. key.properties を作成

```bash
# プロジェクトルートに作成（gitignore 済み）
cat > android/key.properties << EOF
storePassword=<キーストアのパスワード>
keyPassword=<キーのパスワード>
keyAlias=trustcar
storeFile=<keystoreファイルの絶対パス例: /Users/yourname/trustcar-release.keystore>
EOF
```

### 2-3. build.gradle.kts に署名設定（実装済み）

`android/app/build.gradle.kts` には **keystore が無くても壊れない条件付き署名設定が既に実装済み**です。
あなたは `android/key.properties` を置くだけでリリース署名が有効になります（無ければ debug 署名に
フォールバックするので CI / クローン直後も壊れません）。実装内容は以下のとおり:

```kotlin
// ファイル冒頭
import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")  // = android/key.properties
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ...
    signingConfigs {
        create("release") {
            if (hasKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")  // CI / keystore未設定時のフォールバック
            }
        }
    }
}
```

> 💡 R8 による難読化（`isMinifyEnabled` / `isShrinkResources`）は ProGuard ルール未整備だと
> Firebase 等のリフレクション利用箇所で実行時クラッシュの恐れがあるため、**今回は有効化していません**。
> 有効化する場合は別途 `proguard-rules.pro` を整備し、リリースビルドで動作確認すること。

### 2-4. リリース APK / AAB をビルド

```bash
# Google Play 提出用（AAB 形式・推奨）
flutter build appbundle --release

# 出力先: build/app/outputs/bundle/release/app-release.aab

# テスト用 APK
flutter build apk --release
# 出力先: build/app/outputs/flutter-apk/app-release.apk
```

---

## Part 3: iOS リリースビルド（Mac 必須）

### 3-1. Xcode で証明書・プロビジョニングプロファイルを設定

1. Xcode → `ios/Runner.xcworkspace` を開く
2. Runner → Signing & Capabilities
3. Team: Apple Developer アカウントを選択
4. Bundle Identifier: `jp.trustcar.app` を確認
5. 「Automatically manage signing」をチェック

### 3-2. Archive（ストア提出用ビルド）

```bash
flutter build ios --release
```

その後 Xcode で:
1. Product → Archive
2. Organizer が開いたら「Distribute App」
3. App Store Connect → 自動署名 → Upload

---

## Part 4: Google Play ストア申請

### 4-1. 事前準備チェックリスト

```
[ ] Google Play Developer アカウント登録済み（$25）
[ ] keystore 作成済み
[ ] AAB ビルド完了
[ ] アプリアイコン 512×512px PNG 準備済み
[ ] スクリーンショット 2枚以上（各解像度）
[ ] 短い説明文（80字以内）
[ ] 詳細説明文（4,000字以内）
[ ] プライバシーポリシー URL（GitHub Pages で公開済み）
```

### 4-2. 申請手順

1. [Google Play Console](https://play.google.com/console) → 「アプリを作成」
2. アプリ名: `TrustCar`
3. 言語: 日本語
4. アプリ または ゲーム: **アプリ**
5. 無料 または 有料: **無料**（アプリ内課金あり）

**AAB のアップロード:**
1. リリース → 内部テスト → 新しいリリースを作成
2. `app-release.aab` をアップロード
3. リリースノート（日本語）を入力

**ストア掲載情報:**
1. メインストア掲載情報 → 説明・アイコン・スクリーンショット入力
2. カテゴリ: **車とナビ**
3. プライバシーポリシー URL: `https://zashii5793.github.io/trust-car-platform/privacy.html`

**コンテンツレーティング:**
1. ポリシー → アプリのコンテンツ → レーティングアンケートを回答
2. ユーザー作成コンテンツ（SNS投稿機能）あり → 申告する

**審査提出:**
1. 内部テスト → テスター追加 → 自分のアカウントでテスト
2. 問題なければ「本番」トラックへ昇格
3. 審査期間: 数時間〜数日

---

## Part 5: App Store 申請

### 5-1. 事前準備チェックリスト

```
[ ] Apple Developer Program 登録済み（$99/年）
[ ] Xcode インストール済み（Mac 必須）
[ ] iOS リリースビルド完了
[ ] アプリアイコン 1024×1024px PNG（アルファなし）
[ ] スクリーンショット（iPhone 6.5" / 5.5"・iPad Pro 12.9" ※任意）
[ ] 短い説明文（30字以内）
[ ] 詳細説明文（4,000字以内）
[ ] キーワード（100字以内）
[ ] プライバシーポリシー URL
[ ] サポート URL
```

### 5-2. App Store Connect でアプリ登録

1. [App Store Connect](https://appstoreconnect.apple.com) → 「マイ App」→ **+**
2. 入力:
   - プラットフォーム: iOS
   - 名前: `TrustCar`
   - 主要言語: 日本語
   - Bundle ID: `jp.trustcar.app`（Xcode でレジストリに登録済みのものを選択）
   - SKU: `trustcar-app-001`（任意の識別子）

### 5-3. ストア情報の入力

| 項目 | 入力内容 |
|------|---------|
| カテゴリ | 仕事効率化（または ライフスタイル） |
| 価格 | 無料 |
| プライバシーポリシー URL | `https://zashii5793.github.io/trust-car-platform/privacy.html` |
| サポート URL | `https://zashii5793.github.io/trust-car-platform/` |
| マーケティング URL | （任意） |
| App 内課金 | あり（RevenueCat で設定済みのサブスクリプション） |

### 5-4. ビルドのアップロード

```bash
# Xcode で Archive → Distribute → App Store Connect へアップロード
# または
flutter build ios --release
# 後は Xcode の Organizer から Upload
```

アップロード後、App Store Connect の「ビルド」セクションに反映されるまで10〜30分かかります。

### 5-5. 審査提出

1. すべての必須項目が入力済みであることを確認
2. 「審査へ提出」をクリック
3. 審査期間: 通常 **24〜48時間**（初回は長くなる場合あり）
4. リジェクト理由で多いもの:
   - プライバシーポリシーが不十分 → GitHub Pages URL を再確認
   - ガイドライン 4.2（機能が少ない）→ 主要機能の説明を充実させる
   - ガイドライン 3.1.1（アプリ内課金）→ RevenueCat 設定完了後に提出

---

## Part 6: SHA-1 登録（Google Sign-In を有効化）

現状 Google Sign-In は未設定です。使う場合は以下を実施:

```bash
# Android の debug 用 SHA-1 を取得
cd android && ./gradlew signingReport

# または keytool で直接
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android -keypass android
```

取得した SHA-1 を Firebase Console に登録:
1. Firebase Console → プロジェクトの設定 → 全般 → Android アプリ
2. 「フィンガープリントを追加」→ SHA-1 を貼り付け
3. `google-services.json` を再ダウンロードして `android/app/` に上書き

---

## よくある問題と対処

| 症状 | 原因 | 対処 |
|------|------|------|
| `google-services.json` が見つからない | Firebase 設定ファイル未配置 | Part 1-4 の手順で配置 |
| Google Sign-In が失敗する | SHA-1 未登録 | Part 6 を実施 |
| iOS ビルドがコード署名エラー | 証明書未設定 | Xcode → Signing & Capabilities |
| `flutter pub get` が失敗する | Flutter SDK バージョン不一致 | `flutter upgrade` を実行 |
| Firestore 権限エラー | ルール未デプロイ | `firebase deploy --only firestore:rules` |
| RevenueCat 購入できない | API キー未設定 | `HUMAN_TASKS.md` の RevenueCat 手順を参照 |
