# 朝のブリーフィング — 2026-06-21

**夜間エージェント実行時刻**: 2026-06-21 (JST 夜間)  
**Flutter**: 使用不可（コード検証は CI に委譲）  
**mainブランチCI**: 直近 SUCCESS ✅（run #27862841959, 2026-06-20 06:25 UTC）

---

## 実行したアクション（3件完了）

### 1. Issue #39 クローズ — ROI可視化「問い合わせ数の月次通知」
**根拠**: priority:high・claude-task ラベル。CLAUDE_SESSION_NOTES に「残作業: UI配線」と記録されていたが、コードを調査した結果すべての配線が完了していた。

**確認した実装状態（すべてmainにマージ済み / PR #38）**:
- `lib/services/shop_report_service.dart` — `getMonthlyReport()` 実装済み
- `lib/providers/shop_provider.dart` — `ShopReportService` コンストラクタ注入・`monthlyReport` getter 実装済み
- `lib/screens/marketplace/shop_owner_screen.dart:587` — ダッシュボードへのUI配線済み
- `test/services/shop_report_service_test.dart` — テスト済み・CI green

→ **Issue #39 をクローズ（completed）**

---

### 2. Issue #40 クローズ — ShopType にガソリンスタンド追加
**根拠**: enhancement・claude-task ラベル。同じく SESSION_NOTES で実装済みと記録されていたが Issue が残存していた。

**確認した実装状態（PR #38 / commit `030ac77`でmainにマージ済み）**:
- `lib/models/shop.dart:65` — `gasStation('ガソリンスタンド', 'Gas Station')` 追加済み
- `ShopType.fromString` の不明値フォールバック（`other`）も実装済み

→ **Issue #40 をクローズ（completed）**

---

### 3. PR #33 ドラフト解除 → レビュー待ちへ昇格
**根拠**: 2日間 draft のまま放置されていた停滞PR。変更内容は未使用 Firestore ルール関数 `isNewsletterAuthor` の削除のみ（影響ゼロ・リスクなし）。

**CI状況（2026-06-19 UTC）**: Build iOS / Build Android / Analyze & Test / Storage Rules Tests — 全8件 **success** ✅

→ **draft → ready for review に変更。マージ可能状態。**

---

## 現在のオープンPR一覧と推奨アクション

| PR# | タイトル | ドラフト | CI | 日齢 | 推奨 |
|-----|---------|---------|----|----|------|
| **#45** | リリース準備（RevenueCat鍵注入・署名）＋アップデート情報画面 | ❌ 非ドラフト | ✅ | 1日 | **即レビュー・マージ推奨** |
| **#33** | 未使用ルール関数 isNewsletterAuthor を削除 | ❌ 非ドラフト（今夜昇格） | ✅ | 2日 | **即マージ推奨** |
| **#50** | 整備工場向け 月次ROI指標（整備提案 件数・総額） | ✅ ドラフト | ✅ | 0日 | 内容確認後ドラフト解除 |
| **#48** | 実機での車両登録準備とリリースビルド整備 | ✅ ドラフト | ✅ | 0日 | Issue #49 完了後にレビュー |
| **#46** | 業態(ShopType)に業態別アイコンを追加 | ✅ ドラフト | ✅ | 1日 | 内容確認後ドラフト解除 |
| **#35** | 送客トラッキングとOCRワンタップ登録 | ✅ ドラフト | 不明 | 2日 | CI確認・停滞要確認 |
| **#34** | AI提案からの整備工場検索が0件になる不具合修正 | ✅ ドラフト | 不明 | 2日 | バグ修正のため優先確認 |
| **#28** | UX改善 + B2B ROIレポート + 工場認証UI | ✅ ドラフト | 不明 | 2日 | 範囲広い・分割検討 |

### Dependabot PR（83〜104日放置 — 要判断）

| PR# | 内容 | 放置日数 |
|-----|------|---------|
| #19 | codecov-action 4→6 | 83日 |
| #18 | cloud_firestore 6.1.2→6.1.3 | 104日 |
| #17 | build_runner 2.10.5→2.12.2 | 104日 |
| #16 | firebase_core 4.4.0→4.5.0 | 104日 |
| #15 | firebase_messaging 16.1.1→16.1.2 | 104日 |
| #14 | firebase_crashlytics 5.0.7→5.0.8 | 104日 |
| #13 | camera 0.11.3→0.12.0 | 104日 |
| #12 | firebase_auth 6.1.4→6.2.0 | 104日 |

