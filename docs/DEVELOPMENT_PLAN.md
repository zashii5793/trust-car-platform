# Trust Car Platform 開発計画書

**作成日**: 2026年1月31日
**作成者**: 全体PM（6エキスパート視点での総合分析）
**バージョン**: 1.0

---

## エグゼクティブサマリー

### プロジェクトビジョン
> 自動車の整備・点検履歴を確実に管理し、将来的にはカスタムパーツ提案へと繋げる。
> 法人向けにはリース車両管理機能も提供。
> **1つ1つの機能を確かなものに**して、段階的に機能を拡充する。

### 現状評価

| 項目 | 状況 | 評価 |
|------|------|------|
| アーキテクチャ | クリーンアーキテクチャ導入済み | ✅ 良好 |
| テストカバレッジ | 91単体テスト成功 | ✅ 良好 |
| コア機能（整備履歴） | 基本実装済み | ⚠️ 拡張必要 |
| 車検管理 | **未実装**（日付フィールドなし） | ❌ 最優先 |
| 法人機能 | 未実装 | ⚠️ Phase 2 |

---

## 1. 6エキスパート視点からの課題分析

### 1.1 ドメインエキスパート（自動車整備業界）

#### 現在のデータモデルの問題点

```
【車両情報の不足】
❌ ナンバープレート → 車両特定に必須
❌ 車台番号(VIN) → 部品適合確認に必須
❌ 型式 → リコール対応・部品発注に必須
❌ 車検満了日 → 最重要管理項目
❌ 自賠責保険期限 → 法的必須

【整備履歴の不足】
❌ 法定点検の区分（12ヶ月/24ヶ月/6ヶ月）
❌ 消耗品の詳細（品番、メーカー、交換推奨時期）
❌ 整備工場の認証番号・連絡先

【法人・リース対応の欠如】
❌ リース契約情報（期間、月額、走行制限）
❌ リース会社情報
❌ 法人アカウント管理
```

#### 業界標準との乖離

| 項目 | 業界標準 | 現在の実装 |
|------|----------|-----------|
| 点検整備記録簿 | 国交省フォーマット | 独自フォーマット |
| 車検証情報 | 全項目記録 | maker/model/yearのみ |
| 消耗品管理 | 品番・交換サイクル | タイトルのみ |

---

### 1.2 UI/UXデザイナー

#### 現在の画面構成

```
screens/
├── auth/
│   ├── login_screen.dart      ✅ 実装済み
│   └── signup_screen.dart     ✅ 実装済み
├── home/
│   ├── home_screen.dart       ⚠️ ダッシュボード機能不足
│   └── widgets/               ✅ 実装済み
├── vehicle/
│   ├── vehicle_form_screen.dart    ⚠️ 入力項目不足
│   ├── vehicle_detail_screen.dart  ✅ 実装済み
│   └── vehicle_edit_screen.dart    ⚠️ 入力項目不足
├── maintenance/
│   └── maintenance_form_screen.dart ⚠️ 定型入力不足
├── notification/
│   └── notification_list_screen.dart ⚠️ 優先度表示弱い
├── profile/
│   ├── profile_screen.dart    ✅ 実装済み
│   └── settings_screen.dart   ✅ 実装済み
└── export/
    └── export_dialog.dart     ✅ 実装済み
```

#### UX改善ポイント

| 優先度 | 課題 | 改善案 |
|--------|------|--------|
| P0 | 車検までの日数が見えない | ダッシュボードウィジェット |
| P0 | 次回メンテ予定が分からない | カレンダー/リスト表示 |
| P1 | 整備入力が面倒 | 定型タイトル候補 |
| P1 | 緊急通知が埋もれる | 赤バナー表示 |
| P2 | 初回起動で迷う | オンボーディング |

---

### 1.3 バックエンドアーキテクト

#### 現在のアーキテクチャ（良好）

```
lib/
├── core/
│   ├── error/
│   │   └── app_error.dart      ✅ 14種類のエラー型
│   ├── result/
│   │   └── result.dart         ✅ Result<T,E>型
│   ├── di/
│   │   └── service_locator.dart ✅ DI基盤
│   └── config/
│       └── app_config.dart     ✅ Feature Flags
├── domain/
│   ├── repositories/           ✅ Interface定義
│   └── usecases/              ✅ UseCase層
├── data/
│   └── repositories/           ✅ Firebase実装
├── models/                     ⚠️ 拡張必要
└── providers/                  ✅ 状態管理
```

#### データモデル拡張計画

