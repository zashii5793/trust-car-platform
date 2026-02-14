# Claude開発セッションメモ

## 現在の状態（2025-02-11更新）

### 完了済み
- **P0**: 車検・保険アラート、バリデーション強化、走行距離整合性チェック
- **P1**: エラーハンドリング統一（Result<T,AppError>）、テスト追加、ナンバープレート重複チェック
- **P2**: 必須項目明示、AppError対応エラースナックバー
- **Phase 3**: データ同期安定化、AuthService統一、統計・可視化画面
- **Phase 3.5**: 技術的負債解消（アーキテクチャ統一、全ProviderにDI適用）
- **Phase 3.6**: DI完全化、Providerテスト追加
- **Phase 4**: オフラインサポート、プッシュ通知、E2Eテスト環境整備、CI/CD
- **Phase 4.5**: パフォーマンス・品質改善（エキスパート分析に基づく）
- **Phase 5 モデル拡張**: 車検・点検情報システム対応
- **Phase 5 Service/Provider**: Invoice, Document, ServiceMenu の Service/Provider追加

### Phase 5 詳細（2025-02-11）

**モデル拡張** ✅
- Vehicle: DriveType, TransmissionType, VoluntaryInsurance, etc.
- MaintenanceRecord: InspectionResult, WorkItem, Part, 新サービスタイプ
- 新モデル: Invoice, Document, ServiceMenu

**Service/Provider追加** ✅
- InvoiceService / InvoiceProvider
- DocumentService / DocumentProvider
- ServiceMenuService / ServiceMenuProvider
- injection.dart, firestore.rules 更新済み

テスト: 27件追加、全テスト合格、静的解析クリーン

---

## 企画書との整合性分析（2025-02-11）

### 方向性OK
- 車両一元管理 ✅
- 車検・法定点検管理 ✅
- 証跡保存（PDF/写真）✅
- 予測通知（基本）✅
- 請求書管理 ✅
- サービスメニュー ✅

### 課題（優先度順）

#### P0: 車両情報の選択式入力
**問題**: メーカー/車種/グレードがテキスト入力 → 表記ゆれ発生
**対応**:
- VehicleMaster/ModelMaster/GradeMaster モデル作成
- 初期データ投入（主要国産メーカー）
- 車両登録画面を選択式に変更

#### P1: AI提案機能（パーツ）
**問題**: 企画書の核心機能が未実装
**対応**:
- パーツ互換性データベース設計
- AI提案ロジック（車種×ライフスタイル×パーツ）
- メリット・デメリット生成（LLM連携 or テンプレート）

#### P1: BtoBマーケット基盤
**問題**: 収益モデルの根幹が未実装
**対応**:
- Shop, PartListing, Inquiry モデル実装
- 管理者ロール追加
- 事業者認証フロー

#### P2: SNS・コミュニティ
**対応**:
- Post, Comment, Like モデル
- PartReview モデル
- フィード画面

#### P2: 車両購入レコメンド
**対応**:
- 外部API連携（中古車マーケット）

#### P3: ドライブログ・マップ
**対応**:
- DriveSession, VisitedPlace モデル
- マップUI（Google Maps）

---

## 次回やること（優先）

### 1. 車両マスタデータ導入（P0）
```dart
// 新規モデル
class VehicleMaster {
  final String makerId;
  final String makerName;      // "トヨタ"
  final String makerNameEn;    // "Toyota"
}

class VehicleModelMaster {
  final String modelId;
  final String modelName;      // "プリウス"
  final String? bodyType;      // "セダン", "SUV"
  final int? productionStartYear;
  final int? productionEndYear;
}

class GradeMaster {
  final String gradeId;
  final String gradeName;      // "S", "G", "Z"
  final FuelType? fuelType;
  final DriveType? driveType;
}
```

### 2. BtoBマーケット基盤（P1）
- Shop モデル（整備工場/販売店/パーツショップ）
- PartListing モデル
- Inquiry モデル

### 3. 画面追加
- 請求書一覧・詳細画面
- 書類管理画面
- サービスメニュー選択画面

---

## 効率化ルール（必ず守る）

```dart
// 1. Read: 必要な行だけ
Read(file_path: "...", offset: 400, limit: 50)

// 2. Grep: まずファイル特定
Grep(pattern: "...", output_mode: "files_with_matches")

// 3. テスト: 出力最小化
flutter test 2>&1 | grep -oE '\+[0-9]+' | sort -t+ -k2 -n | tail -1

// 4. 大きな分析は事前に別セッションで
```

---

## 主要ファイルパス

```
lib/
├── core/di/
│   ├── injection.dart          # Service登録
│   └── service_locator.dart
├── services/                   # すべてResult<T,AppError>対応
│   ├── firebase_service.dart
│   ├── auth_service.dart
│   ├── invoice_service.dart      # Phase 5
│   ├── document_service.dart     # Phase 5
│   ├── service_menu_service.dart # Phase 5
│   └── ...
├── providers/                  # すべてDI注入
│   ├── vehicle_provider.dart
│   ├── invoice_provider.dart     # Phase 5
│   ├── document_provider.dart    # Phase 5
│   ├── service_menu_provider.dart # Phase 5
│   └── ...
└── models/
    ├── vehicle.dart              # Phase 5拡張済み
    ├── maintenance_record.dart   # Phase 5拡張済み
    ├── invoice.dart              # Phase 5新規
    ├── document.dart             # Phase 5新規
    └── service_menu.dart         # Phase 5新規

test/models/
└── phase5_models_test.dart     # 27テスト
```

---

## 機能仕様
詳細は `docs/FEATURE_SPEC.md` を参照
