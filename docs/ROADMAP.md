# 開発ロードマップ

小さく始め、データと共に賢く育てる開発戦略

---

## Phase 1: MVP（Minimum Viable Product）
**期間**: 3-4ヶ月（2026年1月〜4月）  
**目標**: コアとなる履歴データ基盤を構築し、ユーザーからのフィードバックを得る

### 主な機能

#### ✅ 実装済み
- 車両登録（基本情報、画像）
- メンテナンス履歴管理
  - 修理（内容・金額・実施工場）
  - 点検（法定/任意）
  - 消耗品交換（タイヤ・オイル・バッテリー等）
  - 車検
- 履歴の一元管理（時系列表示）
- 証跡のデジタル保存（点検記録簿、請求書、見積書などを写真やPDFでアップロード・保管）

#### 🔄 実装中・予定
1. **ユーザー認証機能**（Week 1-2）
   - メール/パスワード認証
   - Google/Apple認証（ソーシャルログイン）
   - パスワードリセット機能

2. **ルールベースAI提案**（Week 3-6）
   - 点検時期の自動通知
     - 前回の点検日から一定期間経過
     - 走行距離ベースの通知
   - 消耗品交換の推奨
     - タイヤ交換時期（走行距離・経過年数）
     - オイル交換（走行距離ベース）
     - バッテリー交換（経過年数ベース）
   - 車検期日のリマインダー

3. **プッシュ通知機能**（Week 7-8）
   - 重要な通知の配信
   - ユーザー設定による通知ON/OFF

4. **基本プロフィール機能**（Week 9-10）
   - ユーザー情報管理
   - 複数車両の登録・切り替え
   - 設定画面

5. **データエクスポート機能**（Week 11-12）
   - 履歴データのPDF出力
   - 車両売却時のレポート生成

### 技術実装

#### データベース設計
```
users/
  {userId}/
    - email
    - displayName
    - photoURL
    - createdAt
    - updatedAt
    
vehicles/
  {vehicleId}/
    - userId
    - maker
    - model
    - year
    - grade
    - mileage
    - imageUrl
    - createdAt
    - updatedAt

maintenance_records/
  {recordId}/
    - vehicleId
    - userId
    - type (repair/inspection/parts/carInspection)
    - title
    - description
    - cost
    - shopName
    - date
    - mileageAtService
    - imageUrls[]
    - createdAt

notifications/
  {notificationId}/
    - userId
    - vehicleId
    - type
    - title
    - message
    - isRead
    - createdAt
```

#### AI提案ロジック（ルールベース）
```dart
// 点検時期チェック
if (lastInspectionDate + 6months < today) {
  createNotification("6ヶ月点検の時期です");
}

// オイル交換チェック
if (currentMileage - lastOilChangeMileage > 5000km) {
  createNotification("オイル交換をおすすめします");
}

// タイヤ交換チェック
if (lastTireChangedDate + 4years < today) {
  createNotification("タイヤの点検をおすすめします");
}

// 車検リマインダー
if (carInspectionDate - today < 2months) {
  createNotification("車検が近づいています");
}
```

### KPI目標

| 指標 | 目標値 |
|------|--------|
| ユーザー登録数 | 500人 |
| MAU | 200人 |
| 履歴データ登録数 | 平均5件/ユーザー |
| 3ヶ月継続率 | 40% |
| アプリストア評価 | 4.0以上 |

### 成功基準
- ✅ ユーザーが実際に履歴を登録し続けている
- ✅ AI提案の通知に対して、ユーザーがアクションを起こす
- ✅ ユーザーインタビューでポジティブなフィードバック

---

## Phase 2: エンゲージメント拡大
**期間**: +6ヶ月（2026年5月〜10月）  
**目標**: AIの価値を高め、ユーザーの利用頻度と定着率を向上させる

### 主な機能

#### 1. カスタム提案機能の強化（Month 1-2）

**AIの役割**
膨大なパーツ情報から、ユーザーの車と目的に最適なものを論理的に絞り込む

**ロジック**
- 車種・年式への適合性
- 使用目的（ファミリー/通勤/アウトドア）への適性
- 安全性・実用性の観点

**アウトプット**
「なぜこのカスタムが向いているのか」の理由、メリット・デメリット、注意点（車検・安全・コスト）を明示

