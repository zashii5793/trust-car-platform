# リリース解除ランブック（実機で1台登録するまで）

**作成日**: 2026-07-13
**対象**: プロジェクトオーナー（Firebase Console オーナー権限を持つ人）
**目的**: Issue #49（priority: high）と HUMAN_TASKS P0 を、**コピペで実行できる最短チェックリスト**にまとめる。これが済むまで実機で車両を1台も登録できない。
**想定所要時間**: 約30〜40分（フェーズ0のみ）

> ⚠️ これらは **AIでは代替できない人間作業**。Firebase Console のオーナー権限が必須。
> コード実装・Android署名設定・ルール記述は完了済み。ここでやるのは「有効化」と「本番反映」だけ。

---

## 前提の確認（最初の2分）

```bash
# Firebase CLI が入っているか
firebase --version            # 無ければ: npm install -g firebase-tools

# ログイン（プロジェクトオーナーのGoogleアカウントで）
firebase login

# 対象プロジェクトを確認（trust-car の本番プロジェクトが選ばれているか）
firebase projects:list
firebase use                  # 現在の alias を確認。違えば firebase use <project-id>
```

---

## フェーズ0 — これが無いと登録できない（最優先）

### 0-1. Firebase Authentication を有効化 🔴 最優先

> 車両登録は送信時にログイン必須。これが無いと必ず弾かれる。

**手動操作（Console）**:
1. [Firebase Console](https://console.firebase.google.com/) → 対象プロジェクト → **Authentication** → **Sign-in method**
2. **メール / パスワード** を「有効」にする ✅
3. （任意）**Google** も使うなら「有効」→ Android は **SHA-1 フィンガープリント**を登録
   ```bash
   # デバッグ用 SHA-1 の取得（Android）
   cd android && ./gradlew signingReport | grep SHA1
   ```

- [ ] メール/パスワード = 有効
- [ ] （任意）Google = 有効 ＋ SHA-1 登録

---

### 0-2. Firestore / Storage ルールとインデックスをデプロイ

> `vehicles` 等のルールはリポジトリにあるが**本番未反映だと書き込みが弾かれる**。

**デプロイ前の安全確認（推奨）**:
```bash
git pull                                   # 最新の firestore.rules / indexes を取得
cd test/rules && npm install && npm test   # Emulatorでルールテストが緑か確認
cd ../..
firebase deploy --only firestore:rules --dry-run   # 差分とコンパイル確認（ドライラン）
```

**本番反映**:
```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

**確認**: Firebase Console → Firestore → ルール → バージョン履歴に反映時刻が出ること。

- [ ] ルールテスト緑
- [ ] ドライランでエラーなし
- [ ] `firebase deploy` 実行
- [ ] Console バージョン履歴で反映確認

> 補足: 複合インデックスは初回クエリ時に「作成中」になることがある。数分待つ。

---

### 0-3. Cloud Storage を有効化（写真を付ける場合）

1. Console → **Storage** → 「始める」でバケット作成
2. ロケーション選択（例: `asia-northeast1`）→ 本番モードで開始
3. `storage.rules` は 0-2 で `--only storage` 済みなら反映済み

- [ ] バケット作成済み

---

### 0-4. 設定ファイルを配置（コミット禁止・.gitignore対象）

> `google-services.json` / `GoogleService-Info.plist` は**リポジトリにコミットしない**（CLAUDE.md 禁止事項）。ローカルに置くだけ。

1. Console → プロジェクト設定 → マイアプリ → Android アプリ → `google-services.json` をダウンロード
   → `android/app/google-services.json` に配置
2. 同 → iOS アプリ → `GoogleService-Info.plist` をダウンロード
   → `ios/Runner/GoogleService-Info.plist` に配置

```bash
# 配置後、gitignore されていることを確認（追跡されていないのが正常）
git status --porcelain android/app/google-services.json ios/Runner/GoogleService-Info.plist
# → 何も出なければ OK（.gitignore 済み）
```

- [ ] Android 設定ファイル配置
- [ ] iOS 設定ファイル配置
- [ ] `git status` に出ない（コミット対象外）ことを確認

---

## フェーズA — 自分の実機で1台登録（お試し）

### A-1. Android 実機（署名不要・最短）
```bash
# 端末をUSB接続 → 開発者向けオプションでUSBデバッグをON
flutter devices          # 端末が見えるか
flutter run              # kDebugMode=true。debugビルドで起動
```

### A-2. iPhone 実機（無料Apple IDで7日間）
1. `open ios/Runner.xcworkspace`（Xcode）
2. Runner → Signing & Capabilities → **Team** に自分のApple IDを設定（Automatically manage signing）
3. `flutter run`（端末選択）

### A-3. 登録フロー実機確認
- [ ] ログイン（0-1 が効いているか）
- [ ] 車両登録（車検証OCR or 手入力）→ 保存が通る（0-2 が効いているか）
- [ ] 写真添付 → アップロード成功（0-3 が効いているか）
- [ ] 整備記録を1件追加 → タイムラインに出る

---

## フェーズB — 他の人にも配る（任意・各ストア登録が必要）

| 項目 | 必要なもの | 備考 |
|------|-----------|------|
| B-1 Android内部テスト | Google Play 登録料 $25・keystore生成＋`key.properties` | `build.gradle.kts` の署名設定は実装済み |
| B-2 iOS TestFlight | Apple Developer Program $99/年・証明書＋Provisioning Profile | — |

```bash
# Android リリースビルド（keystore と key.properties 用意後）
flutter build appbundle --release
```

---

## シードデータ（任意・体験を良くする）

安全情報・コミュニティトレンドの初期データ投入（**本番誤投入ガードに注意**）:
```bash
cd scripts && npm install    # firebase-admin は v12 ピン（v14はnamespaced API削除で全滅するため注意）
# node seed_safety_tips.js / node seed_community_trends.js （対象プロジェクトを必ず確認）
```

---

## 完了判定

フェーズ0（0-1〜0-4）とA-3 が全部チェックできたら、**実機で車両登録が通る＝リリース解除**。
以降は滞留PRのマージ（`docs/OPEN_PR_TRIAGE_2026-07-13.md`）で、実装済み機能を本番へ反映していく。

---

_出典: Issue #49 / `docs/HUMAN_TASKS.md` P0 / CLAUDE.md 禁止事項。コマンドは対象プロジェクトを必ず確認してから実行すること。_
