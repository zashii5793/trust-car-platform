# システムアーキテクチャ

Trust Car Platform - Technical Architecture Document

---

## システム概要

### アーキテクチャスタイル
- **クライアント**: Flutter（マルチプラットフォーム）
- **バックエンド**: Firebase（BaaS - Backend as a Service）
- **AI**: External API（OpenAI / Claude / Gemini）
- **決済**: Stripe
- **地図**: Google Maps Platform

### 設計原則
1. **スケーラビリティ**: 段階的な成長に対応
2. **セキュリティ**: データ保護とプライバシー重視
3. **パフォーマンス**: 高速なレスポンスと軽量な動作
4. **保守性**: クリーンアーキテクチャとモジュール化

---

## システム構成図

```
┌─────────────────────────────────────────────────────────────┐
│                        Client Layer                         │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │   iOS App   │  │ Android App │  │   Web App   │       │
│  │  (Flutter)  │  │  (Flutter)  │  │  (Flutter)  │       │
│  └─────────────┘  └─────────────┘  └─────────────┘       │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTPS / WebSocket
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     Firebase Platform                        │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ Auth         │  │ Firestore    │  │ Storage      │    │
│  │ (認証)       │  │ (データベース)│  │ (ファイル)    │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ Functions    │  │ Messaging    │  │ Analytics    │    │
│  │ (サーバー処理)│  │ (通知)       │  │ (分析)        │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ API Calls
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   External Services                          │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ OpenAI/      │  │ Google Maps  │  │ Stripe       │    │
│  │ Claude API   │  │ Platform     │  │ (決済)        │    │
│  │ (AI)         │  │ (地図)       │  │              │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐                       │
│  │ 中古車API    │  │ パーツEC API │                       │
│  │              │  │              │                       │
│  └──────────────┘  └──────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

---

## クライアントアーキテクチャ（Flutter）

### レイヤー構造

```
┌────────────────────────────────────────┐
│         Presentation Layer             │
│  (UI, Screens, Widgets)                │
│                                        │
│  - 画面表示                            │
│  - ユーザー入力                        │
│  - ナビゲーション                      │
└────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│        Application Layer               │
│  (Providers, BLoC, State Management)   │
│                                        │
│  - 状態管理                            │
│  - ビジネスロジック                    │
│  - データフロー制御                    │
└────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│          Domain Layer                  │
│  (Models, Entities, Use Cases)         │
│                                        │
│  - ドメインモデル                      │
│  - ビジネスルール                      │
│  - ユースケース                        │
└────────────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│         Data Layer                     │
│  (Repositories, Data Sources)          │
│                                        │
│  - データアクセス                      │
│  - API通信                             │
│  - ローカルストレージ                  │
└────────────────────────────────────────┘
```

### ディレクトリ構造

```
lib/
├── main.dart
├── app.dart
│
├── core/                       # コア機能
│   ├── constants/             # 定数
│   ├── error/                 # エラーハンドリング
│   ├── network/               # ネットワーク設定
│   ├── utils/                 # ユーティリティ
│   └── themes/                # テーマ設定
│
├── models/                     # データモデル
│   ├── vehicle.dart
│   ├── maintenance_record.dart
│   ├── user.dart
│   ├── post.dart              # SNS投稿
│   ├── drive_record.dart      # ドライブ記録
│   └── corporate/             # 法人向けモデル
│
├── providers/                  # 状態管理（Provider）
│   ├── auth_provider.dart
│   ├── vehicle_provider.dart
│   ├── maintenance_provider.dart
│   ├── social_provider.dart
│   └── corporate_provider.dart
│
├── services/                   # サービス層
│   ├── firebase/
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   └── storage_service.dart
│   ├── ai_service.dart
│   ├── map_service.dart
│   ├── notification_service.dart
│   ├── payment_service.dart
│   └── analytics_service.dart
│
├── repositories/               # リポジトリ層
│   ├── vehicle_repository.dart
│   ├── maintenance_repository.dart
│   └── user_repository.dart
│
├── screens/                    # 画面
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── vehicle/
│   │   ├── vehicle_list_screen.dart
│   │   ├── vehicle_detail_screen.dart
│   │   └── vehicle_registration_screen.dart
│   ├── maintenance/
│   │   ├── maintenance_list_screen.dart
│   │   └── add_maintenance_screen.dart
│   ├── social/                # Phase 2
│   │   ├── timeline_screen.dart
│   │   ├── post_detail_screen.dart
│   │   └── create_post_screen.dart
│   ├── drive/                 # Phase 2
│   │   ├── drive_map_screen.dart
│   │   └── drive_history_screen.dart
│   ├── ai/
│   │   ├── recommendation_screen.dart
│   │   └── vehicle_search_screen.dart
│   └── corporate/             # Phase 3
│       ├── dashboard_screen.dart
│       ├── fleet_screen.dart
│       └── analytics_screen.dart
│
├── widgets/                    # 再利用可能なウィジェット
│   ├── common/
│   │   ├── app_button.dart
│   │   ├── app_card.dart
│   │   └── loading_indicator.dart
│   ├── vehicle/
│   │   └── vehicle_card.dart
│   └── maintenance/
│       └── maintenance_tile.dart
│
└── config/                     # 設定
    ├── routes.dart
    ├── environment.dart
    └── firebase_options.dart
