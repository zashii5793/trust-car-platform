# Launch Plan — 2026年4月

> **作成日**: 2026-04-14
> **ローンチ目標日**: 2026年4月30日
> **現在日**: 2026年4月14日（残り16日）
> **ブランチ**: `claude/continue-development-WYZZp`
> **総合評価**: 8.2/10 — ローンチ可能（P0・P1人間作業の完了が条件）

---

## ローンチ目標日

**2026年4月30日**（ソフトローンチ — iOS + Android 同時公開）

---

## 現状サマリ

### 実装済み機能（2026-03-25時点）

| 機能領域 | 完成度 | 状態 |
|---------|--------|------|
| 認証（Email/Google） | 95% | 本番運用可能 |
| 車両管理 CRUD | 95% | バリデーション含む |
| 整備記録タイムライン（22種類） | 95% | 本番運用可能 |
| 車検証 OCR（ML Kit） | 85% | 実機テスト推奨 |
| アラート / 通知 | 90% | Push通知設定済み |
| SNS（投稿・いいね・コメントUI） | 80% | 投稿詳細・インラインリプライ実装済み |
| ドライブログ（一覧・タイムライン統合） | 55% | GPS記録は未実装 |
| BtoBマーケット（工場） | 75% | UI完成、取引フロー未実装 |
| BtoBマーケット（パーツ） | 70% | 詳細画面完成、購入フロー未実装 |
| プライバシーポリシー / 利用規約画面 | 100% | 実装・テスト済み |

### テスト・品質状況（2026-03-25時点）

- テスト件数: 約 1,933件（unit + widget）— 全件パス
- `flutter analyze`: クリーン
- P0バグ（BUG-1 状態二重管理 / BUG-2 toggleLike レースコンディション）: 修正済み
- Firebase Emulator 対応: 完了（CI `continue-on-error: true` 設定済み）
- Firestore security rules: 実装済み（本番デプロイ待ち）
- Firestore indexes: 約30件定義済み（本番デプロイ待ち）

### インフラ状況

| 項目 | 状態 |
|------|------|
| Bundle ID `jp.trustcar.app` | 全プラットフォーム変更済み |
| `google-services.json` | 仮ファイル — 本番版に要更新（人間作業） |
| `GoogleService-Info.plist` | 未配置（人間作業） |
| GitHub Secrets `GOOGLE_SERVICES_JSON` | 未登録（人間作業） |
| Firestore rules デプロイ | 未実施（人間作業） |
| Firebase Crashlytics 有効化 | 未実施（人間作業） |

---

## 残タスク（優先度付き）

### P0 — リリースブロッカー（これがないとビルド不可）

| # | タスク | 担当 | 工数目安 |
|---|--------|------|---------|
| P0-1 | `google-services.json` 本番版をダウンロード → `android/app/` に配置 | 人間 | 30分 |
| P0-2 | `GoogleService-Info.plist` をダウンロード → `ios/Runner/` に配置（Mac必要） | 人間 | 30分 |
| P0-3 | GitHub Secrets に `GOOGLE_SERVICES_JSON` を登録 | 人間 | 15分 |
| P0-4 | Firestore rules & indexes を本番にデプロイ | 人間 | 30分 |

### P1 — ローンチ前必須（ストア審査に必要）

| # | タスク | 担当 | 工数目安 |
|---|--------|------|---------|
| P1-1 | Apple Developer Program 登録（$99/年、審査最大48時間） | 人間 | 1日 |
| P1-2 | Google Play Developer 登録（$25 一回払い） | 人間 | 1日 |
| P1-3 | App Store Connect にアプリ登録（Bundle ID: `jp.trustcar.app`） | 人間 | 2時間 |
| P1-4 | Google Play Console にアプリ登録 | 人間 | 2時間 |
| P1-5 | プライバシーポリシーをウェブ公開（URLが必要） | 人間 | 2時間 |
| P1-6 | 利用規約をウェブ公開（URLが必要） | 人間 | 2時間 |
| P1-7 | サポートページ URL を用意 | 人間 | 1時間 |
| P1-8 | Firebase Crashlytics を有効化 | 人間 | 30分 |
| P1-9 | Android リリース用 keystore 作成 | 人間 | 30分 |
| P1-10 | iOS リリースビルド証明書・Provisioning Profile 作成（Mac + Xcode 必要） | 人間 | 2時間 |
| P1-11 | リリースビルド動作確認（Android APK + iOS IPA） | 人間 | 2時間 |

