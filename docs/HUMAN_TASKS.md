# 人間が実施すべきタスク一覧

**最終更新**: 2026-06-13  
**前提**: AIが実装・テスト・コードプッシュまで完了済み。以下は **AIでは代替できない** 操作のみ。

---

## P0 — リリースブロッカー（今週中）

### 1. Firestoreセキュリティルールのデプロイ

**なぜ必要**: 以下のルールが追加済みで未デプロイ：
- 前セッション: `fleet_members`, `accessory_showcases`, `car_purchase_inquiries`, `safety_tips`, `shop_chains`
- 今セッション: `community_maintenance_trends`（読み取り=認証済み、書き込み=AdminSDKのみ）
- C2C凍結セッション（2026-06-18）: `accessory_showcases/{id}/comments` サブコレクション
  （読み取り=認証済み、作成/削除=投稿者本人のみ、更新=不可）。
  **未デプロイだと showcase コメントの投稿が全て弾かれる**。
本番反映しないと全ユーザーの書き込みがルールで弾かれる。また、`safety_tips`コレクションの複合インデックス（`isActive + publishedAt`, `isActive + category + publishedAt`）も追加済み。

**手順**:
```bash
# プロジェクトルートで実行
firebase deploy --only firestore:rules,firestore:indexes
```

**確認方法**:
- Firebase Console → Firestore → ルール → バージョン履歴で最新デプロイ日時を確認
- [Firestore Rules Simulator](https://console.firebase.google.com/) でテストリクエストを投げて動作確認

**所要時間**: 5分  
**前提条件**: `firebase login` 済み・プロジェクトオーナー権限

---

### 2. Firebase Authentication の本番有効化

**なぜ必要**: メールリンク認証・Google Sign-In を本番で有効にするにはFirebase Consoleの操作が必要。

**手順**:
1. Firebase Console → Authentication → Sign-in method
2. 以下を「有効」に設定:
   - **メール / パスワード**: 有効 ✅
   - **Google**: 有効 → SHA-1 フィンガープリントを追加（Androidの場合）
3. 承認済みドメインに本番ドメインを追加（Webの場合）

**所要時間**: 15分  
**前提条件**: Firebase Consoleのオーナー権限

---

## P2 — 任意（運用効率化）

### C2C凍結フラグの Remote Config 連携（任意）

**なぜ必要**: `FeatureFlag.c2cPartsMarketplace` の再開判断を、**アプリ再リリースなし**で
運用側から切り替えられるようにする。コード側の受け口（`FeatureFlagService` /
`RemoteFlagSource`）は実装済み・テスト済みで、デフォルトは no-op（ローカル定数のまま）。

**残りの作業（ネイティブ依存のため人間が実施）**:
1. `pubspec.yaml` に `firebase_remote_config` を追加し `flutter pub get`
   （Android/iOSのビルド確認が必要なため、CIの build ジョブで検証すること）
2. Firebase Console → Remote Config で `c2c_parts_marketplace`（Boolean, デフォルト `false`）を作成
3. `RemoteFlagSource` を Remote Config 実装に差し替え、`injection.dart` で注入:

```dart
class FirebaseRemoteFlagSource implements RemoteFlagSource {
  @override
  Future<Map<String, dynamic>> fetch() async {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setDefaults(const {'c2c_parts_marketplace': false});
    await rc.fetchAndActivate();
    return {'c2c_parts_marketplace': rc.getBool('c2c_parts_marketplace')};
  }
}

// injection.dart
locator.registerLazySingleton<FeatureFlagService>(
    () => FeatureFlagService(source: FirebaseRemoteFlagSource()));
```

**確認方法**: Remote Config で `true` に変更 → アプリ再起動でマーケットの
「パーツ」「マイ出品」タブが復活すること。

**所要時間**: 30分  
**前提条件**: Firebase Console + ネイティブビルド環境

---

### 3. google-services.json / GoogleService-Info.plist の配置（新端末ビルド時）

**なぜ必要**: `.gitignore` で管理外のため、新しいマシンでビルドする際に再配置が必要。

**手順**:
1. Firebase Console → プロジェクト設定 → マイアプリ
2. **Android**: `google-services.json` をダウンロード → `android/app/` に配置
3. **iOS**: `GoogleService-Info.plist` をダウンロード → `ios/Runner/` に配置

**所要時間**: 5分

---

## P1 — ローンチ前必須（2週間以内）

### 4. FCM（Firebase Cloud Messaging）サーバーキーの設定

**なぜ必要**: Push通知（車検アラート）はFCMサーバーキーなしに機能しない。

**手順**:
1. Firebase Console → プロジェクト設定 → Cloud Messaging → サーバーキー
2. サーバーキーをコピー
3. GitHub Secrets に `FCM_SERVER_KEY` として登録
4. iOS: APNs認証キーを Firebase Console にアップロード（Developer Accountが必要）

**所要時間**: 30分（APNs設定含む）  
**前提条件**: Apple Developer Account・Firebase Consoleオーナー権限

---

### 5. iOS: Apple Developer Account でのApp ID・証明書設定

**なぜ必要**: TestFlight配布・App Store申請に必要。AIではApple Developer Consoleを操作できない。

**手順**:
1. [Apple Developer Console](https://developer.apple.com/account/) → Certificates, Identifiers & Profiles
2. App ID 登録: `com.trustcar.platform`（`Bundle ID` を `ios/Runner.xcodeproj` と一致させること）
3. Distribution Certificate の作成（期限切れ確認）
4. Provisioning Profile の作成（App Store Distribution用）
5. Xcode → Signing & Capabilities → Team 設定

**所要時間**: 1〜2時間（初回）  
**前提条件**: Apple Developer Program（年間$99）への加入

---

### 6. Android: キーストアの生成とリリースビルド設定

**なぜ必要**: Google Play Store への申請にはリリース署名が必要。

**手順**:
```bash
# キーストア生成（1回だけ実施・紛失厳禁）
keytool -genkey -v -keystore release.keystore \
  -alias trust-car-platform \
  -keyalg RSA -keysize 2048 -validity 10000
```

2. `android/key.properties` に以下を記述（gitignore済み）:
```properties
storePassword=<パスワード>
keyPassword=<パスワード>
keyAlias=trust-car-platform
storeFile=../../release.keystore
```

3. `android/app/build.gradle` のリリースビルド設定確認（AIが設定済みか確認）

**所要時間**: 30分  
**重要**: `release.keystore` は厳重保管（紛失するとアプリ更新不可）

---

### 7. RevenueCat のAPIキー設定

**なぜ必要**: プレミアムプラン・フリートエンタープライズのサブスクリプション課金に必要。

**手順**:
1. [RevenueCat Dashboard](https://app.revenuecat.com/) でアカウント作成
2. アプリを登録（iOS・Android）
3. Public APIキーをコピー
4. `.env` ファイルまたは GitHub Secrets に `REVENUE_CAT_API_KEY_IOS` / `REVENUE_CAT_API_KEY_ANDROID` として登録
5. App Store Connect / Google Play Console でサブスクリプション商品を作成

**所要時間**: 2〜3時間（商品作成含む）  
**前提条件**: App Store Connect / Google Play Console のアカウント

---

### 8. 実機テスト（iOS / Android）

**なぜ必要**: エミュレーターでは再現しない問題（カメラ・GPS・ビープ通知・バイオ認証）の確認が必要。

**確認必須項目**:
- [ ] 車検証OCRカメラが起動する
- [ ] GPS位置情報で近くの整備工場が距離順に並ぶ
- [ ] Push通知が届く（FCM設定後）
- [ ] Google Sign-In が動作する
- [ ] 画像のアップロード（Firebase Storage）が動作する
- [ ] 整備記録の入力→保存→一覧表示が動作する
- [ ] 個人情報（車検証の内容）が適切に暗号化されている

**所要時間**: 半日（2台以上で確認推奨）

---

### 9. Firestore バックアップ設定

**なぜ必要**: 本番データの誤削除リスクに備える。AIではFirebase Console操作不可。

**手順**:
1. Firebase Console → Firestore → バックアップとエクスポート
2. 自動バックアップを「毎日」に設定
3. Cloud Storage バケットを指定（`gs://trust-car-backup-2026` 等）
4. 保持期間: 30日

**所要時間**: 15分  
**費用**: Cloud Storage のストレージ費用（目安: 月〜$5）

---

### 10. 安全運転情報（SafetyTip）の初期シードデータ登録

**なぜ必要**: SafetyTipServiceはCloud Functionsまたは管理者のみが書き込み可能。現時点では画面に何も表示されない。

**シードスクリプト実装済み**: `scripts/seed_safety_tips.js`（6件のサンプルデータ）

**手順**:
```bash
# 1. 依存パッケージのインストール
cd /path/to/trust-car-platform
npm install firebase-admin

# 2. Emulator で動作確認（オプション）
firebase emulators:start --only firestore
node scripts/seed_safety_tips.js --dry-run   # データ確認のみ
node scripts/seed_safety_tips.js --emulator  # Emulatorに書き込み

# 3. 本番に登録
export GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json
node scripts/seed_safety_tips.js
```

**所要時間**: 10分（スクリプト実行のみ）  
**前提条件**: Firebase サービスアカウントJSON（Firebase Console → プロジェクト設定 → サービスアカウント）

---

### 11. コミュニティトレンドの初期シードデータ登録

**なぜ必要**: 主要車種（プリウス・N-BOX・リーフ・フィット・ヴォクシー）のトレンドデータが空だと車両詳細画面の「コミュニティの傾向」セクションに何も表示されない。

**シードスクリプト実装済み**: `scripts/seed_community_trends.js`（5車種 × 5〜6メンテタイプ）

**手順**:
```bash
# 1. 依存パッケージのインストール（seed_safety_tips.js と共有）
npm install firebase-admin

# 2. Emulator で動作確認（オプション）
node scripts/seed_community_trends.js --dry-run   # データ確認のみ
node scripts/seed_community_trends.js --emulator  # Emulatorに書き込み

# 3. 本番に登録
export GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json
node scripts/seed_community_trends.js
```

**所要時間**: 10分（スクリプト実行のみ）  
**前提条件**: Firebase サービスアカウントJSON（同上）  
**注意**: ユーザーが整備記録を登録するたびに自動的にデータが蓄積されるため、シードデータはあくまで初期の「呼び水」として機能する。

---

### 12. 整備工場（Shop）の初期シードデータ登録【重要・コア機能③の前提】

**なぜ必要**: 工場連携（一覧→詳細→問い合わせ→スレッド・近い順ソート・店舗比較）はコードが完備しているが、**工場データがほぼゼロだと機能全体が空回り**する。テストユーザーが「工場に問い合わせる」という主要ユースケースを体験できない。

**シードスクリプト実装済み**: `scripts/seed_shops.js`
- 実在提携候補1件（タカヤモーター）+ テスト用架空サンプル6件（`demo_*`）
- サンプル6件は全国主要都市にGeoPoint・評価・レビュー数・サービスを設定済みで、**近い順ソート・店舗比較が即動作**する

**手順**:
```bash
npm install firebase-admin
node scripts/seed_shops.js --dry-run    # 登録内容の確認
node scripts/seed_shops.js --emulator   # Emulatorで動作確認

export GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json
node scripts/seed_shops.js              # 本番登録
```

**本番投入前の必須確認**:
- [ ] `demo_*` の架空店舗は**本番リリース前に削除または実店舗データへ差し替え**（実在の事業者ではないため）
- [ ] タカヤモーターの `phone` / `address` / `location` などTODO項目を正式情報で埋める
- [ ] `firestore.rules` の `shops` コレクション読み取り権限を確認（認証済みユーザーが一覧を読めること）

**所要時間**: 15分（スクリプト実行）+ 実店舗データ整備は別途

---

## P2 — ローンチ後でも可（バックログ）

### 12. App Store Connect でのアプリ審査申請

**手順**:
1. App Store Connect → マイApp → 新バージョン追加
2. スクリーンショット追加（iPhone 6.7" / iPad 12.9"）
3. プライバシー情報（Privacy Nutrition Label）の入力
4. 年齢制限の設定
5. 審査申請（通常3〜5営業日）

**所要時間**: 2〜3時間（スクリーンショット撮影含む）

---

### 13. Google Play Console でのアプリ申請

**手順**:
1. Google Play Console → アプリを作成
2. APKまたはAABをアップロード
3. コンテンツレーティングのアンケートに回答
4. ターゲット国の設定
5. 審査申請（通常3〜7営業日）

**所要時間**: 2〜3時間

---

### 14. プライバシーポリシー・利用規約の法的レビュー

**なぜ必要**: 車検証・個人情報を扱うため、弁護士による最終確認が推奨される。

- 個人情報保護法の遵守確認（特に車検証のOCRデータ）
- 位置情報の利用目的の明記
- 整備工場への情報提供の同意文言
- データ削除リクエストへの対応ポリシー

**所要時間**: 弁護士費用次第（目安: 3〜5万円）

---

### ~~15. 「車検完了」クイックアクション の実装依頼~~

**[実装済み 2026-06-13]**: 車両詳細画面に「車検完了」ボタン（`inspection_complete_btn`）を追加。タップ → 新しい満了日を選択 → `legalInspection24` 整備記録を自動追加。テスト5件済み。

---

### 16. Firebase App Check の有効化

**なぜ必要**: Bot・不正アクセスからFirestoreを保護する。本番環境推奨。

**手順**:
1. Firebase Console → App Check
2. Android: Play Integrity 有効化
3. iOS: DeviceCheck 有効化
4. アプリコードに App Check 初期化を追加（AIに依頼可）

**所要時間**: 1時間

---

## チェックリスト（ローンチ前の確認）

- [ ] P0-1: Firestore ルールデプロイ
- [ ] P0-2: Firebase Authentication 有効化
- [ ] P0-3: google-services.json / GoogleService-Info.plist 配置
- [ ] P1-4: FCM サーバーキー設定
- [ ] P1-5: iOS App ID・証明書設定
- [ ] P1-6: Android キーストア生成
- [ ] P1-7: RevenueCat API キー設定
- [ ] P1-8: 実機テスト（iOS・Android）
- [ ] P1-9: Firestore バックアップ設定
- [ ] P1-10: SafetyTip 初期シードデータ登録（`node scripts/seed_safety_tips.js`）
- [ ] P1-11: コミュニティトレンド初期シードデータ登録（`node scripts/seed_community_trends.js`）

---

*本ドキュメントはセッション記録から自動生成されました。AIが実施可能な作業（コード実装・テスト・静的解析）はここに含まれていません。*
