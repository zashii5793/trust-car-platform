# Trust Car Platform — 機能仕様書

> **最終更新**: 2026-02-21

---

## プロダクトビジョン

### 私たちが築きたい世界

> **キャッチコピー: 「クルマの未来を、ユーザーの手に。」**
> **キャッチフレーズ: 「クルマをもっと安全に、楽しく、個性的に。」**

このアプリは **「あなただけのカーライフ・コンシェルジュ」** だ。

日本には8,000万台の自動車がある。しかし多くのオーナーは、車検期限を忘れ、整備記録を紛失し、
パーツ選びに迷い、愛車への想いを共有する場所もない。

Trust Car Platform は、**クルマを所有するすべての人が、安心・楽しさ・個性を享受できる世界**を実現する。

### アプリの位置づけ

```
                    個人向け ←──────────────→ 法人向け
                        │                         │
  楽しさ・SNS           │   Trust Car Platform    │  BtoBマーケット
  （コミュニティ）       │   「カーライフ・        │  （整備工場・業者）
                        │    コンシェルジュ」      │
  安心・管理            │                         │
  （メンテナンス記録）   │                         │
```

**3つの価値軸:**

| 価値軸 | ターゲット感情 | 具体的な解決 |
|--------|-------------|------------|
| **安全** | 「見落とさない安心」 | 車検/保険期限アラート、整備記録管理、OCR自動入力 |
| **楽しく** | 「クルマのある生活の喜び」 | ドライブログ、SNSコミュニティ、愛車タイムライン |
| **個性的に** | 「自分だけの一台への誇り」 | AIパーツ提案、BtoBマーケット、カスタム履歴 |

### 競合との差別化

- **単なる整備記録アプリではない** → SNS・コミュニティで「体験」を共有できる
- **単なるSNSではない** → 実用的な車両管理機能が土台にある
- **単なるパーツECではない** → 自分の車両データに基づくAI提案で「当たり前の互換確認」が不要

---

## 設計思想（最重要 — 全機能がこれに従う）

### 「主役は常にユーザー」

> **AIは「判断」しない。理由を添えて選択肢を整理するだけ。**

これは UI/UX・機能実装の根幹となる原則。

| 原則 | 意味 | 実装への影響 |
|------|------|------------|
| **AIは提案する、決めない** | 「これがベスト！」と断言しない。理由付きで複数の選択肢を並べ、ユーザーが選ぶ | PartRecommendationServiceは常に複数候補＋理由を返す |
| **事業者は売り込まない** | BtoBの整備工場・業者はユーザーから興味アクションがあって初めて接触 | 広告的な押し付け表示をしない。ユーザー主導のフロー設計 |
| **情報はフラットに** | ランキングや「イチオシ」ラベルで誘導しない。ユーザーが比較できる形で提供 | パーツ・業者一覧はフィルタ・ソート自由、プロモーション枠も透明に表示 |

```dart
// ❌ NG: AIが断言する
"このパーツがあなたの車に最適です！今すぐ購入"

// ✅ OK: 理由付きで選択肢を整理する
"走行距離と車種から、以下の3つが候補です。
 ・[A] 純正品 — 安心だが価格高め
 ・[B] 社外品X — コスパ良し、口コミ評価高
 ・[C] 社外品Y — 最安値、互換性は要確認"
```

---

## ユーザーセグメント

| セグメント | 特徴 | 主な利用機能 |
|-----------|------|------------|
| **一般カーオーナー** | 車検管理・整備記録を手軽に | アラート、記録管理、OCR |
| **クルマ好き（カーマニア）** | 愛車を自慢・カスタムを楽しむ | SNS、ドライブログ、パーツ提案 |
| **整備工場・業者（BtoB）** | ユーザーへの集客・パーツ販売 | マーケット掲載、問い合わせ管理 |

---

## 機能一覧

### ✅ 実装済み

#### 1. 認証
- メール/パスワード登録・ログイン・パスワードリセット
- Google認証（OAuth）

#### 2. 車両管理
- 車両CRUD（登録・表示・編集・削除）
- 基本情報: メーカー、車種、年式、グレード、走行距離
- 識別情報: ナンバープレート、車台番号、型式
- 車検・保険情報: 車検満了日、自賠責保険期限
- 詳細情報: 車体色、排気量、燃料タイプ、購入日、任意保険
- 駆動方式（DriveType）、トランスミッション（TransmissionType）
- 走行距離整合性チェック（減少禁止）
- ナンバープレート重複チェック
- 関連整備記録のカスケード削除
- 車両写真アップロード（Firebase Storage）

