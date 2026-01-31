# Trust Car Platform - 機能追加ロードマップ

## 更新日: 2025年1月31日

---

## 📋 機能要望一覧

### A. OCR/AI連携機能
1. **車検証OCR** - 車検証から車両情報を自動登録
2. **請求書OCR** - 請求書から整備記録を自動登録
3. **整備記録簿OCR** - 整備記録簿から履歴を一括登録

### B. SNS機能
4. **ドライブマップ** - Google Mapと連動した2Dゲームライク地図
5. **匿名コミュニケーション** - 同車種オーナー間のライトなコミュニケーション

---

## 🔍 6エキスパート分析サマリー

### 加重スコアリング結果

| 機能 | 業界 | UX | 技術 | セキュリティ | テスト | PO | **総合** |
|------|-----|-----|-----|-------------|-------|-----|---------|
| 車検証OCR | 5 | 5 | 5 | 4 | 5 | 5 | **29** |
| 請求書OCR | 5 | 4 | 3 | 4 | 3 | 4 | **23** |
| 整備記録簿OCR | 4 | 3 | 3 | 4 | 4 | 3 | **21** |
| 匿名コミュニケーション | 5 | 4 | 2 | 2 | 2 | 4 | **19** |
| ドライブマップ | 4 | 3 | 1 | 1 | 1 | 3 | **13** |

### 最終優先順位

| 優先度 | 機能 | 工数 | 理由 |
|-------|------|------|------|
| 🥇 1位 | 車検証OCR | 2週間 | 全エキスパートが高評価、ROI最高 |
| 🥈 2位 | 請求書OCR | 3週間 | コア機能強化、ユーザー価値高 |
| 🥉 3位 | 整備記録簿OCR | 3週間 | 技術共通化可能、テストしやすい |
| 4位 | 匿名コミュニケーション | 6週間 | エンゲージメント向上だが設計複雑 |
| 5位 | ドライブマップ | 8週間 | 魅力的だが開発規模・リスク大 |

---

## 🗓️ 実装ロードマップ

### Phase 2.0 - OCR機能 (8週間)

#### Week 1-2: 車検証OCR
- [ ] Cloud Vision API/ML Kit設定
- [ ] 車検証パーサー実装（型式、車台番号、有効期限等）
- [ ] カメラ撮影UI実装（ガイド枠付き）
- [ ] OCR結果確認・編集UI
- [ ] プライバシー保護（画像即削除）
- [ ] テスト（50サンプル、精度95%以上）

**技術スタック:**
- Google Cloud Vision API または Firebase ML Kit
- image_picker パッケージ
- camera パッケージ（高精度撮影用）

#### Week 3-5: 請求書OCR
- [ ] Gemini AI連携設定
- [ ] 金額・日付・作業内容抽出ロジック
- [ ] 多様なフォーマット対応（整備工場別）
- [ ] 確認・編集UI（抽出結果プレビュー）
- [ ] 整備記録への自動マッピング
- [ ] テスト（整備工場10社分フォーマット）

**技術スタック:**
- Gemini AI API（構造化データ抽出）
- Cloud Vision API（OCR）
- Firebase Functions（AI処理）

#### Week 6-8: 整備記録簿OCR
- [ ] 法定点検記録簿フォーマット解析
- [ ] チェックマーク認識
- [ ] 一括登録機能
- [ ] 点検項目マッピング
- [ ] テスト（点検記録パターン網羅）

---

### Phase 3.0 - SNS機能基盤 (6週間)

#### Week 1-2: 匿名ID基盤
- [ ] 匿名ID生成システム（UID + 車種からハッシュ生成）
- [ ] プライバシー設定UI
- [ ] Firestoreセキュリティルール更新
- [ ] 匿名プロフィール機能

**データモデル:**
```dart
class AnonymousProfile {
  final String anonymousId;      // 例: "Aqua_a8f2"
  final String vehicleCategory;  // 車種カテゴリのみ公開
  final DateTime joinedAt;
  final int postCount;
  final int helpfulCount;
}
```

#### Week 3-4: コミュニケーション機能
- [ ] 車種別トピック/チャンネル
- [ ] 投稿・リプライ機能
- [ ] リアクション（いいね、参考になった）
- [ ] 通報・ブロック機能
- [ ] プッシュ通知

