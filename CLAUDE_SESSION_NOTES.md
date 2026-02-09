# Claude開発セッションメモ

## 現在の状態（2024-02-09更新）

### 完了済み
- **P0**: 車検・保険アラート、バリデーション強化、走行距離整合性チェック
- **P1**: エラーハンドリング統一（Result<T,AppError>）、テスト追加、ナンバープレート重複チェック
- **P2**: 必須項目明示、AppError対応エラースナックバー
- **Phase 3**: データ同期安定化、AuthService統一、統計・可視化画面
- **Phase 3.5**: 技術的負債解消（アーキテクチャ統一、全ProviderにDI適用）
- **Phase 3.6**: DI完全化、Providerテスト追加
- **Phase 4**: オフラインサポート、プッシュ通知、E2Eテスト環境整備、CI/CD
- **Phase 4.5**: パフォーマンス・品質改善（エキスパート分析に基づく）

### Phase 4.5 詳細（2024-02-09）
- **Critical課題対応**
  - NotificationProviderエラー型をAppError?に統一
  - Firestoreキャッシュサイズを100MBに制限（メモリリーク防止）
  - N+1クエリをバッチ取得に最適化（10+クエリ → 1-2クエリ）

- **High課題対応**
  - ImageProcessingService追加（バリデーション＋圧縮）
    - サイズ上限: 10MB
    - 形式チェック: JPEG/PNG/WebP（マジックバイト検出）
    - 自動圧縮: 最大2000px、JPEG品質85%、目標500KB
  - FirebaseServiceにuploadProcessedImage()追加
  - Widgetテスト追加（LoginScreen 13件、AddMaintenanceScreen 4件）

- **検証済み（問題なし）**
  - Firebase Security Rules: firestore.rules, storage.rules適切に設定
  - Stream購読ライフサイクル: 全Providerで適切なキャンセル・クリーンアップ
  - エッジケーステスト: 140+テストでカバー

### 品質スコア: 9.0/10
- テスト: 346件全パス（+36件）
- 静的解析: クリーン（info警告1件のみ）
- アーキテクチャ: 完全統一（services層のみ、全DI適用）
- セキュリティ: Firebase Rules適切、画像バリデーション追加
- パフォーマンス: N+1最適化、キャッシュサイズ制限
- CI/CD: GitHub Actions設定済み

---

## 次回やること

### 機能ロードマップ
`docs/FEATURE_SPEC.md` の追加機能要望リストを参照

**Medium課題（残り）**
- ドキュメント強化
- ログ・モニタリング追加
- パフォーマンス計測

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
│   ├── injection.dart          # 8 Service登録（ImageProcessing含む）
│   └── service_locator.dart    # ServiceLocator
├── services/                   # すべてResult<T,AppError>対応
│   ├── firebase_service.dart   # N+1最適化済み
│   ├── auth_service.dart
│   ├── recommendation_service.dart
│   ├── vehicle_certificate_ocr_service.dart
│   ├── invoice_ocr_service.dart
│   ├── pdf_export_service.dart
│   ├── push_notification_service.dart
│   └── image_processing_service.dart  # Phase 4.5新規
├── providers/                  # すべてDI注入、テスト有
│   ├── vehicle_provider.dart
│   ├── maintenance_provider.dart
│   ├── auth_provider.dart
│   ├── notification_provider.dart  # エラー型統一済み
│   └── connectivity_provider.dart
├── widgets/common/
│   └── offline_banner.dart
├── screens/                    # DI経由でService取得
│   └── ...
└── ...

test/
├── providers/                  # 100+テスト
├── services/                   # 70+テスト（ImageProcessing含む）
├── screens/                    # 52テスト（Widget含む）
└── ...（合計346テスト）

integration_test/
├── app_test.dart               # 基本ログインテスト
└── e2e_full_test.dart          # フルジャーニーテスト
```

---

## 機能仕様
詳細は `docs/FEATURE_SPEC.md` を参照
