# エキスパート合同監査（2026-07）— 日本磨き込みフェーズ

> **目的**: `GLOBAL_SERVICE_STANDARDS.md`（North Star）に沿って、5専門（PM / Engineer / Tester / UIUX / Data）が製品を並列分析し、改善バックログを優先度付きで統合したもの。
> **今フェーズ方針**: 日本を基準実装として磨き込む。海外抽象化リファクタはしない（シームのみ）。

---

## 全専門の一致点（最重要シグナル）

**5名全員が独立に同じ結論に到達**：

> **`MaintenanceRecord` に「検証状態」フィールドが存在せず、North Star の核心（工場が裏書きした整備記録＝moat）が、計測も・表示も・保存もできない。**

現状の記録が持つのは `shopName`（自由文字列・検証不能）/ `staffName` / `inspectionResult` / `safetyStandardsCertificate` のみ。「工場が裏書きした」を構造化して保持する場所がない。一方、検証の"種"となる基盤は既にある（`inquiry_maintenance_importer`＝工場発行データの取り込み経路、`VehicleHistorySharingService`＝工場への閲覧権付与）。**器を1つ足すだけで死蔵資産が価値化する。**

---

## Tier 0 — 潜在バグ（日本の本番でも壊れる / 最優先）

| ID | 内容 | 発見 | 対象 | 工数 |
|----|------|------|------|------|
| **B1** | `vehicle_sharing_permissions` の **firestore.rules が未定義** → 本番デプロイで履歴共有機能が全拒否（デフォルト deny に落ちる）。関連複合インデックス(2件)も欠落 | Data / Engineer | `firestore.rules`, `firestore.indexes.json` | M |
| **B2** | `grantPermission` が所有権を検証せず `.set()` で**全上書き** → 他人が `ownerId` を渡して共有許可を乗っ取れる懸念 | Tester / Data | `vehicle_history_sharing_service.dart` | S |
| **B3** | catch で `AppError.unknown(e.toString())` を直生成し `mapFirebaseError()` を経由していない → Permission/NotFound/Network の分類とリトライ判定が消失 | Engineer | `vehicle_history_sharing_service.dart`, `vehicle_retirement_service.dart`（各catch 4箇所） | S |

> ⚠️ B1 のルール/インデックス**デプロイは本番反映のため要確認**（CLAUDE.md セキュリティ方針）。コード追加までを行い、デプロイは人間承認とする。

---

## Tier 1 — moatの核心（検証済み来歴を計測・表示・保存できるようにする）★全員一致

| ID | 内容 | 発見 | 対象 | 工数 |
|----|------|------|------|------|
| **C1** | `MaintenanceRecord` に検証状態フィールドを追加：`verificationSource`(enum: selfReported/shopImported/shopVerified)・`verifiedByShopId`・`verifiedAt`・`shopId`(shops参照)。`inquiryId != null` は `shopImported` として後方互換で導出。**追加のみ・後方互換** | 全員 | `models/maintenance_record.dart`, `inquiry_maintenance_importer.dart` | S〜M |
| **C2** | 検証済み割合の計算を **RED先行**でテスト化（TDD） | Tester | `test/` | S |
| **C3** | 「工場発行率」を計測（analytics イベント record_source=shop/self ＋ 集計）＝PMF卒業条件の計器 | PM | `analytics_service.dart` | S |
| **C4** | タイムラインに「✓工場裏書き」バッジ、車両ヘッダーに「検証済み X/Y件」サマリー | UIUX / PM | `vehicle_detail_screen.dart` | M |

---

## Tier 2 — wedge（獲得）& 継続率

| ID | 内容 | 発見 | 対象 | 工数 |
|----|------|------|------|------|
| **W1** | 車検リマインドが設計済みだが **FCM/APNs 未設定で実際に飛ばない**（獲得エンジンの心臓停止）＋送信履歴 | PM | `push_notification_service.dart`, `inspection_reminder_service.dart` | M（インフラ設定含む） |
| **W2** | 詳細画面の車検切迫感を強化：残日数カウントダウン・「45日=そろそろ予約」段階追加・「工場を探す」CTA | UIUX | `vehicle_detail_screen.dart`, `inspection_urgency.dart` | M |
| **W3** | 整備履歴を「出費」から「資産」へリフレーミング（"この車に積み上げた整備"＋来歴ヒーロー） | UIUX | `vehicle_detail_screen.dart` | S〜M |

---

## Tier 3 — シーム衛生 & 品質（低工数で効く）

| ID | 内容 | 発見 | 対象 | 工数 |
|----|------|------|------|------|
| **S1** | 期限イベント生成を単一ソース化：`expiry_summary.dart` の `vehicleExpiryItems()` に寄せ、3系統(通知/通知タブ/UI)の残日数計算を統合 | Engineer | `expiry_summary.dart`, `inspection_reminder_service.dart`, `recommendation_service.dart` | M |
| **S2** | 期限しきい値定数(30/7・30/90/180・7/30 と散在)を共通化 | Engineer | `core/config`, `inspection_urgency.dart` | S |
| **S3** | 車検インターバル「新車3年・以降2年」の三重定義を `MaintenanceConfig` に統合 | Engineer | `maintenance_config.dart` 他 | M |
| **T1** | テスト追加：grant側権限違反 / 退役×共有の連動 / expiry境界(==now,±1ms) / mileage の Edge Cases | Tester | `test/services/` | S〜M |
| **A1** | アクセシビリティ：満了日の色依存を状態アイコン＋残日数ラベルで併記、Semantics付与 | UIUX | `vehicle_detail_screen.dart` | S |
| **P1** | PMF卒業条件の数値化（下記）を `HUMAN_TASKS.md` / Issueに正式起票 | PM | docs | S |

---

## PMF 卒業条件（数値たたき台 / North Star軸）

| カテゴリ | 指標 | 卒業ライン |
|---|---|---|
| 獲得 | 無料アクティブユーザー | 3,000〜5,000人（1商圏の密度） |
| 定着 | 7日継続率 / DAU/MAU | 40% / 25% |
| コア価値 | 車検日 or 整備記録の登録率 | 70%以上 |
| **moat** | **工場裏書き済み整備記録の割合** | **15%以上（必達）** |
| B2B | 有料工場数 / 3ヶ月継続 | 10店 / 70% |

> 卒業判定の芯は **「工場裏書き率」**。ここが上がらない限り他指標が良くても PMF 未達と判断する。

---

## 推奨実装順（レバレッジ順）

1. **C1（検証フィールドの器）** — 全員一致の最重要・低工数・後方互換。moat を初めて計測可能にする。シーム原則§1-3の実体化。
2. **B3（mapFirebaseError 統一）** — 純粋なバグ修正・工数S・リスク最小。
3. **B2（grant権限違反の是正）＋ T1** — セキュリティ懸念の解消。
4. **B1（共有ルール/インデックス）** — 潜在バグ。コード追加＋デプロイは要確認。
5. C3/C4（計測とバッジ表示）→ 価値ループが閉じる。

以降 Tier 2（wedge・継続率）、Tier 3（シーム衛生）へ。
