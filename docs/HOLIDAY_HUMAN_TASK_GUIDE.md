# 休み中の人間タスク 実施ガイド

> 作成日: 2026-05-02  
> 対象: ローンチに必要な人間対応タスク（AIが代替不可なもののみ）  
> 想定所要時間: **合計 約5〜7時間**（Apple審査待ちを除く）

---

## ⚡ 全体スケジュール（推奨順序）

```
Day 1（1.5h）  ─ 即効・ブロッカー解除
  └─ GitHub Secrets + GitHub Pages + Firebase設定

Day 2（2.5h）  ─ ストア登録（審査に時間がかかるので早めに）
  └─ Apple Developer Program（$99）← 審査最大48h！先に出す
  └─ Google Play Developer（$25）
  └─ RevenueCatアカウント作成

Day 3（2h）    ─ ビルド・署名・RevenueCat設定
  └─ Android keystore作成
  └─ iOS証明書（Mac必要）
  └─ Cloud Functions deploy（Firebase Blaze移行後）
  └─ RevenueCat Product ID登録

任意（1h）     ─ 実機テスト（OCR品質確認）
```

---

## 🔴 P0 — Day 1 午前（30分）ブロッカー

### [P0-1] GitHub Secrets `GOOGLE_SERVICES_JSON` 登録
**所要時間**: 10分  
**前提条件**: GitHubリポジトリのOwner権限

```
1. https://github.com/zashii5793/trust-car-platform/settings/secrets/actions を開く
2. 「New repository secret」をクリック
3. Name: GOOGLE_SERVICES_JSON
4. Value: android/app/google-services.json の中身をそのまま貼り付け
5. 「Add secret」をクリック
```

> ✅ これでGitHub Actions の Android CI ビルドが通るようになる

---

## 🟠 P1 — Day 1 午後（1時間）ローンチ前必須

### [P1-1] GitHub Pages 有効化
**所要時間**: 5分  
**前提条件**: GitHubリポジトリのOwner権限

```
1. https://github.com/zashii5793/trust-car-platform/settings/pages を開く
2. Source: 「Deploy from a branch」を選択
3. Branch: main / フォルダ: /docs/web を選択（または /docs）
4. 「Save」をクリック
5. 数分後に以下URLでアクセスできることを確認:
   https://zashii5793.github.io/trust-car-platform/
   https://zashii5793.github.io/trust-car-platform/privacy.html
   https://zashii5793.github.io/trust-car-platform/terms.html
```

> ✅ プライバシーポリシー・利用規約URLが確定する（ストア申請に必要）  
> ⚠️ HTMLファイルは `docs/web/` に生成済み。追加作業不要

---

### [P1-2] Firebase Authentication 設定確認
**所要時間**: 5分

```
1. https://console.firebase.google.com/ → trust-car-platform プロジェクト
2. 左メニュー「Authentication」→「Sign-in method」タブ
3. 「メール/パスワード」が「有効」になっているか確認
   → 無効なら「有効にする」トグルをONにして保存
4. 「Google」サインインも確認（オプション）
```

---

### [P1-3] Firebase Crashlytics 有効化
**所要時間**: 5分

```
1. Firebase Console → trust-car-platform プロジェクト
2. 左メニュー「Crashlytics」
3. 「使ってみる」ボタンをクリック
4. 「次のステップ」に従ってSDK確認（コードは追加済みなので不要）
5. ダッシュボードが表示されれば完了
   ※ 実際のクラッシュデータは最初のリリースビルド実行後に表示される
```

---

### [P1-4] Firebase Blaze Plan 移行 ← Cloud Functions Deployに必要
**所要時間**: 10分  
**費用**: 従量課金（月$10未満に抑えられる。予算アラート設定で管理）

```
1. Firebase Console → プロジェクト設定 → 使用量と請求
2. 「Spark」→「Blaze」にアップグレード
3. Googleアカウントに紐付いたクレジットカードを設定
4. 予算アラートを $10/月 で設定（推奨）
   → Google Cloud Console → 予算とアラート → 予算を作成
```

> ✅ これで Cloud Functions (RevenueCat Webhook) がデプロイできる

---

### [P1-5] Cloud Functions デプロイ
**所要時間**: 15分  
**前提条件**: [P1-4] Firebase Blaze 移行完了・Node.js・Firebase CLIインストール済み

