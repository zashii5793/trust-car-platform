# 人間対応タスク一覧

> このファイルは **人間が手動でやらないとAIが代替できないタスク**を管理します。
> 完了したら `- [ ]` を `- [x]` に変更してください。
> 毎週月曜のPMレポートで自動集計されます。

---

## 🔴 P0 — リリースブロッカー（これがないとビルドできない）

- [ ] **Firebase Console: `google-services.json` を本番版に更新**
  - 手順: Firebase Console → プロジェクト設定 → Android アプリ → ダウンロード
  - 配置先: `android/app/google-services.json`（現在は仮ファイル）
  - 確認: `cat android/app/google-services.json | python3 -m json.tool` でエラーなし

- [ ] **Firebase Console: `GoogleService-Info.plist` を配置**
  - 手順: Firebase Console → プロジェクト設定 → iOS アプリ → ダウンロード
  - 配置先: `ios/Runner/GoogleService-Info.plist`
  - 注意: Mac + Xcode が必要。Xcodeでファイルをドラッグ追加（コピーにチェック）

- [ ] **GitHub Secrets に `GOOGLE_SERVICES_JSON` を登録**
  - 手順: GitHub リポジトリ → Settings → Secrets → New secret
  - 値: `google-services.json` の内容をそのまま貼り付け
  - 目的: CI (GitHub Actions) の Android ビルドで使用

---

## 🟠 P1 — ローンチ前必須（ストア審査に必要）

### Firebase / インフラ

- [ ] **Firestore ルール & インデックスを本番に適用**
  ```bash
  firebase login
  firebase deploy --only firestore:rules,firestore:indexes
  ```
  - 確認: Firebase Console → Firestore → ルール タブで最新が反映されているか

- [ ] **Firebase Authentication の設定確認**
  - メール/パスワード認証: 有効になっているか
  - Firebase Console → Authentication → Sign-in method

- [ ] **Firebase Crashlytics を有効化**
  - Firebase Console → Crashlytics → 「使ってみる」ボタンを押す
  - 初回リリースビルドを実行するとダッシュボードが表示される

### ストア登録

- [ ] **Apple Developer Program に登録**（$99/年）
  - https://developer.apple.com/programs/
  - 所要時間: 最大48時間（審査あり）
  - 必要: クレジットカード、Apple ID、D-U-N-S番号（法人の場合）

- [ ] **Google Play Developer に登録**（$25 一回払い）
  - https://play.google.com/console/
  - 所要時間: 即時〜数日

- [ ] **App Store Connect でアプリ登録**
  - Bundle ID: `jp.trustcar.app`
  - アプリ名: `TrustCar`（または最終決定した名前）
  - カテゴリ: ライフスタイル または 仕事効率化

- [ ] **Google Play Console でアプリ登録**
  - Package name: `jp.trustcar.app`
  - カテゴリ: 車とナビ

### 法的・コンプライアンス

- [ ] **プライバシーポリシーをウェブ上に公開**
  - App Store / Google Play はアプリ内だけでなく**URLも要求**する
  - 推奨: GitHub Pages, Notion 公開ページ, または独自ドメイン
  - URLをメモしておく（ストア登録時に入力）
  - 例: `https://trustcar.jp/privacy` または `https://yourname.github.io/trustcar/privacy`

- [ ] **利用規約をウェブ上に公開**
  - 同上。URL をストア登録時に入力する

- [ ] **サポートページ URL を用意**
  - App Store 審査で必須。最低限メールアドレスのみのページでも可
  - 例: `support@trustcar.jp` を記載したシンプルなページ

---

## 🟡 P2 — ストア申請前（審査通過に必要）

### ビルド・署名

- [ ] **iOS リリースビルド用の証明書・プロビジョニングプロファイルを作成**（Mac必要）
  ```
  Xcode → Preferences → Accounts → Manage Certificates
  → + → Apple Distribution
  ```

- [ ] **Android リリース用 keystore を作成**
  ```bash
  keytool -genkey -v -keystore trustcar-release.keystore \
    -alias trustcar -keyalg RSA -keysize 2048 -validity 10000
  ```
  - ⚠️ このファイルを**絶対に紛失しないこと**（Google Play への更新に必要）
  - ⚠️ `android/key.properties` に keystore のパスとパスワードを記載（.gitignore 済み）