**実装詳細**
```dart
// カスタム提案生成
class CustomRecommendationService {
  Future<List<CustomRecommendation>> generateRecommendations({
    required Vehicle vehicle,
    required UserPreferences preferences,
  }) async {
    // 車種データベースからパーツ候補を取得
    final compatibleParts = await getCompatibleParts(vehicle);
    
    // ユーザーの使用目的でフィルタリング
    final filteredParts = filterByPurpose(
      compatibleParts,
      preferences.purposes, // [family, outdoor, etc.]
    );
    
    // 安全性・実用性でスコアリング
    final scoredParts = scoreByPractical(filteredParts);
    
    // 上位候補を返す
    return scoredParts.take(5).toList();
  }
}
```

#### 2. 車両購入レコメンド機能（Month 2-3）

**ユーザー入力**
- テーマ（例：ファミリーカー）
- 家族構成
- 使用シーン
- 予算感
- 曖昧な希望

**AIの役割**
ユーザーの希望を言語化・整理し、優先順位を明確化。条件に合う複数の候補を新車・中古車問わず提示する。

**アウトプット**
各候補の理由、メリット・デメリット、注意点を明示

**実装詳細**
```dart
// 車両レコメンド
class VehiclePurchaseRecommendationService {
  Future<List<VehicleRecommendation>> recommend({
    required String theme,
    required FamilyComposition family,
    required List<UsageScene> scenes,
    required BudgetRange budget,
  }) async {
    // LLMに質問を構造化
    final structuredQuery = await llm.structureQuery(
      theme: theme,
      family: family,
      scenes: scenes,
      budget: budget,
    );
    
    // 車両データベースから候補を検索
    final newCars = await searchNewCars(structuredQuery);
    final usedCars = await searchUsedCars(structuredQuery);
    
    // LLMで各候補を評価
    final recommendations = await llm.evaluateVehicles(
      candidates: [...newCars, ...usedCars],
      criteria: structuredQuery,
    );
    
    return recommendations;
  }
}
```

**データソース連携**
- 新車情報API
- 中古車情報API（カーセンサー、グーネット等）

#### 3. 地図連動バーチャルドライブ機能（Month 3-4）

**機能概要**
- 地図上で仮想的にドライブ体験
- ルートの記録と保存
- ドライブスポット推薦
- 走行ルートの共有

**実装詳細**
```dart
// ドライブ記録
class DriveRecord {
  String id;
  String userId;
  String vehicleId;
  String title;
  List<LatLng> route;
  double distance;
  Duration duration;
  List<String> photos;
  DateTime startTime;
  DateTime endTime;
  
  // ドライブスポット
  List<DriveSpot> spots;
}

class DriveSpot {
  String name;
  LatLng location;
  String description;
  List<String> tags; // [絶景, グルメ, 温泉, etc.]
}
```

**Google Maps Platform連携**
- Maps SDK: 地図表示
- Routes API: ルート検索
- Places API: スポット情報

#### 4. ユーザーSNS機能（Month 4-6）

**コミュニティ機能**
- 愛車の写真投稿
- ドライブ記録の投稿
- カスタム履歴の共有
- ユーザー同士のコメント・いいね

**実装詳細**
```dart
// 投稿データ
class Post {
  String id;
  String userId;
  String vehicleId;
  PostType type; // photo, drive, custom
  String title;
  String content;
  List<String> imageUrls;
  List<String> tags;
  int likeCount;
  int commentCount;
  DateTime createdAt;
}

class Comment {
  String id;
  String postId;
  String userId;
  String content;
  DateTime createdAt;
}

// タイムライン
class TimelineService {
  Stream<List<Post>> getTimeline({
    required String userId,
    TimelineFilter filter,
  }) {
    // ユーザーのフォロー関係に基づく投稿取得
    // または全体の人気投稿
  }
}
```

**コンテンツモデレーション**
- 不適切コンテンツの自動検出
- ユーザー報告機能
- 管理画面での手動確認

### 技術実装

#### LLM統合（OpenAI API / Claude API）
```dart
class AIService {
  final http.Client client;
  final String apiKey;
  
  Future<String> generateRecommendation({
    required String prompt,
    required Map<String, dynamic> context,
  }) async {
    final response = await client.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'messages': [
          {
            'role': 'system',
            'content': 'あなたは車の専門家です...',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
      }),
    );
    
    return json.decode(response.body)['choices'][0]['message']['content'];
  }
}
```

