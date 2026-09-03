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
| **A. Web版（Firebase Hosting）** | **可能。最短で当日** | **合計 約1時間** | OCR・プッシュ通知以外のほぼ全機能 |
| **B. Android 実機（APK 直配布）** | **可能。当日** | **約30分** | 全機能（OCR・GPS・カメラ含む） |
| C. iOS（TestFlight） | **来週は非推奨** | 1〜2日＋審査待ち | 全機能 |

> **2026-08-23 更新**: レーンBの前提だった Firebase のアプリ登録は済ませ、
> APK のビルドも CI に載せました。当初「3〜4時間」としていた作業は約30分です。

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

## レーンA：Web版を出す（本命・人間の作業は約1時間）

**2026-08-23 更新: 公開先を GitHub Pages から Firebase Hosting に変えました。**
人間の作業が2つ減ります。理由は A-1 に書きます。

公開URL: `https://trust-car-platform.web.app`

### A-1. Web版を Firebase Hosting へ公開する `[スクリプト化済み]`

**なぜ GitHub Pages をやめたか（実測）**

Firebase Auth は、許可したドメインからしかログインを受け付けません。
承認済みドメインを実際に問い合わせたところ、こうでした。

```
GET https://identitytoolkit.googleapis.com/v1/projects?key=<web APIキー>

  "authorizedDomains": [
    "localhost",
    "trust-car-platform.firebaseapp.com",
    "trust-car-platform.web.app"
  ]
```

`zashii5793.github.io` は入っていません。**GitHub Pages に出すと、画面は表示
されてもログインだけが `auth/unauthorized-domain` で失敗します。**

一方 `trust-car-platform.web.app` は**最初から承認済み**です。Firebase Hosting
に出せば、Console での追加作業なしにログインできます。あわせて、GitHub Pages の
公開元を切り替える作業（旧 A-1）も不要になります。

**手順**:

```bash
cd ~/development/trust_car_platform
./scripts/deploy_web.sh
```

ビルドから公開まで通しでやります。所要 3〜5分。
地図も出したい場合だけ、先に `export GOOGLE_MAPS_API_KEY_WEB=<キー>` してください（A-6）。

**確認**:
- [ ] `https://trust-car-platform.web.app` でログイン画面が出る
- [ ] 新規登録 → ログインまで通る
- [ ] `https://trust-car-platform.web.app/privacy.html` と `/terms.html` が開く

**判断が要る点**: 実行するとアプリが誰でも見られる場所に出ます。URLは推測しにくい
ものの、公開であることに変わりはありません。**自己サインアップを開けたままにするか、
配布先を絞るかを先に決めてください**（A-4）。

> GitHub Pages を使いたい場合は、Settings → Pages → Source を `GitHub Actions` に
> 変更したうえで、Firebase Console → Authentication → Settings → 承認済みドメインに
> `zashii5793.github.io` を追加してください。両方やらないとログインできません。

---

### A-2. docs/ の公開範囲 `[対応済み 2026-08-25]`

**この作業は終わっています。人間の作業はありません。**

GitHub Pages の公開元が「main ブランチの `/docs`」のままで、`docs/` 配下の Markdown が
Jekyll でHTML化され、誰でも読める状態でした。**Pages は停止済み**（全URLが404であることを実測）。

ただし **Pages を止めても、それだけでは足りませんでした。**
このリポジトリは public なので、ソースは GitHub 上でそのまま読めます。

```
https://raw.githubusercontent.com/zashii5793/trust-car-platform/main/docs/OPERATIONS_COST_ESTIMATE.md  → 200
```

Pages が配っていたのは「描画されたHTML」だけで、ソースは元から公開されていました。

