# Claude開発セッションメモ

## 現在の状態（2024-02-08更新）

### 完了済み
- **P0**: 車検・保険アラート、バリデーション強化、走行距離整合性チェック
- **P1**: エラーハンドリング統一（Result<T,AppError>）、テスト追加、ナンバープレート重複チェック
- **P2**: 必須項目明示、AppError対応エラースナックバー
- **Phase 3**: データ同期安定化、AuthService統一、統計・可視化画面
- **Phase 3.5**: 技術的負債解消（アーキテクチャ統一、全ProviderにDI適用）
- **Phase 3.6**: DI完全化、Providerテスト追加
- **Phase 4**: オフラインサポート、プッシュ通知

### Phase 4 詳細
- **4-A1 オフラインサポート**
  - Firestore永続化設定（persistenceEnabled, CACHE_SIZE_UNLIMITED）
  - ConnectivityProvider追加（connectivity_plus使用）
  - OfflineBannerウィジェット追加
  - HomeScreenにオフライン表示統合
  - ConnectivityProviderテスト14件追加

- **4-A2 プッシュ通知**
  - PushNotificationService追加（FCM + flutter_local_notifications）
  - 通知許可リクエスト機能（設定画面から）
  - スケジュール通知対応（timezone使用）
  - DIに登録、main.dartで初期化
  - テスト3件追加

### 品質スコア: 8.4/10
- テスト: 310件全パス（Phase 4で+17件）
- 静的解析: クリーン
- アーキテクチャ: 完全統一（services層のみ、全DI適用）
- オフライン: Firestoreキャッシュ対応
- プッシュ通知: FCM対応
- 残課題: UI層テスト欠落、CI/CD未整備

---

## 次回やること

### 機能ロードマップ
`docs/FEATURE_SPEC.md` の追加機能要望リストを参照

**Phase 4 残り**
- C2: E2Eテスト整備
- C3: CI/CD（GitHub Actions）

**Phase 5（収益化・拡張）**
- B1: BtoBカスタムパーツマーケットプレイス
- B3: 整備工場連携

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
│   ├── injection.dart          # 7 Service登録（Push含む）
│   └── service_locator.dart    # ServiceLocator
├── services/                   # すべてResult<T,AppError>対応
│   ├── firebase_service.dart
│   ├── auth_service.dart
│   ├── recommendation_service.dart
│   ├── vehicle_certificate_ocr_service.dart
│   ├── invoice_ocr_service.dart
│   ├── pdf_export_service.dart
│   └── push_notification_service.dart  # Phase 4新規
├── providers/                  # すべてDI注入、テスト有
│   ├── vehicle_provider.dart
│   ├── maintenance_provider.dart
│   ├── auth_provider.dart
│   ├── notification_provider.dart
│   └── connectivity_provider.dart  # Phase 4新規
├── widgets/common/
│   └── offline_banner.dart     # Phase 4新規
├── screens/                    # DI経由でService取得
│   └── ...
└── ...

test/
├── providers/                  # 93テスト
│   ├── auth_provider_test.dart
│   ├── vehicle_provider_test.dart
│   ├── maintenance_provider_test.dart
│   ├── notification_provider_test.dart
│   └── connectivity_provider_test.dart
├── services/                   # 53テスト（Push含む）
│   ├── ...
│   └── push_notification_service_test.dart  # Phase 4新規
└── ...（合計310テスト）
```

---

## 機能仕様
詳細は `docs/FEATURE_SPEC.md` を参照