**データモデル:**
```dart
class Topic {
  final String id;
  final String title;
  final String category;        // "オイル交換", "カスタム", "ドライブ" 等
  final List<String> vehicleModels;  // 対象車種
  final int postCount;
}

class Post {
  final String id;
  final String topicId;
  final String anonymousId;
  final String content;
  final List<String> imageUrls;
  final int likeCount;
  final int helpfulCount;
  final DateTime createdAt;
}
```

#### Week 5-6: モデレーション
- [ ] 禁止ワードフィルタ（日本語対応）
- [ ] AI自動モデレーション（Gemini AI）
- [ ] 管理者ダッシュボード
- [ ] 段階的ペナルティシステム

---

### Phase 4.0 - ドライブマップ (8週間)

#### Week 1-3: 位置追跡基盤
- [ ] バックグラウンド位置取得（低電力モード）
- [ ] プライバシー保護
  - [ ] 自宅周辺500m除外
  - [ ] 位置精度意図的低下
  - [ ] データ保持期間設定
- [ ] GeoHash保存（効率的なクエリ用）
- [ ] 走行セッション管理

**データモデル:**
```dart
class DriveSession {
  final String id;
  final String odriverId visuel;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceKm;
  final List<GeoPoint> routePoints;  // 間引き済み
  final List<String> visitedPrefectures;
}
```

#### Week 4-6: 2Dマップレンダリング
- [ ] ゲームライクUIデザイン
- [ ] 走行ルート描画（カスタムレンダリング）
- [ ] お気に入りスポット表示
- [ ] 訪問店舗・施設マーカー
- [ ] 統計表示（総走行距離、訪問都道府県数）

#### Week 7-8: ゲーミフィケーション
- [ ] 実績バッジシステム
  - [ ] 全国制覇
  - [ ] 峠マスター
  - [ ] 海岸線ドライバー
  - [ ] 深夜の走り屋（冗談）
- [ ] 都道府県コレクション
- [ ] SNSシェア機能（マップ画像生成）

---

## 🔒 セキュリティ要件

### 共通要件
- 全画像はCloud Functions経由で処理後即削除
- 個人情報（住所、氏名）は端末内のみで表示、サーバー非保存
- 車台番号はハッシュ化保存

### 位置情報
```dart
class LocationPrivacyGuard {
  static const double HOME_EXCLUSION_RADIUS = 500; // meters

  static LatLng obfuscateLocation(LatLng precise) {
    // ±50m程度のランダムオフセット
    final random = Random();
    final offsetLat = (random.nextDouble() - 0.5) * 0.001;
    final offsetLng = (random.nextDouble() - 0.5) * 0.001;
    return LatLng(precise.latitude + offsetLat, precise.longitude + offsetLng);
  }

  static bool isNearHome(LatLng location, LatLng homeLocation) {
    return Geolocator.distanceBetween(
      location.latitude, location.longitude,
      homeLocation.latitude, homeLocation.longitude
    ) < HOME_EXCLUSION_RADIUS;
  }
}
```

### 匿名ID
```dart
class AnonymousIdentity {
  static String generateAnonymousId(String uid, String vehicleModel) {
    final salt = 'trust_car_2025_salt';
    final hash = sha256.convert(utf8.encode('$uid:$vehicleModel:$salt'));
    final prefix = vehicleModel.split(' ').first;
    return '${prefix}_${hash.toString().substring(0, 4)}';
  }
}
```

---

## 📊 KPI目標

### Phase 2.0
- 車検証OCR: 車両登録完了率 +40%
- 請求書OCR: 整備記録登録数/月 +60%
- OCR精度: 95%以上

### Phase 3.0
- DAU: +100%
- 平均滞在時間: +50%
- 投稿数/日: 100件以上

### Phase 4.0
- ドライブマップ利用率: 30%以上
- SNSシェア: 月間1000件
- アプリ評価: 4.5以上

---

## 📝 備考

- 各Phaseは前Phaseのテストが全てパスしてから開始
- 週次でテスト実行、品質基準クリアを確認
- セキュリティレビューは各Phase完了時に実施
