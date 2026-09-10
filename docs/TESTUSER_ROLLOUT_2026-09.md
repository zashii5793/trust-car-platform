# テスター配布（2026年9月 第2週末）— iPhone と Android の両方で触れる環境

**目的**: 今週末、テスターに TrustCar を iPhone / Android の実機で触ってもらう。
**対象読者**: 人間（GitHub の Actions ボタン・Firebase Console・Apple の各コンソールを操作する人）。
**データ環境**: 本番 Firebase プロジェクト `trust-car-platform` をそのまま使う（8月と同じ決定）。
**前回**: `docs/TESTUSER_ROLLOUT_2026-08.md`。そこで「人間の手元 Mac が要る」「iOS は間に合わない」だった2点を、
今回は **GitHub Actions のボタン2つ**に置き換えた。

---

## 0. 結論：週末に配れるもの

| テスターの端末 | 配るもの | 週末の可否 | 人間の作業 |
|---|---|---|---|
| **Android** | APK（`download.html` から直接インストール） | **可能** | §1 の Secret 1つ + §2 のボタン1回 |
| **iPhone（ブラウザ版）** | 同じ `download.html` から Web 版を「ホーム画面に追加」 | **可能** | 同上（追加作業なし） |
| **iPhone（アプリ版）** | TestFlight | **Apple Developer Program が承認済みなら 1日**。未承認なら不可 | §4（約1時間 + Apple 側の処理待ち） |

テスターに渡す URL は **1つだけ**:

```
https://trust-car-platform.web.app/download.html
```

このページが端末を見て、Android には APK、iPhone にはブラウザ版（TestFlight のリンクがあればそれも）を出す。

**iPhone のブラウザ版で試せないもの**: 車検証のカメラ読み取り（OCR）とプッシュ通知。
この2つを iPhone で見たいなら TestFlight（§4）が要る。

---

## 1. 1回だけの準備（約15分）

### 1-1. Firebase Hosting へ出すための鍵を GitHub に置く `[要作業]`

Actions から Firebase Hosting へデプロイするための鍵。**これが無いと §2 は途中で止まる**
（配布物は Artifacts に残るので、手元から `firebase deploy` する逃げ道はある）。

