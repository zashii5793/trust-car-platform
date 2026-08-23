# テストユーザー配布（2026年8月最終週）— 人間側の作業一覧と手順

**目的**: 来週、テストユーザーに TrustCar を実際に触ってもらう。
**対象読者**: 人間（Firebase Console / GitHub Settings / Apple・Google の各コンソールなど、AI から操作できない領域の担当）。
**データ環境**: 本番 Firebase プロジェクト `trust-car-platform` をそのまま使う（決定済み）。
**ストア公開は対象外**。ストア申請までを見据えた全量は `docs/HUMAN_TASKS.md` を参照。

検証状態の表記は `docs/HUMAN_TASKS.md` と同じ。
`[実測]` = 実際に確認した / `[コード検証済]` = コードを読んで確認した / `[要確認]` = 人間の確認が必要。

---

## 0. 結論：来週は「Web版」を本命、「Android実機」を並走。iOSは間に合わない

| レーン | 来週の可否 | 人間の作業量 | 触れる範囲 |
|---|---|---|---|
| **A. Web版（GitHub Pages）** | **可能。最短で当日** | **合計 約1.5時間** | OCR・プッシュ通知以外のほぼ全機能 |
| **B. Android 実機（APK 直配布 / Play 内部テスト）** | 可能（半日〜1日） | 約3〜4時間 | 全機能（OCR・GPS・カメラ含む） |
| C. iOS（TestFlight） | **来週は非推奨** | 1〜2日＋審査待ち | 全機能 |

**iOS を外す理由（実測）**:
Firebase に登録されている iOS アプリの Bundle ID が `com.example.trustCarPlatform` で、
実際のアプリの `jp.trustcar.app` と食い違っています。**この状態では iOS は起動すらしません**（白画面）。

```
firebase apps:list
  trust_car_platform (android)  → package_name: com.example.trust_car_platform
  trust_car_platform (ios)      → BUNDLE_ID:    com.example.trustCarPlatform
  trust_car_platform (web)      → 問題なし
```

Firebase の iOS アプリは**あとから Bundle ID を変更できません**。新規登録が必要です。
そこに Apple Developer の承認・証明書・Beta Review が重なるため、来週の枠には収まりません。

**Android も同じ食い違いがあります**が、こちらは新規登録して `google-services.json` を差し替えるだけで解消します（レーンB-1）。

---

## レーンA：Web版を出す（本命・合計 約1.5時間）

公開URL: `https://zashii5793.github.io/trust-car-platform/`

### A-1. GitHub Pages の公開元を「GitHub Actions」に変える `[実測: 未対応]`

**これが最大の詰まり**です。CI（Web Preview）はビルドもデプロイも成功していますが、
**公開されているのはアプリではなく `docs/` の Jekyll サイト**です。

```
GET https://api.github.com/repos/zashii5793/trust-car-platform/pages
  "build_type": "legacy"
  "source": { "branch": "main", "path": "/docs" }
```

Pages の設定が「main ブランチの /docs を Jekyll で公開」のままなので、
push のたびに Jekyll ビルドが Actions のデプロイを上書きしています。

**手順**:
1. GitHub → リポジトリ `zashii5793/trust-car-platform` → **Settings** → **Pages**
2. Build and deployment → Source を `Deploy from a branch` から **`GitHub Actions`** に変更
3. Actions タブ → **Web Preview** → `Run workflow`（ブランチ: `main`）
4. 2〜3分後に `https://zashii5793.github.io/trust-car-platform/` を開き、
   ドキュメントサイトではなく**アプリのログイン画面**が出ることを確認

**所要時間**: 5分
**副作用**: 現在公開中の以下のURLが 404 になります。
- `https://zashii5793.github.io/trust-car-platform/web/privacy.html`
- `https://zashii5793.github.io/trust-car-platform/web/terms.html`

規約・プライバシーポリシーは**アプリ内画面としても実装済み**（`lib/screens/settings/`）なので
テストユーザーの利用には影響しません。ただしストア申請では外部URLが要るため、
**AI 側で `web/` 配下に同梱し直します**（下記「AI側で並行して進めること」）。

---

### A-2. Firebase Authentication の承認済みドメインに github.io を追加 `[要確認]`

**未対応だとログインできません。** Firebase Auth は許可したドメインからのみ認証を受け付けます。

