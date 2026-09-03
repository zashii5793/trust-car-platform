# Firebase Authentication の本番設定手順（P0-4）

**作成**: 2026-09-03
**対象**: `docs/HUMAN_TASKS.md` P0-4
**所要時間**: 20〜30分（Apple の設定を除く）

Firebase Console でしかできない作業です。**Identity Platform の管理 API が要るため、
CLI からは設定できません。**

---

## 先に知っておくこと

コードを読んで確認した、いまの状態です。

| 方式 | アプリ側の実装 | Console 側 |
|---|---|---|
| メール / パスワード | `auth_service.dart` にあり | 本番にテストユーザーがいるため有効化済みの可能性が高い。要確認 |
| — | — | **この開発機に Android SDK が無いため、Android のローカル確認はできません** |
| Google | `signInWithGoogle()` あり（L94） | **SHA-1 が未登録。このままでは Android で失敗します**（下記） |
| Apple | `signInWithApple()` あり（L135）。nonce 対応済み | Apple Developer 側の設定が前提（P1-5） |

### Android の Google ログインは、いまのままでは動きません

`android/app/google-services.json` の `oauth_client` に、**Android 用の
エントリ（`client_type: 1`・SHA-1 付き）がありません。** Web 用（`client_type: 3`）
だけです。

```
package: jp.trustcar.app
  oauth_client type 3 (web)      ← これしかない
```

Google Sign-In は、アプリの署名証明書（SHA-1）とパッケージ名の組で本人確認を
します。**SHA-1 を Firebase に登録し、`google-services.json` を取り直さないと、
Android では `ApiException: 10`（DEVELOPER_ERROR）で失敗します。**

`com.example.trust_car_platform`（旧パッケージ名）のクライアントも残っています。
消しても実害はありませんが、混乱の元なので整理を勧めます。

### Web の承認済みドメインは追加不要です

`scripts/deploy_web.sh` が Firebase Hosting（`trust-car-platform.web.app`）へ
公開する作りで、このドメインは既定で承認済みです。**GitHub Pages
（`zashii5793.github.io`）を使う場合だけ、承認済みドメインへの追加が要ります**
（追加しないと `auth/unauthorized-domain` でログインできません）。

---

## この作業は P0-1 の後にやってください

**SHA-1 はリリース鍵のものを登録するのが正解です。** 理由は2つあります。

1. **この開発機では debug の SHA-1 が取れません。** Android SDK が入っておらず
   （`flutter doctor` → `✗ Unable to locate Android SDK`）、`./gradlew signingReport`
   は Java 26 で `IllegalArgumentException: 26.0.1` を出して止まります
   （JDK 17 も入っているので切り替えれば動く可能性はありますが、SDK が無い以上
   結局ビルドはできません）。
2. **テスト配布の APK は GitHub Actions がビルドしています。** そこの debug 署名は
   ランナー側で生成されるため、SHA-1 が安定しません。debug の SHA-1 を追いかけても
   配布物では動きません。

**したがって、P0-1 でリリース用キーストアを作り、その SHA-1 を登録してください。**
手元で Android 実機デバッグをしたくなったときは、Android Studio を入れて
Android SDK を用意したうえで、debug の SHA-1 を追加登録します。

---

## 手順

### 1. SHA-1 を取得する

**P0-1 のキーストアを作ってから**:

```bash
keytool -list -v -keystore ~/trustcar-release.keystore -alias trust-car-platform
```

`SHA1:` の行をコピーします。

**Google Play App Signing を使う場合は、Play Console 側の SHA-1 も要ります**
（アップロード鍵とは別物）。Play Console → 設定 → アプリの整合性 →
アプリ署名鍵証明書の SHA-1 を、初回アップロード後に追加してください。
**これを忘れると、Play から配信したアプリだけ Google ログインが失敗します。**

### 2. Firebase Console に SHA-1 を登録する

1. [Firebase Console](https://console.firebase.google.com/project/trust-car-platform/settings/general) → プロジェクトの設定 → 全般
2. マイアプリ → Android アプリ（`jp.trustcar.app`）
3. 「フィンガープリントを追加」→ 手順1の SHA-1 を貼る
4. **debug と release の両方を登録**（開発中も本番も動くように）

### 3. google-services.json を取り直す

**ここを飛ばすと、SHA-1 を登録しても反映されません。**

1. 同じ画面で `google-services.json` をダウンロード
2. `android/app/google-services.json` に上書き
3. 確認: `oauth_client` に `"client_type": 1` のエントリが増えていること

```bash
python3 -c "
import json
d = json.load(open('android/app/google-services.json'))
for c in d['client']:
    print(c['client_info']['android_client_info']['package_name'])
    for o in c.get('oauth_client', []):
        print('  type', o.get('client_type'), o.get('android_info', {}).get('certificate_hash', '(web)'))
"
```

**このファイルは `.gitignore` 対象です**（コミットしないでください）。

### 4. Sign-in method を有効化する

[Console → Authentication → Sign-in method](https://console.firebase.google.com/project/trust-car-platform/authentication/providers)

- [ ] **メール / パスワード**: 有効（既に有効の可能性が高い）
- [ ] **Google**: 有効。プロジェクトのサポートメールを設定
- [ ] **Apple**: 有効。Apple Developer 側の Service ID・Key ID・チーム ID が要る（P1-5 の後）

### 5. 動作確認

この開発機では Android ビルドができないため、**配布した APK で確認します**
（`docs/TESTUSER_ROLLOUT_2026-08.md` の配布手順）。

- [ ] Google ログインでアカウントが選べて、ホーム画面まで入れる
- [ ] 一度ログアウトして、同じアカウントで入り直せる
- [ ] iOS 実機で Apple ログインが通る（P1-5 完了後）
- [ ] Web（`trust-car-platform.web.app`）でも Google ログインが通る

**`ApiException: 10` が出たら、SHA-1 か `google-services.json` の取り直しが
できていません。** 手順2と3を見直してください。

---

## 関連

- `docs/HUMAN_TASKS.md` P0-1（リリース署名。release の SHA-1 はここで作る鍵から取る）
- `docs/HUMAN_TASKS.md` P1-5（Apple Developer の設定）
- `scripts/deploy_web.sh`（Web の公開先と承認済みドメインの経緯）