⚠️ 各ブランチは104日間 main とダイバージしており、現在の main（多数の機能追加）との互換性は未確認。個別にリベースして CI を再トリガーすること。camera (#13) は破壊的変更の可能性が高い（0.11→0.12）。

---

## オープンIssueの現状

| Issue# | タイトル | ラベル | 状況 |
|--------|---------|--------|------|
| #49 | 実機で車両登録するためのフェーズ0準備 | priority:high | **人間作業必須**（Firebase設定・設定ファイル配置） |
| #41 | GoogleMap連動（提携/非提携の網羅表示） | priority:high | **ブロック中** — Google Maps APIキー（HUMAN_TASKS #17）が前提 |
| #42 | 初期パートナー向けキャンペーン価格 | enhancement | **今夜 #39 クローズにより着手可能になった**（「順序の鉄則」: ROI可視化完了→本Issueへ） |
| #43 | [#41-1a] 近隣検索の地図表示＋提携ピン | enhancement | **ブロック中** — Google Maps APIキー待ち |
| #44 | [#41-1b] 非提携先の地図表示（Places API） | enhancement | **ブロック中** — #43完了後 |
| #37 | ショーケースコメントのモデレーション（通報） | enhancement | フェーズ1（いいね）はPR #47でマージ済。フェーズ2（通報）は未実装 |
| #30 | ダークモード一貫性（Colors.*直書きをAppColorsへ） | enhancement | Flutter未使用のため夜間着手不可 |
| #29 | 共通UIコンポーネント採用率向上 | enhancement | Flutter未使用のため夜間着手不可 |
| #23 | 広告・マーケットプレイス基盤 | enhancement | 将来構想・低優先 |

---

## 人間の判断が必要な事項

1. **PR #45（リリース準備）のレビューとマージ** — CI green・non-draft・1日経過。RevenueCat鍵注入方式（`--dart-define`）と Android 署名フォールバック設計の確認を推奨。

2. **Dependabot PR群（#12〜#19）への対応方針決定** — 104日放置。個別リベース＋CI再実行で接続可否を確認してからマージ or close。特に `firebase_auth` (#12) と `cloud_firestore` (#18) は優先確認を推奨。camera (#13) は破壊的変更の可能性あり（API確認必須）。

3. **Issue #49（実機登録フェーズ0）の人間作業完了** — Firebase Authentication 有効化、`firestore:rules,indexes,storage` デプロイ、`google-services.json`/`GoogleService-Info.plist` 配置が完了するまで実機テストは不可。

---

## 明朝の推奨アクション 3つ

### 1. PR #33 と #45 を即マージ（所要時間: 15分）
- **#33**: 未使用関数削除のみ。CI全件green・non-draft。即マージ可。
- **#45**: リリース準備（RevenueCat鍵注入・署名・What's New画面）。CI全件green・non-draft。1日レビュー後マージ推奨。

### 2. Issue #42（キャンペーン価格）の設計合意（所要時間: 30分）
Issue #39（ROI可視化）のクローズにより、「順序の鉄則」上 #42 が着手可能な状態になった。キャンペーン対象（商圏・店数・期間）と割引方式について Agree レベルの合意を行い、着手コメントを付けること。

### 3. Google Maps APIキーのプロビジョニング（所要時間: 30〜60分）
HUMAN_TASKS #17 の完了により、Issue #43（地図表示・提携ピン）→ #44（Places API非提携）→ #41（プル型集客エンジン）の最大ロードブロックが解消される。Issue #41 は `priority:high` かつ事業的重要度が最高（ニワトリ・タマゴ問題を需要側から割る）。

---

## 備考

- 夜間セッションは Flutter SDK が未インストールのクラウド環境のため、コード変更は実施せず Issue/PR 管理と分析のみを行った。
- PR #34（AI提案→工場検索バグ修正）は CI 状況不明・2日停滞。バグ修正のため次回夜間セッションの優先候補。
- PR #50（整備提案ROI指標）は本日作成・CI green。Issue #39 の拡張機能に相当し、設計判断（`collectionGroup('messages')` 使用）を PR description に明記済み。確認後ドラフト解除推奨。
