# テスト実行レポート（ドラフト） — 2026-08-09

**作成**: QAテストセッション（Claude）
**対象**: ペルソナテスト・総合テスト・運用テストの設計・実装
**ステータス**: ドラフト（CI実行待ち）

> ⚠️ **重要**: 本セッションの実行環境には Flutter SDK が無いため、
> `flutter test` は**実行していない**。本レポートに「パス」の記載は無く、
> 追加テストの検証は CI（`flutter test --exclude-tags emulator`）で行われる。
> 整形のみ `dart format --language-version=3.0` を実行済み。

---

## 1. カバレッジ監査結果

### 1.1 画面 × テスト有無（テストが無い画面のみ抜粋）

lib/screens/ 全56ファイルと test/ を突き合わせた結果。以下の12画面には
**画面（Widget）テストが1件も無い**。

| 画面 | 画面テスト | 周辺のテスト | 優先度・備考 |
|------|-----------|-------------|-------------|
| `drive/drive_log_detail_screen.dart` | ❌ なし | `test/utils/route_privacy_test.dart`（25件） | **高**（今週追加機能）。ぼかしロジックはutilで検証済みだが、画面の表示分岐は未検証 |
| `accessories/accessory_showcase_screen.dart` | ❌ なし | `showcase_detail_screen_test.dart` はあり | 中 |
| `ai_chat/ai_chat_screen.dart` | ❌ なし | provider / service テストあり | 中 |
| `document_scanner_screen.dart` | ❌ なし | OCRサービステストあり | 低（カメラ依存 → 手動テスト項目へ） |
| `insurance_edit_screen.dart` | ❌ なし | `voluntary_insurance_test.dart`（モデル） | 中 |
| `marketplace/case_study_management_screen.dart` | ❌ なし | — | 中 |
| `marketplace/nearby_shops_map_screen.dart` | ❌ なし | `shop_map_utils_test.dart` | 低（地図描画 → 手動テスト項目へ） |
| `newsletter/newsletter_compose_screen.dart` | ❌ なし | `newsletter_service_test.dart` | 中 |
| `newsletter/newsletter_list_screen.dart` | ❌ なし | 同上 | 中 |
| `safety/safety_tip_screen.dart` | ❌ なし | `safety_tip_service_test.dart` | 中（ペルソナEの主要導線） |
| `shop/shop_comparison_screen.dart` | ❌ なし | `shop_comparison_service_test.dart` | 中（ペルソナCの主要導線） |
| `vehicle/retired_vehicles_screen.dart` | ❌ なし | `vehicle_retirement_service_test.dart`（17件） | 中（ペルソナFの主要導線） |

上記以外の44画面には対応する画面テストが存在する（`test/screens/` 46ファイル
+ `test/golden/`）。

### 1.2 今週追加機能のカバレッジ状況

| 機能 | 既存テスト | 今回の対応 |
|------|-----------|-----------|
| オプション装備（equipment_section） | モデル: `test/models/vehicle_equipment_test.dart`（28件）。**`EquipmentSection` ウィジェット自体と編集画面統合は未テスト** | Firestore保存→読み戻し→退役後の保全ジャーニーを追加（persona_journey） |
| 整備明細（maintenance_detail_breakdown） | ウィジェット: `test/widgets/maintenance_detail_breakdown_test.dart`（13件）、モデル: `phase5_models_test.dart` | Firestore**往復**（parts/partsCost/taxAmount）と4年分時系列を追加（persona_journey） |
| ドライブログ詳細（drive_log_detail_screen） | util: `route_privacy_test.dart`（25件）のみ。**画面テストなし** | isPublic切替×ぼかしの結合ジャーニーを追加（persona_journey）。画面テストは未着手（残課題） |
| 工場の提携/未提携出し分け | ✅ `shop_detail_screen_test.dart` で3件カバー済み | 重複回避のため追加なし |
| 通知既読トグル | ✅ UI: `notification_list_screen_test.dart`、provider: `notification_provider_test.dart`（Fakeストア使用）。**実装クラス `SharedPrefsNotificationStateStore` は未テスト** | 実装ストアの永続化・再起動・500件上限テストを追加（operational） |
| 居住地選択 | ✅ `profile_screen_test.dart`（region fields）でカバー済み | 重複回避のため追加なし |

