# TrustCar PM 評価レポート

> **作成日**: 2026-04-29  
> **対象ブランチ**: `claude/continue-development-WYZZp`  
> **評価者**: PM Agent  
> **総合スコア**: **8.6 / 10**

---

## エグゼクティブサマリー

TrustCar は Phase 1〜7 の基盤実装が完了し、技術的なローンチ準備は高い水準に達している。コア機能（認証・車両管理・整備記録・SNS・BtoBマーケット）はすべて実装済みで、1,866件のテストが存在する。ただし、**ストアへの申請を実行するには人間が対応する必要のある P0/P1 ブロッカーが 11 件残っている**。Phase 7（BtoB課金）の基盤は今日実装されたが、RevenueCat 連携（Week 2）と Cloud Functions（Week 4）が未完了のため収益化はまだ先。

---

## 1. 進捗サマリー

### 1-1. フェーズ完了状況

| フェーズ | 内容 | 状態 |
|---------|------|------|
| Phase 1 | 認証（メール/パスワード） | ✅ 完了 |
| Phase 2 | 車両管理・OCR（車検証） | ✅ 完了 |
| Phase 3 | 整備記録・PDF出力・請求書OCR | ✅ 完了 |
| Phase 4 | GPSドライブログ | ✅ 完了 |
| Phase 5 | カーライフSNS（投稿・いいね・フォロー） | ✅ 完了 |
| Phase 6 | BtoBマーケット（店舗・問い合わせ・出品） | ✅ 完了 |
| Phase 7 | BtoB課金基盤（プラン・制限ロジック） | 🟡 基盤実装済み・RevenueCat連携待ち |
| Phase 8 | 予約カレンダー・高精度AIパーツ推薦 | ⬜ 未着手（ローンチ後） |

### 1-2. 直近コミット（本日分）

| コミット | 内容 |
|---------|------|
| `71d6908` | Phase 7 BtoB subscription 基盤（ShopSubscriptionService・Provider・UI・テスト） |
| `5e88faa` | プロフィール編集・PDFエクスポート・カメラフラッシュの TODO 3件を解消 |
| `3f0094b` | App Store / Google Play ストアメタデータ作成 |
| `fe072bf` | firebase config files 生成・GitHub Pages 用 HTML 作成 |

---

## 2. コード品質評価

### 2-1. スコアカード

| 指標 | 値 | 評価 |
|-----|-----|------|
| テスト件数（unit/widget） | 1,866 件 | ✅ 優秀 |
| テストファイル数 | 81 ファイル | ✅ |
| 実装ファイル数 | 125 ファイル | — |
| テスト/実装比率 | 0.65 | ✅ 良好 |
| lib/ コード行数 | 46,404 行 | — |
| test/ コード行数 | 31,307 行 | — |
| 残存 TODO コメント | **1 件**（Phase 7 Week 2 用マーカー） | ✅ 許容範囲 |
| `print()` / `debugPrint` 残存 | 12 件（OCR デバッグ用含む） | 🟡 要改善 |
| CI ワークフロー | 存在・coverage 付き | ✅ |
| `flutter analyze` | 設定あり（`--fatal-infos`） | ✅ |

### 2-2. テストカバレッジ詳細

| カテゴリ | テスト件数 | カバー率 |
|---------|---------|---------|
| models | 386 件 | ✅ 全19モデル |
| services | 799 件 | ✅ 全21サービス |
| providers | 337 件 | 🟡 15中13（`subscription_provider`・`base_provider` 未テスト） |
| screens | 20 件 | 🔴 35中12画面のみ（ウィジェットテスト薄い） |
| core | 146 件 | ✅ |

### 2-3. 特定された品質問題

#### P1 問題（今日中に修正）

| # | 問題 | ファイル | 影響 |
|---|-----|---------|------|
| Q1 | `SubscriptionProvider` のテストなし | `test/providers/` | 新Providerの動作保証なし |
| Q2 | `shop_test.dart` が `enterprise` tier / `subscriptionStatus` フィールドをカバーしていない | `test/models/shop_test.dart` | 今日追加したモデル変更の回帰テストなし |

#### P2 問題（今週中）

| # | 問題 | ファイル | 影響 |
|---|-----|---------|------|
| Q3 | `debugPrint` が OCR 2 サービスに残存（本番ビルドでも実行される） | `invoice_ocr_service.dart:181-183`、`vehicle_certificate_ocr_service.dart:133-135` | 本番ログにOCRテキストが出力される（情報漏洩リスク） |
| Q4 | `screens/` のウィジェットテストが薄い（35画面中12画面のみ） | `test/screens/` | 新画面（`ShopPlanScreen`、`ProfileEditSheet` 等）の動作未保証 |

---

## 3. ローンチ準備状況

### 3-1. ブロッカー一覧（人間対応必須）

#### P0 — リリースブロッカー