```

---

## データベース設計（Cloud Firestore）

### コレクション構造

```
/users/{userId}
  - email: string
  - displayName: string
  - photoURL: string
  - subscription: {
      plan: string
      status: string
      startDate: timestamp
      endDate: timestamp
    }
  - createdAt: timestamp
  - updatedAt: timestamp

/vehicles/{vehicleId}
  - userId: string (indexed)
  - maker: string
  - model: string
  - year: number
  - grade: string
  - mileage: number
  - imageUrl: string
  - createdAt: timestamp (indexed)
  - updatedAt: timestamp

/maintenance_records/{recordId}
  - vehicleId: string (indexed)
  - userId: string (indexed)
  - type: string (repair/inspection/parts/carInspection)
  - title: string
  - description: string
  - cost: number
  - shopName: string
  - date: timestamp (indexed)
  - mileageAtService: number
  - imageUrls: array<string>
  - createdAt: timestamp

/notifications/{notificationId}
  - userId: string (indexed)
  - vehicleId: string
  - type: string
  - title: string
  - message: string
  - isRead: boolean (indexed)
  - createdAt: timestamp (indexed)

/posts/{postId}                    # Phase 2: SNS
  - userId: string (indexed)
  - vehicleId: string
  - type: string (photo/drive/custom)
  - title: string
  - content: string
  - imageUrls: array<string>
  - tags: array<string>
  - likeCount: number
  - commentCount: number
  - createdAt: timestamp (indexed)

/comments/{commentId}              # Phase 2: SNS
  - postId: string (indexed)
  - userId: string
  - content: string
  - createdAt: timestamp

/drive_records/{driveId}           # Phase 2: ドライブ
  - userId: string (indexed)
  - vehicleId: string
  - title: string
  - route: geopoint array
  - distance: number
  - duration: number
  - photos: array<string>
  - spots: array<object>
  - startTime: timestamp
  - endTime: timestamp

/service_providers/{providerId}    # Phase 3: 事業者
  - type: string (workshop/dealer)
  - name: string
  - address: string
  - location: geopoint (indexed)
  - specialties: array<string>
  - rating: number
  - reviewCount: number
  - contactInfo: object
  - isVerified: boolean
  - joinedAt: timestamp

/inquiries/{inquiryId}             # Phase 3: 問い合わせ
  - userId: string (indexed)
  - providerId: string (indexed)
  - vehicleId: string
  - type: string
  - content: string
  - status: string (pending/accepted/completed)
  - createdAt: timestamp

/corporate_accounts/{corporateId}  # Phase 3: 法人
  - companyName: string
  - taxId: string
  - plan: string
  - vehicleLimit: number
  - contactInfo: object
  - createdAt: timestamp

/corporate_users/{userId}          # Phase 3: 法人ユーザー
  - corporateAccountId: string (indexed)
  - role: string (admin/manager/viewer)
  - assignedVehicleIds: array<string>
  - createdAt: timestamp