### KPI目標

| 指標 | 目標値 |
|------|--------|
| MAU | 2,000人 |
| 6ヶ月継続率 | 60% |
| レコメンド閲覧率 | 70% |
| SNS投稿数 | 平均2投稿/月・ユーザー |
| ドライブ記録数 | 500件 |

### 成功基準
- ✅ AIレコメンドの精度と満足度が高い
- ✅ ユーザーがコミュニティ機能を積極的に利用している
- ✅ ドライブ記録の共有が活発

---

## Phase 3: エコシステム完成と収益化
**期間**: +6ヶ月（2026年11月〜2027年4月）  
**目標**: B2Bモデルを確立し、事業をスケールさせる

### 主な機能

#### 1. 整備工場・販売店連携機能（Month 1-3）

**「信頼できるパートナー」エコシステム**

**フロー**
1. **AI提案**: ユーザーがAIによるカスタムや車両購入のレコメンドを閲覧
2. **ユーザーの意思表示**: 提案内容に対して「興味あり」ボタンをタップ
3. **選択肢の提示**: このタイミングでのみ、提携している優良な整備工場や販売店の候補が表示される
   - 表示情報には、得意分野（EV、輸入車 etc.）やユーザー評価も含まれる
4. **ユーザー起点のアクション**: ユーザーが自らの意思で「問い合わせる」ボタンをタップし、初めて事業者とのコンタクトが開始される

**重要原則**
- ユーザーの許可なく、事業者から連絡が来ることは一切ありません
- すべての行動はユーザー起点です

**実装詳細**
```dart
// 事業者データ
class ServiceProvider {
  String id;
  ProviderType type; // workshop, dealer
  String name;
  String address;
  LatLng location;
  List<String> specialties; // [EV, 輸入車, etc.]
  double rating;
  int reviewCount;
  String phoneNumber;
  String email;
  List<String> photos;
  
  // 提携情報
  bool isVerified;
  DateTime joinedAt;
}

// 問い合わせ
class Inquiry {
  String id;
  String userId;
  String providerId;
  String vehicleId;
  InquiryType type; // custom, purchase, maintenance
  String content;
  InquiryStatus status; // pending, accepted, completed
  DateTime createdAt;
}

// 事業者マッチング
class ProviderMatchingService {
  Future<List<ServiceProvider>> findProviders({
    required RecommendationType type,
    required LatLng userLocation,
    required Vehicle vehicle,
  }) async {
    // 位置情報ベースで近くの事業者を取得
    final nearbyProviders = await getNearbyProviders(userLocation);
    
    // 専門性でフィルタリング
    final matchedProviders = filterBySpecialty(
      nearbyProviders,
      vehicle: vehicle,
      type: type,
    );
    
    // 評価順でソート
    return matchedProviders..sort((a, b) => b.rating.compareTo(a.rating));
  }
}
```

**事業者向け管理画面**
- 問い合わせ一覧・管理
- ユーザー評価の確認
- プロフィール編集
- プロモーション機能

#### 2. 法人向け車両管理機能（Month 3-5）

**機能概要**
- 複数車両の一元管理
- 社員ごとのアクセス権限管理
- 車両稼働状況の可視化
- メンテナンススケジュールの自動管理
- コスト分析とレポート機能

**実装詳細**
```dart
// 法人アカウント
class CorporateAccount {
  String id;
  String companyName;
  String taxId;
  String address;
  String contactEmail;
  String contactPhone;
  PlanType plan; // basic, standard, premium
  int vehicleLimit;
  DateTime createdAt;
}

// 法人ユーザー
class CorporateUser {
  String id;
  String corporateAccountId;
  String email;
  String displayName;
  CorporateRole role; // admin, manager, viewer
  List<String> assignedVehicleIds;
  DateTime createdAt;
}

// 車両アサインメント
class VehicleAssignment {
  String id;
  String corporateAccountId;
  String vehicleId;
  String userId;
  DateTime assignedAt;
  DateTime? returnedAt;
}

// コスト分析
class CostAnalytics {
  String corporateAccountId;
  DateTime period;
  Map<String, double> costByVehicle;
  Map<MaintenanceType, double> costByType;
  double totalCost;
  
  // 予測
  double predictedNextMonthCost;
}
```