### P2 — ストア申請前（審査通過に必要）

| # | タスク | 担当 | 工数目安 |
|---|--------|------|---------|
| P2-1 | スクリーンショット準備（iPhone 6.7"、iPad、Android フォン + 7インチ） | 人間 | 3時間 |
| P2-2 | アプリアイコン最終版確認（iOS 1024×1024px / Android 512×512px） | 人間 | 1時間 |
| P2-3 | App Store 説明文・キーワード作成（日本語） | 人間 | 2時間 |
| P2-4 | Google Play 説明文・スクリーンショット登録 | 人間 | 2時間 |
| P2-5 | TestFlight アップロード・社内βテスト | 人間 | 2時間 |
| P2-6 | 審査員用テストアカウント情報を用意 | 人間 | 30分 |

### P3 — β公開後（ローンチ後 1〜3ヶ月以内）

| # | タスク | 担当 |
|---|--------|------|
| P3-1 | GPS リアルタイム記録機能実装 | Claude |
| P3-2 | Push通知のいいね・コメント連携 | Claude |
| P3-3 | BtoB 課金機能（加盟料・成果報酬 — Phase 7） | Claude |
| P3-4 | Firebase Blaze Plan 移行（登録300人超または Storage 700MB超） | 人間 |
| P3-5 | Google Cloud 予算アラート設定（$10/月） | 人間 |
| P3-6 | BtoBパートナー（工場・業者）初期リクルーティング（5〜10社） | 人間 |
| P3-7 | ユーザーインタビュー実施（βユーザー最低5人） | 人間 |

---

## 週次マイルストーン

### Week 1（4/14 - 4/18）: Firebase 本番設定 + ビルド確立

**目標**: Android / iOS 両プラットフォームでリリースビルドが通る状態にする

| 日程 | タスク | 担当 |
|------|--------|------|
| 4/14（月） | `google-services.json` 本番版 DL・配置（P0-1） | 人間 |
| 4/14（月） | `GoogleService-Info.plist` DL・配置（P0-2） | 人間 |
| 4/14（月） | GitHub Secrets `GOOGLE_SERVICES_JSON` 登録（P0-3） | 人間 |
| 4/15（火） | Firestore rules & indexes 本番デプロイ（P0-4） | 人間 |
| 4/15（火） | Firebase Crashlytics 有効化（P1-8） | 人間 |
| 4/16（水） | Android keystore 作成（P1-9） | 人間 |
| 4/16（水） | `flutter build apk --release` 成功確認 | 人間 |
| 4/17（木） | iOS 証明書・Provisioning Profile 作成（P1-10） | 人間（Mac必要） |
| 4/17（木） | `flutter build ios --release` 成功確認 | 人間（Mac必要） |
| 4/18（金） | CI パイプライン正常稼働確認 | Claude / 人間 |

**Week 1 完了条件**: `flutter build apk --release` および `flutter build ios --release` が両方成功する

### Week 2（4/21 - 4/25）: ストア申請準備

**目標**: App Store / Google Play に申請できる状態にする