```

### インデックス設定

```javascript
// 複合インデックス
vehicles: [userId, createdAt DESC]
maintenance_records: [vehicleId, date DESC]
maintenance_records: [userId, createdAt DESC]
notifications: [userId, isRead, createdAt DESC]
posts: [createdAt DESC, likeCount DESC]
drive_records: [userId, startTime DESC]
```

### セキュリティルール

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ユーザーデータ
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // 車両データ
    match /vehicles/{vehicleId} {
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth.uid == resource.data.userId;
    }
    
    // メンテナンス履歴
    match /maintenance_records/{recordId} {
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth.uid == resource.data.userId;
    }
    
    // 投稿（公開コンテンツ）
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth.uid == resource.data.userId;
    }
    
    // 法人データ
    match /corporate_accounts/{corporateId} {
      allow read: if request.auth != null && 
                     isCorpUser(corporateId);
      allow write: if request.auth != null && 
                      isCorpAdmin(corporateId);
    }
    
    // ヘルパー関数
    function isCorpUser(corporateId) {
      return exists(/databases/$(database)/documents/corporate_users/$(request.auth.uid)) &&
             get(/databases/$(database)/documents/corporate_users/$(request.auth.uid)).data.corporateAccountId == corporateId;
    }
    
    function isCorpAdmin(corporateId) {
      return isCorpUser(corporateId) &&
             get(/databases/$(database)/documents/corporate_users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

---

## Cloud Functions（サーバーレス処理）

### 主要な関数

```javascript
// functions/index.js

// AI レコメンド生成（Phase 1）
exports.generateAIRecommendations = functions
  .firestore
  .document('vehicles/{vehicleId}')
  .onCreate(async (snap, context) => {
    const vehicle = snap.data();
    const recommendations = await callAIService(vehicle);
    
    // 通知を作成
    await admin.firestore()
      .collection('notifications')
      .add({
        userId: vehicle.userId,
        vehicleId: context.params.vehicleId,
        type: 'recommendation',
        title: '車両のレコメンドが生成されました',
        message: recommendations,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  });

// 定期点検リマインダー（Phase 1）
exports.checkMaintenanceReminders = functions
  .pubsub
  .schedule('0 9 * * *')  // 毎日9時
  .timeZone('Asia/Tokyo')
  .onRun(async (context) => {
    const vehiclesSnapshot = await admin.firestore()
      .collection('vehicles')
      .get();
    
    for (const vehicleDoc of vehiclesSnapshot.docs) {
      const vehicle = vehicleDoc.data();
      const lastMaintenance = await getLastMaintenance(vehicleDoc.id);
      
      if (needsReminder(lastMaintenance)) {
        await createNotification(vehicle.userId, vehicleDoc.id);
      }
    }
  });

// プッシュ通知送信（Phase 1）
exports.sendPushNotification = functions
  .firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const user = await admin.firestore()
      .collection('users')
      .doc(notification.userId)
      .get();
    
    const fcmToken = user.data().fcmToken;
    
    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: notification.title,
          body: notification.message,
        },
      });
    }
  });

// いいね数の集計（Phase 2）
exports.updateLikeCount = functions
  .firestore
  .document('posts/{postId}/likes/{userId}')
  .onWrite(async (change, context) => {
    const postRef = admin.firestore()
      .collection('posts')
      .doc(context.params.postId);
    
    if (change.after.exists) {
      // いいねが追加された
      await postRef.update({
        likeCount: admin.firestore.FieldValue.increment(1),
      });
    } else {
      // いいねが削除された
      await postRef.update({
        likeCount: admin.firestore.FieldValue.increment(-1),
      });
    }
  });

