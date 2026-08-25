# iOS が起動しない件の直し方（2026-08-25）

> **2026-08-25 追記: 登録と差し替えは完了した。** 残っているのは実機/シミュレータ
> での起動確認だけ（§4）。**ビルドが通っただけでは確かめたことにならない。**
>
> ```
>  新 App ID   1:31421119456:ios:5646ac324f34398880c985
>  新 API Key  AIzaSyBt0hMKqo9viDFCXvNcDpNWcQ34seKfPEg
>  Bundle      jp.trustcar.app
> ```
>
> 差し替えた場所: `ios/Runner/GoogleService-Info.plist`（gitignore 対象・手元のみ）/
> `lib/firebase_options.dart` の ios・macos / `.github/workflows/ci.yml` の
> フォールバック plist。
>
> **apiKey も別物だった。** 旧値 `AIzaSyDZQ4UK6I…` は web の鍵で、iOS の鍵は
> `AIzaSyBt0hMKqo…`。Android で直したときとまったく同じ形。

**症状**: iOS アプリを起動すると白画面のまま何も出ない。ビルドは通る。

**原因**: Firebase に登録されている iOS アプリの Bundle ID が
`com.example.trustCarPlatform` で、実際のアプリの `jp.trustcar.app` と食い違っている。
それなのに設定ファイル側では **「com.example のアプリIDに、Bundle ID だけ
`jp.trustcar.app` と書いた」実在しない組み合わせ**になっている。

**2026-08-23 に Android で直したのと、まったく同じ形の壊れ方。** iOS には手が
入っていない。

---

## 1. いま何がどうなっているか（実測）

食い違いは**3か所**にある。すべて同じ App ID を指している。

| 場所 | Bundle ID | App ID | 判定 |
|---|---|---|---|
| `ios/Runner/GoogleService-Info.plist` | `com.example.trustCarPlatform` | `1:31421119456:ios:4320af5d1401f02c80c985` | Firebase の登録と一致（＝実アプリと不一致） |
| `.github/workflows/ci.yml` L301〜 | **`jp.trustcar.app`** | 同上 | **実在しない組み合わせ** |
| `lib/firebase_options.dart` L56〜 | `iosBundleId: 'jp.trustcar.app'` | 同上 | **実在しない組み合わせ** |

Firebase の iOS SDK は起動時に Bundle ID を照合するため、ここで落ちる。

### なぜ CI で気づけなかったか

`ci.yml` の iOS ビルドは `flutter build ios --no-codesign --debug`。
**ビルドするだけでアプリを起動しない。** だから設定が実在しない組み合わせでも
CI は緑のまま通る。Android がまさにこれで、
「gradle は package_name しか照合しないため、ビルドは通り、実行時にだけ壊れる」
と記録されている（`docs/TESTUSER_ROLLOUT_2026-08.md` B-1）。

**ビルドが通ることは、動くことの保証にならない。** 同じ罠を iOS でも踏んでいる。

---

## 2. 人間の作業（Firebase Console）【完了】

**Firebase の iOS アプリは、後から Bundle ID を変更できない。** 新規登録が要る。

1. [Firebase Console](https://console.firebase.google.com/) → プロジェクト `trust-car-platform`
2. プロジェクトの設定（歯車）→ **マイアプリ** → **アプリを追加** → **iOS**
3. **Apple バンドル ID** に `jp.trustcar.app` を入力
   - アプリのニックネーム: `TrustCar iOS`（任意）
   - App Store ID は空でよい（未申請のため）
4. **「アプリを登録」** → `GoogleService-Info.plist` をダウンロード
5. ダウンロードしたファイルを `ios/Runner/GoogleService-Info.plist` に**上書き配置**
   - このファイルは `.gitignore` 対象なのでコミットされない（そのままでよい）
6. 残りのステップ（SDK 追加・初期化コード）は**やらなくてよい**。Flutter 側で済んでいる
7. 新しい **App ID** と **API キー** を控える
   - プロジェクトの設定 → マイアプリ → `jp.trustcar.app` の欄に表示される
   - App ID は `1:31421119456:ios:xxxxxxxxxxxxxxxx` の形

**旧 `com.example.trustCarPlatform` のアプリは消さないこと。** 参照が切れると
面倒なので、使われなくなるだけにしておく（Android で同じ判断をしている）。

**所要**: 10分

---

## 3. AI 側の作業（値をもらってから）【完了】

上の 7 で控えた App ID と API キーを渡してもらえれば、こちらで直す。

- `lib/firebase_options.dart` の `ios` と `macos` の `appId` / `apiKey`
- `.github/workflows/ci.yml` L301〜 のフォールバック plist（`GOOGLE_APP_ID` / `API_KEY` / `BUNDLE_ID`）

**macos も同じ App ID を使っている**ので、あわせて直す。

---

## 4. 直ったことの確かめ方

**ビルドが通っただけでは確かめたことにならない。** 実機かシミュレータで起動する。

- [ ] アプリが起動して、白画面で止まらない
- [ ] ログイン画面が出る
- [ ] 新規登録 → ログインが通る（Firebase Auth に届いている証拠）
- [ ] 愛車を登録して、再起動しても残っている（Firestore に届いている証拠）

ログイン画面が出ても、**登録が通らなければ直っていない**。画面が出ることと
Firebase に届いていることは別。

---

## 5. あわせて直すべき CI の穴（任意・推奨）

いまの iOS ビルドはアプリを起動しないので、この種の壊れ方を一生検出できない。
`integration_test/` は既にあるので、シミュレータ上で
「起動して最初の画面が出る」だけを見る検査を CI に足せば、次は自動で止められる。

ただし macOS ランナーは課金が10倍なので、`ios` ラベル付き PR と main への push
だけに絞ること（`ci.yml` の既存方針と同じ）。

---

*作成: 2026-08-25 / 3か所の食い違いはコードと設定の実測*
