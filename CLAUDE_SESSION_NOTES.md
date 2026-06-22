# Claude Session Notes

最終更新: 2026-06-22

---

## 意思決定ログ（2026-06-22）: 夜間エージェント — 通報機能実装・停滞PR解消

**ブランチ**: `claude/night-20260622` / PR #52（draft）

**作業対象の根拠**:
- PR #50（ROI指標）・PR #34（バグ修正）: CI全グリーン・`mergeable_state: clean` のままDRAFT放置 → Draft解除
- Issue #37 フェーズ2（通報機能）: `claude-task` ラベルで明示。フェーズ1（いいね）はPR #47でマージ済みで次の対象

**Flutter環境**: `$HOME/flutter` に 3.44.2 を導入。全テスト3436件パス・analyze クリーン

**実装内容（Issue #37 フェーズ2）**:
- `CommentReportReason` enum（spam / harassment / inappropriate / other）
- `PopularAccessoriesService.reportComment`（重複通報防止・`comment_reports` コレクションへ保存）
- `showcase_detail_screen`: `_CommentTile` に非オーナー向け「通報」オーバーフローメニュー
- `_ReportCommentSheet` ボトムシート（通報理由選択UI）
- `firestore.rules`: `comment_reports` ルール追加（create のみ・status=='pending'強制）
- テスト +6件（reportComment の正常系2件 + Edge Cases 4件）

**残作業（人間判断が必要）**:
- 通報しきい値での自動非表示の可否（Issue #37 参照）
- 通報レビュー運用主体・ツール（Cloud Functions / 管理画面）
- `firebase deploy --only firestore:rules`（comment_reports ルール本番反映）

**PR状況**:
- PR #50: Draft解除（Closes #39）
- PR #34: Draft解除
- PR #52: 新規作成（Closes #37 フェーズ2）

---

## 意思決定ログ（2026-06-19）: 事業性評価の追補と集客モデルの合意・実装着手

ブランチ `claude/charming-brahmagupta-h6bm98` / 評価書 PR #38。

**背景**: オーナーから事業面で4点の提起（業態拡張／GoogleMap風の網羅表示／提携フリーミアム／価格妥当性・初年度キャンペーン）。`docs/BUSINESS_VIABILITY_ASSESSMENT.md` に §7 として追補。

**合意した設計（Agree レベル / GoogleMap連動表示, 評価書 §7.7）**:
- データ調達: **ハイブリッド**（地図=Google Maps SDK／提携=自前Firestore／非提携=Places API近隣を都度・初期1商圏限定）
- 見せ方: 地図ピン色分け（提携=ブランド色＋審査済バッジ／非提携=グレー）＋一覧で提携を上位固定
- 非提携の権限: 閲覧＋地図/電話リンクのみ（質問・予約・実績は提携特典→需要蓄積→プル型営業）

**起票した Issue**:
- #39 ROI可視化（問い合わせ数の月次通知）= 最優先
- #40 ShopType にガソリンスタンド追加（業態拡張）
- #41 GoogleMap連動の網羅表示＋提携フリーミアム（プル型集客エンジン）
- #42 初期パートナー向けキャンペーン価格＋据え置き特権

