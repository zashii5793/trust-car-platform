# 携帯端末で「自分のクルマを登録」するための人間作業

**ゴール**: 自分の iPhone / Android 実機にアプリを入れて、実際にクルマ（車両）を1台登録してみる。
そのうえで **他の人にも配れる**（TestFlight / Google Play 内部テスト）状態まで持っていく。

**前提**: コード実装（車両登録画面・認証・Firestore/Storage 連携）は完了済み。以下は **AI では代替できない人間作業のみ**。
**環境**: Mac あり（iOS/Android 両方ビルド可能）。

> 詳細なコマンド例は `docs/SETUP_AND_STORE_GUIDE.md`、全リリース向けの網羅版は `docs/HUMAN_TASKS.md` を参照。
> 本書は「まず1台登録する」ことに最短で到達するための **絞り込み版・実行順序つき** チェックリスト。

---

## 車両登録に必要な前提（コード側の確認結果）

| 項目 | 状態 | 補足 |
|------|------|------|
| 車両登録画面 | ✅ 実装済み | `lib/screens/vehicle_registration_screen.dart`（3ステップ・OCR自動入力あり） |
| 登録に必要な認証 | ⚠️ **送信時にログイン必須** | 未ログインだと登録ボタンでエラー。Auth 有効化が前提 |
| Firestore `vehicles` ルール | ✅ コードに存在 | `firestore.rules` 61行〜（所有者のみ読み書き）→ **デプロイが必要** |
| Storage 車両画像ルール | ✅ コードに存在 | `storage.rules` 23行〜（本人のみ書き込み）→ **デプロイ＋Storage有効化が必要** |
| 必須入力項目 | メーカー / 車種 / グレード / 年式 / 走行距離 | 写真・車検満了日などは任意 |

---

## フェーズ0 — まず必ず必要（これが無いと登録できない）

> 所要: 合計 30〜40分 / 前提: Firebase Console のオーナー権限・`firebase login` 済み

### 0-1. Firebase Authentication を有効化 🔴 最優先
登録は送信時にログインを要求するため、認証が無いと**絶対に登録できない**。

1. Firebase Console → Authentication → Sign-in method
2. **メール / パスワード** を「有効」にする（まずはこれだけでOK・最短）
3. （任意）**Google** も使うなら有効化 → Android は SHA-1 フィンガープリント登録が必要

### 0-2. Firestore / Storage ルールをデプロイ
ルールはリポジトリに入っているが**本番未反映だと書き込みが弾かれる**。

```bash
firebase login                      # オーナー権限アカウント
git pull                            # 最新の firestore.rules / storage.rules を取得
firebase deploy --only firestore:rules,firestore:indexes,storage
```
- 確認: Console → Firestore / Storage → ルール → バージョン履歴に反映時刻が出る

### 0-3. Cloud Storage を有効化（写真を付けるなら）
- Firebase Console → Storage →「始める」でバケットを作成
- 写真を付けずに登録するだけなら省略可（写真は任意項目）

### 0-4. 設定ファイルを配置
`.gitignore` 管理外のため、ビルドする Mac に手動配置が必要。

1. Firebase Console → プロジェクト設定 → マイアプリ
2. **Android**: `google-services.json` をダウンロード → `android/app/` に置く
3. **iOS**: `GoogleService-Info.plist` をダウンロード → `ios/Runner/` に置く

✅ **フェーズ0完了チェック**
- [ ] 0-1 Auth（メール/パスワード）有効化
- [ ] 0-2 ルール・インデックス・Storage ルールをデプロイ
- [ ] 0-3 Cloud Storage 有効化（写真を使う場合）
- [ ] 0-4 google-services.json / GoogleService-Info.plist 配置

---

## フェーズA — 自分の実機で1台登録してみる（最短ルート）

> ここまで来れば「お試し登録」が可能。配布の手前。

### A-1. Android 実機（最も簡単・署名不要）
1. 端末で「開発者向けオプション」→「USBデバッグ」を ON
2. Mac に USB 接続して許可
3. プロジェクトルートで:
   ```bash
   flutter devices            # 端末が見えるか確認
   flutter run                # debug ビルドが端末にインストールされる
   ```
4. アプリ起動 → メール/パスワードで新規登録 → 車両登録画面で1台登録

### A-2. iPhone 実機（Mac + Xcode の署名が必要）
無料の Apple ID でも **7日間有効** の署名で実機お試しが可能（Developer Program 未加入でOK）。
1. `ios/Runner.xcworkspace` を Xcode で開く
2. Runner → Signing & Capabilities → **Team** に自分の Apple ID を選択
   （Xcode → Settings → Accounts で Apple ID を追加しておく）
3. Bundle Identifier は `jp.trustcar.app`（既存設定）。無料アカウントで衝突する場合は一時的に
   `jp.trustcar.app.dev` 等へ変更（※App 内課金等を試すなら本番IDが必要）
4. iPhone を USB 接続 → 端末側で「このコンピュータを信頼」
5. ターミナルから:
   ```bash
   flutter devices
   flutter run                # 接続中の iPhone を選択
   ```
