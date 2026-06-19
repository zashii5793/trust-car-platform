# 【P0手順書】Firebase Authentication の本番有効化

> リリースブロッカー P0 #2。**人間が実行**（Firebase Console / 各種コンソール操作はAIで代替不可）。
> 所要: 15〜30分（iOSのGoogleサインインまで含むと+α）。
> 対象プロジェクト: **`trust-car-platform`**

> ⚠️ 重要 — **アプリの実際のID（コードで確認済み）**:
> - Android `applicationId` = **`jp.trustcar.app`**（`android/app/build.gradle`）
> - iOS `PRODUCT_BUNDLE_IDENTIFIER` = **`jp.trustcar.app`**（`ios/Runner.xcodeproj`）
> - ⚠️ `docs/HUMAN_TASKS.md` の「`com.trustcar.platform`」は**古い記載で誤り**。本番では `jp.trustcar.app` を使うこと。

---

## 0. アプリが使う認証方式（コードで確認済み）

`lib/services/auth_service.dart` より、本アプリが使用するのは2方式のみ:

| 方式 | コード | Consoleで有効化が必要 |
|------|--------|----------------------|
| **メール / パスワード** | `createUserWithEmailAndPassword` / `signInWithEmailAndPassword` / `sendPasswordResetEmail` | ✅ 必須 |
| **Google サインイン** | `google_sign_in` パッケージ（`GoogleSignIn()`） | ✅ 必須 |

> 電話番号・匿名・その他プロバイダは未使用 → 有効化不要。

---

## 1. メール/パスワード認証の有効化（最優先・5分）

1. [Firebase Console](https://console.firebase.google.com/project/trust-car-platform/authentication/providers) → **Authentication** → **Sign-in method**
2. **メール / パスワード** → 「有効にする」をON → 保存
   - 「メールリンク（パスワードなしのログイン）」は本アプリ未使用なのでOFFのままでよい
3. これだけで新規登録・ログイン・パスワードリセットが本番で動作する

---

## 2. Google サインインの有効化

### 2-1. Console でプロバイダを有効化（共通）
1. Authentication → Sign-in method → **Google** → 「有効にする」
2. **プロジェクトのサポートメール**を選択 → 保存

### 2-2. Android（SHA-1/SHA-256 登録が必須）
Google サインインは署名フィンガープリントの登録が無いと**本番APKで失敗する**。

```bash
# リリース用キーストアのSHA-1 / SHA-256 を取得（P0 #5 で作成したキーストア）
keytool -list -v -keystore /path/to/release.keystore -alias trust-car-platform
# デバッグ用（開発端末で試すなら）:
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```
1. Console → プロジェクト設定 → 「マイアプリ」→ Android アプリ（`jp.trustcar.app`）
2. **SHA-1 と SHA-256 の両方**を「フィンガープリントを追加」で登録
3. 登録後、**`google-services.json` を再ダウンロード** → `android/app/` に再配置（P0 #3）
   - SHA登録後のjsonには `oauth_client` が増えるため、必ず再取得すること

### 2-3. iOS（URLスキーム設定）
1. Console → プロジェクト設定 → iOS アプリ（`jp.trustcar.app`）→ `GoogleService-Info.plist` をダウンロード → `ios/Runner/` に配置（P0 #3）
2. `GoogleService-Info.plist` 内の **`REVERSED_CLIENT_ID`** をコピー
3. Xcode → Runner → Target → **Info** → URL Types に、その `REVERSED_CLIENT_ID` を `URL Schemes` として追加
   - これが無いと Google サインインのリダイレクトが返ってこない

### 2-4. Web（使う場合のみ）
- Authentication → Settings → **承認済みドメイン** に本番ドメイン（独自ドメイン or `*.web.app` / `*.firebaseapp.com`）を追加

---

## 3. 動作確認（実機推奨）

- [ ] メール新規登録 → 受信トレイ不要でアカウント作成できる
- [ ] メールでログイン → 成功
- [ ] パスワードリセットメールが届く
- [ ] Google サインイン → アカウント選択 → アプリに戻ってログイン完了（Android/iOS各1台）
- [ ] サインアウト → 再ログインできる

> Google サインインが「すぐ画面が閉じて失敗」する場合の典型原因:
> - Android: SHA-1未登録 / `google-services.json` がSHA登録前の古い版
> - iOS: `REVERSED_CLIENT_ID` のURLスキーム未設定 / `GoogleService-Info.plist` 未配置

---

## 4. よくある落とし穴（ガードレール）

- ❌ Bundle ID を `com.trustcar.platform` で登録（誤）→ 正は **`jp.trustcar.app`**
- ❌ SHA登録後に `google-services.json` を再取得し忘れる → Googleログインが永遠に失敗
- ❌ iOS の URL Types 未設定でログインループ
- ⚠️ デバッグ署名とリリース署名で SHA-1 は別物 → **両方**登録しておくと開発/本番どちらも動く

---

## 5. 完了条件（このP0タスクのDONE定義）

- [ ] メール/パスワードが Console で有効
- [ ] Google が Console で有効 + サポートメール設定済み
- [ ] Android: リリース/デバッグ両方の SHA-1/256 登録 + `google-services.json` 再配置
- [ ] iOS: `GoogleService-Info.plist` 配置 + `REVERSED_CLIENT_ID` の URL Scheme 設定
- [ ] 実機でメール/Google 双方のログインが成功
- [ ] `HUMAN_TASKS.md` の Bundle ID 記載を `jp.trustcar.app` に修正

> 完了したら P0 #3（`google-services.json` / `GoogleService-Info.plist` 配置）と #6（実機テスト）へ。