#### 3. 整備記録管理
- 整備記録CRUD
- 22種類のメンテナンスタイプ対応
- 費用・実施工場・走行距離・部品情報・メモ記録
- 作業項目（WorkItem）・部品情報（Part）詳細記録
- タイプ別フィルタリング
- メンテナンス統計・可視化（年間コスト推移、月別、タイプ別、店舗別）

#### 4. OCR自動入力
- 車検証OCR（ML Kit Text Recognition）
- 請求書/領収書OCR

#### 5. アラート・通知
- 車検期限アラート（期限切れ/30日以内/7日以内で色分け）
- 自賠責保険期限アラート
- メンテナンス推奨通知

#### 6. PDF出力
- 整備記録のPDFエクスポート

#### 7. 書類・請求書管理（Phase 5）
- Invoice / Document / ServiceMenu モデル・Service・Provider

#### 8. インフラ・品質基盤
- オフラインサポート（Firestore永続化 100MB）
- Firebase Crashlytics / Performance
- LoggingService
- CI/CD（GitHub Actions）

#### 9. SNS・BtoB・AI 基盤（モデル・Service層のみ、UI未実装）
- Post/Comment/Follow、Shop/Inquiry/PartListing、PartRecommendationService

---

### 🔲 未実装（優先度順）

#### P0: 車両マスタ（表記ゆれ解消）

**問題**: メーカー/車種/グレードがテキスト自由入力 → 表記ゆれ発生

**設計方針（運用フロー）**:
```
新車発表
  → CSV（vehicle_masters.csv）を更新
  → scripts/import_vehicle_master.dart を実行
  → Firestoreに投入
  → アプリに即時反映
```

**Firestoreコレクション設計**:
```
vehicle_makers/{makerId}
  - name: "トヨタ"
  - nameEn: "Toyota"
  - displayOrder: 1

vehicle_models/{modelId}
  - makerId: "toyota"
  - name: "プリウス"
  - bodyType: "セダン"          # セダン/SUV/軽/ミニバン/スポーツ/トラック
  - productionStartYear: 1997
  - productionEndYear: null     # 現行モデルはnull

vehicle_grades/{gradeId}
  - modelId: "prius"
  - name: "Z"
  - fuelType: "hybrid"          # gasoline/hybrid/ev/diesel/phev
  - driveType: "fwd"            # fwd/rwd/awd/4wd
  - startYear: 2023
  - endYear: null               # 現行グレードはnull
```

**実装ファイル**:
```
models/vehicle_master.dart           # VehicleMaker / VehicleModel / VehicleGrade
services/vehicle_master_service.dart # Firestore CRUD（injection.dart登録済み）
scripts/import_vehicle_master.dart   # CSV→Firestore投入スクリプト（新規作成）
data/vehicle_masters.csv            # 初期マスタデータ（新規作成）
screens/ 車両登録・編集画面          # ドロップダウン選択式に改修
```

---

#### P0: 「愛車タイムライン」UI
**企画書で明示されているUI**。現在は「整備記録一覧（日付降順リスト）」止まり。

整備記録を時系列タイムライン形式で表示し、「この車と歩んだ歴史」を視覚的に体験できるUI。

---

#### P0: ホーム画面「AIからの提案」セクション
**企画書のモックアップに明示**。

```
ホーム画面の構成:
  ├── マイカー情報カード（車検残日数、走行距離）
  ├── 【AIからの提案】セクション  ← 未実装
  │    ├── メンテナンス提案（理由付きで複数提示）
  │    └── （将来）天気連動ドライブスポット提案
  └── 最近の整備記録
```

**設計思想に従い**: 「○○が必要です！」ではなく「○○km走りました。以下の整備が候補です（理由）」という表示。

---

#### P1: BtoBマーケット画面
**収益モデルの根幹**。モデル・Service層は実装済み。

**収益モデル（企画書より）**:
- **加盟料**: 整備工場・販売店からのプラットフォーム利用料
- **広告・送客費**: カスタムパーツメーカーからの広告掲載料、ユーザー送客に応じた成果報酬

**UI設計原則（「売り込まない」原則）**:
- ユーザーが「この工場に興味あり」をタップして初めて接触
- 業者からのプッシュ型アプローチは不可
- 広告枠は「広告」と明示する

