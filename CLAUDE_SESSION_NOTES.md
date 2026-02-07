# Claude開発セッションメモ

## 現在の状態（2024-02-07更新）

### 完了済み
- **P0**: 車検・保険アラート、バリデーション強化、走行距離整合性チェック
- **P1**: エラーハンドリング統一（Result<T,AppError>）、テスト追加、ナンバープレート重複チェック
- **P2**: 必須項目明示、AppError対応エラースナックバー
- **Phase 3**: データ同期安定化、AuthService統一、統計・可視化画面
- **Phase 3.5**: 技術的負債解消（アーキテクチャ統一、全ProviderにDI適用）
- **Phase 3.6**: DI完全化、Providerテスト追加

### Phase 3.6 詳細
- 6 ServiceをすべてDIに登録（OCR, PDF含む）
- Screen層の直接new排除（FirebaseService, OcrService, PdfService）
- NotificationProviderのFirestore直接アクセス廃止
- Providerテスト追加（3ファイル、79テスト）
- ドキュメント整合性修正（品質スコア、Phase状態）

### 品質スコア: 8.0/10
- テスト: 293件全パス（Providerテスト79件追加）
- 静的解析: クリーン
- アーキテクチャ: 完全統一（services層のみ、全DI適用）
- 残課題: UI層テスト欠落、CI/CD未整備

---

## 次回やること

### 機能ロードマップ
`docs/FEATURE_SPEC.md` の追加機能要望リストを参照

**Phase 4（実用性向上）**
- A1: オフラインサポート
- A2: プッシュ通知（FCM）
- C2/C3: E2Eテスト・CI/CD

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
│   ├── injection.dart          # 6 Service登録（OCR, PDF含む）
│   └── service_locator.dart    # ServiceLocator
├── services/                   # すべてResult<T,AppError>対応
│   ├── firebase_service.dart
│   ├── auth_service.dart
│   ├── recommendation_service.dart
│   ├── vehicle_certificate_ocr_service.dart
│   ├── invoice_ocr_service.dart
│   └── pdf_export_service.dart
├── providers/                  # すべてDI注入、テスト有
│   ├── vehicle_provider.dart
│   ├── maintenance_provider.dart
│   ├── auth_provider.dart
│   └── notification_provider.dart
├── screens/                    # DI経由でService取得
│   └── ...
└── ...

test/
├── providers/                  # 79テスト（Phase 3.6新規）
│   ├── auth_provider_test.dart
│   ├── vehicle_provider_test.dart
│   ├── maintenance_provider_test.dart
│   └── notification_provider_test.dart
├── services/                   # 50テスト
└── ...（合計293テスト）
```

---

## 機能仕様
詳細は `docs/FEATURE_SPEC.md` を参照