**順序の鉄則**: D(#39 ROI可視化) → B/C(#41 集客) → E(#42 キャンペーン)。ROIを見せる前に集客・値引きを先行させない。

**実装（本セッション / #39 のService層）**:
- `ShopReportService.getMonthlyReport(shopId, {asOf})` を新設（`Result<ShopMonthlyReport, AppError>`）。
  当月総数・前月総数・前月比（momChange）・当月のstatus内訳を返す最小ROIロジック。
- `ShopMonthlyReport` モデル新設、`injection.dart` に登録。
- `firestore.indexes.json` に `inquiries: shopId ASC + createdAt ASC` の複合インデックスを追加
  （既存 `getMonthlyInquiryCount` の潜在的不足も同時に解消）。
- テスト `test/services/shop_report_service_test.dart`（totals/status内訳/月・年境界/Edge Cases）。
- ⚠️ 残作業: 店舗ダッシュボードへのUI配線（Provider→画面）。インデックスは本番 `firebase deploy` が別途必要（要人手）。
- ⚠️ ローカルに Flutter SDK が無く `flutter test`/`analyze` 未実行。検証は CI（subosito/flutter-action, 3.38.0）に委譲。

---

## 意思決定ログ（2026-06-18）: C2Cパーツ手数料8%機能の凍結

**決定**: ロードマップ項目「2.5 C2Cパーツ手数料8%」を**凍結**。リソースは 2.1〜2.3 に集中。

**背景**:
- メルカリ/ヤフオク/モノタロウが既存。8%×低単価パーツでは運用コスト割れ。返品・送金・トラブル対応の運用負荷が重い。
- 在庫連携は未実装（調査で確認）。
- 当初要望は「良かったパーツをシェアし合ってコメントできる」程度の軽量機能だった。

**調査で判明した事実**: C2Cパーツ売買の中核（8%手数料/ペイアウト計算・出品CRUD・問い合わせ双方向）は
**実装済み・テスト済み**だった。よって「未着手の中止」ではなく「稼働中コードの導線遮断」として対応。

**実装（本セッション）**:
- 凍結: `FeatureFlag.c2cPartsMarketplace`（デフォルト `false`）を追加し、
  - `MarketplaceScreen` の「パーツ」「マイ出品」タブを非表示（工場・業者/問い合わせは残置）
  - `ProfileScreen` の「マイ出品」メニューを非表示
  - コード・テスト・Firestoreルールは**残置**（フラグ1つで復活可能）
- 代替の軽量機能: 既存 `AccessoryShowcase`（パーツ/アクセサリーのシェア）に**コメント機能**を追加
  - `ShowcaseComment` モデル + `PopularAccessoriesService.{addComment,getComments,deleteComment}`
  - `accessory_showcases/{id}/comments` サブコレクション + Firestoreルール（投稿者のみ作成/削除）
  - `ShowcaseDetailScreen`（投稿詳細＋コメントスレッド）。トレンドカードのタップから遷移
  - 売買・いいね・通知・在庫連携は**スコープ外**（「コメントにとどめる」方針）

**人間タスク**: `firebase deploy --only firestore:rules`（showcase comments ルール反映）

---

## 現在の状態

**ブランチ**: `claude/continue-development-WYZZp`
**テスト**: 3284件以上（第13弾で+走行距離4件+コミュニティトレンド2件追加）全パス・失敗0件
**`flutter analyze lib/`**: No issues found

## 人間タスク（テストユーザー配布前に必須）

1. `firebase deploy --only firestore:rules,firestore:indexes` —
   vehicle_grade_specs / posts可視性 / social_notifications / vehicle_listings
   のルール強化 + posts複合インデックス3本（同車種フィルタは未デプロイだと500エラー）
   **今セッション追加**: `community_maintenance_trends` ルール + `safety_tips` 複合インデックス2本
2. `firebase deploy --only storage` — storage.rules がコードと一致するよう全面整備済み。
   **本番のConsole編集ルールとの差分を必ず確認してからデプロイ**
   （旧ルールはリポジトリと乖離している疑い。監査レポート参照）
3. シードデータ登録（スクリプト実装済み・手順は `docs/HUMAN_TASKS.md` 参照）:
   - `node scripts/seed_safety_tips.js`（6件）
   - `node scripts/seed_community_trends.js`（5車種）

---

## 直近セッション（2026-06-11）の成果

### ビジネスモデル検証（PM/UX/QA 3観点並列調査）
- **結論: モデルは筋が良いが価値導線が3箇所切れていた**
- BtoB: 4プラン（¥0/¥3,980/¥9,800/¥14,800）+ RevenueCat実装済み（完成度90%）
- BtoC: プレミアムゲートに漏れ（PDF出力が車両詳細から素通し）

### 価値導線修正（TDD実装）
1. **PDF出力プレミアムゲート**: `vehicle_detail_screen.dart` のPDFボタンに
   `UserSubscriptionProvider.canExportPdf` チェック + アップグレード案内ダイアログ
2. **車検期限の視覚強調**: `core/utils/inspection_urgency.dart` 新設
   （≤7日 critical / ≤30日 warning）。ダッシュボード「次の車検」チップを
   緊急度で色分け（Key: `dashboard_inspection_chip_{normal,warning,critical}`）
3. **整備記録空状態CTA**: タイムライン空状態に「整備記録を追加」ボタン
   （ドライブタブ除く）→ AddMaintenanceScreen 遷移

### 第2弾（同日実装・全2785件パス）
1. **問い合わせ月次上限の事前警告**: `InquiryService.countUserInquiriesThisMonth`
   （fail-open設計）+ 送信前ゲート + プレミアム訴求ダイアログ
2. **広告枠の透明性強化**: isFeatured は認証済みでも「広告」常時表示
3. **車検期限OSリマインダー**: `inspection_reminder_service.dart` 新規。
   満了30/7/1日前にローカル通知（FNV-1a決定的ID、7000-7899予約レンジ、
   再スケジュール時に置換）。NotificationProvider へコンストラクタ注入

### ビジネスモデル検証メモ（ディーラー顧客囲い込みへの対抗軸）
- ディーラーは「自社販売車1台」しか見ない → 本アプリは**一家数台を
  メーカー横断で一元管理**（ディーラー縦割りの間隙）
- 車検・自賠責の期限管理が**OSリマインダーで自動化**（ディーラーDMは郵送/電話）
- 問い合わせは**ユーザー主導・比較可能**（ディーラーの言い値ではなく
  近隣工場の評判を見て気軽に相見積もり）
- AIパーツ提案は**複数候補+理由提示**でディーラー純正一択を相対化

### 第3弾（同日実装）
1. **任意保険管理の配線**: `VoluntaryInsurance` モデルは存在したが完全未使用
   （UIなし・通知なし）だったのを配線。車両編集画面に保険会社名+満期日
   フィールド追加、RecommendationService にアプリ内通知
   （`_checkVoluntaryInsuranceExpiryDate`）、OSリマインダー
   （ID 8000-8899 レンジ）を追加
2. **通知権限の重大バグ修正**: `requestPermission` は設定画面のトグルでしか
   呼ばれず、AndroidManifest に `POST_NOTIFICATIONS` 宣言もなかった
   → Android 13+/iOS で通知が一切届かない状態だった。Manifest宣言追加 +
   `InspectionReminderService.scheduleForVehicles` 内で権限リクエスト
   （OSダイアログは一度しか出ないため毎回呼んで安全）
3. **PdfExportService の Result<T> 化** + mileage_notification_service
   テスト追加（QAギャップ解消）

### プロダクト戦略メモ（パーツ提案の「多すぎる問題」への回答）
ユーザー指摘: ドラレコ等はメーカー多数で汎用提案はAmazonレビューに勝てない。
**方針: 「カタログ網羅」では戦わず「同車種オーナーの実例」で戦う**
- 差別化の核 = 「同じ車に乗っている人が実際に付けたパーツ + 整備記録」
  （Amazonにない文脈: 車種適合・取付実例・整備履歴との紐付け）
- そのために SNS は「車種を軸としたゆるいつながり」設計が必須:
  - 投稿に車両（maker/model/year）が自動紐付け → 同車種フィードで発見
  - 整備記録 → ワンタップでSNS共有（「この記録を投稿」）= 実例DB化
  - パーツ提案画面に「同車種オーナーの装着例」セクション
- 近隣工場ともゆるいつながり: 工場の施工事例投稿（売り込みではなく実績共有）
  → ユーザーが実例から工場を発見する導線（「売り込まない」原則と整合）

### 第4弾（法人・リース対応）
1. **1日前リマインダー廃止**: ユーザー指摘どおり1日前は対応不能で無意味
   → `reminderDaysBefore = [30, 7]`（IDレンジ: リース6000-6599 /
   車検7000-7599 / 任意保険8000-8599）
2. **リース情報（LeaseInfo）**: リース会社・月額・契約期間・メンテパック内容を
   Vehicleモデルに追加。車両編集画面にセクション追加。
   リース満了90日前からアプリ内通知（返却/再リース判断は時間がかかるため
   他期限より早め）+ OSリマインダー
3. **法人アカウント**: `AppUser.accountType`（personal/business）+ companyName。
   設定画面に「法人アカウント登録」（会社名入力ダイアログ →
   `AuthService.updateBusinessProfile`）。
   ※ updateUserProfile のシグネチャ変更は21モックを壊すため別メソッドに分離
4. **フリートプラン（`models/fleet_plan.dart`）**: 価格設計
   - 〜4台無料 / フリート5〜20台 ¥4,980 / ビジネス21〜50台 ¥9,800 / 51台〜個別
   - `isPromotionalFreePeriod = true`: ローンチ期は全機能無料開放、
     ホームダッシュボードに5台以上で「現在無料開放中（正式リリース後¥4,980〜）」
     バナー表示 = メリット実感→有料化の導線

### 第5弾（2026-06-12実装・全2851件パス）
1. **法人フリート管理**: Vehicle に companyId 追加。FleetService（getCompanyVehicles/
   getFleetStats/linkVehicleToCompany）。FleetProvider（緊急度ソート・urgencyFilter）。
   FleetDashboardScreen（台数サマリー・緊急度別カラーコード・フィルタチップ・フリートコード表示）。
   HomeScreen プロフィールタブに法人ユーザー向け「フリート管理」メニュー追加。
2. **SNS 同車種フィルタ**: PostService.getFeed に modelName パラメータ追加。
   PostProvider.filterByVehicleModel/selectedModelName。
   SnsFeedScreen に「同じ○○ オーナー」フィルタチップ（VehicleProvider から車種自動取得）。
3. **整備記録→SNS共有**: PostCreateScreen に initialContent/initialVehicleId/initialCategory
   追加。AddMaintenanceScreen 新規保存後に共有ダイアログ → PostCreateScreen プリフィル遷移。

### 第6弾（2026-06-12実装）

1. **フリートメンバー招待フロー**: `FleetService.joinFleetByCode` 追加。
   VehicleEditScreen にフリートコード入力フィールド + 「参加」ボタン、
   参加中は「脱退」ボタン表示。バリデーション（空文字・権限チェック）。
2. **担当者アサイン**: `FleetService.assignVehicle` 追加。
   Vehicle モデルに `assigneeId`/`assigneeName` フィールド追加。
   FleetDashboardScreen の車両カードをタップすると AssignmentSheet が開き担当者名を設定。
3. **車両詳細リース・任意保険表示**: VehicleDetailScreen に
   `_VoluntaryInsuranceSection`（保険会社名・満期日カラーコード）、
   `_LeaseInfoSection`（リース会社・月額・契約期間・メンテパック）追加。
4. **車種グレード仕様自動入力**: VehicleGrade に乗車定員・車両重量・
   標準装備・オプション装備フィールド追加（`hasSpecData` getter）。
   GradeSelectorField 選択時に燃料タイプ・排気量を自動入力 + 仕様プレビューカード表示。
5. **整備スケジュール自動生成**: `MaintenanceScheduleService` 新規。
   燃料タイプ別（EV/HV/PHEV/ディーゼル/ガソリン）に整備項目と推奨インターバルを生成。
   VehicleDetailScreen に `_MaintenanceScheduleSection`（次回推奨km表示）追加。
   `injection.dart` に ServiceLocator 登録済み。

**テスト**: MaintenanceScheduleService 19件・FleetService +10件追加（合計 2432件+）
**全テスト**: `+2432 -31`（31件は前セッションから続く既存の失敗）

### 第7弾（2026-06-12実装・コミュニティ仕様データ）

**マスタデータ戦略の決定**: カーセンサー等に公開APIは存在しない。
外部データ購入ではなく**「ユーザー手動入力 → コミュニティ蓄積」**方式を採用
（プロダクト戦略「同車種オーナーの実例で戦う」と整合）。

1. **VehicleSpecService 新規**（`vehicle_grade_specs` コレクション）:
   - specId = `{maker}_{model}_{year}_{grade}`（小文字・スペース→`_`）
   - fetchSpec: grade選択時にコミュニティデータを取得して自動入力
   - saveSpec: 車両保存時に貢献。**最初の投稿者データを正**とし、
     以降は contributorCount++ のみ（データ汚染防止）
2. **実車写真表示**: `sampleImageUrl` — 最初に写真付きで登録した
   オーナーの実車写真をグレード選択時に表示。null の場合のみ後続が補完
   （firestore.rules で強制）
3. **コミュニティ確認バッジ**: contributorCount >= 3 で
   `isVerified` → 緑バッジ「X人が確認」。3人未満はグレーテキスト
4. **フリートCSVエクスポート**: `FleetCsvExportService`
   （RFC 4180・UTF-8 BOM で Excel 日本語対応）。
   FleetDashboardScreen → share_plus で共有
5. **ai_chat_provider テスト16件追加**（カバレッジギャップ解消）

**テスト追加**: vehicle_spec 15件 / fleet_csv 10件 / ai_chat_provider 16件
**人間タスク**: `firebase deploy --only firestore:rules`（vehicle_grade_specs ルール反映）

### 第8弾（2026-06-12実装・テストユーザー受け入れ準備）

**機能**: OCR→コミュニティ仕様サジェスト（fetchSpecsForModel）/
パーツ提案「同車種オーナーの装着例」/ フリートCSV整備サマリー

**エキスパート3観点並列監査（QA/セキュリティ/UX）を実施し全P0/High修正**:
- [P0] オンボーディング→ログイン後に遷移しない致命バグ
  （pushReplacementがAuthWrapper破棄 → onCompletedコールバック方式）
- contributorCount水増し防止: contributorIds で1ユーザー1カウント
  （firestore.rulesでも増分+1・本人追加のみを強制）
- OCR生テキストのdebugPrint削除（車検証の個人情報がlogcatに残る問題）
- posts可視性のルール強制（非公開投稿がSDK直クエリで全読み可能だった）
- storage.rules全面整備（コードの実パスと不一致でリポジトリ管理が形骸化していた）
- CSV数式インジェクション対策 + 一時ファイル削除
- 実車写真共有の明示同意制（ナンバー写り込み対策・デフォルト非共有）
- **既存31件のテスト失敗も解消**（ServiceLocator未登録時のgraceful degradation）

### 第9弾（2026-06-12実装・第8弾残課題解消 + 公開範囲UI）

**エキスパート3観点（QA/セキュリティ/UX）分析レポート実施後、P0課題を全解消。**

1. **写真共有同意チェックボックス（Item 1）**
   - 車両登録Step1: 写真選択後に `CheckboxListTile` を表示
   - キー: `photo_consent_checkbox`
   - 「ナンバーや個人情報が写り込んでいない場合のみ選択」警告文
   - 写真再選択のたびに同意をリセット（安全設計）
   - `_askPhotoShareConsent` ダイアログ廃止

2. **車検日未設定プロンプトカード（Item 2）**
   - `_InspectionSetupCard` をダッシュボードに追加
   - `inspectionExpiryDate == null` の車両がある場合のみ表示
   - キー: `inspection_setup_card`
   - 「登録する」→ VehicleEditScreen 遷移
   - 汎用テキスト（車種名なし）でウィジェットツリー汚染を回避

3. **フォロワー限定投稿（Item 3）**
   - `PostService.getUserPosts`: `isViewerFollowing` フラグで `whereIn` クエリ切替
   - Firestore rules: `exists(/follows/{viewerUid}_{authorUid})` でサーバー強制
   - **[UX P0解消]** `PostCreateScreen` に `SegmentedButton<PostVisibility>` 追加
     （全体公開 / フォロワーのみ / 自分のみ）
   - `sns_feed_screen` の投稿カードに `_VisibilityBadge` 追加（public 以外に表示）

**テスト**: 2963件パス（+5件: 公開範囲セレクターUIテスト）
**静的解析**: No issues found
**コミット**: `0a0701f`

### 第10弾（2026-06-12実装・ペルソナ駆動の機能追加 + 総合テスト）

**ユーザー視点ギャップ分析（3エージェント並列調査）の結論**:
- 実装済み確認: 問い合わせ双方向スレッド / 工場側返信UI / AIパーツ提案（ルールベース・
  複数候補+理由）/ AIチャット（claude-haiku via Cloud Functions・20回/日）/
  質問カテゴリ+コメント / 同車種フィルタ / 整備記録→SNS共有
- ギャップ→実装: 貨物車区分なし / getNearbyShops未配線 / 一括問い合わせなし

1. **VehicleUseCategory（用途区分）**: 貨物車（1・4ナンバー）は毎年車検、
   自家用乗用は2年。`suggestedNextInspectionDate` で区分別サイクル自動計算。
   車両編集画面の車検セクションにドロップダウン（Key: `use_category_dropdown`）+
   毎年車検の警告ノート。null = 自家用乗用車として扱う（後方互換）
2. **フリート車検一括問い合わせ**: `FleetInquiryComposer`（純粋関数・15テスト）。
   車検60日以内を抽出→確認ダイアログ→ShopListScreen(selectMode)で工場選択→
   InquiryScreen プリフィル。貨物車は文面に区分明記（工場が毎年車検と分かる）
3. **近隣工場の距離表示**: `ShopProvider.sortByDistanceFrom`（dart:math 正確版
   Haversine）。「近い順」ボタン（位置権限拒否/サービス無効をSnackBar案内）。
   カードに「現在地から X.Xkm」
4. **ペルソナ総合テスト**（`test/integration/persona_scenarios_test.dart` 23件）:
   - Persona A: 個人4台（貨物・リース・車検未登録の混在）
   - Persona B: 中小企業20台（critical/warning分類・CSV・権限違反・一括問い合わせ）
   - Persona C: 近所の3工場（得意サービス・評価/レビュー数・距離で比較）

**テスト**: 3021件パス（+58件）/ コミット: `ae8553d`

### 第11弾（2026-06-12実装 — Sprint 13 自律開発）

**注: 第11弾の続き（セッション引き継ぎ後）** 

**報告書**: `docs/PERSONA_TEST_REPORT.md`（ペルソナ別統合テスト）、`docs/MARKETING_APPEAL_REPORT.md`（マーケ専門家分析）を生成。

1. **ShopChain（多店舗チェーン対応）**: `lib/models/shop_chain.dart`、`lib/services/shop_chain_service.dart` 新規。コバック・ジェームス等のフランチャイズチェーンを表現。`Shop`モデルに `chainId/chainName` 追加。`createChain`, `getChain`, `getShopsInChain`, `linkShopToChain`, `unlinkShopFromChain`（オーナーのみ許可） — 16テスト

2. **AccessoryShowcase / PopularAccessoriesService**: ユーザーがドラレコ等のアクセサリー使用実績を投稿し、コミュニティで人気アイテムを集計。`submitShowcase`, `getShowcasesByCategory`, `getPopularTrends`, `getTopAccessories`（カテゴリ横断） — 14テスト

3. **CarPurchaseInquiryService**: 中古車購入相談。`createInquiry`, `getMyInquiries`, `closeInquiry`, `generateSearchLinks`（カーセンサー + Goo-net ディープリンク、API契約不要のURL構築） — 15テスト

4. **SafetyTipService**: 公式機関（JAF/警察庁/国交省/消防庁/ITARDA）限定の安全情報。`SafetyTip.disclaimer` 定数（法的免責必須）、sourceUrl HTTPS必須チェック、isActive フィルタ — 13テスト

**合計テスト**: 3126件 → 3184件（+58件）  
**コミット**: `13c5b6b`, `dd1db1a`, `e246dbd`  
**プッシュ済み**: `claude/continue-development-WYZZp`

### 第12弾（Sprint 13 最終 — 車両ライフサイクル + ペルソナ完全網羅）

**背景**: 「社運がかかってる機能だからペルソナを世界レベルで拡充せよ」「廃車・売却・データ保持も対応せよ」の指示を受け実装。

1. **Vehicle ライフサイクル管理**:
   - `VehicleStatus` enum: active / sold（売却）/ scrapped（廃車）/ leaseReturned（リース返却）/ transferred（譲渡）
   - `Vehicle` モデルに `status`, `retiredAt`, `retirementNote`, `isDataRetained` フィールド追加
   - **`VehicleRetirementService`** 新規:
     - `retireVehicle`: オーナー確認・二重退役防止・reason=active禁止
     - `restoreVehicle`: 誤操作取り消し（soldを再度activeに戻せる）
     - `getRetiredVehicles`: 売却済み・廃車済み一覧（whereNotIn使用）
     - `getActiveVehicles`: アクティブ車両のみ（ガレージ表示用）
     - `isDataRetained: bool` — ユーザーが「整備記録を残す」か選択できる
   - 17テスト全パス

2. **FleetMemberService**（フリートRBAC）:
   - `FleetRole`: owner / manager / staff / viewer の4段階
   - `addMember`: オーナーのみ招待可
   - `updateRole`: オーナーのみ変更可
   - `removeMember`: オーナーまたは本人が脱退可
   - `canWrite`: manager以上が書き込み可
   - 33テスト全パス

3. **ShopComparisonService**（工場比較・純粋関数）:
   - スコア = `rating × ln(reviewCount + 1) - 0.05 × distanceKm`
   - 対数スコアリングにより少数レビューの高評価工場に偏らない設計
   - `compare`, `recommend` — Firestore不要の純粋関数
   - 14テスト全パス

4. **ペルソナシナリオテスト拡張（A〜D → A〜I）**:
   - Persona E: 新社会人・N-BOX（SafetyTip + PopularAccessories。初回整備low confidence）
   - Persona F: 売却・廃車ユーザー（VehicleRetirement + データ保持選択）
   - Persona G: EVオーナー・日産リーフ（オイル交換なし。タイヤ/ブレーキ/ワイパーのみ）
   - Persona H: 旧車オーナー1994年製Beat（CarPurchaseInquiry部品探し・製造年30年超）
   - Persona I: SUV購入検討者（CarSensor/Goo-netリンク生成・チャイルドシート人気）
   - **71件 → 全パス**（既存A〜D含む）

**全テスト**: 3,284件 全パス（+100件）  
**コミット**: `ed80681`  
**プッシュ済み**: `claude/continue-development-WYZZp`

### 第13弾（2026-06-13実装 — 車両詳細画面強化・コミュニティ連携）

**概要**: 車両詳細画面への2つのクイックアクション追加 + コミュニティトレンドの完全実装。

1. **車検完了クイックアクション** (`vehicle_detail_screen.dart`):
   - 車検満了日行に「車検完了」ボタン（Key: `inspection_complete_btn`）
   - タップ → `_InspectionCompleteDialog`（日付選択 + 走行距離入力）
   - 完了: `FirebaseService.updateVehicle` + `MaintenanceProvider.addMaintenanceRecord(legalInspection24)`
   - テスト5件追加

2. **走行距離クイック更新** (`vehicle_detail_screen.dart`):
   - 走行距離行に「更新する」ボタン（Key: `update_mileage_btn`）
   - タップ → `_MileageUpdateDialog`（StatefulWidget でコントローラーライフサイクル管理）
   - アニメーション中の `TextEditingController.dispose` 競合を StatefulWidget 化で解消
   - テスト4件追加

3. **コミュニティトレンドセクション** (`_CommunityTrendSection`):
   - 車両詳細画面の統計・AI提案セクション後に配置
   - `CommunityTrendService.getTrendsForVehicle` で同車種ピアデータ取得
   - `initState`で`isRegistered`チェック → 未登録時は`_loaded = true`直接セット（async setState競合回避）
   - `_CommunityInsightRow`: 実施率%・整備タイプ・中央値コストを表示
   - データなし/サービス未登録時は`SizedBox.shrink()`でグレースフルデグレード

4. **コミュニティトレンド自動投稿** (`add_maintenance_screen.dart`):
   - 新規整備記録保存成功後に `unawaited(_submitTrendData(record))` でfire-and-forget
   - 前回同種記録との差分（intervalKm/days）を自動計算して匿名投稿
   - 全エラー抑制（VehicleProvider未登録・サービス未登録・Firestore失敗すべて無視）
   - テスト2件追加

5. **シードスクリプト** (`scripts/`):
   - `seed_safety_tips.js`: 安全情報6件（`--dry-run`/`--emulator`対応）
   - `seed_community_trends.js`: 5車種データ（プリウス/N-BOX/リーフ/フィット/ヴォクシー）

6. **Firestoreルール・インデックス整備**:
   - `firestore.rules`: `community_maintenance_trends` ルール追加
   - `firestore.indexes.json`: `safety_tips` 複合インデックス2本追加

**テスト追加**: +11件（走行距離4 + 車検5 + コミュニティ2）  
**`flutter analyze lib/`**: No issues found  
**コミット**: `ce14df6`, `8840216`

### 第14弾（2026-06-13実装・価値導線/通知/保険/フリート）

QA/PM/UX分析を踏まえた自律実装。各タスク単位でコミット。

1. **QAバグ修正**（commit前半）: 走行距離オドメーター逆行ガード・二重送信ガード・
   保存失敗ハンドリング・トレンド集計null汚染防止
2. **工場→ユーザー整備明細スレッド連携**: InquiryMaintenancePayload + 純粋変換関数
   （pullモデル=ユーザー承認制）。工場側「整備明細を送る」/ユーザー側「記録に追加」
3. **任意保険の入力充実**（個人・法人フリート対応）: VoluntaryInsurance 大幅拡張
   （契約形態/等級/料率/補償額/車両保険/運転者条件/特約）+ InsuranceEditScreen 新規
4. **保険満期サマリー露出・テンプレート・フリート保険概況**: expiry_summary /
   insurance_templates ユーティリティ + 各UI
5. **AI通知の既読/削除を永続化**: 通知IDを締切日ベースの決定的IDに変更 +
   NotificationStateStore（SharedPreferences）。再起動後も既読/削除が保持
6. **法人フリート管理の発見性向上**: ホームのフリートバナーをタップ可能化→
   FleetDashboard 直接遷移（従来はプロフィール奥のみ）

**注**: 「OCR起点化」「任意保険OSリマインダー」は調査の結果**既に実装済み**だったため
重複作業せず（OCRは両画面でメインCTA済、保険リマインダーは8000-8599で実装+テスト済）。

**全テスト**: 3355件パス / analyze クリーン / format 準拠
**主要コミット**: 車検バグ修正〜`ff14e1e`（通知永続化）〜`ec92c02`（フリート導線）

### 残課題（次セッション候補）
- 装着例セクションの再読み込み対応（現在initState時のみ取得）
- `isViewerFollowing` サーバーサイド検証（Cloud Function推奨。現在はクライアントのみ）
- スペック貢献ロジックのテスト: `spec.sampleImageUrl` が既に存在する場合
- `getUserPosts` ページネーション + フォロワーフィルタの統合テスト
- 店舗比較画面（2〜3工場を表形式で並べて比較）— ペルソナC調査で未実装と判明
- フリートメンバー権限モデル（総務担当ロール。現在はオーナーのみ書き込み可）
- 法人向けウェブ管理画面（工場側の問い合わせ対応をPCブラウザで）— Enterprise プラン向け
- ShopService の手書きTaylor級数Haversineを dart:math 版に置換（精度改善）
- `AccessoryShowcase` を `Post` モデルと統合するか分離維持か検討（UI実装時に判断）

---

## 過去セッション（2026-06-10）の成果

### CI 完全修復
- `dart format lib test`（Dart 3.10.0 一致）
- `flutter analyze --fatal-infos` 150件 → 0件
- テスト 2656→2719 件パス
- CIエミュレータ起動をベストエフォート化（`continue-on-error: true`、Java 17追加）

### lib/ 実バグ修正
- `AppSpacing.horizontalXxs` 未定義追加（3画面コンパイル不能修正）
- `InquiryService` / `ShopSubscriptionService`: Firebase lazy初期化（テスト分離）
- `ShopOwnerScreen.dispose()`: `context.read` クラッシュ修正
- `VehicleOcrMatcher`: 空文字マッチ誤判定修正
- `VehicleRegistrationScreen`: PopScope 状態同期・エラー SnackBar

### 新機能（コア機能①「整備履歴の一元管理」強化）
- `MaintenanceProvider.searchRecords()` + `MaintenanceSortBy`（TDD 25件）
- `MaintenanceSearchScreen`（FilterChip + 件数/合計表示、TDD 7件）
- `VehicleDetailScreen` AppBar に検索アイコン追加

### アクセシビリティ
- `_VehicleEmptyOnboarding`: 装飾アイコン `ExcludeSemantics`、見出し `Semantics(header:true)`
- `_SummaryItem`: 統合セマンティクスラベル（`$label $value`）
- 通知双方向スワイプ（Dismissible）TDD 5件

---

## 過去セッション（2026-06-09）の成果サマリー

| カテゴリ | 内容 |
|---|---|
| セキュリティ | askCarAi.ts TOCTOU修正（`runTransaction`）・入力長/履歴件数上限 |
| 機能 | AIチャット履歴永続化（SharedPreferences、最大20件） |
| UI刷新 | NavigationBar移行・整備タイムライン・AI提案セクション・チャットタイムスタンプ・整備プレビューバナー・通知reason表示・プロフィール統計 |
| 車両オンボーディング | `_VehicleEmptyOnboarding`（ヒーロー + 3機能 + CTA） |

---

## アーキテクチャ注意事項

- `AppSpacing.radiusFull = 100.0`（`borderRadiusFull` は存在しない）
- `Expanded` は `Row/Column/Flex` の直接の子でなければならない（`Semantics` で挟まない）
- `testWidgets` 内で `Future.delayed` → FakeAsync でハング（同期ストリーム使用）
- 無限アニメ画面で `pumpAndSettle` → ハング（有界 `pump` を使う）
- `ElevatedButton.icon` は `find.bySubtype<ElevatedButton>()` で探す

---

## 未解決・人間が対応すべき事項

| 優先度 | タスク |
|---|---|
| P1 | PR #20 をレビュー・マージ |
| P1 | `google-services.json` を Firebase Console からダウンロード → `android/app/` に配置 |
| P1 | `GoogleService-Info.plist` を Firebase Console からダウンロード → `ios/Runner/` に配置 |

---

## 参照ファイル

| 目的 | パス |
|---|---|
| 機能仕様 | `docs/FEATURE_SPEC.md` |
| デザインシステム | `docs/DESIGN_SYSTEM.md` |
| 人間タスク | `docs/HUMAN_TASKS.md` |
| CI 設定 | `.github/workflows/ci.yml` |