ローカルのターミナルで実行:
```bash
# Firebase CLI がなければインストール
npm install -g firebase-tools

# ログイン
firebase login

# プロジェクトルートで実行
cd trust-car-platform

# RevenueCat Webhook シークレットを設定（任意の長い文字列を設定）
firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET
# → プロンプトが出るので、ランダムな文字列を入力（例: openssl rand -hex 32 で生成）

# デプロイ
firebase deploy --only functions
```

デプロイ後に表示される URL をメモ:
```
✓  functions[onRevenueCatWebhook]: Deployed
   → https://asia-northeast1-trust-car-platform.cloudfunctions.net/onRevenueCatWebhook
```

> ✅ RevenueCat の Webhook 設定でこのURLを使う（Day 3 の [P2-4] で設定）

---

## 🟡 P1 — Day 2（2.5時間）ストア登録（審査あり・早めに！）

### [P1-6] Apple Developer Program 登録 ⚠️ 審査最大48時間
**所要時間**: 30分（手続きのみ）  
**費用**: $99/年（≒約¥15,000）  
**前提条件**: Apple ID・クレジットカード  
**⚠️ 最優先！ 審査に最大2日かかる**

```
1. https://developer.apple.com/programs/enroll/ を開く
2. 「Start your enrollment」→ Apple ID でログイン
3. 個人: 「Individual」を選択
   法人: 「Organization」→ D-U-N-S番号が必要（別途取得に1週間）
4. 情報入力 → クレジットカード決済（$99）
5. メールで確認リンクが届く（24〜48時間）
6. 承認後: https://developer.apple.com/ → 「Account」でログイン確認
```

---

### [P1-7] Google Play Developer 登録
**所要時間**: 30分  
**費用**: $25（一回払い）  
**前提条件**: Googleアカウント・クレジットカード

```
1. https://play.google.com/console/ を開く
2. 「今すぐ開始」→ Googleアカウントでログイン
3. 「デベロッパーとして登録」→ 情報入力
4. $25 を支払い（クレジットカード）
5. アカウント確認メールが届く（数時間〜1日）
6. Play Console が使えるようになったら確認
```

---

### [P1-8] RevenueCat アカウント作成
**所要時間**: 20分  
**費用**: 無料（月収$2,500まで）  
**前提条件**: なし（App Store/Play Console は後でも設定可）

```
1. https://app.revenuecat.com/signup を開く
2. メールアドレスで登録（またはGitHubアカウント連携）
3. 「New Project」→ プロジェクト名: TrustCar
4. 「Add App」→ 「Apple App Store」を選択
   - App Name: TrustCar
   - Bundle ID: jp.trustcar.app
   - App Store Connect API Key: [P2-1] で取得後に設定
5. 「Add App」→「Google Play Store」を選択
   - Package Name: jp.trustcar.app
   - Google Play Service Account Key: [P2-1] で取得後に設定
6. 「API Keys」タブ → Public SDK Key をメモ（アプリに設定する値）
   例: appl_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

> ✅ SDK Key は `lib/services/revenue_cat_service.dart` の `_apiKey` 定数に設定（AIに依頼）

---

## 🟡 P2 — Day 3（2時間）ビルド・署名・RevenueCat設定

### [P2-1] App Store Connect でアプリ登録
**所要時間**: 30分  
**前提条件**: [P1-6] Apple Developer Program 承認済み

```
1. https://appstoreconnect.apple.com/ → 「マイ App」→「+」
2. 新規 App:
   - プラットフォーム: iOS
   - 名前: TrustCar - 愛車管理＆カーライフ
   - 言語: 日本語
   - バンドルID: jp.trustcar.app（Certificates, IDs & Profiles で先に登録が必要）
   - SKU: trustcar-app-2026
3. アプリ情報 → カテゴリ: ライフスタイル（主）/ 仕事効率化（副）
4. プライバシーポリシーURL:
   https://zashii5793.github.io/trust-car-platform/privacy.html
5. サポートURL:
   https://zashii5793.github.io/trust-car-platform/
6. 説明文を docs/STORE_METADATA.md からコピー