// 決済完了処理（Phase 3）
exports.handlePaymentSuccess = functions
  .https
  .onRequest(async (req, res) => {
    const event = req.body;
    
    if (event.type === 'checkout.session.completed') {
      const session = event.data.object;
      const userId = session.metadata.userId;
      const plan = session.metadata.plan;
      
      // サブスクリプション情報を更新
      await admin.firestore()
        .collection('users')
        .doc(userId)
        .update({
          'subscription.plan': plan,
          'subscription.status': 'active',
          'subscription.startDate': admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    
    res.json({ received: true });
  });
```

---

## API統合

### AI API（OpenAI / Claude）

```dart
class AIService {
  final http.Client _client;
  final String _apiKey;
  
  Future<AIRecommendation> generateCustomRecommendation({
    required Vehicle vehicle,
    required UserPreferences preferences,
  }) async {
    final prompt = _buildPrompt(vehicle, preferences);
    
    final response = await _client.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'messages': [
          {
            'role': 'system',
            'content': '''あなたは車の専門家です。
ユーザーの車両情報と好みに基づいて、
最適なカスタム提案を行ってください。
必ず理由とメリット・デメリットを含めてください。''',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.7,
      }),
    );
    
    final jsonResponse = json.decode(response.body);
    final content = jsonResponse['choices'][0]['message']['content'];
    
    return AIRecommendation.fromJson(content);
  }
}
```

### Google Maps Platform

```dart
class MapService {
  final GoogleMapsController _controller;
  
  Future<List<Place>> searchNearbyPlaces({
    required LatLng location,
    required String type,
    int radius = 5000,
  }) async {
    final response = await http.get(
      Uri.parse('https://maps.googleapis.com/maps/api/place/nearbysearch/json')
        .replace(queryParameters: {
          'location': '${location.latitude},${location.longitude}',
          'radius': radius.toString(),
          'type': type,
          'key': _apiKey,
        }),
    );
    
    final jsonResponse = json.decode(response.body);
    final results = jsonResponse['results'] as List;
    
    return results.map((json) => Place.fromJson(json)).toList();
  }
  
  Future<List<LatLng>> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final response = await http.get(
      Uri.parse('https://maps.googleapis.com/maps/api/directions/json')
        .replace(queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'key': _apiKey,
        }),
    );
    
    final jsonResponse = json.decode(response.body);
    final route = jsonResponse['routes'][0];
    final polyline = route['overview_polyline']['points'];
    
    return _decodePolyline(polyline);
  }
}
```

### Stripe決済

```dart
class PaymentService {
  final Stripe _stripe;
  
  Future<PaymentIntent> createPaymentIntent({
    required int amount,
    required String currency,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.stripe.com/v1/payment_intents'),
      headers: {
        'Authorization': 'Bearer $_secretKey',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'amount': amount.toString(),
        'currency': currency,
      },
    );
    
    return PaymentIntent.fromJson(json.decode(response.body));
  }
  
  Future<void> confirmPayment(String clientSecret) async {
    await _stripe.confirmPayment(
      paymentIntentClientSecret: clientSecret,
    );
  }
}
```

---

## セキュリティ

### 認証フロー

```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // メール/パスワード認証
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
  
  // Google認証
  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    final GoogleSignInAuthentication googleAuth = 
        await googleUser!.authentication;
    
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    
    return await _auth.signInWithCredential(credential);
  }
  
  // サインアウト
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }
}
```

### データ暗号化

- **通信**: TLS/SSL（HTTPS）
- **保存**: Firebase暗号化（デフォルト）
- **機密情報**: 環境変数での管理

```dart
// .env
OPENAI_API_KEY=sk-...
STRIPE_SECRET_KEY=sk_...
GOOGLE_MAPS_API_KEY=AIza...
```

---

## パフォーマンス最適化

### キャッシング戦略

```dart
class CachedFirestoreService {
  final Map<String, dynamic> _cache = {};
  final Duration _cacheDuration = Duration(minutes: 5);
  
  Future<T> getCached<T>({
    required String key,
    required Future<T> Function() fetcher,
  }) async {
    final cached = _cache[key];
    
    if (cached != null && !_isExpired(cached['timestamp'])) {
      return cached['data'] as T;
    }
    
    final data = await fetcher();
    _cache[key] = {
      'data': data,
      'timestamp': DateTime.now(),
    };
    
    return data;
  }
  
  bool _isExpired(DateTime timestamp) {
    return DateTime.now().difference(timestamp) > _cacheDuration;
  }
}
```

### 画像最適化

```dart
class ImageOptimizationService {
  Future<File> compressImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final img.Image? image = img.decodeImage(bytes);
    
    if (image == null) return imageFile;
    
    // リサイズ
    final resized = img.copyResize(
      image,
      width: 1200,
      interpolation: img.Interpolation.cubic,
    );
    
    // 圧縮
    final compressed = img.encodeJpg(resized, quality: 85);
    
    // ファイル保存
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/compressed.jpg');
    await file.writeAsBytes(compressed);
    
    return file;
  }
}
```

### ページネーション

```dart
class PaginatedList<T> {
  final int pageSize;
  DocumentSnapshot? _lastDocument;
  