1. [Firebase Console](https://console.firebase.google.com/project/trust-car-platform/settings/serviceaccounts/adminsdk)
   → プロジェクトの設定 → **サービス アカウント** → 「新しい秘密鍵の生成」→ JSON が落ちてくる
2. GitHub → リポジトリ → Settings → Secrets and variables → Actions → **New repository secret**
   - Name: `FIREBASE_SERVICE_ACCOUNT`
   - Secret: 落ちてきた JSON の**中身を丸ごと**貼る
3. 落ちてきた JSON ファイルは、貼ったら削除する（プロジェクトのフル権限を持つ鍵）

> この鍵（`firebase-adminsdk-...`）は Editor 権限を持つ。Hosting だけでなく Firestore も触れる。
> 権限を絞りたければ、Google Cloud Console で「Firebase Hosting 管理者」だけを付けた
> サービスアカウントを別に作る。週末に間に合わせるなら上の手順で十分。

### 1-2. Authentication のメール/パスワードが有効か確かめる `[要確認]`

Firebase Console → Authentication → Sign-in method → 「メール/パスワード」が **有効**。
手順は `docs/SETUP_AUTH_CONSOLE.md`。**これが無効だと、どの端末でも新規登録で止まる。**

### 1-3. Storage ルールは 9/6 に本番反映済み `[実測]`

9/4 時点で未反映だった `storage.rules` は、2026-09-06 のセッションで `firebase deploy --only storage` が
通っている（`CLAUDE_SESSION_NOTES.md` 2026-09-06）。**追加の作業は要らない。**

§2 のワークフローの **`deploy_storage_rules`** は、今後 `storage.rules` を変えたときに同じ鍵で反映する
ためのもの。写真アップロードが弾かれたときだけオンにする。普段はオフ。

---

## 2. 配布の手順（毎回・ボタン1回・待ち時間 15〜20分）

1. GitHub → **Actions** → 左の一覧から **Test Distribution** → 右上 **Run workflow**
2. 入力:

   | 項目 | 入れるもの |
   |---|---|
   | `note` | 目印。例: `9/13 テスター配布1回目` |
   | `include_apk` | オン（Android にも配る） |
   | `testflight_url` | TestFlight の公開リンクがあれば（§4-7）。無ければ空 |
   | `deploy_storage_rules` | 初回だけオン（§1-3）。以降はオフ |

3. 15〜20分待つ。終わったら実行ページの **Summary** に URL が並ぶ
4. **自分のスマホで `download.html` を開き、Android なら APK を入れて起動、iPhone ならブラウザ版でログインまで**やる。
   プロフィール画面の最下部に `バージョン 1.0.0 (xxxxxxx)` と出ていて、Summary の「コミット」と一致していれば、
   いま出したものが届いている
5. テスターに `https://trust-car-platform.web.app/download.html` を送る。案内文は `docs/TESTUSER_GUIDE.md` の前半

**中身を直して出し直すとき**は、main にマージしてから 1〜3 をもう一度。
APK のファイル名にコミットが入るので（`TrustCar-xxxxxxx.apk`）、古い APK を掴んだままにはならない。

### ワークフローが赤で止まったとき

| Summary / ログの表示 | 原因 | やること |
|---|---|---|
| `FIREBASE_SERVICE_ACCOUNT が未設定です` | §1-1 をやっていない | §1-1。配布物は Artifacts `trustcar-test-site` にあるので、急ぐなら展開して `firebase deploy --only hosting` |
| `HTTP Error: 403` を含むデプロイ失敗 | 鍵の権限不足 | 鍵を作ったサービスアカウントに Editor か「Firebase Hosting 管理者」があるか |
| `APK の成果物が見つかりません` | `apk` ジョブが失敗している | そのジョブのログを見る。Android SDK の取得失敗なら再実行で通ることが多い |
| Web ビルド失敗 | main が壊れている | `web_preview.yml` の直近の結果を見る（PR ごとに Web ビルドは検証している） |

---

## 3. iPhone（ブラウザ版）で触ってもらうときに知っておくこと

- **Safari で開いてもらう。** LINE などのアプリ内ブラウザだと「ホーム画面に追加」が無い。
  `download.html` にその旨と手順を書いてある
- ホーム画面に追加すると、アドレスバーの無い全画面で動く（`web/manifest.json` の `display: standalone`）
- **ログインはメール/パスワードを勧める。** ホーム画面から起動した状態では、Google ログインのポップアップが
  Safari 側に飛んで戻ってこないことがある。ブラウザ（Safari そのまま）で使う場合は問題ない
- 開いた直後の数秒、日本語が □ になる。フォントの読み込み中（`CLAUDE_SESSION_NOTES.md` 2026-08-24 に実測あり）
- 試せないもの: 車検証 OCR・請求書 OCR・プッシュ通知。**この3つが「試したい機能」に入っているなら §4 へ**

---

## 4. iPhone アプリ版（TestFlight）を出す

### 前提

**Apple Developer Program（年 $99）の承認が下りていること。** 8月時点の記録は「申請済み・承認待ち」
（`docs/HUMAN_TASKS.md` §5）。[developer.apple.com/account](https://developer.apple.com/account) を開いて
Membership に Team ID が出ていれば承認済み。**出ていなければ §4 は週末に間に合わない。§3 で凌ぐ。**

仕組み: `.github/workflows/testflight.yml` が macOS ランナーで署名付き `.ipa` を作り、App Store Connect へ上げる。
署名は **Xcode の自動署名 + App Store Connect API キー**。証明書や Provisioning Profile を
人間が作って GitHub に貼る手順は**無い**（xcodebuild が API キーで作って取ってくる）。

所要: 人間の作業 約1時間 + Apple 側の処理待ち（ビルド処理 10〜30分、外部テスター向け審査 半日〜1日）。

### 4-1. Team ID を控える（1分）

[developer.apple.com/account](https://developer.apple.com/account) → Membership details → **Team ID**（10文字）。

### 4-2. App ID を登録する（3分）

[Certificates, Identifiers & Profiles → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
→ **+** → App IDs → App → 次の値で登録。

| 項目 | 値 |
|---|---|
| Description | TrustCar |
| Bundle ID | Explicit: `jp.trustcar.app` |
| Capabilities | **今回はチェック不要**（下記「まだ動かないもの」参照） |

### 4-3. App Store Connect にアプリを作る（5分）

[App Store Connect → アプリ](https://appstoreconnect.apple.com/apps) → **+** → 新規 App。

| 項目 | 値 |
|---|---|
| プラットフォーム | iOS |
| 名前 | TrustCar（既に取られていれば `TrustCar クルマ統合管理` など） |
| プライマリ言語 | 日本語 |
| バンドル ID | `jp.trustcar.app`（4-2 で作ったもの） |
| SKU | `trustcar-ios` |
| ユーザアクセス | フルアクセス |

**アプリのレコードが無いと、ビルドのアップロードが弾かれる。** 先に作る。

### 4-4. App Store Connect API キーを発行する（5分・ダウンロードは1回だけ）

App Store Connect → **ユーザとアクセス** → **統合** タブ → **App Store Connect API** → チームキー → **+**

| 項目 | 値 |
|---|---|
| 名前 | `github-actions-testflight` |
| アクセス | **Admin**（自動署名で証明書を作るのに必要。Developer では足りない） |

作ると **Issuer ID**（UUID）と **キー ID**（10文字）が出る。**「API キーをダウンロード」は1回しか押せない。**
落ちてきた `AuthKey_XXXXXXXXXX.p8` を安全な場所に保管する。

### 4-5. GitHub Secrets に4つ入れる（5分）

Settings → Secrets and variables → Actions → New repository secret を4回。

| Name | 値 |
|---|---|
| `APPLE_TEAM_ID` | 4-1 の Team ID |
| `APP_STORE_CONNECT_KEY_ID` | 4-4 のキー ID |
| `APP_STORE_CONNECT_ISSUER_ID` | 4-4 の Issuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | `.p8` をテキストエディタで開いた中身（`-----BEGIN PRIVATE KEY-----` から `-----END PRIVATE KEY-----` まで） |

### 4-6. TestFlight ワークフローを回す（待ち 15〜20分）

Actions → **TestFlight** → Run workflow → `note` に目印、`upload` はオン。

- 最初の `Check secrets` ジョブが赤なら、4-5 のどれかが抜けている（macOS は起動していないので課金なし）
- `Archive` で止まったら、ログの `::error::` 行を見る。ありがちなもの:

  | 表示 | 原因 |
  |---|---|
  | `No Accounts` / `No signing certificate` | API キーの権限が Admin でない、または `.p8` の貼り間違い |
  | `No profiles for 'jp.trustcar.app'` | 4-2 の App ID が無い、または Team ID が違う |
  | `Provisioning profile ... doesn't include signing certificate` | 一度失敗して古い状態が残った。もう一度回す |

- `Upload to App Store Connect` で `The app record ... could not be found` → 4-3 をやっていない

緑になったら App Store Connect → アプリ → **TestFlight** タブに build が出る（処理に 10〜30分。「処理中」の間は待つ）。

### 4-7. テスターに配る

**A. 内部テスト（審査なし・即日）** — テスターが数人で、連絡先を知っているなら**こちらが速い**

1. App Store Connect → ユーザとアクセス → **+** でテスターをユーザとして招待（役割: `Customer Support` で十分。
   アプリのデータは一切見えない）
2. TestFlight タブ → 内部テスト → **+** でグループを作り、ユーザとビルドを追加
3. テスターの Apple ID 宛に TestFlight の招待メールが届く。TestFlight アプリを入れて「承諾」

**B. 外部テスト（公開リンク・初回のみ審査）** — 人数が多い・連絡先を集めたくないなら

1. TestFlight タブ → 外部テスト → **+** でグループ作成 → ビルドを追加
2. 「テスト情報」（何をテストしてほしいか・連絡先メール）を埋めて審査に出す。**初回のみ Beta App Review（半日〜1日）**
3. 承認されたら **公開リンクを有効化** → `https://testflight.apple.com/join/XXXXXXXX` が出る
4. そのリンクを **Test Distribution の `testflight_url`** に入れて回すと、`download.html` の iPhone 向けに
   「TestFlight でアプリを入れる」ボタンが出る

### iPhone アプリ版で、まだ動かないもの（コード側の宿題・週末には入れない）

| 機能 | 状態 | 直すには |
|---|---|---|
| **Apple でサインイン** | ログイン画面にボタンは出るが、押すと失敗する | `ios/Runner/Runner.entitlements` に `com.apple.developer.applesignin` を足し、4-2 の App ID で Sign in with Apple を有効化、Firebase Console で Apple プロバイダを有効化 |
| **プッシュ通知** | 届かない | APNs 認証キー（.p8）を Apple で作って Firebase Console → Cloud Messaging に登録、entitlements に `aps-environment` |

**テスターには「iPhone はメールかGoogleでログインしてください」と伝える。**
Google ログインも Firebase の iOS アプリに `REVERSED_CLIENT_ID` が要るため、
`GOOGLE_SERVICES_PLIST` Secret を Console の最新 plist で入れていない場合は失敗しうる。
**確実なのはメール/パスワード。**

---

## 5. スケジュールの目安

| いつ | 何を | 所要 |
|---|---|---|
| 平日のうちに | §1（Secret・Auth 確認） | 15分 |
| 平日のうちに | §2 を1回回して、自分の Android / iPhone で1周 | 30分（待ち含む） |
| Apple が承認済みなら平日のうちに | §4-1〜4-6 | 1時間 + 待ち |
| 木〜金 | §4-7 B の審査に出す（外部リンクを使う場合） | 審査 半日〜1日 |
| 金曜 | 最終の §2（`testflight_url` 入り）→ テスターに URL 送付 | 20分 |
| 週末 | フィードバックを `node scripts/read_feedback.js` で読む（`docs/TESTUSER_GUIDE.md` 後半） | — |

---

## 6. AI 側で対応済み（人間の作業ではありません・2026-09-09）

| 何を | どこ |
|---|---|
| Web + APK + 受け取りページを Firebase Hosting へ出すワークフロー | `.github/workflows/test_distribution.yml` |
| APK ビルドを配布ワークフローから呼べるようにした（`workflow_call`） | `.github/workflows/test_apk.yml` |
| TestFlight へ署名付き `.ipa` を上げるワークフロー（Secret 不足なら macOS を起動せず止まる） | `.github/workflows/testflight.yml`, `ios/ExportOptions.plist` |
| 輸出コンプライアンスの質問をビルドごとに聞かれないようにした | `ios/Runner/Info.plist` の `ITSAppUsesNonExemptEncryption=false` |
| CI 用 `GoogleService-Info.plist` を1ファイルに寄せた（ci.yml と testflight.yml で共用・食い違い防止） | `ios/ci/GoogleService-Info.ci.plist` |
| 受け取りページに iPhone の「ホーム画面に追加」手順と TestFlight 欄（リンクがある時だけ出る） | `web/download.html` |
| 停止済みの GitHub Pages へデプロイしようとして main が毎回赤くなっていたのを止めた | `.github/workflows/web_preview.yml` |
| 手元用スクリプトを Linux でも動くようにし、TestFlight リンクにも対応 | `scripts/publish_test_build.sh`, `scripts/deploy_web.sh` |

**まだ AI 側でやれていないこと**: Sign in with Apple / プッシュ通知の iOS 設定（entitlements と Xcode プロジェクトの変更。
Mac で Xcode を開いて確認しながら入れるのが安全なため、週末の枝から外した）。
