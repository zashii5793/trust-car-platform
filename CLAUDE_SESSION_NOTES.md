# Claude Session Notes

最終更新: 2026-06-11

---

## 現在の状態

**ブランチ**: `claude/continue-development-WYZZp`（PR #20 マージ済み・main取り込み済み）
**テスト**: 2719件+ 全パス（`--exclude-tags emulator`）

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

### 残課題（次セッション候補）
- PdfExportService の Result<T> 化（規約違反）
- mileage_notification_service / ai_chat_provider のテスト追加
- 自動車保険（任意保険）の期限・証券管理機能（現状は自賠責のみ）
- 通知権限リクエストの導線確認（OSリマインダーの前提）

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