```dart
// Phase 1.5: 車両モデル拡張
class Vehicle {
  // 既存
  final String id;
  final String maker;
  final String model;
  final int year;
  final String? grade;
  final int mileage;
  final String? imageUrl;

  // 追加（P0）
  final String? licensePlate;        // ナンバープレート
  final String? vinNumber;           // 車台番号
  final String? modelCode;           // 型式
  final DateTime? inspectionExpiryDate;  // 車検満了日 ★最重要
  final DateTime? insuranceExpiryDate;   // 自賠責期限

  // 追加（P1）
  final String? color;               // 車体色
  final int? engineDisplacement;     // 排気量
  final FuelType? fuelType;          // 燃料タイプ
  final DateTime? purchaseDate;      // 購入日/納車日
}

// Phase 2.0: リース契約
class LeaseContract {
  final String id;
  final String vehicleId;
  final String corporateAccountId;
  final String leaseCompany;
  final DateTime startDate;
  final DateTime endDate;
  final int monthlyPayment;
  final int? mileageLimit;           // 走行距離制限
  final int? penaltyPerKm;           // 超過時ペナルティ
  final LeaseType type;              // ファイナンス/オペレーティング
}
```

---

### 1.4 セキュリティエンジニア

#### 現在のセキュリティ状況

| 項目 | 状況 | リスク |
|------|------|--------|
| 認証 | Firebase Auth | ✅ 低 |
| データ分離 | userId フィールド | ✅ 低 |
| Firestore Rules | 基本実装 | ⚠️ 中（強化必要）|
| 機微情報暗号化 | 未実装 | ⚠️ 中 |
| 監査ログ | 未実装 | ⚠️ 中 |
| 法人データ分離 | 未実装 | ❌ 高（法人向け必須）|

#### 機微情報の定義

```
【高機密】暗号化必須
- 車台番号（VIN）: 個人特定可能
- ナンバープレート: 個人特定可能

【中機密】アクセス制限
- 整備履歴: ビジネス情報
- 費用情報: 財務情報

【低機密】標準保護
- 車両基本情報（メーカー、車種）
```

---

### 1.5 テストエンジニア

#### 現在のテストカバレッジ

```
テスト合計: 91件（全成功）

【実装済み】
✅ core/app_error_test.dart      (12件)
✅ core/result_test.dart         (12件)
✅ core/service_locator_test.dart (5件)
✅ core/app_config_test.dart     (18件)
✅ models/user_test.dart         (10件)
✅ models/maintenance_record_test.dart (5件)
✅ models/vehicle_test.dart      (4件)
✅ widget_test.dart              (14件)

【未実装】⚠️ 高優先度
❌ providers/vehicle_provider_test.dart
❌ providers/maintenance_provider_test.dart
❌ providers/notification_provider_test.dart
❌ repositories/firebase_vehicle_repository_test.dart
❌ repositories/firebase_maintenance_repository_test.dart

【Integration Test】
✅ ログイン画面表示 (1件)
✅ フォーム入力 (1件)
✅ ログインフロー (1件)
❌ 車両登録フロー
❌ メンテナンス追加フロー
❌ 通知確認フロー
```

#### テスト拡充計画

| Phase | テスト種別 | 件数目標 |
|-------|-----------|---------|
| 1.5 | Provider単体テスト | +30件 |
| 1.5 | Repositoryモックテスト | +20件 |
| 1.5 | Integration Test | +5件 |
| 2.0 | 法人機能テスト | +40件 |
| 2.0 | E2Eテスト | +10件 |

---

### 1.6 プロダクトオーナー

#### ビジネス優先度マトリクス

```
                    ビジネス価値
                    高 ─────────────────────────────┐
                    │  ★車検管理      ★法人機能    │
                    │  ★ダッシュボード              │
                    │                              │
                    │  プッシュ通知   整備工場連携  │
                    │  履歴検索                    │
                    │                              │
                    │  SNS共有      AI提案        │
                    低 ─────────────────────────────┘
                       低 ──────────────────────── 高
                              技術難易度

★ = Phase 1.5 で実装
```

---

## 2. 開発ロードマップ

### Phase 1.5: MVP完成（6週間）

**目標**: 車検管理を中心とした確実なMVP

```
Week 1-2: データモデル強化
├─ Vehicle モデル拡張（車検日、識別情報）
├─ MaintenanceType 細分化（12ヶ月/24ヶ月点検）
├─ Firestore マイグレーション
└─ 車両登録/編集画面の更新

Week 3-4: ダッシュボード実装
├─ 車検カウントダウンウィジェット
├─ 次回メンテナンス表示
├─ 緊急通知バナー
└─ ホーム画面リファクタリング

Week 5-6: 通知 & テスト強化
├─ FCM プッシュ通知
├─ Provider 単体テスト
├─ Repository モックテスト
└─ Integration Test 拡充
```

### Phase 2.0: 法人機能（8週間）

**目標**: リース車両管理を含む法人対応