- [ ] **リリースビルドの動作確認**
  ```bash
  flutter build apk --release          # Android
  flutter build ios --release          # iOS（Mac必要）
  ```
  - エミュレーター接続（kDebugMode=false）で Firebase 本番に繋がることを確認

### スクリーンショット・メタデータ

- [ ] **スクリーンショットを GitHub Actions でダウンロード** ← AIが自動生成
  - 手順: GitHub → Actions →「App Screenshots」→ Run workflow → Artifacts からダウンロード
  - 自動撮影される画面: ログイン・ホーム・車両詳細・整備記録・SNSフィード 等
  - ⚠️ ダウンロード後、**説明文テキスト（キャプション）** を各画像に添付する作業は人間が行う
  - App Store 提出形式への変換（解像度確認）は不要（ワークフロー内で対応）

- [ ] **アプリアイコン最終版を確認**
  - iOS: 1024×1024px PNG（アルファなし）
  - Android: 512×512px PNG

- [ ] **アプリの説明文を日本語で作成**
  - 短い説明（80文字以内）
  - 詳細説明（4000文字以内）
  - キーワード（App Store: 100文字以内）

---

## 🟢 P3 — β公開後（ローンチ後1〜3ヶ月以内）

### モニタリング設定

- [ ] **Firebase Alerts の設定**
  - Firebase Console → プロジェクトの設定 → 統合 → Slack or メール通知
  - クラッシュフリー率が 99% を下回ったらアラート

- [ ] **Google Cloud 予算アラートを設定**（Blaze 移行前に必須）
  - Google Cloud Console → 予算とアラート → $10/月で設定
  - 詳細: `docs/MAINTENANCE_RUNBOOK.md` → セクション7参照

- [ ] **Firebase Blaze Plan に移行**
  - タイミング: Storage > 700MB または登録ユーザー 300 人超えたとき
  - 詳細: `docs/MAINTENANCE_RUNBOOK.md` → セクション7参照

### ビジネス

- [ ] **BtoB パートナー（工場・業者）の初期リクルーティング**
  - ローンチ前に5〜10社の工場に声がけしておく
  - SNSで口コミが始まる前に工場側コンテンツを充実させる

- [ ] **ユーザーインタビュー実施**（β期間中、最低5人）
  - 「整備記録の入力は面倒ではなかったか？」
  - 「SNS機能は使うか？」
  - 「BtoBマーケットで工場に問い合わせしたいと思うか？」

- [ ] **App Store / Google Play のレビュー返信ルールを決める**
  - 例: 1つ星レビューには24時間以内に返信する

---

## ✅ 完了済みタスク（参考）

- [x] Bundle ID を `jp.trustcar.app` に変更（2026-03-13）
- [x] `firestore.indexes.json` 約30件を定義（2026-03-13）
- [x] プライバシーポリシー画面・利用規約画面 実装（2026-03-25）
- [x] サインアップ画面の同意文をリンク化（2026-03-25）
- [x] Firebase Emulator 接続（ローカル開発用）追加（2026-03-25）
- [x] CI に `google-services.json` 自動生成ステップ追加（2026-03-25）
- [x] `docs/MAINTENANCE_RUNBOOK.md` 作成（2026-03-25）
- [x] テスト 1,933件 全パス達成（2026-03-25）
- [x] `flutter analyze` クリーン（2026-03-25）

---

## 📅 週次チェックリスト（毎週月曜に確認）

毎週月曜に自動作成される GitHub Issue（`pm-report` ラベル）を確認する。

| 確認項目 | 頻度 |
|---------|------|
| テスト全件パス確認 | 毎週（自動） |
| 静的解析クリーン確認 | 毎週（自動） |
| このファイルのタスク進捗更新 | 毎週（手動） |
| Firebase Console 使用量確認 | 毎週（手動） |
| Crashlytics ダッシュボード確認 | 毎週（手動・リリース後） |
| 未完了タスクの優先度見直し | 月次 |
