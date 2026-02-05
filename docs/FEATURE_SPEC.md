# Trust Car Platform - 機能仕様書

## 概要
Flutter製の車両管理アプリケーション。Firebase（Auth, Firestore, Storage）をバックエンドとして使用。

---

## コア機能

### 1. 車両管理

#### 1.1 車両登録
- **基本情報**: メーカー、車種、年式、グレード、走行距離（すべて必須）
- **識別情報**: ナンバープレート、車台番号、型式（任意）
- **車検・保険**: 車検満了日、自賠責保険期限（任意だが推奨）
- **詳細情報**: 車体色、排気量、燃料タイプ、購入日（任意）
- **画像**: 車両写真（任意）

#### 1.2 車検証OCRスキャン
- カメラで車検証を撮影
- ML Kit Text Recognitionで文字認識
- 以下のフィールドを自動抽出:
  - 車台番号、型式、車名
  - 初度登録年月、車検満了日
  - 所有者情報（住所・氏名）
- 信頼度スコア表示
- 確認後フォームに自動入力

#### 1.3 車両編集
- 全フィールドの編集可能
- 走行距離は減少不可（整合性チェック）
- 変更検知（未保存警告）
- ナンバープレート重複チェック

#### 1.4 車両削除
- 確認ダイアログ表示
- 関連する整備記録も削除

---

### 2. 整備記録管理

#### 2.1 整備記録登録
- **メンテナンスタイプ**: 22種類
  - 定期点検系: オイル交換、フィルター交換、タイヤ交換など
  - 法定系: 12ヶ月点検、車検
  - 消耗品系: ブレーキパッド、バッテリー、ワイパーなど
  - その他: 洗車、事故修理、カスタムなど
- **必須**: タイトル、実施日、費用
- **任意**: 実施工場、走行距離、部品情報、メモ

#### 2.2 請求書OCRスキャン
- カメラで請求書/領収書を撮影
- 以下を自動抽出:
  - 日付、金額、店舗名
  - 作業項目
- メンテナンスタイプ自動推定
- 確認後フォームに自動入力

#### 2.3 整備記録一覧
- 日付降順表示
- タイプ別フィルタリング可能

#### 2.4 メンテナンス統計・可視化
- **サマリー**: 総費用、履歴数、平均費用/回、種類数
- **年間コスト推移**: 横棒グラフで年別比較
- **月別コスト推移**: 直近12ヶ月の月別集計
- **タイプ別内訳**: コスト・回数・割合を表示
- **店舗別集計**: 利用店舗ごとの費用集計

---

### 3. アラート・通知

#### 3.1 車検・保険期限アラート
- ホーム画面の車両カードに警告バナー表示
- **車検**:
  - 期限切れ: 赤色「車検切れ」
  - 30日以内: オレンジ「車検 残りX日」
  - 7日以内: 赤色
- **自賠責保険**:
  - 期限切れ: 赤色「自賠責切れ」
  - 30日以内: オレンジ「保険 残りX日」

#### 3.2 レコメンド通知
- 整備履歴から次回推奨時期を計算
- オイル交換: 前回から5,000km or 6ヶ月
- タイヤ交換: 前回から40,000km or 4年
- その他各種メンテナンス

---

### 4. 認証

#### 4.1 メール認証
- 新規登録（メール + パスワード）
- ログイン
- パスワードリセット

#### 4.2 Google認証
- Googleアカウントでログイン

---

## 技術仕様

### アーキテクチャ
```
lib/
├── core/
│   ├── error/app_error.dart    # エラー型定義
│   └── result/result.dart       # Result<T,E>型
├── models/
│   ├── vehicle.dart             # 車両モデル
│   ├── maintenance_record.dart  # 整備記録モデル
│   └── app_notification.dart    # 通知モデル
├── services/
│   ├── firebase_service.dart    # Firebase操作（Result対応）
│   ├── auth_service.dart        # 認証
│   ├── recommendation_service.dart
│   ├── vehicle_certificate_ocr_service.dart
│   └── invoice_ocr_service.dart
├── providers/
│   ├── vehicle_provider.dart    # AppError対応
│   ├── maintenance_provider.dart
│   └── notification_provider.dart
└── screens/
    ├── home_screen.dart         # 警告バナー付き
    ├── vehicle_registration_screen.dart
    ├── vehicle_edit_screen.dart
    ├── add_maintenance_screen.dart
    └── ...
```