```
Week 1-4: 法人基盤
├─ CorporateAccount モデル
├─ LeaseContract モデル
├─ ロール管理（admin/manager/viewer）
├─ マルチテナントSecurity Rules
└─ 法人ダッシュボード

Week 5-8: エンゲージメント強化
├─ 履歴フィルター/検索
├─ 定型タイトルサジェスト
├─ レポート出力強化（CSV）
├─ 監査ログ
└─ パフォーマンス最適化
```

### Phase 2.5: AI & エコシステム（将来）

```
- カスタムパーツ提案AI
- 整備工場連携API
- SNS機能（投稿、ドライブ記録）
- マーケットプレイス連携
```

---

## 3. Phase 1.5 詳細計画

### 3.1 Week 1-2: データモデル強化

#### タスク一覧

| ID | タスク | 担当 | 工数 | 依存 |
|----|--------|------|------|------|
| 1.1 | Vehicle モデル拡張 | Backend | 4h | - |
| 1.2 | FuelType enum 追加 | Backend | 1h | - |
| 1.3 | MaintenanceType 拡張 | Backend | 2h | - |
| 1.4 | Firestore マイグレーション計画 | Backend | 2h | 1.1 |
| 1.5 | 車両登録画面 更新 | Frontend | 6h | 1.1 |
| 1.6 | 車両編集画面 更新 | Frontend | 4h | 1.5 |
| 1.7 | 車両詳細画面 更新 | Frontend | 3h | 1.1 |
| 1.8 | メンテナンス追加画面 更新 | Frontend | 3h | 1.3 |
| 1.9 | Vehicle モデルテスト追加 | Test | 3h | 1.1 |
| 1.10 | 画面テスト追加 | Test | 4h | 1.5-1.8 |

#### Vehicle モデル拡張仕様

```dart
// lib/models/vehicle.dart

enum FuelType {
  gasoline('ガソリン'),
  diesel('ディーゼル'),
  hybrid('ハイブリッド'),
  electric('電気'),
  phev('プラグインハイブリッド'),
  hydrogen('水素');

  final String displayName;
  const FuelType(this.displayName);
}

class Vehicle {
  final String id;
  final String userId;
  final String maker;
  final String model;
  final int year;
  final String? grade;
  final int mileage;
  final String? imageUrl;

  // Phase 1.5 追加フィールド
  final String? licensePlate;           // 例: "品川 300 あ 12-34"
  final String? vinNumber;              // 車台番号 17桁
  final String? modelCode;              // 型式 例: "DBA-GRB"
  final DateTime? inspectionExpiryDate; // 車検満了日
  final DateTime? insuranceExpiryDate;  // 自賠責期限
  final String? color;                  // 車体色
  final int? engineDisplacement;        // 排気量(cc)
  final FuelType? fuelType;             // 燃料タイプ
  final DateTime? purchaseDate;         // 購入日

  final DateTime createdAt;
  final DateTime? updatedAt;

  // 車検までの残日数
  int? get daysUntilInspection {
    if (inspectionExpiryDate == null) return null;
    return inspectionExpiryDate!.difference(DateTime.now()).inDays;
  }

  // 車検期限が近いか（30日以内）
  bool get isInspectionDueSoon {
    final days = daysUntilInspection;
    return days != null && days <= 30 && days >= 0;
  }

  // 車検期限切れか
  bool get isInspectionExpired {
    final days = daysUntilInspection;
    return days != null && days < 0;
  }
}
```

#### MaintenanceType 拡張仕様

```dart
// lib/models/maintenance_record.dart

enum MaintenanceType {
  repair('修理', Icons.build),
  legalInspection12('12ヶ月点検', Icons.assignment),
  legalInspection24('24ヶ月点検', Icons.assignment_turned_in),
  carInspection('車検', Icons.verified),
  oilChange('オイル交換', Icons.opacity),
  tireChange('タイヤ交換', Icons.tire_repair),
  batteryChange('バッテリー交換', Icons.battery_charging_full),
  brakeService('ブレーキ整備', Icons.do_not_disturb),
  airConditioner('エアコン整備', Icons.ac_unit),
  partsReplacement('部品交換', Icons.settings),
  other('その他', Icons.more_horiz);

  final String displayName;
  final IconData icon;
  const MaintenanceType(this.displayName, this.icon);
}
```

### 3.2 Week 3-4: ダッシュボード実装

#### ダッシュボードウィジェット設計