**手順**:
1. Firebase Console → `trust-car-platform` → **Authentication** → **Settings** → **承認済みドメイン**
2. `zashii5793.github.io` を追加
3. 同じ画面の **Sign-in method** で **メール/パスワード** が「有効」であることを確認
4. Google ログインも使わせるなら、Google プロバイダを有効化（Web は SHA-1 不要）

**所要時間**: 10分
**確認方法**: 公開URLで新規登録 → ログインまで通ること。
通らない場合はブラウザのコンソールに `auth/unauthorized-domain` が出ます。

---

### A-3. Firestore ルールとインデックスを本番へデプロイ `[要確認]`

**未デプロイの機能は、画面は出るがデータが一切読めません**（ルールで全部弾かれる）。
`firestore.rules` は現在 823 行、`firestore.indexes.json` も更新が入っています。
前回デプロイ以降の差分は Console のバージョン履歴でしか判定できません。

**手順**:
```bash
cd ~/development/trust_car_platform
git checkout main && git pull

# 1) ルールのローカル検証
cd test/rules && npm install && npm test && cd ../..

# 2) 中身の差分を目視（Console のバージョン履歴と突き合わせ）
firebase deploy --only firestore:rules --dry-run

# 3) 本番反映
firebase deploy --only firestore:rules,firestore:indexes
```

4. Firebase Console → Firestore → ルール → **バージョン履歴**で反映時刻を確認
5. インデックスは「構築中」から「有効」に変わるまで数分〜数十分。**テスト開始前に必ず「有効」を確認**

**所要時間**: 10分（＋インデックス構築の待ち時間）
**備考**: この端末の `firebase` CLI はログイン済みです。**AI に代行させることも可能**ですが、
本番反映なので実行前に必ず声をかけてください。

---

### A-4. 本番データの棚卸し（テストユーザーに見せてよい状態にする） `[要確認]`

本番プロジェクトをそのまま使うため、**見せてはいけないデータが残っていないか**の確認が必須です。

**手順**:
1. **架空の整備工場を消すか差し替える**
   Firestore → `shops` コレクションで `demo_` から始まる ID を確認。
   実在しない事業者なので、テストユーザーに見せる前に削除するか実店舗データに差し替える。
2. **タカヤモーターの情報を正式なものにする**
   `phone` / `address` / `location` が仮値のままなら埋める。
3. **ペルソナ用の Auth ユーザーが本番にいないか確認する（重要）**
   Firebase Console → Authentication → Users で `persona.a@example.com` 〜 `persona.i@example.com` を検索。
   **これらは共通パスワード `password123` です。本番に存在すると、公開URLから誰でもログインできます。**
   いた場合は削除:
   ```bash
   cd scripts
   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
   node seed_personas.js --delete-auth
   node seed_full_experience.js --delete
   node seed_fleet_year.js --delete
   ```
4. **見せたい初期データを投入する**（空の画面ばかりだと評価できないため）
   ```bash
   node seed_safety_tips.js        # 安全運転情報 6件
   node seed_community_trends.js   # コミュニティトレンド 5車種
   ```

**所要時間**: 30分
**前提**: Firebase サービスアカウントキー（Console → プロジェクト設定 → サービスアカウント → 新しい秘密鍵を生成）

---

### A-5. テストユーザーのアカウント発行方針を決める `[意思決定]`

| 方針 | 内容 | 向き |
|---|---|---|
| **推奨: 自己サインアップ** | 公開URLから各自メールアドレスで新規登録 | 実際の登録体験まで検証できる。人数が増えても手間ゼロ |
| 事前発行 | こちらでアカウントを作って ID/PW を配る | 相手のITリテラシーが低い場合。ただし登録導線の検証ができない |

**自己サインアップを選ぶ場合の注意**: 公開URLは誰でも開けます。
URLを不特定多数に出さない運用（個別連絡でのみ配布）にしてください。
アクセス制限をかけたい場合は別途対応が必要なので、その旨を伝えてください。

**所要時間**: 15分（方針決定と、テストユーザーへの連絡）

---

### A-6. 問い合わせ先メールアドレスの実在確認 `[コード検証済]`

アプリ内のヘルプ画面に `support@trustcar.jp` が記載されています
（`lib/screens/settings/help_screen.dart`）。

- [ ] `support@trustcar.jp` が実際に受信できるか確認する
- [ ] 受信できないなら、実在する連絡先に差し替える（差し替え作業は AI に依頼可）

**所要時間**: 10分

---

### A-7. Google Maps の Web用APIキー（任意・後回し可） `[実測: 未設定]`