| # | タスク | 担当 | 期限 |
|---|-------|------|------|
| H1 | **GitHub Secrets `GOOGLE_SERVICES_JSON` 登録** | 人間 | 即日 |
| H2 | **Apple Developer Program 登録**（$99/年、審査48h） | 人間 | 今週 |
| H3 | **Google Play Developer 登録**（$25） | 人間 | 今週 |

#### P1 — ローンチ前必須

| # | タスク | 担当 | 期限 |
|---|-------|------|------|
| H4 | Firebase Authentication 有効確認（メール/パスワード） | 人間 | 今週 |
| H5 | Firebase Crashlytics 有効化（Console ボタン押すだけ） | 人間 | 今週 |
| H6 | GitHub Pages 有効化（Privacy/Terms URL 公開） | 人間 | 今週 |
| H7 | App Store Connect でアプリ登録（Bundle ID: `jp.trustcar.app`） | 人間 | 来週 |
| H8 | Google Play Console でアプリ登録 | 人間 | 来週 |
| H9 | Android リリース keystore 作成 | 人間 | 来週 |
| H10 | iOS 証明書・プロビジョニングプロファイル作成（Mac必要） | 人間 | 来週 |
| H11 | リリースビルド動作確認（Android APK + iOS） | 人間 | 再来週 |

### 3-2. AI 対応残タスク

| # | タスク | 優先度 | 工数目安 |
|---|-------|-------|---------|
| A1 | SubscriptionProvider テスト追加 | P1 | 1h |
| A2 | shop_test.dart に新フィールドのテスト追加 | P1 | 30min |
| A3 | OCR services の debugPrint を LoggingService 経由に変更 | P2 | 30min |
| A4 | RevenueCat SDK 統合（Phase 7 Week 2） | P2 | 4h |
| A5 | Cloud Functions: RevenueCat Webhook 実装 | P2 | 8h |
| A6 | inquiry_service に問い合わせ上限チェック組み込み | P2 | 1h |

---

## 4. アーキテクチャ評価

### 良い点

- **一貫したアーキテクチャ**: Service → Provider → UI の分離が全ファイルで守られている
- **Result 型パターン**: 全 Service が `Result<T, AppError>` を返しており、エラーハンドリングが統一
- **テスタビリティ**: Firebase 依存は全 Service でコンストラクタ注入可能（`FakeFirebaseFirestore` で単体テスト可能）
- **セキュリティ設計**: Firestore rules で subscriptionStatus の直接書き込みを Cloud Functions のみに制限（今日実装）

### 改善余地

- **`CLAUDE_SESSION_NOTES.md` が 2026-03-25 以降更新されていない**（最新状態を反映していない）
- **screens/ テストが薄い**: 35画面中12画面のみカバー（約34%）

---

## 5. リスク評価

| リスク | 確率 | 影響 | 対策 |
|-------|-----|-----|-----|
| Apple 審査が 48h 超過 | 中 | 高（リリース遅延） | 今週中に申請書類準備 |
| Firebase Spark 無料枠超過（DAU 100人超で発生可能性） | 中 | 中 | Blaze 移行手順は MAINTENANCE_RUNBOOK.md に記載済み |
| RevenueCat 連携前に収益ゼロでスタート | 高 | 低（想定内） | ローンチ後 3〜6ヶ月で Phase 7 完成予定 |
| keystore 紛失（Android 更新不可になる） | 低 | 最高 | 作成後すぐにクラウドストレージへバックアップ |
| sha-1 未登録で Google Sign-In 動作不可 | 中 | 低（メール認証のみでローンチ可） | 初回ローンチはメール認証のみ |

---

## 6. 総合スコア（前回比較）

| 軸 | 今回 | 前回 (2026-03-25) | 変化 |
|----|-----|-----------------|-----|
| 技術的完成度 | **9.0 / 10** | 8.5 | ↑ (+0.5) |
| テスト品質 | **8.5 / 10** | 8.0 | ↑ (+0.5) |
| セキュリティ | **8.5 / 10** | 8.0 | ↑ (+0.5) |
| ビジネスモデル | **6.5 / 10** | 5.0 | ↑ (+1.5)（Phase 7 基盤完成） |
| 保守・運用 | **8.5 / 10** | 8.5 | → |
| ストア審査準備 | **7.0 / 10** | 7.0 | → |
| **総合** | **8.6 / 10** | 8.2 | ↑ (+0.4) |

---

## 7. 次週アクションプラン

### 人間が今週やること（P0/P1）

```
月: GitHub Secrets 登録 → Apple Developer / Google Play 申請開始
火: Firebase Auth 確認・Crashlytics 有効化
水: GitHub Pages 有効化
木〜金: ストア登録（App Store Connect / Google Play Console）
```

### AI が今日修正すること（品質問題）

```
[ ] Q1: SubscriptionProvider テスト追加
[ ] Q2: shop_test.dart に enterprise / subscriptionStatus テスト追加
[ ] Q3: OCR debugPrint → LoggingService 経由に変更
[ ] CLAUDE_SESSION_NOTES.md 更新
```

---

*このレポートは `docs/PM_EVALUATION_REPORT_2026-04-29.md` として保存されました。*