| 日程 | タスク | 担当 |
|------|--------|------|
| 4/21（月） | Apple Developer Program 登録（P1-1、審査待ち含む） | 人間 |
| 4/21（月） | Google Play Developer 登録（P1-2） | 人間 |
| 4/21（月） | プライバシーポリシー・利用規約をウェブ公開（P1-5, P1-6） | 人間 |
| 4/22（火） | App Store Connect アプリ登録（P1-3） | 人間 |
| 4/22（火） | Google Play Console アプリ登録（P1-4） | 人間 |
| 4/23（水） | スクリーンショット撮影・準備（P2-1） | 人間 |
| 4/23（水） | アプリアイコン最終確認（P2-2） | 人間 |
| 4/24（木） | TestFlight アップロード・社内βテスト（P2-5） | 人間 |
| 4/24（木） | App Store 説明文・キーワード作成（P2-3） | 人間 |
| 4/25（金） | Google Play 説明文・スクリーンショット登録（P2-4） | 人間 |
| 4/25（金） | 審査員用テストアカウント準備（P2-6） | 人間 |

**Week 2 完了条件**: App Store Connect / Google Play Console への申請パッケージが揃っている

### Week 3（4/28 - 4/30）: 審査申請 + ローンチ

**目標**: 両ストアに審査申請し、4月30日公開を実現する

| 日程 | タスク | 担当 |
|------|--------|------|
| 4/28（月） | App Store 審査申請（通常 3〜7日） | 人間 |
| 4/28（月） | Google Play 審査申請（通常 3〜5日） | 人間 |
| 4/28〜4/30 | 審査フィードバック対応（リジェクト時は即日対応） | 人間 + Claude |
| 4/30（木） | 公開（審査通過次第、即日リリース設定） | 人間 |

**注意**: App Store 審査は最大 7日かかる場合がある。4/28 申請で 5/5 通過のリスクがある。
リスク軽減のため、Week 2 末（4/25）に申請できる体制が理想。

---

## P0 ブロッカー（ローンチ前必須）

以下がひとつでも未完了だとリリースできない。

| # | ブロッカー | 状態 | 解除方法 |
|---|-----------|------|---------|
| B-1 | `google-services.json` 本番版未配置 | 未完了 | Firebase Console → Android アプリ → ダウンロード → `android/app/` に配置 |
| B-2 | `GoogleService-Info.plist` 未配置 | 未完了 | Firebase Console → iOS アプリ → ダウンロード → `ios/Runner/` に配置（Mac + Xcode 必要） |
| B-3 | Firestore rules & indexes 未デプロイ | 未完了 | `firebase deploy --only firestore:rules,firestore:indexes` |
| B-4 | Apple Developer Program 未登録 | 未完了 | https://developer.apple.com/programs/ で登録（審査最大48時間） |
| B-5 | Android リリース keystore 未作成 | 未完了 | `keytool -genkey ...` で生成（紛失厳禁） |

---

## リスクと対策

| リスク | 確率 | 影響 | 対策 |
|--------|------|------|------|
| Apple Developer 審査遅延（最大 48時間） | 中 | Week 2 の計画が後ろ倒し | 4/21（月）朝一番に申請する |
| App Store 審査リジェクト（プライバシー・UI不備） | 中 | 公開が5月以降にずれ込む | リジェクト理由の事前チェックリストを実施。テストアカウント・プライバシーURL・位置情報説明を完備する |
| Firebase Spark 無料枠超過（ユーザー 1,000人超） | 低 | サービス停止 | 300人超えたら Blaze Plan 移行。Google Cloud 予算アラート $10/月 設定 |
| `google-services.json` 配置後の CI 失敗 | 中 | ビルドパイプライン停止 | 配置後すぐに CI を手動実行して確認する |
| iOS リリースビルド失敗（Mac環境依存） | 中 | iOS 公開が遅延 | Week 1 中（4/17 まで）に Mac 環境でビルド確認を済ませる |
| 審査員によるクラッシュ検出 | 低 | リジェクト | 実機でリリースビルドの全主要フロー（ログイン・車両登録・整備記録・SNS）を事前確認する |
| OCR 機能（ML Kit）の実機不具合 | 中 | 機能低下・苦情 | 審査申請前に実機テスト。不具合発見時は車検証OCRを「β機能」として説明文に明記 |