App Store Connect API Key の作成（RevenueCat連携用）:
1. https://appstoreconnect.apple.com/access/api
2. 「+」→ 名前: RevenueCat / 役割: Admin
3. .p8ファイルをダウンロード（Key IDとIssuer IDをメモ）
4. RevenueCat Dashboard → Apps → Apple → API Key に設定
```

---

### [P2-2] Google Play Console でアプリ登録
**所要時間**: 30分  
**前提条件**: [P1-7] Google Play Developer 承認済み

```
1. https://play.google.com/console/ → 「アプリを作成」
2. アプリ名: TrustCar - 愛車管理＆カーライフ
3. デフォルト言語: 日本語
4. アプリ or ゲーム: アプリ
5. 無料 or 有料: 無料
6. ストアの掲載情報 → docs/STORE_METADATA.md の内容をコピー
7. プライバシーポリシー URL:
   https://zashii5793.github.io/trust-car-platform/privacy.html

Google Play Service Account（RevenueCat連携用）:
1. Google Cloud Console → IAM とサービスアカウント
2. 「サービスアカウントを作成」→ 名前: revenuecat-service
3. 役割: 編集者
4. 「キーを作成」→ JSON をダウンロード
5. Play Console → 設定 → API アクセス → サービスアカウントを連携
6. RevenueCat Dashboard → Apps → Google Play → Service Account に設定
```

---

### [P2-3] RevenueCat Product ID 登録
**所要時間**: 30分  
**前提条件**: [P2-1][P2-2] でアプリ登録完了

**App Store Connect でサブスクリプション作成:**
```
1. App Store Connect → アプリ → App内課金 → サブスクリプション → 「+」
2. 以下のProduct IDで作成:
   - trustcar_btob_standard_monthly   参照名: BtoBスタンダード月額  価格: ¥3,980
   - trustcar_btob_premium_monthly    参照名: BtoBプレミアム月額    価格: ¥9,800
   - trustcar_btob_enterprise_monthly 参照名: BtoBエンタープライズ  価格: ¥14,800
3. 各プランの説明文を入力（日本語）
4. サブスクリプショングループ: 「TrustCar BtoBプラン」を作成して紐付け
```

**Google Play Console でサブスクリプション作成:**
```
1. Play Console → アプリ → 収益化 → 定期購入 → 「定期購入を作成」
2. 上記と同じProduct IDで作成（価格は自動換算されるので確認）
```

**RevenueCat でOfferings設定:**
```
1. RevenueCat Dashboard → Offerings → 「+」
2. Offering ID: default
3. Packages を追加:
   - $rc_monthly → trustcar_btob_standard_monthly を紐付け
   - premium    → trustcar_btob_premium_monthly を紐付け
   - enterprise → trustcar_btob_enterprise_monthly を紐付け
4. Entitlements を作成:
   - btob_standard  → trustcar_btob_standard_monthly, premium, enterprise に紐付け
   - btob_premium   → trustcar_btob_premium_monthly, enterprise に紐付け
   - btob_enterprise → trustcar_btob_enterprise_monthly に紐付け
```

---

### [P2-4] RevenueCat Webhook 設定
**所要時間**: 10分  
**前提条件**: [P1-5] Cloud Functions デプロイ済み

```
1. RevenueCat Dashboard → プロジェクト → Integrations → Webhooks
2. 「+ New Webhook Endpoint」
3. URL: https://asia-northeast1-trust-car-platform.cloudfunctions.net/onRevenueCatWebhook
4. Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET に設定した文字列>
5. Events: すべてにチェック（または INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, BILLING_ISSUE）
6. 「Send test」で疎通確認 → Firebase Cloud Functions のログで受信確認
```

---

### [P2-5] Android Keystore 作成
**所要時間**: 10分  
**⚠️ このファイルは絶対に紛失しないこと（Googleストア更新に永続的に必要）**

```bash
# ターミナルで実行（Javaが必要）
keytool -genkey -v \
  -keystore ~/trustcar-release.keystore \
  -alias trustcar \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000

# 入力を求められる:
# - キーストアのパスワード（強力なものを設定・メモ必須）
# - 氏名・組織・都市・国（Japanなら JP）

# android/key.properties に記載（.gitignore済み）
cat > android/key.properties << EOF
storePassword=<設定したパスワード>
keyPassword=<設定したパスワード>
keyAlias=trustcar
storeFile=<keystoreの絶対パス>
EOF
```

> ✅ 作成後: AIに `android/app/build.gradle` のsigning設定を依頼

---

### [P2-6] iOS 証明書・プロビジョニングプロファイル作成
**所要時間**: 30分  
**前提条件**: [P1-6] Apple Developer Program 承認済み・**Mac必要**

```
1. Xcode → Preferences（⌘,）→ Accounts → Apple ID でログイン
2. trust-car-platform プロジェクトを Xcode で開く
3. Runner → Signing & Capabilities:
   - Team: 登録した Apple Developer アカウントを選択
   - Bundle Identifier: jp.trustcar.app
   - 「Automatically manage signing」をON