未設定でも**アプリは動きます**。地図が出ず、近隣工場が距離順のリスト表示にフォールバックするだけです。
地図をテスト対象に含めたい場合のみ実施してください。

**手順**:
1. Google Cloud Console → APIとサービス → 認証情報 → APIキー発行
2. **Maps JavaScript API** を有効化
3. キーの制限: HTTPリファラー `https://zashii5793.github.io/*`
4. GitHub → Settings → Secrets and variables → Actions → **`GOOGLE_MAPS_API_KEY_WEB`** を登録
5. Web Preview を再実行

**所要時間**: 1時間
**費用**: 地図表示は月10,000ロードまで無料枠内。念のため Google Cloud で予算アラートを設定。

---

## レーンB：Android 実機で配る（OCR・GPS・カメラを検証したい場合）

**Web版では OCR（車検証・請求書の読み取り）とプッシュ通知が一切動きません**
（`vehicle_certificate_ocr_service.dart` / `invoice_ocr_service.dart` の `isSupported` が Web では false）。
**この2つは TrustCar の中核機能**なので、評価してもらうならレーンB が要ります。

### B-1. Firebase に `jp.trustcar.app` の Android アプリを新規登録 `[実測: 未対応]`

現在登録されているのは `com.example.trust_car_platform` で、実際のアプリIDと違います。

```
android/app/build.gradle.kts      applicationId = "jp.trustcar.app"
android/app/google-services.json  package_name  = "com.example.trust_car_platform"   ← 不一致
```

**手順**:
1. Firebase Console → プロジェクト設定 → マイアプリ → **アプリを追加 → Android**
2. パッケージ名に **`jp.trustcar.app`** を入力して登録
3. `google-services.json` をダウンロードし、`android/app/` に上書き配置
4. **旧アプリ（`com.example.*`）は削除しない**。使わなくなるだけ。消すと紐づく設定の参照が切れる可能性あり

**所要時間**: 15分

---

### B-2. リリース署名用のキーストアを作る `[実測: 未作成]`

`android/key.properties` がありません。**この状態でリリースビルドを叩くとビルドが止まります**
（debug 鍵で黙って署名されないよう、`build.gradle.kts` 側で意図的にエラーにしてあります）。

**手順**:
```bash
# 1) キーストア生成（1回だけ。紛失するとアプリ更新が永久に不可能）
keytool -genkey -v -keystore ~/trustcar-release.keystore \
  -alias trust-car-platform \
  -keyalg RSA -keysize 2048 -validity 10000
```

2. `android/key.properties` を作成（`.gitignore` 対象。**コミットしないこと**）
```properties
storePassword=<パスワード>
keyPassword=<パスワード>
keyAlias=trust-car-platform
storeFile=/Users/zashii/trustcar-release.keystore
```

3. キーストアとパスワードをパスワードマネージャに保管

**所要時間**: 30分

---

### B-3. SHA-1 を Firebase に登録（Google ログインを使う場合）

**手順**:
```bash
# デバッグ用
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey \
  -storepass android -keypass android | grep SHA1
# リリース用
keytool -list -v -keystore ~/trustcar-release.keystore -alias trust-car-platform | grep SHA1
```
Firebase Console → プロジェクト設定 → Android アプリ（`jp.trustcar.app`）→ **フィンガープリントを追加** に両方登録
→ `google-services.json` を**再ダウンロードして差し替え**

**所要時間**: 15分

---

### B-4. ビルドして配る

**選択肢1: APK を直接渡す（推奨・審査なし）**
```bash
cd ~/development/trust_car_platform
flutter build apk --release
# 出力: build/app/outputs/flutter-apk/app-release.apk
```
Google Drive などに置いてリンクを配る。テストユーザー側は「提供元不明のアプリ」の許可が必要。
**手順を案内文に必ず書くこと**（Android 端末に不慣れな人はここで詰まります）。

**選択肢2: Play Console の内部テスト（配布は楽だが初回に手間）**
```bash
flutter build appbundle --release
# 出力: build/app/outputs/bundle/release/app-release.aab
```
Play Console → アプリを作成 → 内部テスト → AAB アップロード → テスター（メールアドレス）を登録。
**初回はアプリ登録・データセーフティフォーム・コンテンツレーティングの入力が必要**で、2〜3時間かかります。
来週だけの話なら**選択肢1で十分**です。

**所要時間**: 選択肢1なら1時間 / 選択肢2なら3時間

---

### B-5. 配る前に自分の実機で1周する `[未実施]`