**対応**: 金額・収益見込み・競合の評価を含む5本を
[trust-car-platform-internal](https://github.com/zashii5793/trust-car-platform-internal)（private）へ移しました。
技術ドキュメントは公開したままです。詳細は `docs/INTERNAL_DOCS.md`。

> **リポジトリごと private にする案は見送りました。**
> GitHub Actions の無料枠が月2,000分になるためです（public は無制限）。
> iOS ビルドは10倍課金で実測18分＝180分なので、月10回程度で枠を使い切ります。

**残っている問題**: 移したファイルは**git 履歴に残っています**。最新の状態から消えるだけで、
過去のコミットを辿れば読めます。完全に消すには履歴の書き換えと force push が要りますが、
未マージの PR が全て壊れます。すでに公開された情報として扱ってください。

---

### A-3. Firestore ルールとインデックスを本番へデプロイ `[要確認]`

**未デプロイの機能は、画面は出るがデータが一切読めません**（ルールで全部弾かれる）。
今回 `feedback` コレクションのルールを追加したので、**これをやらないと
アプリ内のフィードバック送信が失敗します**。

**手順**:
```bash
cd ~/development/trust_car_platform
git checkout main && git pull

# 1) ルールのローカル検証（Emulator を自動で起動します）
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
**前提**: 上のコマンドは main を見ています。**先に PR #149 をマージしてください。**

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

### A-6. Google Maps の Web用APIキー（任意・後回し可） `[実測: 未設定]`

未設定でも**アプリは動きます**。地図が出ず、近隣工場が距離順のリスト表示にフォールバックするだけです。
地図をテスト対象に含めたい場合のみ実施してください。

**手順**:
1. Google Cloud Console → APIとサービス → 認証情報 → APIキー発行
2. **Maps JavaScript API** を有効化
3. キーの制限: HTTPリファラー `https://trust-car-platform.web.app/*`
4. 公開時に渡す: `export GOOGLE_MAPS_API_KEY_WEB=<キー>` してから `./scripts/deploy_web.sh`

**所要時間**: 1時間
**費用**: 地図表示は月10,000ロードまで無料枠内。念のため Google Cloud で予算アラートを設定。

---


## レーンB：Android 実機で配る（OCR・GPS・カメラを検証したい場合）

**Web版では OCR（車検証・請求書の読み取り）とプッシュ通知が一切動きません**
（`vehicle_certificate_ocr_service.dart` / `invoice_ocr_service.dart` の `isSupported` が Web では false）。
**この2つは TrustCar の中核機能**なので、評価してもらうならレーンB が要ります。

### B-1. Firebase の Android アプリ登録 `[対応済み 2026-08-23]`

**この作業は終わっています。人間の作業はありません。**

登録されていたのは `com.example.trust_car_platform` だけで、実際のアプリID
`jp.trustcar.app` のアプリは存在していませんでした。`jp.trustcar.app` の
Android アプリを新規登録し、`google-services.json`・`firebase_options.dart`・
`ci.yml` の3か所を正しい値に差し替えてあります。

```
App ID:  1:31421119456:android:145b8b79b1d9e7cf80c985
API Key: AIzaSyDwjPzpdQqXFl4be7oE3n-yzcl6hoLv_Uw
```

旧 `com.example` のアプリは、紐づく参照が切れないよう残してあります（使われなくなるだけ）。

> **これがなぜ見逃されていたか**: `ci.yml` が `google-services.json` をその場で
> 書き起こしており、その中身が「com.example のアプリIDに、package_name だけ
> jp.trustcar.app と書いた」実在しない組み合わせでした。gradle の
> google-services プラグインは package_name しか照合しないため、
> **ビルドは通り、実行時にだけ壊れます。**

---

### B-2. APK の作りかた `[スクリプト化済み]`

**開発機に Android SDK が入っていません**（`flutter doctor` が
`Unable to locate Android SDK`）。手元でのビルドは、Android Studio を入れて
SDK を落とすところからになります。**GitHub Actions で作るほうが速いので、
そちらに寄せました。**

**手順**:
1. GitHub → Actions → **Test APK** → `Run workflow`
2. 3〜5分で完了。実行ページ下部の **Artifacts** から `trustcar-test-apk` をダウンロード
3. zip を展開して出てくる `.apk` を配布（保持期間は14日）

**所要時間**: 5分（待ち時間込み）
**前提**: **PR #149 をマージして、ワークフローが main に入っていること。**
`workflow_dispatch` は既定ブランチにあるワークフローしか一覧に出ません。

**署名について**: 署名用の Secret が未設定の間は **profile ビルド**になります。
release と同じ AOT コンパイルなので体感速度はほぼ同じで、debug 鍵で署名されるため
直接インストールできます。**テスト配布はこれで十分です。**

---

### B-3. リリース署名鍵（Play の内部テストを使う場合のみ） `[任意]`

直接 APK を配るなら不要です。Google Play の内部テストを使う段になったら実行してください
（Play は debug 鍵の成果物を受け付けません）。

```bash
cd ~/development/trust_car_platform
./scripts/create_release_keystore.sh
```

キーストアの生成、`android/key.properties` の作成、GitHub Secrets への登録、
SHA-1 の表示までを通しでやります。以後 Test APK ワークフローは署名付きの
release ビルドに切り替わります。

**重要**: このキーストアを紛失すると、同じ鍵での更新が二度とできなくなります。
Play を使う場合は初回アップロード時に **Play App Signing** を必ず有効化してください。

**所要時間**: 15分

---

### B-4. SHA-1 を Firebase に登録（Google ログインを使う場合） `[要確認]`

メール／パスワードでのログインだけなら不要です。

```bash
# デバッグ鍵（profile ビルドの APK はこの鍵で署名されます）
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey \
  -storepass android -keypass android | grep SHA1
```

Firebase Console → プロジェクト設定 → `jp.trustcar.app` → **フィンガープリントを追加**

**所要時間**: 10分

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

| 日 | 作業 | 担当 | 所要 |
|---|---|---|---|
| まず最初 | **PR #149 をマージ**（これが全部の前提） | 人間 | 5分 |
| 同上 | **GitHub Pages を止める**（docs の公開を切る・A-2） | 人間 | 2分 |
| 次 | A-3 ルール・インデックスを本番へデプロイ | 人間（AI代行可） | 10分＋待ち |
| 次 | `./scripts/deploy_web.sh` で Web を公開（A-1） | 人間 | 5分 |
| 次 | 公開URLでログイン〜愛車登録〜整備記録まで1周 | 人間 | 30分 |
| 次 | A-4 本番データの棚卸し（ペルソナAuth削除・シード投入） | 人間 | 30分 |
| 次 | Actions → Test APK を実行して APK を入手（B-2） | 人間 | 5分 |
| 次 | B-5 実機で1周（**OCRの実画像精度がいちばん重要**） | 人間 | 1時間 |
| 配布日 | `docs/TESTUSER_GUIDE.md` の前半を送る | 人間 | 15分 |
| 期間中 | フィードバックのトリアージ | AI | — |

**人間の作業は合計 約2.5時間**（待ち時間を除く）。うち1時間は実機での確認です。

---

## 実際に動かして確認したこと（2026-08-23）

Firebase Emulator に繋いだ Web 版を、ブラウザで実際に触って確認しました。
**ビルドが通ることは、動くことの保証ではない**ためです（iOS がまさにその状態でした）。

通ったもの:
- 新規登録 → ログイン
- 愛車が0台のときの案内（「まず愛車を登録しよう」＋登録ボタン）
- プロフィール → ご意見・不具合の報告 → 送信 → 完了画面
- 送信内容が Firestore の `feedback` にルールを通って書き込まれること
- `node scripts/read_feedback.js --emulator` で読み出せること
- 車両登録の1画面目（Web では「車検証の読み取りに対応していません」と出て手入力に落ちる）

**触ったことで見つかって直したもの:**
下タブの「プロフィール」が描いているのは `home_screen.dart` の `_ProfileTab` で、
`ProfileScreen` ではありませんでした。最初フィードバックの導線を `ProfileScreen`
側に付けており、**画面には在るが利用者はたどり着けない**状態でした。
ヘルプも同じ理由で、サポート欄に出ていませんでした。両方 `_ProfileTab` に移しました。

### 覚えておくこと（テストユーザーに聞かれたら）

**最初の数秒だけ日本語が □□□ で表示される件は、2026-08-24 に塞ぎました。**
起動中は青いスプラッシュで覆い、日本語フォントが届いてから退きます。
経緯と実測値は次節に書きます。

---

## 起動直後の見え方を直した（2026-08-24・実測）

**測ったこと**（`flutter build web --release` をローカルで配信し、Chrome で計測）:

```
 最初のフレーム            0.9 秒
 Roboto の到着             1.4 秒
 日本語フォントの到着       3.4 秒   ← ここまで □□□
 （初回の実ダウンロード時） 1.5〜6.7 秒かかる
```

**分かったこと**: 「アプリが立ち上がったら隠すのをやめる」では早すぎます。
日本語フォントは**最初の描画より後**に取りに行くので、first-frame で消すと
その先が □□□ のままです。実際、最初の実装（first-frame から 0.9 秒後に消す）は
消えた先に豆腐が残りました。

**直した形**: `web/index.html` のスプラッシュを、フォントの取得そのものを
`PerformanceObserver` で見て消します。判定を誤らないよう、待つ相手は
**日本語フォントに限って**います（Roboto も同じ配布元から 1.4 秒で届くため、
これを数えると早合点して消えます）。

消えなくなる事故を避ける逃げ道が3つあります。

| 条件 | 動き |
|---|---|
| 日本語フォント到着 → 0.7 秒静か | 消す（通常経路） |
| 最初のフレームから 8 秒、フォントが来ない | 消す（取りに行く必要が無かったと判断） |
| 6 秒経過 | 「時間がかかっています」を画面に出す |
| 20 秒経過 | 何があっても消す |

**あとから確かめる方法**: ブラウザのコンソールで `window.__splashTrace` を見ると、
最初のフレーム・フォント到着・消した時刻・消した理由が出ます。

---

## AI側で対応済み（人間の作業ではありません）

すべて PR #149 に入っています。**マージするまでは効きません。**

- [x] **アプリ内フィードバックの配線**
      `feedback_screen.dart` ほか一式が未コミット・未配線のまま残っていた。
      DI 登録・プロフィール画面「サポート」・ヘルプ画面末尾からの導線を追加。
      `firestore.rules` に `feedback` の規則（本人が書くだけ・誰も読めない）と
      ルールテスト10件。
- [x] **初回ガイド（はじめの3ステップ）の配線**
      同じく未配線で残っていた。愛車登録／車検満了日／整備記録1件を1枚のカードで
      案内する。達成判定は実データから引くので、済んだ項目は消える。表示中は
      車検の催促カードを重ねない。
- [x] **走行記録が止まる条件を画面に明記**（D-1 の A案）
      記録中の画面に「この画面を開いたままにしてください」を出す。
- [x] **Firebase の Android アプリを `jp.trustcar.app` で新規登録**
      `google-services.json` / `firebase_options.dart` / `ci.yml` を正しい値に差し替え。
- [x] **テスト用 APK をビルドする CI ワークフロー**（`.github/workflows/test_apk.yml`）
      開発機に Android SDK が無いため。署名鍵があれば release、無ければ profile。
- [x] **Web を Firebase Hosting に出す設定とスクリプト**（`firebase.json` / `scripts/deploy_web.sh`）
- [x] **リリース署名鍵の作成スクリプト**（`scripts/create_release_keystore.sh`）
- [x] **規約・プライバシーポリシーを Web ビルドに同梱**
- [x] **表示名がテンプレートのままだったのを修正**
      Android のランチャーもブラウザのタブも `trust_car_platform` と出ていた。
- [x] **`docs/_config.yml` で内部ドキュメントの公開を止める**（main に入って初めて効く・A-2）
- [x] **テストユーザー向けの案内文**（`docs/TESTUSER_GUIDE.md`）

### 2026-08-24 に足したもの

- [x] **どのビルドかを特定できるようにした**
      テスト配布中はバージョンが `1.0.0` のまま APK も Web も何度も出し直す。
      これまでフィードバックに載るのは `1.0.0` だけで、「直っていない」と
      言われても**その人がどのビルドを触っているか分からなかった**。
      ビルド時に `--dart-define=APP_BUILD_ID=<短縮SHA>` を渡し、
      プロフィール画面の最下部とフィードバックの両方に出す
      （例: `バージョン 1.0.0 (a1b2c3d) / web`）。
      `scripts/deploy_web.sh`・`test_apk.yml`・`web_preview.yml` に配線済み。
      手元の `flutter run` では空になり、表示はバージョンだけに落ちる。
- [x] **起動直後の白画面と文字化けを塞いだ**（上節）

### 残っている AI 側の宿題

- [ ] `support@trustcar.jp` が受信できない場合の差し替え（A-7 の確認待ち）
- [ ] フィードバックが溜まりはじめたらトリアージして Issue 化

---

*最終更新: 2026-08-24*
