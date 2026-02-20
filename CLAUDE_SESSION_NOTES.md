# Claude開発セッションメモ

> **最終更新**: 2026-02-21

---

## プロダクトビジョン（最重要）

> **キャッチコピー: 「クルマの未来を、ユーザーの手に。」**
> **キャッチフレーズ: 「クルマをもっと安全に、楽しく、個性的に。」**

アプリ定義: **「あなただけのカーライフ・コンシェルジュ」**

コンセプト3本柱: **安全 / 楽しく / 個性的に**

### 設計思想「主役は常にユーザー」（全実装がこれに従う）

| 原則 | 実装への影響 |
|------|------------|
| AIは提案する、決めない | PartRecommendationは必ず複数候補＋理由を返す。「ベスト1」断言NG |
| 事業者は売り込まない | BtoBはユーザー主導のフロー。プッシュ型表示NG |
| 情報はフラットに | ランキング・イチオシラベルで誘導しない |

---

## 現在の状態（Phase 6開始）

### 完了済み（Phase 1〜5）
- 認証（メール + Google）
- 車両管理 CRUD・バリデーション
- 整備記録 22タイプ・統計可視化
- OCR（車検証・請求書）
- アラート（車検/自賠責/メンテ推奨）
- PDF出力
- 書類管理（Invoice/Document/ServiceMenu）モデル・Service・Provider
- SNS基盤（Post/Comment/Follow）モデル・Service — UI未実装
- BtoBマーケット基盤（Shop/Inquiry/PartListing）モデル・Service — UI未実装
- AI推奨基盤（PartRecommendationService）— UI未実装
- 品質基盤（Crashlytics・Performance・LoggingService）
- CI/CD（GitHub Actions）
- テスト 434件全パス・静的解析クリーン

### 今セッションの作業
- ✅ 企画書HTML（docs/pitch_deck.html）作成・コミット
- ✅ FEATURE_SPEC.md 全面見直し（ビジョン・設計思想・企画書反映）
- ✅ CLAUDE_SESSION_NOTES.md 更新
- ⬜ P0: 車両マスタ実装（CSV投入スクリプト＋モデル＋UI改修）

### 企画書（新規事業_企画書.pdf）との主要差分（反映済み）
- キャッチコピー: 「クルマの未来を、ユーザーの手に。」「自由を、あなたのガレージへ。」
- 設計思想「主役は常にユーザー」「AIは判断しない」を明文化
- 「愛車タイムライン」UI を P0 に追加
- ホーム画面「AIからの提案」セクションを P0 に追加
- BtoBの収益モデルを「加盟料＋広告・送客費」に修正
- 将来展望（OBD-II連携・EV管理・保険ローン連携）を追記

---

## 次回やること（優先順）

### P0-a: 車両マスタ（最優先）
```
実装ファイル:
  models/vehicle_master.dart           # VehicleMaker / VehicleModel / VehicleGrade
  services/vehicle_master_service.dart # injection.dart登録済み（中身確認要）
  scripts/import_vehicle_master.dart   # CSV→Firestore投入スクリプト（新規）
  data/vehicle_masters.csv            # 国産主要メーカー初期データ（新規）
  screens/vehicle_registration_screen.dart  # ドロップダウン選択式に改修
  screens/vehicle_edit_screen.dart          # 同上

運用フロー:
  新車発表 → CSVに追記 → スクリプト実行 → Firestore即時反映
```

### P0-b: 愛車タイムライン UI（P0-aと同タイミング）
```
整備記録の時系列タイムライン表示
screens/vehicle_detail_screen.dart を改修
or 新規 screens/vehicle_timeline_screen.dart
```

### P0-c: ホーム画面「AIからの提案」セクション
```
設計思想に従い: 複数候補＋理由の表示。「ベスト1」断言NG
screens/home_screen.dart に追加
```

### P1: BtoBマーケット画面（次フェーズ）
### P1: AIパーツ提案ロジック（次フェーズ）

---

## 設計上の注意点

### アーキテクチャ
- `domain/data` 層は存在しない（過去削除済み）→ 再作成厳禁
- Providerは必ずServiceLocator経由でコンストラクタ注入
- 新Service追加: injection.dart → Provider → main.dartのMultiProvider

### PartRecommendation の設計原則
```dart
// ❌ NG
class PartRecommendation {
  final bool isBest;  // これは持たない
}

// ✅ OK
class PartRecommendation {
  final String partName;
  final List<String> reasons;   // 推奨理由（複数）
  final List<String> cautions;  // 注意点・デメリット
  final int confidenceScore;    // 0-100
}
```

### 車両マスタの運用設計
- Firestoreに `vehicle_makers` / `vehicle_models` / `vehicle_grades` コレクション
- グレードは年式（startYear/endYear）で管理（モデルチェンジ対応）
- 管理者がCSVを投入する運用フロー（管理者画面は将来）

---

## 主要ファイルパス

```
lib/
├── core/di/injection.dart           # Service全登録
├── services/vehicle_master_service.dart  # P0: 中身確認要
├── providers/                       # 全Providerがコンストラクタ注入
└── models/vehicle_master.dart       # P0: 要確認（存在するか？）

docs/
├── FEATURE_SPEC.md     # 機能仕様書（ビジョン・設計思想含む）★最重要
├── pitch_deck.html     # 企画書HTMLピッチデッキ
└── DEVELOPMENT_WORKFLOW.md

scripts/
└── import_vehicle_master.dart  # P0で作成予定

data/
└── vehicle_masters.csv        # P0で作成予定
```
