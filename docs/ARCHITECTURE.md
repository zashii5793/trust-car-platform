# Trust Car Platform — アーキテクチャ設計書

> **対象読者**: バグ修正・保守担当者、新規開発者
> **目的**: コードを理解してエラーを素早くトレースする
> **最終更新**: 2026-03-06

---

## 目次

1. [全体アーキテクチャ](#1-全体アーキテクチャ)
2. [起動フロー（main.dart）](#2-起動フローmaindart)
3. [DIコンテナ（ServiceLocator / Injection）](#3-diコンテナservicelocator--injection)
4. [エラーハンドリング（Result / AppError）](#4-エラーハンドリングresult--apperror)
5. [状態管理（Provider）](#5-状態管理provider)
6. [サービス層（Services）](#6-サービス層services)
7. [モデル層（Models）](#7-モデル層models)
8. [画面層（Screens）](#8-画面層screens)
9. [Firebase構成](#9-firebase構成)
10. [バグ調査チートシート](#10-バグ調査チートシート)
11. [新機能追加チェックリスト](#11-新機能追加チェックリスト)

---

## 1. 全体アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────────┐
│  UI層  (lib/screens/)                                                │
│  Consumer<XxxProvider> でデータ購読                                  │
│  ユーザー操作 → Provider メソッドを呼ぶ                               │
└──────────────────────────────┬──────────────────────────────────────┘
                                │ context.read<P>().method()
┌──────────────────────────────▼──────────────────────────────────────┐
│  Provider層  (lib/providers/)                                        │
│  ChangeNotifier を継承                                               │
│  ・状態（_isLoading, _error, データリスト）を保持                    │
│  ・Service をコンストラクタ注入で受け取る                             │
│  ・Result<T,AppError> をハンドリングして notifyListeners()            │
└──────────────────────────────┬──────────────────────────────────────┘
                                │ _xxxService.methodName()
┌──────────────────────────────▼──────────────────────────────────────┐
│  Service層  (lib/services/)                                          │
│  ・Firebase SDK を直接操作                                           │
│  ・戻り値は必ず Result<T, AppError>                                  │
│  ・例外は catch して mapFirebaseError() 経由で AppError に変換        │
└──────────────────────────────┬──────────────────────────────────────┘
                                │ Firebase SDK
┌──────────────────────────────▼──────────────────────────────────────┐
│  Firebase バックエンド                                                │
│  Auth / Firestore / Storage / Messaging / Crashlytics / Performance  │
└─────────────────────────────────────────────────────────────────────┘

DIコンテナ（ServiceLocator）
  └─ Injection.init() で全 Service をシングルトン登録（21個）
  └─ main.dart の MultiProvider で sl.get<XxxService>() して Provider に注入
```

### レイヤー間の依存ルール

| 方向 | 許可 | 禁止 |
|------|------|------|
| UI → Provider | ✅ `context.read<P>().method()` | ❌ UI 内でServiceを直接呼ばない |
| UI → Service | ❌ 原則禁止 | — |
| Provider → Service | ✅ コンストラクタ注入 | ❌ Provider 内で `new XxxService()` |
| Service → Firebase | ✅ | — |
| Service → Service | ❌ 原則禁止 | — |
| Model → あらゆる層 | ❌ データのみ、ロジックなし | — |

---

## 2. 起動フロー（main.dart）

```
main()
 │
 ├─ WidgetsFlutterBinding.ensureInitialized()
 │
 ├─ Firebase.initializeApp()                  ← firebase_options.dart の設定を使用
 │
 ├─ FirebaseFirestore.instance.settings 設定   ← offline persistence 100MB キャッシュ有効
 │
 ├─ _initializeCrashlytics()                   ← release モードのみ有効
 │     FlutterError.onError    → Crashlytics
 │     PlatformDispatcher.onError → Crashlytics (fatal)
 │
 ├─ Injection.init()                           ← 全 Service を ServiceLocator に登録（21個）
 │
 ├─ _setupAuthLogging()                        ← Auth 状態変化を LoggingService に記録
 │
 ├─ PushNotificationService.initializeTimezone()
 │
 ├─ pushService.initialize()                   ← FCM トークン取得・権限要求
 │
 └─ runApp(MyApp())
      │
      └─ MultiProvider（7 Provider を生成）
           │
           └─ MaterialApp
                │  theme: AppTheme.lightTheme
                │  darkTheme: AppTheme.darkTheme
                │  themeMode: ThemeMode.system
                │
                └─ AuthWrapper
                     │
                     ├─ authProvider.isLoading        → CircularProgressIndicator
                     ├─ authProvider.isAuthenticated  → HomeScreen
                     └─ （未認証）                    → LoginScreen
```

### デバッグ時の注意点

- Crashlytics は **`kDebugMode == false`** 時のみ動作。デバッグ時はコンソールログのみ。
- Firestore のオフラインキャッシュが有効なため、ネットワーク切断時でもデータが返ることがある。実際の通信エラーと区別するには `NetworkError.isRetryable` を確認する。
- `Injection.init()` は `_initialized` フラグで冪等（2回呼ばれてもスキップ）。テスト後は `Injection.reset()` でリセットが必要。

---

## 3. DIコンテナ（ServiceLocator / Injection）

### 使い方

```dart
// lib/core/di/service_locator.dart で定義されている短縮形
import 'package:trust_car_platform/core/di/service_locator.dart';

final service = sl.get<XxxService>();           // 取得
final service = sl.tryGet<XxxService>();        // 未登録なら null
```

### 登録順序（injection.dart — 依存順に並べてある）

```
順番  Service                         理由
───────────────────────────────────────────────────────
 1.  LoggingService                  最初に登録（全エラーの自動ログで使用）
 2.  PerformanceService              LoggingService に依存
 3.  FirebaseService                 Firestore/Auth/Storage 操作の中核
 4.  AuthService
 5.  RecommendationService           ローカルルールのみ（Firebase 非依存）
 6.  VehicleCertificateOcrService
 7.  InvoiceOcrService
 8.  PdfExportService
 9.  PushNotificationService
10.  ImageProcessingService
11.  InvoiceService
12.  DocumentService
13.  ServiceMenuService
14.  VehicleMasterService
15.  PartRecommendationService
16.  ShopService
17.  InquiryService
18.  PostService
19.  FollowService
20.  VehicleListingService
21.  DriveLogService
```

### よくある DI 関連バグ

| 症状 | 原因 | 対処 |
|------|------|------|
| `ServiceNotRegisteredException` | `Injection.init()` 未実行 or 順序ミス | `main()` の呼び出しフローを確認 |
| Provider が古いデータを持つ | 複数インスタンスが混在 | Provider 内で `new` していないか確認 |
| テストで本番 Service が動く | テスト後のリセット漏れ | `tearDown` で `Injection.reset()` を呼ぶ |
| 新 Service で `ServiceNotRegistered` | injection.dart への追記忘れ | 登録ステップを確認 |

---

## 4. エラーハンドリング（Result / AppError）

### Result\<T, E\> パターン

すべての Service メソッドは例外をスローせず `Result` を返す。

```dart
// ── Service 側（定型パターン）──────────────────────────────────────
Future<Result<Vehicle, AppError>> getVehicle(String id) async {
  try {
    final doc = await _firestore.collection('vehicles').doc(id).get();
    if (!doc.exists) {
      return Result.failure(
          AppError.notFound('Vehicle not found', resourceType: '車両'));
    }
    return Result.success(Vehicle.fromMap(doc.data()!, doc.id));
  } catch (e) {
    return Result.failure(mapFirebaseError(e));  // Firebase例外 → AppError
  }
}

// ── Provider 側（定型パターン）──────────────────────────────────────
Future<void> loadVehicle(String id) async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  final result = await _firebaseService.getVehicle(id);

  result.when(
    success: (vehicle) => _currentVehicle = vehicle,
    failure: (error)   => _error = error.userMessage,
  );

  _isLoading = false;
  notifyListeners();
}

// ── UI 側（Consumer + 条件分岐）──────────────────────────────────────
Consumer<VehicleProvider>(
  builder: (context, provider, _) {
    if (provider.isLoading)  return const CircularProgressIndicator();
    if (provider.error != null) return Text(provider.error!);
    return VehicleCard(vehicle: provider.currentVehicle!);
  },
)
```

### Result のユーティリティメソッド

| メソッド | 説明 |
|---------|------|
| `result.isSuccess` / `isFailure` | 判定 |
| `result.valueOrNull` | 成功値（失敗時 null） |
| `result.errorOrNull` | エラー値（成功時 null） |
| `result.when(success:, failure:)` | パターンマッチ |
| `result.map(transform)` | 成功値を変換 |
| `result.flatMap(transform)` | Result を返す変換 |
| `result.getOrElse(default)` | 失敗時にデフォルト値 |
| `result.onSuccess(action)` | 副作用（成功時）→ result を返す |
| `result.onFailure(action)` | 副作用（失敗時）→ result を返す |

### AppError の種類と発生場面

```
AppError (sealed class)
│
├── NetworkError           ─ Firestore unavailable / ネットワーク断
│     isRetryable: true
│     userMessage: "ネットワーク接続を確認してください"
│
├── AuthError              ─ Firebase Auth の操作失敗
│     isRetryable: tooManyRequests のみ true
│     type: AuthErrorType（7種）
│       invalidCredentials  → "メールアドレスまたはパスワードが正しくありません"
│       userNotFound        → "ユーザーが見つかりません"
│       emailAlreadyInUse   → "このメールアドレスは既に使用されています"
│       weakPassword        → "パスワードが弱すぎます"
│       sessionExpired      → "セッションが期限切れです。再度ログインしてください"
│       tooManyRequests     → "しばらく待ってからお試しください"
│       unknown             → "認証エラーが発生しました"
│
├── ValidationError        ─ 入力チェック失敗（field 名付き）
│     isRetryable: false
│     userMessage: "{field}の入力内容を確認してください"
│
├── NotFoundError          ─ Firestore ドキュメント不在
│     isRetryable: false
│     userMessage: "{resourceType}が見つかりません"
│
├── PermissionError        ─ Firestore security rules 拒否（permission-denied）
│     isRetryable: false
│     userMessage: "この操作を行う権限がありません"
│
├── ServerError            ─ Firestore サーバー障害
│     isRetryable: true
│     userMessage: "サーバーエラーが発生しました。しばらく待ってからお試しください"
│
├── CacheError             ─ ローカルキャッシュ読み込み失敗
│     isRetryable: true
│     userMessage: "データの読み込みに失敗しました"
│
└── UnknownError           ─ それ以外（originalError を保持）
      isRetryable: false
      userMessage: "エラーが発生しました"
      → originalError.toString() で元の例外を確認できる
```

### mapFirebaseError() の自動変換ロジック

`catch (e)` で受け取った例外文字列を小文字化してパターン判別:

```
"user-not-found"          → AuthError(userNotFound)
"wrong-password"          → AuthError(invalidCredentials)
"invalid-credential"      → AuthError(invalidCredentials)
"email-already-in-use"    → AuthError(emailAlreadyInUse)
"weak-password"           → AuthError(weakPassword)
"too-many-requests"       → AuthError(tooManyRequests)
"permission-denied"       → PermissionError
"not-found"               → NotFoundError
"unavailable"             → NetworkError
"network" / "connection"  → NetworkError
それ以外                   → UnknownError (originalError 保持)
```

> **デバッグ tip**: `UnknownError` が返ってきたら `error.originalError.toString()` を見る。Firebase の新エラーコードが `mapFirebaseError()` に未対応の可能性がある。

---

## 5. 状態管理（Provider）

### 登録されている Provider（7個）

```dart
// lib/main.dart の MultiProvider
[
  ConnectivityProvider,           // オフライン状態の監視
  AuthProvider,                   // 認証状態・ユーザープロフィール
  VehicleProvider,                // 車両一覧・選択中車両
  MaintenanceProvider,            // 整備記録一覧・フィルタ
  NotificationProvider,           // 通知一覧・AI 提案（topSuggestions）
  PartRecommendationProvider,     // パーツ一覧・検索・おすすめ
  ShopProvider,                   // ショップ一覧・フィルタ・問い合わせ
]
```

### Provider の状態変数パターン（全 Provider 共通）

```dart
class XxxProvider with ChangeNotifier {
  // ── 状態変数 ──────────────────────────────────────────
  bool _isLoading = false;
  String? _error;              // AppError.userMessage を格納
  List<XxxModel> _items = [];

  // ── ゲッター（UI はこれを読む）───────────────────────
  bool get isLoading => _isLoading;
  String? get error  => _error;
  List<XxxModel> get items => _items;

  // ── コンストラクタ（Service をコンストラクタ注入）────
  final XxxService _xxxService;
  XxxProvider({required XxxService xxxService})
      : _xxxService = xxxService;

  // ── アクションメソッド ────────────────────────────────
  Future<void> loadItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();        // ← UI にローディング開始を通知

    final result = await _xxxService.getItems();

    result.when(
      success: (items) => _items = items,
      failure: (error)  => _error = error.userMessage,
    );

    _isLoading = false;
    notifyListeners();        // ← UI にデータ更新を通知
  }
}
```

### UI から Provider にアクセスする方法

| 用途 | コード | タイミング |
|------|--------|-----------|
| データ読み取り（build 内） | `context.watch<P>()` | Widget 再描画ごと |
| 特定 Widget だけ再描画 | `Consumer<P>(builder: ...)` | P が変化したときだけ |
| メソッド呼び出し（イベント） | `context.read<P>().method()` | build の外（onPressed 等） |
| 一部フィールドだけ監視 | `Selector<P, T>(selector: ...)` | パフォーマンス最適化 |

### Provider 一覧と主要な状態

| Provider | 主な状態変数 | 主なメソッド |
|---------|------------|------------|
| `AuthProvider` | `isAuthenticated`, `currentUser`, `isLoading` | `signIn()`, `signUp()`, `signOut()`, `updateProfile()` |
| `VehicleProvider` | `vehicles`, `selectedVehicle`, `isLoading`, `error` | `loadVehicles()`, `addVehicle()`, `updateVehicle()`, `deleteVehicle()` |
| `MaintenanceProvider` | `records`, `isLoading`, `error` | `loadRecords(vehicleId)`, `addRecord()`, `deleteRecord()` |
| `NotificationProvider` | `notifications`, `topSuggestions`, `unreadCount` | `loadNotifications()`, `markAsRead()`, `markAllAsRead()` |
| `PartRecommendationProvider` | `recommendations`, `browseParts`, `searchQuery`, `isLoading` | `loadRecommendations(vehicle)`, `loadBrowseParts(category, query)` |
| `ShopProvider` | `shops`, `selectedShop`, `inquiries`, `isLoading` | `loadShops(filter)`, `loadShopDetail()`, `createInquiry()` |
| `ConnectivityProvider` | `isOnline`, `connectionType` | — （自動監視） |

---

## 6. サービス層（Services）

### 主要サービス一覧と責務

```
FirebaseService（中核 — 車両・整備記録・画像）
  addVehicle(vehicle) → Result<String, AppError>      // ← String = 生成されたdocumentId
  updateVehicle(id, vehicle) → Result<void, AppError>
  deleteVehicle(id) → Result<void, AppError>
  getVehicle(id) → Result<Vehicle?, AppError>
  getUserVehicles() → Stream<List<Vehicle>>           // ← リアルタイム更新
  addMaintenanceRecord(record) → Result<String, AppError>
  getMaintenanceRecordsForVehicle(vehicleId, {limit}) → Result<List, AppError>
  getMaintenanceRecordsForVehicles(vehicleIds, {limitPerVehicle}) → Result<Map, AppError>
  uploadImage(file, path) → Result<String, AppError>  // ← String = Storage URL
  isLicensePlateExists(plate) → Result<bool, AppError>

AuthService
  signUpWithEmail({email, password, displayName}) → Result<UserCredential, AppError>
  signInWithEmail({email, password}) → Result<UserCredential, AppError>
  signInWithGoogle() → Result<UserCredential?, AppError>
  signOut() → Result<void, AppError>
  getUserProfile() → Result<AppUser?, AppError>
  updateUserProfile({displayName, photoUrl}) → Result<void, AppError>
  authStateChanges → Stream<User?>               // ← Firebase Auth ストリーム

RecommendationService（ローカルロジック — Firebase 非依存）
  generateRecommendations(vehicle, records) → List<AppNotification>
  // 12 種類の MaintenanceRule でルールベース判定
  // 例: 走行距離5000kmごとにオイル交換推奨

ShopService
  getShops({type, serviceCategory, prefecture, limit}) → Result<List<Shop>, AppError>
  getFeaturedShops({limit}) → Result<List<Shop>, AppError>
  getShopsByService(category, {limit}) → Result<List<Shop>, AppError>
  searchShops(query, {limit}) → Result<List<Shop>, AppError>
  getShop(shopId) → Result<Shop, AppError>

InquiryService
  createInquiry({userId, shopId, type, subject, message, vehicleId}) → Result<Inquiry, AppError>
  getMessages(inquiryId) → Result<List<InquiryMessage>, AppError>
  sendMessage({inquiryId, senderId, isFromShop, content}) → Result<InquiryMessage, AppError>
  updateStatus(inquiryId, status) → Result<Inquiry, AppError>
  markAsRead({inquiryId, isUser}) → Result<void, AppError>
  getUserInquiries(userId, {status, limit}) → Result<List<Inquiry>, AppError>
  getUnreadCountForUser(userId) → Result<int, AppError>

PartRecommendationService
  getFeaturedParts({limit}) → Result<List<PartListing>, AppError>
  getPartsByCategory(category, {limit}) → Result<List<PartListing>, AppError>
  searchParts(keyword, {category, limit}) → Result<List<PartListing>, AppError>
  getPartDetail(partId) → Result<PartListing, AppError>
  getRecommendationsForVehicle(vehicle, {category}) → Result<List<PartRecommendation>, AppError>

PushNotificationService
  initialize() → Result<void, AppError>
  requestPermission() → Result<bool, AppError>
  scheduleNotification({id, title, body, scheduledDate}) → Result<void, AppError>
  cancelNotification(id) → Result<void, AppError>

DriveLogService（最多 27 メソッド）
  ドライブログ CRUD / 統計計算 / ウェイポイント / スポット全般
```

### Service の書き方規約

```dart
// 全 Service メソッドはこの形式を厳守
Future<Result<ReturnType, AppError>> methodName({
  required String requiredParam,
  String? optionalParam,
  int limit = 20,              // ページネーション
  DocumentSnapshot? startAfter // カーソルベースページネーション
}) async {
  try {
    // Firebase 操作
    return Result.success(value);
  } catch (e, stackTrace) {
    return Result.failure(mapFirebaseError(e, stackTrace: stackTrace));
  }
}

// Stream（リアルタイム更新が必要な場合のみ）
Stream<List<Model>> streamItems(String userId) {
  return _firestore
      .collection('items')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => Model.fromMap(d.data(), d.id)).toList());
}
```

---

## 7. モデル層（Models）

### モデル間の関係図

```
AppUser (users/{userId})
  │
  └─ Vehicle (vehicles/{vehicleId})          userId で紐付け
       ├─ MaintenanceRecord                  vehicleId で紐付け
       │   (maintenance_records/{recordId})
       ├─ Document                           vehicleId で紐付け
       │   (documents/{documentId})
       └─ Invoice                            vehicleId で紐付け
           (invoices/{invoiceId})

Shop (shops/{shopId})
  ├─ ServiceMenu                             shopId で紐付け
  │   (service_menus/{menuId})
  └─ Inquiry                                shopId / userId 両方で紐付け
      (inquiries/{inquiryId})
       └─ InquiryMessage                    サブコレクション
           (inquiries/{id}/messages/{msgId})

PartListing (part_listings/{partId})         shopId で紐付け

AppNotification (notifications/{notifId})   userId で紐付け

Post (posts/{postId})                        userId で紐付け
  ├─ PostLike   (post_likes/{postId_userId})
  └─ Comment    (comments/{commentId})

DriveLog (drive_logs/{logId})               userId / vehicleId で紐付け
  └─ DriveWaypoint                          driveLogId フィールドで紐付け
      (drive_waypoints/{waypointId})         ※ 位置情報のためセキュリティ最優先
```

### モデルの共通実装パターン

```dart
class XxxModel {
  final String id;          // Firestore ドキュメント ID
  final String userId;      // 所有者（Firestore rules と一致）
  final DateTime createdAt;
  final DateTime updatedAt;

  // コンストラクタ（全フィールドを named parameter）
  const XxxModel({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    // ...
  });

  // Firestore から読み込み
  factory XxxModel.fromMap(Map<String, dynamic> map, String id) {
    return XxxModel(
      id: id,
      userId: map['userId'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      // ...
    );
  }

  // Firestore へ書き込み
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      // ...
    };
  }

  // イミュータブルなコピー
  XxxModel copyWith({String? userId, DateTime? updatedAt, ...}) {
    return XxxModel(
      id: id,
      userId: userId ?? this.userId,
      updatedAt: updatedAt ?? this.updatedAt,
      // ...
    );
  }
}
```

### 主要な Enum 一覧

| Enum | 主な値 | 格納形式（Firestore） |
|------|--------|---------------------|
| `MaintenanceType` | oilChange, inspection, tireRotation ... (30種) | 文字列 `'oilChange'` |
| `ShopType` | maintenanceShop, dealer, partsShop, customShop ... | 文字列 |
| `ServiceCategory` | inspection, maintenance, repair, tire ... | 文字列リスト |
| `InquiryType` | estimate, appointment, partInquiry, serviceInquiry ... | 文字列 |
| `InquiryStatus` | pending, inProgress, replied, closed, cancelled | 文字列 |
| `PartCategory` | exhaust, brake, suspension, interior ... (17種) | 文字列 |
| `FuelType` | gasoline, diesel, hybrid, electric, phev, hydrogen | 文字列 |
| `AuthErrorType` | invalidCredentials, userNotFound, emailAlreadyInUse ... (7種) | Dart 内部のみ |

---

## 8. 画面層（Screens）

### ナビゲーション構造

```
AuthWrapper
  │
  ├─ [未認証] LoginScreen
  │     └─ SignUpScreen（ナビゲーション push）
  │
  └─ [認証済み] HomeScreen（BottomNavigationBar 4タブ）
        │
        ├─ Tab 0: マイカー（index 0）
        │     │  FAB → VehicleRegistrationScreen
        │     └─ VehicleDetailScreen（車両タップ）
        │           ├─ VehicleEditScreen
        │           ├─ AddMaintenanceScreen（整備追加）
        │           ├─ MaintenanceStatsScreen（年間統計）
        │           ├─ PartRecommendationScreen
        │           └─ DocumentScannerScreen
        │                 └─ VehicleCertificateResultScreen
        │
        ├─ Tab 1: マーケット（index 1）
        │     └─ MarketplaceScreen（TabBar 2タブ）
        │           ├─ ShopListScreen（工場・業者）
        │           │     └─ ShopDetailScreen
        │           │           └─ InquiryScreen
        │           └─ PartListScreen（パーツ）
        │
        ├─ Tab 2: 通知（index 2）
        │     └─ NotificationListScreen
        │
        └─ Tab 3: プロフィール（index 3）
              ├─ ProfileScreen
              └─ SettingsScreen
```

### 各画面の役割・依存 Provider

| 画面 | 使用 Provider | 主な機能 |
|------|-------------|---------|
| `HomeScreen` | AuthProvider | タブ切り替え。Tab 0 のみ FAB 表示。Tab 2（通知）に「すべて既読」ボタン |
| `VehicleDetailScreen` | VehicleProvider, MaintenanceProvider | 整備タイムライン、期限アラート、AI 推薦表示 |
| `VehicleEditScreen` | VehicleProvider | 車両情報編集。VehicleMasterService で maker/model ドロップダウン |
| `AddMaintenanceScreen` | MaintenanceProvider | 22種の整備タイプ選択、コスト・走行距離入力 |
| `MaintenanceStatsScreen` | MaintenanceProvider | 年間コスト推移・月別・タイプ別グラフ |
| `ShopListScreen` | ShopProvider | 業種/サービス/地域の 3段 Dropdown フィルタ |
| `ShopDetailScreen` | ShopProvider | 画像カルーセル、星評価、ExpansionTile 営業時間 |
| `InquiryScreen` | ShopProvider | ChoiceChip 種別選択、500 字カウンタ、ミニカード表示 |
| `PartListScreen` | PartRecommendationProvider | 17 カテゴリ Chip、キーワード検索、互換性バッジ |
| `NotificationListScreen` | NotificationProvider | 通知一覧、既読マーク |

---

## 9. Firebase 構成

### Firestore コレクション構造

```
users/{userId}
vehicles/{vehicleId}
maintenance_records/{recordId}
documents/{documentId}
invoices/{invoiceId}
notifications/{notificationId}
shops/{shopId}
service_menus/{menuId}
part_listings/{partId}
inquiries/{inquiryId}
  └─ messages/{messageId}     ← サブコレクション
posts/{postId}
post_likes/{postId_userId}
comments/{commentId}
follows/{followId}
drive_logs/{logId}
drive_waypoints/{waypointId}  ← driveLogId フィールドで紐付け
spots/{spotId}
```

### Firestore Security Rules 概要

```javascript
// ヘルパー関数
function isAuthenticated()       { return request.auth != null; }
function isDocumentOwner()       { return resource.data.userId == request.auth.uid; }
function isCreatingOwnDocument() { return request.resource.data.userId == request.auth.uid; }

// コレクション別ルール（抜粋）
users/{userId}:
  read, update: userId == auth.uid のみ

vehicles/*:
  read, update, delete: isDocumentOwner()
  create: isCreatingOwnDocument()

shops/*:
  read: isAuthenticated()（全員閲覧可）
  create: shopId == auth.uid（1ユーザー1店舗モデル）
  update, delete: shopId == auth.uid

drive_waypoints/*:          ← 位置情報最優先で保護
  全操作: resource.data.userId == auth.uid

inquiries/messages/*:
  read: senderId == auth.uid || receiverId == auth.uid
  create: request.resource.data.senderId == auth.uid
  update: receiverId のみ isRead/readAt フィールド変更可
  delete: 不可
```

### Firestore 複合インデックス（15 件）

複合クエリを実行するには必ずインデックスが必要。`firestore.indexes.json` で管理。

```
vehicles:            userId + createdAt DESC
maintenance_records: vehicleId + date DESC
                     vehicleId + type + date DESC
shops:               isActive + isFeatured DESC + rating DESC
                     isActive + type + isFeatured DESC
                     isActive + prefecture + isFeatured DESC
part_listings:       isActive + isFeatured DESC + rating DESC
                     isActive + category + isFeatured DESC + rating DESC
inquiries:           userId + createdAt DESC
                     shopId + createdAt DESC
posts:               userId + createdAt DESC
                     visibility + createdAt DESC
notifications:       userId + isRead + createdAt DESC
drive_logs:          userId + startedAt DESC
vehicle_listings:    isActive + createdAt DESC
```

> **注意**: フィルタ条件が増えて Firestore が `FAILED_PRECONDITION` を返した場合、インデックスが不足している。エラーメッセージに記載されている URL を開くと Firebase Console でワンクリック作成できる。作成後 `firestore.indexes.json` にも追記すること。

### Firebase サービス別用途

| サービス | 用途 | 設定 |
|---------|------|------|
| Firestore | データ永続化・リアルタイム同期 | offline persistence 100MB |
| Auth | メール/パスワード・Google OAuth | セッション永続化 |
| Storage | 車両画像・書類スキャン画像 | — |
| Messaging (FCM) | プッシュ通知 | PushNotificationService 経由 |
| Crashlytics | クラッシュ報告 | Release mode のみ有効 |
| Performance | パフォーマンス計測 | PerformanceService 経由 |

---

## 10. バグ調査チートシート

### エラー発生時のトレース手順

```
① UI でエラーメッセージが表示される
        ↓
② Provider の _error 変数を確認（= AppError.userMessage の文字列）
        ↓
③ AppError の型を特定して原因を絞る
   ├─ PermissionError  → firestore.rules を確認、auth.uid とドキュメントの userId を照合
   ├─ NetworkError     → isOnline（ConnectivityProvider）を確認、Firebase ステータス確認
   ├─ NotFoundError    → ドキュメント ID が正しいか、削除済みでないか確認
   ├─ AuthError        → AuthErrorType を確認（sessionExpired なら再ログイン要求）
   └─ UnknownError     → error.originalError.toString() でスタックトレースを見る
        ↓
④ LoggingService / Crashlytics のログを確認
        ↓
⑤ Firebase Emulator で再現する
   firebase emulators:start --only firestore,auth
   flutter test test/integration/
```

### よくあるバグパターンと対処

#### パターン A: データが画面に反映されない

```
原因候補:
  1. notifyListeners() が呼ばれていない
  2. Consumer の範囲が間違っている（build メソッドの外で watch している）
  3. Result.success は返っているが _items への代入が抜けている

確認方法:
  Provider の該当メソッドを追い、notifyListeners() 直前に
  print(_items.length) を入れて確認する
```

#### パターン B: Firestore にデータが保存されない

```
原因候補:
  1. Security rules で弾かれている → PermissionError
  2. toMap() の中に DateTime が Timestamp に変換されていないフィールドがある
  3. ネットワーク不通（offline cache に pending write として積まれている）

確認手順:
  1. flutter run のコンソールで PermissionError を探す
  2. firestore.rules の当該コレクションのルールを確認
  3. Firebase Emulator Console（localhost:4000）でドキュメントを直接確認
```

#### パターン C: ログインができない

```
AuthError.type 別の対処:
  invalidCredentials → パスワード間違い or 未登録メール
  emailAlreadyInUse  → SignUp 時に既存メールを使用
  sessionExpired     → AuthProvider.refreshUser() を呼ぶ or 再ログイン
  tooManyRequests    → isRetryable: true → 一定時間後に自動リトライ可能
  userNotFound       → ユーザーが削除されている
```

#### パターン D: 画像が表示されない

```
原因候補:
  1. imageUrl が null（フォームで未選択のまま保存）
  2. Firebase Storage URL が期限切れ
  3. CachedNetworkImage のキャッシュが古い

確認:
  Vehicle.imageUrl や MaintenanceRecord.imageUrls が null でないか確認
  → null 許容フィールドなので UI 側でフォールバック画像を必ず用意する
```

#### パターン E: Firestore クエリが遅い / エラーになる

```
"FAILED_PRECONDITION" エラー → インデックス不足

対処:
  1. エラーメッセージ内の URL を Firebase Console で開く
  2. ワンクリックでインデックスを作成
  3. firestore.indexes.json に同じ定義を追記
  4. firebase deploy --only firestore:indexes でデプロイ
```

#### パターン F: テストが通らない

```
単体テスト（providers/）:
  - MockService の戻り値設定（xxxResult = Result.success(...)）を確認
  - notifyListeners() の呼び出し回数を addListener でトレース

統合テスト（integration/）:
  - Firebase Emulator が起動しているか確認
    → firebase emulators:start --only firestore,auth
  - setUp で clearFirestore() が呼ばれているか確認
  - @Tags(['emulator']) アノテーションが付いているか確認
  - shops/part_listings/inquiries は clearFirestore() でクリアされないため
    テスト内で _clearExtra(firestore) を呼ぶ（user_scenario_integration_test.dart 参照）
```

### ファイル別クイックリファレンス

| 調べたいこと | 参照ファイル |
|------------|-------------|
| DI 登録順・新 Service 追加 | `lib/core/di/injection.dart` |
| エラー変換ロジック | `lib/core/error/app_error.dart` の `mapFirebaseError()` |
| Result のメソッド一覧 | `lib/core/result/result.dart` |
| 起動フロー全体 | `lib/main.dart` |
| 車両・整備の Firestore 操作 | `lib/services/firebase_service.dart` |
| 認証フロー | `lib/services/auth_service.dart` |
| 整備推奨ルール（12 種） | `lib/services/recommendation_service.dart` |
| Firestore セキュリティルール | `firestore.rules` |
| Firestore インデックス定義 | `firestore.indexes.json` |
| CI/CD パイプライン | `.github/workflows/ci.yml` |
| デプロイ準備評価 | `docs/DEPLOY_READINESS_REPORT.md` |
| テスト戦略 | `docs/TEST_REPORT.md` |

---

## 11. 新機能追加チェックリスト

```
□ 1. Model 作成
      lib/models/xxx.dart に XxxModel を追加
      fromMap(map, id) / toMap() / copyWith() を実装
      Enum が必要な場合は同ファイル内または別ファイルに定義

□ 2. Service 作成
      lib/services/xxx_service.dart に XxxService を追加
      全メソッドの戻り値を Result<T, AppError> に統一
      例外は必ず catch して mapFirebaseError(e) で変換

□ 3. DI 登録
      lib/core/di/injection.dart に追記:
      locator.registerLazySingleton<XxxService>(() => XxxService());

□ 4. Provider 作成（状態管理が必要な場合）
      lib/providers/xxx_provider.dart に XxxProvider を追加
      コンストラクタで XxxService を受け取る（new しない）

□ 5. MultiProvider 登録（Provider を追加した場合）
      lib/main.dart の providers リストに追加:
      ChangeNotifierProvider(
        create: (_) => XxxProvider(xxxService: sl.get<XxxService>()),
      )

□ 6. Firestore インデックス追加（複合クエリを使う場合）
      firestore.indexes.json に定義を追加
      firebase deploy --only firestore:indexes でデプロイ

□ 7. Firestore セキュリティルール更新
      firestore.rules に新コレクションのルールを追加
      firebase deploy --only firestore:rules でデプロイ

□ 8. テスト作成（TDD: RED → GREEN → REFACTOR）
      test/services/xxx_service_test.dart
      test/providers/xxx_provider_test.dart
      test/integration/xxx_integration_test.dart（Firebase 操作がある場合）

□ 9. 静的解析クリア
      flutter analyze
      → 警告・エラーが 0 件であることを確認

□ 10. CLAUDE_SESSION_NOTES.md 更新
       今回の設計決定事項を記録
```