```
screens/marketplace/
  shop_list_screen.dart     # 工場・業者一覧（フィルタ・ソート自由）
  shop_detail_screen.dart   # 詳細・問い合わせ（ユーザー主導）
  part_list_screen.dart     # パーツ一覧（車種フィルタ付き）
  inquiry_screen.dart       # 問い合わせ送信
```

---

#### P1: AIパーツ提案ロジック実装

**設計思想に従い**:
- 車種×走行距離×整備履歴からパーツ候補を複数スコアリング
- 各候補に「推奨理由」「注意点」を必ずセットで表示
- 「ベスト1」を押し付けない。ユーザーが比較して選ぶ形式

```dart
// PartRecommendation モデルのあるべき姿
class PartRecommendation {
  final String partName;
  final List<String> reasons;    // 推奨理由（複数）
  final List<String> cautions;   // 注意点・デメリット
  final int confidenceScore;     // 信頼度（0-100）
  // ❌ "isBest" や "isRecommended" フラグは持たない
}
```

---

#### P2: SNSフィード画面
- 投稿一覧（フィード）、投稿作成（写真付き）、コメント・いいね
- 同じ車種オーナーとのつながり

#### P2: 車両購入レコメンド
- 予算・条件・ライフスタイルから中古車を提案（外部API連携）

#### P3: ドライブログ × マップUI
- 走行ルート記録・訪問スポット・ドライブ履歴タイムライン
- **マップUI方針**: Google Maps標準ではなく、企画書に描かれた独自スタイルのビジュアルマップを目指す
  - 理由: Google Maps標準だと「それでいい」で終わりがち。アプリの世界観・個性が死ぬ
  - 実装検討: flutter_map + カスタムスタイルタイル or Canvas描画によるオリジナルマップ
  - ※ 実装コストが高いため P3 で詳細設計する

#### 将来展望（企画書記載）
- OBD-II連携（リアルタイム車両診断）
- EV専用管理（充電履歴、航続距離管理）
- 保険・ローン連携
- 天気API連動ドライブスポット提案

---

## 技術仕様

### アーキテクチャ

```
main.dart → Injection.init() → ServiceLocator
                                      ↓
Provider（コンストラクタ注入） ← Service（Result<T,AppError>）
      ↓                                    ↓
  UI層（screens/）                  Firebase SDK
```

**重要な原則**:
- Service層が正: `lib/services/` にFirebase操作を集約。domain/data層は存在しない
- DIはServiceLocator: Provider内で`new`せず、コンストラクタ注入
- 新Serviceの追加: `injection.dart`登録 → Provider引数追加 → main.dartのMultiProviderに追加

### エラーハンドリング
- `Result<T, AppError>`: 全Service層で統一
- AppError種類: NetworkError / AuthError / ValidationError / NotFoundError / PermissionError / ServerError / CacheError / UnknownError
- UI表示: AppError → Snackbar で統一

### バリデーション規約
- 走行距離: 0〜200万km
- 年式: 1900〜来年
- 走行距離整合性: 編集時に減少禁止
- ナンバープレート: 重複禁止

### テストカバレッジ（2026-02-21時点）

| 層 | 件数 | 状態 |
|---|---|---|
| core/（Result, AppError等） | 67件 | ✅ |
| models/ | 48件 | ✅ |
| services/ | 96件 | ✅ |
| providers/ + screens/ | 96件 | ✅ |
| **合計** | **434件** | **全パス** |

### 技術スタック

| カテゴリ | 技術 |
|---------|------|
| フロントエンド | Flutter 3 / Dart |
| バックエンド | Firebase（Auth, Firestore, Storage, Messaging, Crashlytics, Performance） |
| 状態管理 | Provider（コンストラクタ注入） |
| OCR | Google ML Kit Text Recognition |
| DI | 独自ServiceLocator（get_it不使用） |
| PDF出力 | pdf / printing |
| 通知 | firebase_messaging + flutter_local_notifications |

---

## ロードマップ

| フェーズ | 時期 | 内容 |
|---------|------|------|
| Phase 1〜5 ✅ | 〜2026/02 | コア機能・アーキテクチャ・品質基盤 |
| **Phase 6 ← 今ここ** | **2026/Q1** | **車両マスタ(P0)・愛車タイムライン・ホームAI提案セクション** |
| Phase 7 | 2026/Q2 | BtoBマーケット画面・AIパーツ提案ロジック・SNSフィード |
| Phase 8 | 2026/Q3 | プレミアムプラン決済・整備工場パートナー開拓 |
| Phase 9+ | 2027〜 | BtoBマーケット本格展開・OBD-II連携・海外展開検討 |