**ダッシュボード機能**
- 全車両の一覧とステータス
- メンテナンススケジュール（カレンダー表示）
- コストレポート（月次・年次）
- 車両稼働率の分析
- アラート管理（車検期限、点検時期）

#### 3. プレミアム会員機能（Month 5-6）

**B2C収益化**

**提供価値**
- 高度なAI提案機能（パーソナライズ精度の向上）
- 登録できる車両履歴や証跡データの無制限化
- 優先サポート
- 広告非表示

**料金プラン**
- ベーシック（無料）
  - 車両登録: 1台
  - 履歴登録: 50件まで
  - AI提案: 基本機能のみ

- プレミアム（¥500/月）
  - 車両登録: 無制限
  - 履歴登録: 無制限
  - AI提案: 高度なパーソナライズ
  - 優先サポート

**実装詳細**
```dart
// サブスクリプション
class Subscription {
  String id;
  String userId;
  SubscriptionPlan plan;
  SubscriptionStatus status; // active, expired, cancelled
  DateTime startDate;
  DateTime? endDate;
  String paymentMethodId;
}

// 決済連携（Stripe）
class PaymentService {
  Future<Subscription> createSubscription({
    required String userId,
    required SubscriptionPlan plan,
  }) async {
    // Stripe Customer作成
    final customer = await stripe.createCustomer(userId);
    
    // Subscription作成
    final subscription = await stripe.createSubscription(
      customerId: customer.id,
      priceId: plan.stripePriceId,
    );
    
    return Subscription.fromStripe(subscription);
  }
}
```

### 技術実装

#### Stripe連携
```dart
dependencies:
  stripe_platform_interface: ^10.0.0
  stripe_android: ^10.0.0
  stripe_ios: ^10.0.0
```

#### 権限管理
```dart
// 権限チェック
class PermissionService {
  bool canAccessFeature(User user, Feature feature) {
    switch (feature) {
      case Feature.unlimitedVehicles:
        return user.subscription?.plan == SubscriptionPlan.premium;
      case Feature.unlimitedHistory:
        return user.subscription?.plan == SubscriptionPlan.premium;
      case Feature.advancedAI:
        return user.subscription?.plan == SubscriptionPlan.premium;
      default:
        return true;
    }
  }
}
```

### KPI目標

| 指標 | 目標値 |
|------|--------|
| MAU | 10,000人 |
| プレミアム転換率 | 10% |
| 問い合わせ転換率 | 5% |
| 法人契約数 | 50社 |
| 法人管理車両数 | 500台 |

### 成功基準
- ✅ B2Bモデルでの安定した収益が発生している
- ✅ 事業者パートナーの満足度が高い
- ✅ 法人顧客の継続率が高い

---

## 技術的マイルストーン

### Phase 1
- Firebase完全統合
- ルールベースAIシステム構築
- プッシュ通知基盤
- 基本的なセキュリティルール実装

### Phase 2
- LLM API統合（OpenAI/Claude）
- Google Maps Platform統合
- リアルタイム同期機能（SNS）
- 画像処理・圧縮最適化

### Phase 3
- Stripe決済システム統合
- 事業者向け管理ダッシュボード
- 高度な権限管理システム
- データ分析・レポート機能
- パフォーマンス最適化

---

## リスク管理

### 技術的リスク
| リスク | 対策 |
|--------|------|
| Firebase コスト増加 | 読み取り/書き込みの最適化、キャッシング戦略 |
| LLM API コスト増加 | プロンプト最適化、キャッシング、バッチ処理 |
| スケーラビリティ | Cloud Functions のタイムアウト対策、分散処理 |

### ビジネスリスク
| リスク | 対策 |
|--------|------|
| ユーザー獲得コスト | オーガニック成長戦略、口コミ促進 |
| 事業者パートナー確保 | パイロットプログラム、成功事例の蓄積 |
| 競合参入 | 差別化ポイントの強化、コミュニティ形成 |

---

## 次のステップ

### 短期（1-2週間）
1. Phase 1 の残タスク完了
2. デザインシステムの実装
3. ユーザーテスト実施

### 中期（1-3ヶ月）
1. Phase 2 の機能開発開始
2. β版リリース
3. ユーザーフィードバック収集と改善

### 長期（3-6ヶ月）
1. Phase 3 の準備
2. 事業者パートナーシップ構築
3. 収益化基盤の確立
