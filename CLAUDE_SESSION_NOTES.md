# Claude開発セッションメモ

## 現在の状態（2024-02-05更新）

### 完了済み
- **P0**: 車検・保険アラート、バリデーション強化、走行距離整合性チェック
- **P1**: エラーハンドリング統一（Result<T,AppError>）、テスト追加、ナンバープレート重複チェック
- **P2**: 必須項目明示、AppError対応エラースナックバー
- **Phase 3**: データ同期安定化、AuthService統一、統計・可視化画面
- **Phase 3.5**: 技術的負債解消（アーキテクチャ統一、DI適用）

### Phase 3.5 詳細
- 死んだdomain/data層を削除（lib/domain/, lib/data/）
- DI適用: main.dartでInjection.init()、全ProviderにServiceをコンストラクタ注入
- CLAUDE.mdにアーキテクチャ方針を明記（二重管理の再発防止）
- 品質スコアを9.5→7.0に下方修正（正直な評価）
- 上長向けレポート作成（docs/REPORT_AI_DEV_STATUS.md）

### 品質スコア: 7.5/10（修正済み・正直な評価）
- テスト: 214件全パス
- 静的解析: クリーン
- アーキテクチャ: 統一済み（二重管理解消）
- DI: 全Provider適用済み
- 残課題: Providerテスト欠落、UI層テスト欠落、CI/CD未整備

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
├── services/
│   ├── firebase_service.dart    # Result<T,AppError>対応済、Legacy削除済
│   └── auth_service.dart        # Result<T,AppError>対応済（Phase 3）
├── providers/
│   ├── vehicle_provider.dart    # AppError対応、再接続ロジック追加
│   ├── maintenance_provider.dart # AppError対応、再接続ロジック追加
│   └── auth_provider.dart       # AppError対応（Phase 3）
├── screens/
│   ├── home_screen.dart
│   ├── vehicle_detail_screen.dart   # 統計リンク追加
│   ├── maintenance_stats_screen.dart # 新規（Phase 3）
│   ├── vehicle_registration_screen.dart
│   └── vehicle_edit_screen.dart
├── widgets/common/loading_indicator.dart
└── core/
    ├── error/app_error.dart
    └── result/result.dart

docs/
├── FEATURE_SPEC.md          # 機能仕様書（要望リスト含む）
└── DEVELOPMENT_WORKFLOW.md  # 開発ワークフロー（Phase 3新規）

CLAUDE.md                    # AI開発ガイド（Phase 3新規）

test/
├── services/
│   ├── firebase_service_test.dart  # 27テスト
│   └── auth_service_test.dart      # 23テスト（Phase 3新規）
└── ...（合計214テスト）
```

---

## 機能仕様
詳細は `docs/FEATURE_SPEC.md` を参照