---

## 2. 追加したテスト一覧

### 2.1 `test/integration/persona_journey_test.dart`（新規・26件）

ペルソナが「1年使った」状態を FakeFirebaseFirestore に構築し、
サービス層を通した一連の流れを検証する。

| グループ | 件数 | 守る仕様 |
|---------|------|---------|
| Persona B — 法人100台フリートの月初点検 | 5+2 | `FleetService.getFleetStats` の critical(≤7日・期限切れ含む)/warning(8–30日)/normal 分類が100台規模でも正確なこと。`isInspectionExpired`/`isInspectionDueSoon` の台数集計。`assignVehicle` で設定した担当者が読み戻せること。0台法人・存在しないIDの安全性 |
| Persona D — 整備記録4年分の時系列と明細 | 3+2 | `maintenance_records` の日付降順クエリで4年分10件が正しく並ぶこと。明細（`parts`・`workItems`・`partsCost`・`laborCost`・`miscCost`・`taxAmount`）の Firestore 往復保全。`calculatedTotal`/`calculatedPartsCost` と入力内訳の一致。明細なし旧記録の後方互換（null のまま読める） |
| 共通 — 車両登録→装備→退役→復元 | 3+3 | `VehicleEquipment`（ナビ/ドラレコ/ETC の型番・フラグ装備・自由記述）の保存→読み戻し等価性。売却退役（`retireVehicle`）後も装備と `isDataRetained` が失われないこと。`restoreVehicle` で使用中に戻ること。空装備は保存されない仕様（`hasAnyValue=false` → 書き込みなし） |
| 公開ドライブログ — isPublic切替と経路ぼかし | 5+3 | 非公開ログが公開フィードに出ないこと。`updateDriveLog(isPublic: true)` 切替後にフィードへ出ること。`buildBlurredRoute` が公開時に自宅500m圏の点を全除去すること。住所が市区町村までに丸められること。非公開（本人閲覧）は無加工。短経路は空になり1点も漏れないこと。他人による isPublic 切替の権限拒否 |

### 2.2 `test/integration/operational_test.dart`（新規・28件）

| グループ | 件数 | 守る仕様 |
|---------|------|---------|
| プラン制限 — 無料/プレミアムの境界 | 6+3 | 無料プランの上限値固定（車両3台・ドライブログ30日・問い合わせ月3件・PDF不可）。3台で上限到達/2台で余地ありの境界。保持境界: **29日前=保持 / ちょうど30日=削除側 / 31日=削除**（purge 実装時に従う仕様をテストで固定）。プレミアムは無制限 |
| 通知既読状態の永続化 | 3+3 | `SharedPrefsNotificationStateStore` の既読/削除済みID保存と、新インスタンス（=アプリ再起動相当）での読み戻し。既読→未読トグルの永続化。初回起動は空。500件超で古いIDから破棄 |
| 退会フロー相当 — 現仕様の固定 | 3+2 | `account_deletions/{uid}` に status=pending マーカーが記録されること。**マーカー記録後も vehicles/整備記録/ドライブログはクライアントから即時削除されない**（サーバー側 purge が30日以内に実施＝プライバシーポリシー記載と整合）。requires-recent-login 相当のロールバックでマーカーのみ消えデータ無傷。マーカー二重書き込みは上書き |
| ライセンスプレート正規化での重複検出 | 5+3 | 全角IME入力（`品川　３００　あ　１２－３４`）と半角登録済み（`品川 300 あ 12-34`）が同一車両と判定されること。スペース詰め・長音記号ハイフン（`品川300あ12ー34`）も同一。`excludeVehicleId` で自車両編集は除外。ユーザー単位チェック（他ユーザーの同一ナンバーは非重複）。空文字・プレート未登録の安全性 |