6. 初回は iPhone の「設定 → 一般 → VPN とデバイス管理」で開発者アプリを信頼

✅ **フェーズA完了チェック**
- [ ] A-1 Android 実機で登録成功
- [ ] A-2 iPhone 実機で登録成功
- [ ] A-3 下記「登録フロー実機確認チェックリスト」を一通り確認

### A-3. 登録フロー実機確認チェックリスト（車両登録に特化）
エミュレーターでは再現しないカメラ・ストレージ・権限まわりを実機で確認する。
（全機能の網羅版は `HUMAN_TASKS.md` P1-8 を参照）

**認証 → 登録の基本動線**
- [ ] メール/パスワードで新規登録・ログインできる
- [ ] （Google有効化時のみ）Google Sign-In が実機で完了する
- [ ] ログイン状態でホーム → 車両登録画面に遷移できる

**必須項目だけで登録（最小ケース）**
- [ ] ステップ1: メーカー / 車種 / グレード / 年式 / 走行距離 を入力して進める
- [ ] 写真なし・任意項目なしで「登録」が成功し、一覧に表示される
- [ ] 年式・走行距離の境界値（例: 1900年・0km・極端な大きい値）でバリデーションが働く

**写真つき登録（Storage 連携）**
- [ ] カメラ/ギャラリーから写真を選択できる（カメラ・写真の権限ダイアログが出る）
- [ ] 登録時に写真が Firebase Storage にアップロードされ、詳細画面で表示される
- [ ] 「写真をコミュニティと共有」チェックの ON/OFF が反映される

**車検証OCR 自動入力（任意）**
- [ ] 「車検証をスキャンして自動入力」でカメラが起動する
- [ ] 撮影 → OCR 結果がフォームに反映される（誤認識は手修正できる）

**永続化・権限の確認**
- [ ] アプリ再起動後も登録した車両が残っている（Firestore 保存）
- [ ] 別アカウントでログインすると他人の車両が見えない（所有者ルールの確認）
- [ ] 未ログイン/セッション切れ時は登録ボタンで適切なエラーが出る

---

## フェーズB — 他の人にも配る

> 「お試し」だけなら不要。配布したくなったらここから。各ストアの登録・審査に時間がかかる。

### B-1. Android: Google Play 内部テスト配信
1. **Google Play Console アカウント作成**（初回登録料 **$25 / 一回のみ**）
2. **リリース用キーストアを生成**（紛失厳禁・以降のアップデートに必須）:
   ```bash
   keytool -genkey -v -keystore release.keystore \
     -alias trust-car-platform -keyalg RSA -keysize 2048 -validity 10000
   ```
3. `android/key.properties` を作成（gitignore 済み・**キーストアの絶対パス推奨**）:
   ```properties
   storePassword=<パスワード>
   keyPassword=<パスワード>
   keyAlias=trust-car-platform
   storeFile=/Users/<ユーザー名>/release.keystore
   ```
4. ✅ `android/app/build.gradle.kts` のリリース署名設定は **設定済み**。
   `android/key.properties` が存在すればリリース署名を自動使用し、無ければデバッグ署名に
   フォールバックする（CI・`flutter run` を壊さない）。**人間の作業は 2〜3 のみ**。
5. ビルドして AAB を作成 → Play Console にアップロード:
   ```bash
   flutter build appbundle --release
   ```
6. Play Console → テスト → 内部テスト → テスターのメールを登録 → リンクを共有

### B-2. iOS: TestFlight 配信
1. **Apple Developer Program に加入**（**$99 / 年**）
2. Apple Developer Console で App ID（`jp.trustcar.app`）・Distribution 証明書・Provisioning Profile を作成
3. App Store Connect で当該 App を作成
4. Xcode で Archive → App Store Connect へアップロード（または `flutter build ipa --release`）
5. App Store Connect → TestFlight → テスターを招待（内部テスターはすぐ、外部は簡易レビューあり）

✅ **フェーズB完了チェック**
- [ ] B-1 Google Play 内部テストでテスターが入手・登録できた
- [ ] B-2 TestFlight でテスターが入手・登録できた

---

## 詰まりやすいポイント

| 症状 | 原因 / 対処 |
|------|------------|
| 登録ボタンで「ログインセッションが切れました」 | 0-1 の Auth 未有効化 / 未ログイン |
| 登録時に permission-denied | 0-2 のルール未デプロイ |
| 写真アップロードで失敗 | 0-3 の Storage 未有効化、または storage ルール未デプロイ |
| `flutter run` で端末が出ない | USBデバッグ未ON（Android）/「信頼」未許可（iOS）|
| iOS 実機でアプリが起動直後に落ちる | GoogleService-Info.plist 未配置、または署名 Team 未設定 |
| iOS 無料アカウントで `flutter build ipa` 不可 | 配布(IPA)は Developer Program($99/年) が必要 |

---

*関連ドキュメント: `docs/SETUP_AND_STORE_GUIDE.md`（コマンド詳細）/ `docs/HUMAN_TASKS.md`（全リリース向け網羅版）*
