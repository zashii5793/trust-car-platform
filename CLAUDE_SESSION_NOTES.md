# Claude開発セッションメモ

## 現在の状態（2024-02-03）

### 完了済み
- **P0**: 車検・保険アラート、バリデーション強化、走行距離整合性チェック
- **P1**: エラーハンドリング統一（Result<T,AppError>）、テスト追加、ナンバープレート重複チェック

### 品質スコア: 8.5/10
- テスト: 191件全パス
- 静的解析: クリーン

### 最新コミット
```
30ab7b3 feat: P1品質改善
a0d016d feat: P0品質改善
```

---

## 次回やること（P2）

### 7. 必須項目の明示（0.5日）
対象ファイル:
- `lib/screens/vehicle_registration_screen.dart` (行400-470付近)
- `lib/screens/vehicle_edit_screen.dart` (行430-510付近)
修正: ラベルに`*`マークを追加、またはヘルパーテキスト追加

### 8. 具体的エラーメッセージ（0.5日）
対象: `lib/widgets/common/app_button.dart` の `showErrorSnackBar`
修正: AppErrorの種類に応じたメッセージ表示

### 9. AuthServiceテスト追加（1日）
新規: `test/services/auth_service_test.dart`

---

## 効率化ルール（必ず守る）

```dart
// 1. Read: 必要な行だけ
Read(file_path: "...", offset: 400, limit: 50)

// 2. Grep: まずファイル特定
Grep(pattern: "...", output_mode: "files_with_matches")

// 3. テスト: 出力最小化
flutter test --reporter=compact 2>&1 | tail -3

// 4. 大きな分析は事前に別セッションで
```

---

## 週間スケジュール目安

| 曜日 | 作業 | 消費 |
|------|------|------|
| 月 | P2-7,8（必須項目、エラーメッセージ） | 0.5 |
| 火 | P2-9（AuthServiceテスト） | 0.5 |
| 水 | 設計・調査のみ | 0.3 |
| 木 | 新機能実装 | 1.0 |
| 金 | テスト・修正 | 0.5 |

---

## 主要ファイルパス

```
lib/
├── services/firebase_service.dart    # Result<T,AppError>対応済
├── providers/
│   ├── vehicle_provider.dart         # AppError対応済
│   └── maintenance_provider.dart     # AppError対応済
├── screens/
│   ├── home_screen.dart              # 警告バナー実装済
│   ├── vehicle_registration_screen.dart
│   └── vehicle_edit_screen.dart
└── core/
    ├── error/app_error.dart
    └── result/result.dart

test/
├── services/firebase_service_test.dart  # 27テスト
└── ...（合計191テスト）
```