**追加テスト合計: 54件**（すべて FakeFirebaseFirestore / SharedPreferences
モックで動作。emulator タグなし → `--exclude-tags emulator` の対象内）

---

## 3. 実行結果

| 項目 | 結果 |
|------|------|
| `flutter test`（新規2ファイル） | **未実行**（本環境に Flutter SDK なし。CIで検証される） |
| `flutter analyze lib/` | **未実行**（同上。ただし lib/ は変更していない） |
| `dart format --language-version=3.0`（新規2ファイル） | ✅ 実行済み・整形済み |

---

## 4. 要修正（プロダクションコード側の課題）

lib/ は変更禁止のため、テスト実装中に見つかった課題を記録する。

1. **`FirebaseService` / `AuthService` がDI不可**
   `FirebaseFirestore.instance` / `FirebaseAuth.instance` に直結しており、
   コンストラクタ注入が無い。このため `isLicensePlateExists`・
   `deleteAccount` を本体クラスで直接単体テストできず、operational_test
   では比較仕様・データ契約の再現テストに留めた。他サービス
   （FleetService 等）と同じ `({FirebaseFirestore? firestore})` パターンへの
   移行を推奨。
2. **プラン制限の強制実装が無い**
   `UserPlanLimits.driveLogRetentionDays` / `maxVehicles` は値の定義のみで、
   lib/ に purge・登録ブロックの実装が存在しない
   （`maxMonthlyInquiries` のみ inquiry_screen の UI 層でチェック）。
   operational_test で境界仕様（29/30/31日）を先に固定したので、
   実装時はこのテストの仕様に合わせること。
3. **`drive_log_detail_screen` / `EquipmentSection` の画面・ウィジェット
   テスト未着手**（§1.2参照）。次スプリントでの追加を推奨。
4. **`DriveLogService.deleteDriveLog` が waypoint / like を逐次削除**
   （batch/チャンクなし）。大規模ログで部分削除が起き得る。

---

## 5. 手動テスト項目（実機でしか確認できない）

CI・Fakeでは検証不能。リリース前に実機でのチェックを要する。

### カメラ・OCR
- [ ] 車検証スキャン（document_scanner）: 撮影→OCR→登録フロー
- [ ] 請求書スキャン→明細取り込み（invoice_result）
- [ ] 暗所・斜め撮影での OCR 精度劣化時のエラーハンドリング

### 課金（RevenueCat）
- [ ] 無料→プレミアムの購入フロー（サンドボックス）
- [ ] 復元購入（機種変更後）
- [ ] 解約後のプランダウングレード反映

### プッシュ通知（FCM）
- [ ] 車検アラート通知の受信（フォアグラウンド/バックグラウンド/終了時）
- [ ] 通知タップからの画面遷移
- [ ] 通知許可拒否時のアプリ内フォールバック

### 地図・GPS
- [ ] ドライブ記録の実走行 GPS トラッキング精度・バッテリー消費
- [ ] 公開ドライブログの地図描画で自宅500m除去が視覚的に効いていること
- [ ] nearby_shops_map の現在地表示と距離ソート

### 認証・その他
- [ ] Google Sign-In 実機フロー（新規/再ログイン/退会→requires-recent-login）
- [ ] 退会実行後30日以内にサーバー側 purge が完了すること（運用監視）
- [ ] PDF エクスポートの共有シート・印刷
- [ ] 全角IMEでのナンバー入力→重複警告の実機表示

---

## 6. 次のアクション候補

1. CI で新規54件のパスを確認し、本レポートを確定版に更新する
2. `drive_log_detail_screen` / `EquipmentSection` の Widget テストを追加する
   （§1.1 優先度・高）
3. §4-1 の DI リファクタ Issue（`claude-task`）を起票する