**ビルドが通ることは、動くことの保証になりません**（iOS がまさにその状態でした）。
テストユーザーに渡す前に、最低限これだけは自分で確認してください。

- [ ] アプリが起動して最初の画面が出る
- [ ] 新規登録 → ログインができる
- [ ] 愛車を登録できる
- [ ] **車検証OCR**: 実物の車検証を撮影して、登録番号・車台番号・型式・満了日が入るか
- [ ] **請求書OCR**: 実際の請求書で、合計金額・日付・店舗名が取れるか
- [ ] GPS で近隣工場が距離順に並ぶ
- [ ] 写真のアップロードができる
- [ ] カメラ・位置情報の権限ダイアログが日本語で出る

**所要時間**: 1時間

---

## 意思決定が必要な項目（AIでは判断できない）

### D-1. 走行記録のバックグラウンド動作 `[コード検証済: 現在は止まる]`

運転中に画面をロックする、他アプリに切り替えると**記録が止まります**。

**推奨: A案（現状のまま出す）。** 画面に「記録中はアプリを開いたままにしてください」と明記して配る。
正式対応（iOS Background Modes / Android Foreground Service）はストア審査で用途説明を求められ、
リジェクトリスクが上がります。テストユーザー段階でやる価値は薄いです。

詳細は `docs/HUMAN_TASKS.md` の P2-12。

### D-2. C2C パーツマーケットは凍結のまま

`FeatureFlag.c2cPartsMarketplace` は既定で凍結（false）。テスト段階では**触らせない**推奨。
開けたくなったら Firebase Console → Remote Config で `c2c_parts_marketplace` を作成して切り替え（アプリ再配布不要）。

### D-3. テストユーザーに何を評価してほしいか

これが決まらないと、フィードバックが「なんとなく使いにくい」で終わります。
評価軸（例: 車検証OCRの精度 / 整備記録の入力の手間 / 工場検索の使い勝手）を2〜3個に絞ってください。
**案内文とテストシナリオのドラフトは AI 側で用意します**。

---

## 想定スケジュール

| 日 | 作業 | 担当 |
|---|---|---|
| 今日 | A-1（Pages切替）、A-2（承認済みドメイン） | 人間 15分 |
| 今日 | 公開URLでログイン〜愛車登録まで自分で通す | 人間 30分 |
| 今日〜明日 | A-3（ルール・インデックス本番デプロイ） | 人間（AI代行可） |
| 明日 | A-4（本番データ棚卸し・ペルソナAuth削除） | 人間 30分 |
| 明日 | B-1〜B-3（Firebase Androidアプリ登録・キーストア・SHA-1） | 人間 1時間 |
| 週末 | B-4（APKビルド）、B-5（実機1周・OCR確認） | 人間 2時間 |
| 週明け | A-5 の方針で案内文とURL/APKを配布 | 人間 |
| 期間中 | フィードバック回収と一次トリアージ | AI |

---

## AI側で並行して進めること（人間の作業ではありません）

- [x] **`web/privacy.html` / `web/terms.html` を同梱**（2026-08-23）
      Pages を GitHub Actions に切り替えても規約ページが残るようにした。
      新URL: `https://zashii5793.github.io/trust-car-platform/privacy.html` / `.../terms.html`
- [x] **アプリ内フィードバック機能を仕上げて配線**（2026-08-23）
      `feedback_screen.dart` ほか一式が未コミット・未配線のまま残っていたので、
      DI 登録（`injection.dart`）とプロフィール画面「サポート」への導線を追加。
      `firestore.rules` に `feedback` コレクションの規則（本人が書くだけ・誰も読めない）を追加し、
      ルールテスト10件を追加。全115件パス。
      **A-3（ルール本番デプロイ）を実施しないと、この機能は本番で動きません。**
- [ ] テストユーザー向けの案内文とテストシナリオのドラフト作成
- [ ] `support@trustcar.jp` が使えない場合の連絡先差し替え（A-6 の確認待ち）
- [ ] 走行記録画面への「アプリを開いたままにしてください」の明記（D-1 で A案を選んだ場合）
- [ ] 初回ガイド（`lib/widgets/getting_started_card.dart`）の配線。
      同じく未配線で残っているが、ホーム画面の既存オンボーディング
      （`_VehicleEmptyOnboarding` / `_InspectionSetupCard`）と役割が重なるため、
      どう統合するかは要判断。指示があれば進めます。

---

*最終更新: 2026-08-23*