4. Xcode が自動で証明書・プロファイルを生成
5. Product → Archive → Validate App → Distribute App でテスト
```

---

## 📱 任意 — 実機テスト（OCR品質確認）

### [OPT-1] 車検証OCR実機テスト
**所要時間**: 30分  
**参照**: `docs/REAL_DATA_VALIDATION_CHECKLIST.md` § Phase 1

```
用意するもの:
  - 手元の実際の車検証（旧様式A4 と 新様式ICカード+記録事項の両方推奨）
  - テスト端末（iOS or Android）

確認内容（10シナリオ中 V-01〜V-05 を優先）:
  [ ] 登録番号（ナンバープレート）が正しく読み取れるか
  [ ] 車台番号・型式・車名が読み取れるか
  [ ] 有効期間の日付が正しく変換されるか（令和→西暦）
  [ ] 新様式の「記録事項」A4別紙はOCRで読み取れるか

フィードバック先: AIに報告 → 精度改善実装を依頼
```

---

### [OPT-2] 整備請求書OCR実機テスト
**所要時間**: 30分  
**参照**: `docs/REAL_DATA_VALIDATION_CHECKLIST.md` § Phase 2

```
用意するもの:
  - 実際の整備請求書（オイル交換・車検など 2〜3枚）

確認内容:
  [ ] 日付・合計金額が正しく読み取れるか
  [ ] 整備種別（オイル交換など）が推定されるか
  [ ] 走行距離が読み取れるか（記載がある場合）
```

---

## ✅ タスク進捗チェックリスト

| # | タスク | 優先度 | 時間 | 費用 | 完了 |
|---|--------|--------|------|------|------|
| P0-1 | GitHub Secrets 登録 | P0 | 10分 | 無料 | [ ] |
| P1-1 | GitHub Pages 有効化 | P1 | 5分 | 無料 | [ ] |
| P1-2 | Firebase Auth 確認 | P1 | 5分 | 無料 | [ ] |
| P1-3 | Firebase Crashlytics 有効化 | P1 | 5分 | 無料 | [ ] |
| P1-4 | Firebase Blaze 移行 | P1 | 10分 | 従量課金 | [ ] |
| P1-5 | Cloud Functions デプロイ | P1 | 15分 | 無料 | [ ] |
| P1-6 | Apple Developer 登録 ⚠️先に | P1 | 30分 | $99/年 | [ ] |
| P1-7 | Google Play Developer 登録 | P1 | 30分 | $25 | [ ] |
| P1-8 | RevenueCat アカウント作成 | P1 | 20分 | 無料 | [ ] |
| P2-1 | App Store Connect アプリ登録 | P2 | 30分 | 無料 | [ ] |
| P2-2 | Google Play Console アプリ登録 | P2 | 30分 | 無料 | [ ] |
| P2-3 | RevenueCat Product ID 登録 | P2 | 30分 | 無料 | [ ] |
| P2-4 | RevenueCat Webhook 設定 | P2 | 10分 | 無料 | [ ] |
| P2-5 | Android Keystore 作成 | P2 | 10分 | 無料 | [ ] |
| P2-6 | iOS 証明書作成（Mac） | P2 | 30分 | 無料 | [ ] |
| OPT-1 | 車検証OCR 実機テスト | 任意 | 30分 | 無料 | [ ] |
| OPT-2 | 請求書OCR 実機テスト | 任意 | 30分 | 無料 | [ ] |

**合計（P0+P1+P2）**: 約5時間 / **費用**: $99+$25 = 約¥19,000

---

## 📞 完了後にAIに依頼すること

各タスク完了後、AIに以下を伝えると次の作業を進められます：

| 完了タスク | AIへの依頼 |
|-----------|-----------|
| RevenueCat SDK Key 取得 | 「RevenueCat SDK Key: appl_xxx を設定して」 |
| Android Keystore 作成 | 「android/app/build.gradle に signing設定を追加して」 |
| Cloud Functions デプロイ完了 | 「Webhook URLを確認して疎通テストして」 |
| OCRテスト結果 | 「車検証のXXXフィールドが読み取れなかった。改善して」 |
| Apple Developer 承認 | 「App Store Connect のBundle ID設定を手伝って」 |