  PaginatedList({this.pageSize = 20});
  
  Future<List<T>> loadNextPage(
    Query query,
    T Function(DocumentSnapshot) fromFirestore,
  ) async {
    Query paginatedQuery = query.limit(pageSize);
    
    if (_lastDocument != null) {
      paginatedQuery = paginatedQuery.startAfterDocument(_lastDocument!);
    }
    
    final snapshot = await paginatedQuery.get();
    
    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
    }
    
    return snapshot.docs.map(fromFirestore).toList();
  }
}
```

---

## モニタリング・分析

### Firebase Analytics

```dart
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }
  
  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    await _analytics.logEvent(
      name: name,
      parameters: parameters,
    );
  }
  
  // 主要イベント
  Future<void> logVehicleAdded(String vehicleId) async {
    await logEvent(
      name: 'vehicle_added',
      parameters: {'vehicle_id': vehicleId},
    );
  }
  
  Future<void> logMaintenanceRecorded(String type) async {
    await logEvent(
      name: 'maintenance_recorded',
      parameters: {'type': type},
    );
  }
  
  Future<void> logAIRecommendationViewed() async {
    await logEvent(name: 'ai_recommendation_viewed');
  }
}
```

### エラーログ

```dart
class ErrorHandler {
  static Future<void> logError(
    dynamic error,
    StackTrace stackTrace,
  ) async {
    // Firebase Crashlytics
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      fatal: false,
    );
    
    // ログ出力
    print('Error: $error');
    print('StackTrace: $stackTrace');
  }
  
  static void setupErrorHandling() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    };
  }
}
```

---

## デプロイメント

### 環境構成

```
開発環境 (Development)
- Firebase Project: trust-car-dev
- Debug mode
- Test data

ステージング環境 (Staging)
- Firebase Project: trust-car-staging
- Release mode
- Production-like data

本番環境 (Production)
- Firebase Project: trust-car-prod
- Release mode
- Real user data
```

### CI/CD（GitHub Actions）

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches:
      - main
      - develop

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.38.7'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Run tests
        run: flutter test
      
      - name: Build Web
        run: flutter build web
      
      - name: Deploy to Firebase Hosting
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
          projectId: trust-car-prod
```

---

## バックアップ・リカバリー

### データバックアップ

```bash
# Firestore自動バックアップ設定
gcloud firestore backups schedules create \
  --database='(default)' \
  --recurrence=daily \
  --retention=7d
```

### 災害対策

- **定期バックアップ**: 毎日自動バックアップ
- **地理的冗長性**: Firestoreのマルチリージョン設定
- **復旧手順書**: ドキュメント化

---

## スケーリング戦略

### Phase 1-2（〜10,000 MAU）
- Firebase無料枠 + 従量課金
- 単一リージョン
- 基本的なキャッシング

### Phase 3（〜100,000 MAU）
- Firebaseスケールアップ
- マルチリージョン展開
- CDN活用
- キャッシング強化

### Phase 4以降（100,000+ MAU）
- 独自バックエンド検討
- マイクロサービス化
- Kubernetes導入

---

## 技術選定理由

### Flutter
- **クロスプラットフォーム**: iOS/Android/Web同時対応
- **高速開発**: Hot Reload、豊富なウィジェット
- **パフォーマンス**: ネイティブ並みの性能
- **コミュニティ**: 大規模で活発

### Firebase
- **速い立ち上げ**: BaaSで初期開発が高速
- **スケーラビリティ**: 自動スケーリング
- **統合性**: 認証、DB、ストレージ、通知が統合
- **コスト効率**: 初期段階では低コスト

### Provider（状態管理）
- **シンプル**: 学習コストが低い
- **公式推奨**: Flutter公式が推奨
- **十分な機能**: MVPには十分

---

## 今後の技術課題

### Phase 1-2
- [ ] ユニットテスト100%カバレッジ
- [ ] E2Eテスト導入
- [ ] パフォーマンス監視体制

### Phase 3
- [ ] マイクロサービス化検討
- [ ] GraphQL導入検討
- [ ] 機械学習モデルの自社開発

---

## 参考資料

- [Flutter Architecture](https://flutter.dev/docs/development/data-and-backend/state-mgmt/intro)
- [Firebase Best Practices](https://firebase.google.com/docs/firestore/best-practices)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
