# 夜間レポート — 2026-07-11

**実行ブランチ**: `claude/night-20260711`
**実行時刻**: 2026-07-11 〜 2026-07-12（UTC）
**テスト**: 3480件 全パス / `flutter analyze lib/` No issues found

---

## 今夜やったこと

### 1. stalled CI の修正（`claude/auto-improve-fleet-urgency-dedup`）

ユーザーのリファクタリングコミットが `dart format` 未適用でCIが詰まっていた。

- `refactor: FleetService の車検緊急度判定を inspectionUrgencyForDays に集約` をcherry-pick
- `test/services/fleet_service_test.dart` に `dart format` を適用してコミット

### 2. Issue #63 実装（priority: high）— AI提案セクション強化

**ホーム「AIからの提案」に燃料タイプ別フィルタリングと次回km目安を追加。**

#### 変更ファイル

| ファイル | 変更内容 |
|---------|---------|
| `lib/services/recommendation_service.dart` | `MaintenanceScheduleService?` オプション注入、燃料タイプフィルタ、次回km目安 |
| `lib/core/di/injection.dart` | `RecommendationService` に `scheduleService` を注入登録 |
| `test/services/recommendation_service_schedule_test.dart` | TDDテスト13件（新規） |

#### 機能概要

- **EV・水素車**: オイル交換など不要なメンテ推奨を生成しない
- **ガソリン・ハイブリッド**: 従来通り適切なインターバルで推奨を生成
- **reason フィールド**: `🎯 次回目安: 60,000km（あと2,000km）` 形式の走行距離コンテキストを追加
- **後方互換**: `const RecommendationService()` は従来動作を維持

#### TDD結果（全13件パス）

```
燃料タイプ別フィルタリング
  ✓ EV: オイル交換推奨を生成しない
  ✓ 水素: オイル交換推奨を生成しない
  ✓ ガソリン: オイル交換推奨を生成する
  ✓ ハイブリッド: オイル交換推奨を生成する（インターバルは長め）
  ✓ 後方互換: scheduleService なしの場合 EV でもオイル交換を生成する

次回km目安の reason 追加
  ✓ タイヤローテーション推奨に次回km目安が含まれる
  ✓ 次回km目安は現在走行距離より大きい値を示す
  ✓ scheduleService なし: reason に次回km目安マーカーが含まれない
  ✓ km インターバルのない項目（車検など）は次回km目安なし

Edge Cases
  ✓ fuelType が null: ガソリン扱いでオイル交換を生成する
  ✓ mileage が 0: nextDueKm は最初のインターバルを示す（クラッシュなし）
  ✓ 走行距離がインターバルをちょうど超えた: 超過表示
  ✓ 記録あり: 走行距離超過で推奨が生成され次回km目安を表示
```

### 3. PR作成

**PR #78**: https://github.com/zashii5793/trust-car-platform/pull/78

- CI不通（`dart format` 未適用）を検知 → 修正コミットを追加プッシュ済み
- CI通過確認済み

---

## 継続セッションで追加実装（2026-07-12）

### 4. Issue #41 Phase 2 — 非パートナー店舗への問い合わせ需要蓄積

ユーザー承認を受け、Issue #41 の Phase 2（サービス層）を実装。

| ファイル | 変更内容 |
|---------|---------|
| `lib/models/shop_inquiry_demand.dart` | 新規モデル（需要記録ドキュメント） |
| `lib/services/shop_demand_service.dart` | `recordDemand` / `getDemandCountForShop` / `getDemandsForShop` |
| `lib/models/shop.dart` | `isPartner` getter 追加（active/trialing → true） |
| `lib/core/constants/firestore_collections.dart` | `shopInquiryDemands` 定数追加 |
| `firestore.rules` | `shop_inquiry_demands` セキュリティルール追加 |
| `firestore.indexes.json` | `shopId ASC + createdAt DESC` 複合インデックス追加 |
| `lib/core/di/injection.dart` | `ShopDemandService` 登録 |
| `test/services/shop_demand_service_test.dart` | TDDテスト19件（新規） |

**設計意図**: 非パートナー店舗への問い合わせを遮断して需要を蓄積 →
店舗オンボーディング時に「N人があなたへの問い合わせを試みました」と表示するプルセールスフック。

> Phase 1（Google Maps SDK + 地図上のピン表示）は外部APIキーが必要なため、次セッションに持ち越し。

### 5. 整備記録の査定価値バナー（ユーザー要望）

車両詳細画面の統計セクション直下に `_MaintenanceValueBanner` を追加。

| 条件 | 表示 |
|------|------|
| 車検記録あり | 「車検記録あり — 査定で信頼性アピール」（緑カード） |
| 整備記録 N件のみ | 「整備記録 N件 — 査定価値UP」（緑カード） |
| 記録なし | 非表示 |

### 6. コードコンフリクトチェック & 修正（ユーザー要望）

コンカレント実装後の整合性チェックを実施し、以下の WARN を修正：

- `ShopInquiryDemand.fromFirestore`: `as String` → `(as String?) ?? ''` 安全キャスト
- `ShopDemandService.getDemandsForShop`: `orderBy('createdAt', descending: true)` 追加漏れ
- `ShopDemandService._collection`: ハードコード文字列 → `FirestoreCollections` 定数使用

---

## 人間タスク（残積み）

1. `firebase deploy --only firestore:rules,firestore:indexes`
   — 今セッションで追加した `shop_inquiry_demands` ルール + インデックスを含む本番反映
2. `firebase deploy --only storage` — storage.rules の本番反映（差分確認必須）
3. シードデータ登録（手順は `docs/HUMAN_TASKS.md` 参照）
4. **Issue #41 Phase 2 UI配線**: `inquiry_screen.dart` の送信フローに `isPartner` チェックを組み込む
   （`ShopDemandService.recordDemand()` 呼び出し / 非パートナー向けゲートUI）

---

## 次のアクション候補（3件）

1. **Issue #41 Phase 2 UI配線** — `inquiry_screen.dart` で `Shop.isPartner` を確認し、非パートナーの場合は `ShopDemandService.recordDemand()` を呼んでゲートダイアログを表示
2. **Issue #41 Phase 1** — Google Maps SDK 連動（地図上に提携店ピン表示）。APIキーを環境変数として設定後に着手
3. **PR #78 マージ** — CI が全パスしていることを確認後にマージ
