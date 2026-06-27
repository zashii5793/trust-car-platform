# 人間が実施すべきタスク一覧

**最終更新**: 2026-06-13  
**前提**: AIが実装・テスト・コードプッシュまで完了済み。以下は **AIでは代替できない** 操作のみ。

---

## P0 — リリースブロッカー（今週中）

### 1. Firestoreセキュリティルールのデプロイ

**なぜ必要**: 以下のルールが追加済みで未デプロイ：
- 前セッション: `fleet_members`, `accessory_showcases`, `car_purchase_inquiries`, `safety_tips`, `shop_chains`
- 今セッション: `community_maintenance_trends`（読み取り=認証済み、書き込み=AdminSDKのみ）
- C2C凍結セッション（2026-06-18〜）: `accessory_showcases/{id}/comments` サブコレクション
  （読み取り=認証済み、作成/削除=投稿者本人のみ、編集=投稿者本人のみ、
  いいね=`likeCount` ±1 のみ誰でも可、`comments/{id}/likes/{uid}` は本人のみ作成/削除）。
  さらに `comment_reports/{reportId}`（コメント通報＝作成は本人のみ・読取/更新/削除はサーバー専用）。
  **未デプロイだと showcase コメントの投稿・いいね・通報が全て弾かれる**。
本番反映しないと全ユーザーの書き込みがルールで弾かれる。また、`safety_tips`コレクションの複合インデックス（`isActive + publishedAt`, `isActive + category + publishedAt`）も追加済み。
- 事業性評価セッション（2026-06-19）: `inquiries` の複合インデックス `shopId + createdAt`（ASC）を追加済み。
  **未デプロイだと工場ダッシュボードの月次レポート（ROI可視化 #39）と月次件数チェックがクエリエラーになる**。

> ✅ **デプロイ前検証**: `cd test/rules && npm install && npm test` で Firestore/Storage の
> ルールを Emulator 検証できる（CI の "Storage & Firestore Rules Tests" でも自動実行）。
> デプロイ前にローカルで一度流すと安全。

#### デプロイ手順チェックリスト（ルール）
- [ ] `firebase login`（プロジェクトオーナー権限）
- [ ] `git pull`（最新の `firestore.rules` / `firestore.indexes.json` を取得）
- [ ] **ドライラン**: `firebase deploy --only firestore:rules --dry-run`（差分とコンパイル確認）
- [ ] `cd test/rules && npm test`（Emulator でルールテストが緑か）
- [ ] 本番反映: `firebase deploy --only firestore:rules,firestore:indexes`
- [ ] Firebase Console → Firestore → ルール → バージョン履歴で反映時刻を確認

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

### C2C凍結フラグの Remote Config パラメータ作成

**なぜ必要**: `FeatureFlag.c2cPartsMarketplace` の再開判断を、**アプリ再リリースなし**で
運用側から切り替えられるようにする。

**実装済み（コード・依存は完了）**:
- `firebase_remote_config 6.5.1` を追加（**`firebase_core` は 4.9.0 に固定**して、共有 Firebase iOS SDK
  ポッドの巻き上げ＝`cloud_firestore` の iOS ビルド破壊を回避）
- `FirebaseRemoteFlagSource`（`RemoteFlagSource` 実装）＋ `FeatureFlagService` を `injection.dart` に
  配線済み。起動時に `sync()` で Remote Config を取得し `AppConfig` に反映。未設定・取得失敗時は
  ローカル既定値（凍結）を維持（フェイルセーフ）

**残りの作業（人間が実施）**:
1. **Firebase Console → Remote Config** でパラメータ作成:
   - キー名: `c2c_parts_marketplace` / 型: Boolean / デフォルト: `false`（凍結のまま）
2. CI の **build-ios / build-android** が緑であることを確認（ネイティブビルド検証）
3. 動作確認: Remote Config で `true` に変更 → アプリ再起動でマーケットの
   「パーツ」「マイ出品」タブが復活すること

**注意**: 将来 `firebase_core` を上げる際は、`cloud_firestore` の iOS ネイティブコードと
Firebase iOS SDK の整合（CocoaPods）を必ず CI ビルドで確認すること。

**所要時間**: 15分  
**前提条件**: Firebase Console のオーナー権限

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

### 17. Google Maps Platform APIキーの発行・設定（#41 近隣検索の地図表示の前提）

**なぜ必要**: 近隣検索のGoogleMap連動（提携/非提携の網羅表示, Issue #41 / 評価書 §7.7）には Maps SDK のAPIキーとネイティブ設定が必須。コード実装の前提となる人手タスク。

**手順**:
1. Google Cloud Console → 該当プロジェクト → APIとサービス → 認証情報 → APIキー発行
2. 有効化するAPI（フェーズ別・コスト最適化のため最小限から）:
   - **フェーズ1a**: Maps SDK for Android / Maps SDK for iOS（地図表示＝Dynamic Maps）
   - **フェーズ1b（任意）**: Places API（非提携先の近隣検索。**従量課金が高いため要判断**）
3. APIキー制限（必須・漏洩対策）:
   - Android: パッケージ名＋SHA-1 で制限
   - iOS: Bundle ID で制限
   - 各キーで「使用するAPIのみ」に制限
4. アプリへの設定（ハードコード禁止）:
   - Android: `--dart-define=MAPS_API_KEY=...` ＋ `AndroidManifest.xml` の `manifestPlaceholders` 経由
   - iOS: `AppDelegate` で注入
5. Google Cloud で **予算アラート**を設定（無料枠超過の早期検知）

**コスト目安（2026年時点・要最新確認）**:
- 地図表示（Dynamic Maps, Essentials）: 月10,000ロードまで無料、超過後 約$7/1,000
- Places 近隣検索（Pro）: 無料枠5,000/月、超過後 高単価（約$25〜/1,000）
- → **フェーズ1a（地図＋提携ピンのみ）は無料枠内に収まりやすい。Places（1b）は1商圏限定＋キャッシュでコスト管理**

**所要時間**: 1〜2時間  
**前提条件**: Google Cloud プロジェクトのオーナー権限・課金有効化

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
- [ ] P0-1（再掲）: `inquiries: shopId + createdAt` 複合インデックスのデプロイ（#39 月次レポートの前提）
- [ ] P2-17: Google Maps Platform APIキー発行・設定（#41 近隣検索の地図表示の前提）

---

*本ドキュメントはセッション記録から自動生成されました。AIが実施可能な作業（コード実装・テスト・静的解析）はここに含まれていません。*