### エラーハンドリング
- **Result<T, AppError>**: すべてのService層で統一
- **AppError種類**:
  - NetworkError（リトライ可）
  - AuthError
  - ValidationError
  - NotFoundError
  - PermissionError
  - ServerError（リトライ可）
  - CacheError（リトライ可）
  - UnknownError

### バリデーション
- 走行距離: 0〜200万km
- 年式: 1900〜来年
- 走行距離整合性: 減少禁止（編集時）
- ナンバープレート: 重複禁止

---

## テスト

### カバレッジ
- 合計: 214テスト
- モデル: 48テスト
- Result/AppError: 67テスト
- OCRサービス: 46テスト
- Firebaseパターン: 27テスト
- AuthService: 23テスト（新規）

---

## 品質スコア: 9.5/10

### 完了した改善
- [x] P0: 車検・保険アラート、バリデーション強化
- [x] P1: エラーハンドリング統一、テスト追加
- [x] P2: 必須項目明示、エラーメッセージ改善
- [x] Phase 3: データ同期安定化、AuthService統一、統計画面

### Phase 3で実施した改善
- [x] Legacyメソッド削除（firebase_service.dart）
- [x] Streamリスナーにエラーリカバリー（指数バックオフ再接続）
- [x] AuthServiceをResult<T,AppError>パターンに統一
- [x] 車両削除時のカスケード削除（整備記録連動）
- [x] AuthServiceテスト追加（23件）
- [x] メンテナンス統計・可視化画面

### 今後の改善候補
- [ ] オフラインサポート
- [ ] OCRエッジケーステスト強化
- [ ] E2Eテスト整備
- [ ] CI/CD構築

---

## 追加機能要望リスト（未実装）

### 1. BtoBカスタムパーツマーケットプレイス（優先度: 高）

**概要**: 企業がユーザーの車両に合ったカスタムパーツを提案・広告できるプラットフォーム

#### 企業側機能
- **企業アカウント登録**
  - 会社情報（名前、住所、連絡先、業種）
  - 取扱パーツカテゴリ
  - 対応車種リスト
- **パーツ/サービス登録**
  - パーツ名、説明、価格帯
  - 対応車種（メーカー/車種/年式）
  - 画像、取り付け事例
- **広告配信**
  - ターゲット車種指定
  - 表示期間設定
  - 広告費用（課金モデル要検討）

#### ユーザー側機能
- **レコメンド表示**
  - ホーム画面に自分の車に合ったパーツ提案
  - 車両詳細画面にマッチするパーツ一覧
- **問い合わせ機能**
  - アプリ内メッセージ
  - 電話/メール連携
  - 見積もり依頼
- **お気に入り保存**

#### データモデル（案）
```dart
// 企業モデル
class Company {
  String id;
  String name;
  String address;
  String phone;
  String email;
  List<String> categories;  // エアロ、マフラー、ホイール等
  List<VehicleSpec> supportedVehicles;
  bool isVerified;  // 認証済み企業
}

// パーツ/サービスモデル
class PartListing {
  String id;
  String companyId;
  String name;
  String description;
  int? priceFrom;
  int? priceTo;
  List<String> imageUrls;
  List<VehicleSpec> compatibleVehicles;
  String category;
  bool isActive;
}

// 問い合わせモデル
class Inquiry {
  String id;
  String userId;
  String companyId;
  String? partListingId;
  String vehicleId;
  String message;
  InquiryStatus status;  // pending, replied, closed
  DateTime createdAt;
}
```

#### 実装優先順位
1. 企業アカウント・パーツ登録（管理画面）
2. ユーザー向けパーツ一覧・詳細表示
3. 問い合わせ機能
4. レコメンドアルゴリズム
5. 課金・広告システム

---

### 2. （次の要望をここに）

### 3. （次の要望をここに）