---

## ローンチチェックリスト

### インフラ

- [ ] `google-services.json` 本番版を `android/app/` に配置（Firebase Console DL）
- [ ] `GoogleService-Info.plist` を `ios/Runner/` に配置（Firebase Console DL）
- [ ] Firebase Authentication でメール/パスワード認証が有効になっているか確認
- [ ] Firestore rules を本番にデプロイ（`firebase deploy --only firestore:rules`）
- [ ] Firestore indexes を本番にデプロイ（`firebase deploy --only firestore:indexes`）
- [ ] Firebase Console → API キーにパッケージ名・Bundle ID の制限を設定
- [ ] Firebase Crashlytics を有効化

### ビルド・署名

- [ ] Android リリース keystore 作成・安全な場所にバックアップ
- [ ] `android/key.properties` に keystore パス・パスワード記載（.gitignore 済み確認）
- [ ] `flutter build apk --release` でビルド成功
- [ ] iOS 証明書・Provisioning Profile 作成（Mac + Xcode）
- [ ] `flutter build ios --release` でビルド成功
- [ ] GitHub Secrets に `GOOGLE_SERVICES_JSON` を登録済み

### テスト・品質

- [ ] `flutter test --exclude-tags emulator` 全件パス
- [ ] `flutter analyze lib/` クリーン
- [ ] Android 実機（または最新エミュレータ）でリリースビルドの動作確認
- [ ] iOS 実機（または最新シミュレータ）でリリースビルドの動作確認
- [ ] Firebase Crashlytics がログを受け取っているか確認（初回リリースビルド起動）
- [ ] 主要フロー（ログイン → 車両登録 → 整備記録 → SNS投稿）をリリースビルドで確認

### ストア申請

- [ ] Apple Developer Program 登録済み（$99/年）
- [ ] Google Play Developer 登録済み（$25）
- [ ] App Store Connect にアプリ登録（Bundle ID: `jp.trustcar.app`）
- [ ] Google Play Console にアプリ登録（Package name: `jp.trustcar.app`）
- [ ] アプリアイコン（iOS: 1024×1024px / Android: 512×512px）用意済み
- [ ] スクリーンショット用意済み（iPhone 6.7" / iPad / Android フォン + 7インチ）
- [ ] アプリ説明文（短い説明 80文字以内 + 詳細説明）日本語で作成済み
- [ ] App Store キーワード（100文字以内）設定済み

### 法的・コンプライアンス

- [ ] プライバシーポリシーをウェブ URL で公開済み
- [ ] 利用規約をウェブ URL で公開済み
- [ ] サポートページ URL（またはメールアドレス）用意済み
- [ ] 位置情報使用理由が iOS `Info.plist` に記載されているか確認
- [ ] 審査員用テストアカウント情報を用意済み

### リリース後（β公開後 1週間以内）

- [ ] Google Cloud 予算アラート $10/月 設定
- [ ] Firebase Alerts（クラッシュフリー率 99%以下でアラート）設定
- [ ] App Store / Google Play レビュー返信ルール決定（例: 1つ星 → 24時間以内返信）
- [ ] BtoBパートナー候補（工場・業者）への声がけ開始

---

## 参考リンク

| ドキュメント | パス |
|-------------|------|
| 人間対応タスク管理 | `docs/HUMAN_TASKS.md` |
| 保守・運用ランブック | `docs/MAINTENANCE_RUNBOOK.md` |
| ローンチチェックリスト（詳細） | `docs/LAUNCH_CHECKLIST.md` |
| デプロイ準備評価レポート | `docs/DEPLOY_READINESS_REPORT.md` |
| セッションメモ | `CLAUDE_SESSION_NOTES.md` |