```
┌─────────────────────────────────────────┐
│  [!] 車検期限まであと 15日              │ ← 緊急バナー（30日以内）
└─────────────────────────────────────────┘

┌─────────────────┐ ┌─────────────────────┐
│ 車検カウントダウン  │ │ 次回メンテナンス      │
│    ┌───────┐    │ │                     │
│    │  45   │    │ │ ・オイル交換 (2/15)  │
│    │  日   │    │ │ ・タイヤローテ (3/1) │
│    └───────┘    │ │                     │
│ 2026/03/15 満了  │ │ [+ 追加]            │
└─────────────────┘ └─────────────────────┘

┌─────────────────────────────────────────┐
│ 走行距離: 45,230 km                     │
│ ████████████████░░░░ 75%               │
│ 次回オイル交換まで: 2,770 km            │
└─────────────────────────────────────────┘

┌─ 所有車両 ──────────────────────────────┐
│ [車両カード1] [車両カード2] [+追加]      │
└─────────────────────────────────────────┘
```

#### タスク一覧

| ID | タスク | 担当 | 工数 | 依存 |
|----|--------|------|------|------|
| 2.1 | InspectionCountdownWidget | Frontend | 4h | 1.1 |
| 2.2 | NextMaintenanceWidget | Frontend | 4h | - |
| 2.3 | MileageProgressWidget | Frontend | 3h | - |
| 2.4 | UrgentAlertBanner | Frontend | 2h | 1.1 |
| 2.5 | DashboardScreen 新規作成 | Frontend | 4h | 2.1-2.4 |
| 2.6 | HomeScreen リファクタ | Frontend | 3h | 2.5 |
| 2.7 | NotificationProvider 拡張 | Backend | 3h | 1.1 |
| 2.8 | Widget テスト | Test | 4h | 2.1-2.4 |
| 2.9 | Integration Test | Test | 4h | 2.5 |

### 3.3 Week 5-6: 通知 & テスト強化

#### FCM実装計画

```dart
// lib/services/notification_service.dart

class NotificationService {
  // 車検リマインダー（30日前、14日前、7日前、当日）
  Future<void> scheduleInspectionReminders(Vehicle vehicle);

  // メンテナンスリマインダー（距離ベース）
  Future<void> checkMileageBasedReminders(Vehicle vehicle);

  // 自賠責期限リマインダー
  Future<void> scheduleInsuranceReminders(Vehicle vehicle);
}
```

#### テスト拡充計画

```
test/
├── providers/
│   ├── vehicle_provider_test.dart      # 新規 (+10件)
│   ├── maintenance_provider_test.dart  # 新規 (+10件)
│   └── notification_provider_test.dart # 新規 (+10件)
├── repositories/
│   ├── mock_vehicle_repository.dart    # モック実装
│   ├── mock_maintenance_repository.dart
│   └── firebase_vehicle_repository_test.dart # 新規 (+15件)
└── integration_test/
    ├── vehicle_registration_test.dart  # 新規
    ├── maintenance_flow_test.dart      # 新規
    └── dashboard_test.dart             # 新規
```

---

## 4. 成功指標（KPI）

### Phase 1.5 完了時

| 指標 | 現在 | 目標 | 測定方法 |
|------|------|------|----------|
| 単体テスト数 | 91 | 150+ | flutter test |
| Integration Test | 3 | 10+ | flutter drive |
| 車検日登録率 | 0% | 80% | Firestore query |
| ビルドサイズ | 31MB | <35MB | flutter build |
| 起動時間 | - | <3秒 | Lighthouse |

### Phase 2.0 完了時

| 指標 | 目標 | 測定方法 |
|------|------|----------|
| 法人アカウント数 | 10社 | Firestore |
| リース車両登録数 | 50台 | Firestore |
| DAU/MAU | 30% | Analytics |
| ユーザー継続率（7日） | 50% | コホート |

---

## 5. リスクと対策

| リスク | 影響度 | 発生確率 | 対策 |
|--------|--------|----------|------|
| Firestore マイグレーション失敗 | 高 | 低 | 段階的移行、バックアップ |
| FCM 設定の複雑さ | 中 | 中 | 段階的実装、ローカル通知から |
| 法人機能の複雑化 | 高 | 中 | MVP最小化、フィードバック収集 |
| パフォーマンス劣化 | 中 | 低 | 定期的な計測、最適化 |

---

## 6. 次のアクション

### 即座に着手（今週）

1. **Vehicle モデル拡張**
   - `inspectionExpiryDate` フィールド追加
   - `licensePlate`, `vinNumber`, `modelCode` 追加
   - バリデーション実装

2. **MaintenanceType 拡張**
   - 12ヶ月/24ヶ月点検の区分追加
   - アイコン定義

3. **テスト追加**
   - 新フィールドの単体テスト
   - バリデーションテスト

### 来週着手

4. **画面更新**
   - 車両登録画面に新フィールド追加
   - 車両詳細画面で車検日表示

5. **ダッシュボード設計**
   - ワイヤーフレーム作成
   - コンポーネント分割

---

*この計画は2週間ごとにレビューし、必要に応じて調整します。*

**承認**: _______________
**日付**: 2026年1月31日
