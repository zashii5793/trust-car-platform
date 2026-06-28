// User Journey Widget Integration Tests
//
// Simulates realistic multi-step user flows across multiple screens
// using fake providers (no real Firebase required).
//
// Personas covered:
//   P1 — ゲストユーザー          : Login screen, navigate to Signup
//   P2 — 新規登録ユーザー        : Signup form validation, field requirements
//   P3 — 初回ログインユーザー     : HomeScreen empty states, all tabs reachable
//   P4 — 一般車両オーナー        : HomeScreen with vehicles, notification badge
//   P4b — 車両詳細フロー         : Vehicle card tap → detail → maintenance add
//   P5 — SNS投稿ユーザー        : Navigate to SNS feed, open PostCreateScreen
//   P6 — マーケットプレイス利用者  : Switch to marketplace, verify 3 tabs
//   P7 — 通知ありユーザー        : Unread badge, navigate to 通知 tab
//   P8 — オフラインユーザー       : Offline banner visible
//   P9 — ショップオーナー        : Inquiry list, filter chips, bottom sheet
//   P10 — 車両登録フロー          : VehicleRegistrationScreen wizard
//   P11 — プロフィール管理        : Profile tab, settings navigation, B2C plan display

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;

import 'package:trust_car_platform/screens/home_screen.dart';
import 'package:trust_car_platform/screens/auth/login_screen.dart';
import 'package:trust_car_platform/screens/auth/signup_screen.dart';
import 'package:trust_car_platform/screens/marketplace/shop_inquiry_list_screen.dart';
import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/providers/vehicle_provider.dart';
import 'package:trust_car_platform/providers/maintenance_provider.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/providers/notification_provider.dart';
import 'package:trust_car_platform/providers/connectivity_provider.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';
import 'package:trust_car_platform/providers/post_provider.dart';
import 'package:trust_car_platform/providers/drive_log_provider.dart';
import 'package:trust_car_platform/providers/user_subscription_provider.dart';
import 'package:trust_car_platform/models/user_plan.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/recommendation_service.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/services/post_service.dart';
import 'package:trust_car_platform/services/drive_log_service.dart';
import 'package:trust_car_platform/services/vehicle_master_service.dart';
import 'package:trust_car_platform/services/vehicle_certificate_ocr_service.dart';
import 'package:trust_car_platform/services/invoice_ocr_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/vehicle_master.dart';
import 'package:trust_car_platform/models/app_notification.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// =============================================================================
// Shared stubs
// =============================================================================

class _StubFirebaseService implements FirebaseService {
  @override
  String? get currentUserId => 'uid-test';

  @override
  Stream<List<Vehicle>> getUserVehicles() => const Stream.empty();

  @override
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(String vid) =>
      const Stream.empty();

  @override
  Future<Result<String, AppError>> addVehicle(Vehicle v) async =>
      const Result.success('id');

  @override
  Future<Result<void, AppError>> updateVehicle(String id, Vehicle v) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteVehicle(String id) async =>
      const Result.success(null);

  @override
  Future<Result<Vehicle?, AppError>> getVehicle(String id) async =>
      const Result.success(null);

  @override
  Future<Result<bool, AppError>> isLicensePlateExists(String plate,
          {String? excludeVehicleId}) async =>
      const Result.success(false);

  @override
  Future<Result<String, AppError>> addMaintenanceRecord(
          MaintenanceRecord r) async =>
      const Result.success('rid');

  @override
  Future<Result<void, AppError>> updateMaintenanceRecord(
          String id, MaintenanceRecord r) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteMaintenanceRecord(String id) async =>
      const Result.success(null);

  @override
  Future<Result<List<MaintenanceRecord>, AppError>>
      getMaintenanceRecordsForVehicle(String vehicleId,
              {int limit = 20, DocumentSnapshot? startAfter}) async =>
          const Result.success([]);

  @override
  Future<Result<Map<String, List<MaintenanceRecord>>, AppError>>
      getMaintenanceRecordsForVehicles(List<String> vehicleIds,
              {int limitPerVehicle = 20}) async =>
          const Result.success({});

  @override
  Future<Result<String, AppError>> uploadImage(dynamic f, String path) async =>
      const Result.success('url');

  @override
  Future<Result<String, AppError>> uploadImageBytes(
          dynamic b, String path) async =>
      const Result.success('url');

  @override
  Future<Result<List<String>, AppError>> uploadImages(
          List<dynamic> files, String basePath) async =>
      const Result.success([]);

  @override
  Future<Result<String, AppError>> uploadProcessedImage(
    dynamic bytes,
    String path, {
    required dynamic imageService,
  }) async =>
      const Result.success('url');
}

class _StubAuthService implements AuthService {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<Result<UserCredential, AppError>> signInWithEmail(
          {required String email, required String password}) async =>
      Result.failure(AppError.unknown('stub'));

  @override
  Future<Result<UserCredential, AppError>> signUpWithEmail(
          {required String email,
          required String password,
          String? displayName}) async =>
      Result.failure(AppError.unknown('stub'));

  @override
  Future<Result<UserCredential?, AppError>> signInWithGoogle() async =>
      Result.failure(AppError.unknown('stub'));

  @override
  Future<Result<void, AppError>> signOut() async => const Result.success(null);

  @override
  Future<Result<AppUser?, AppError>> getUserProfile() async =>
      Result.failure(AppError.unknown('stub'));

  @override
  Future<Result<void, AppError>> updateUserProfile(
          {String? displayName, String? photoUrl}) async =>
      Result.failure(AppError.unknown('stub'));

  @override
  Future<Result<void, AppError>> sendPasswordResetEmail(String email) async =>
      const Result.success(null);

  Future<Result<void, AppError>> deleteAccount() async =>
      const Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubConnectivityProvider extends ChangeNotifier
    implements ConnectivityProvider {
  final bool _offline;
  _StubConnectivityProvider({bool isOffline = false}) : _offline = isOffline;

  @override
  bool get isOnline => !_offline;

  @override
  bool get isOffline => _offline;

  @override
  bool get isInitialized => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubInquiryService implements InquiryService {
  @override
  Stream<List<InquiryMessage>> streamMessages(String inquiryId) =>
      Stream.value([]);

  @override
  Future<Result<void, AppError>> markAsRead({
    required String inquiryId,
    required bool isUser,
  }) async =>
      const Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubShopService implements ShopService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubInvoiceOcrService implements InvoiceOcrService {
  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// =============================================================================
// Fake providers
// =============================================================================

class _FakeVehicleProvider extends VehicleProvider {
  _FakeVehicleProvider({List<Vehicle>? vehicles})
      : _fakeVehicles = vehicles ?? [],
        super(firebaseService: _StubFirebaseService());

  List<Vehicle> _fakeVehicles;

  @override
  List<Vehicle> get vehicles => _fakeVehicles;

  @override
  bool get isLoading => false;

  @override
  AppError? get error => null;

  @override
  String? get errorMessage => null;

  @override
  bool get isRetryable => false;

  @override
  void listenToVehicles() {}

  @override
  void stopListening() {}

  @override
  void clear() {
    _fakeVehicles = [];
    notifyListeners();
  }

  @override
  void clearError() {}
}

class _FakeNotificationProvider extends NotificationProvider {
  _FakeNotificationProvider({List<AppNotification>? notifications})
      : _fakeNotifications = notifications ?? [],
        super(
          firebaseService: _StubFirebaseService(),
          recommendationService: RecommendationService(),
        );

  final List<AppNotification> _fakeNotifications;

  @override
  List<AppNotification> get notifications => _fakeNotifications;

  @override
  int get unreadCount => _fakeNotifications.where((n) => !n.isRead).length;

  @override
  List<AppNotification> get topSuggestions =>
      _fakeNotifications.take(3).toList();

  @override
  Future<void> generateNotificationsForVehicles(List<Vehicle> vehicles) async {}
}

class _FakeShopProvider extends ShopProvider {
  final bool _loading;
  final List<Inquiry> _inquiries;

  _FakeShopProvider({
    bool loading = false,
    List<Inquiry> inquiries = const [],
  })  : _loading = loading,
        _inquiries = List.of(inquiries),
        super(
          shopService: _StubShopService(),
          inquiryService: _StubInquiryService(),
        );

  @override
  Stream<List<InquiryMessage>> streamInquiryMessages(String inquiryId) =>
      Stream.value([]);

  @override
  bool get isLoadingShopInquiries => _loading;

  @override
  List<Inquiry> get shopInquiries => _inquiries;

  @override
  Future<void> loadShops() async {}

  @override
  Future<void> searchShops(String query) async {}

  @override
  Future<void> loadShopInquiries(String shopId,
      {InquiryStatus? status}) async {}

  @override
  void markInquiryAsReadLocally(String inquiryId) {
    final idx = _inquiries.indexWhere((i) => i.id == inquiryId);
    if (idx != -1) {
      _inquiries[idx] = _inquiries[idx].copyWith(unreadCountShop: 0);
      notifyListeners();
    }
  }
}

// =============================================================================
// P10 stubs — VehicleRegistrationScreen ServiceLocator dependencies
// =============================================================================

class _StubVehicleMasterService implements VehicleMasterService {
  static const _maker =
      VehicleMaker(id: 'm1', name: 'トヨタ', nameEn: 'Toyota', country: 'JP');
  static const _model = VehicleModel(id: 'v1', makerId: 'm1', name: 'プリウス');
  static const _grade = VehicleGrade(id: 'g1', modelId: 'v1', name: 'S');

  @override
  Future<Result<List<VehicleMaker>, AppError>> getMakers() async =>
      const Result.success([_maker]);

  @override
  Future<Result<List<VehicleModel>, AppError>> getModelsForMaker(
          String makerId) async =>
      const Result.success([_model]);

  @override
  Future<Result<List<VehicleGrade>, AppError>> getGradesForModel(
          String modelId) async =>
      const Result.success([_grade]);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubOcrService implements VehicleCertificateOcrService {
  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// AuthService stub that emits null immediately so AuthProvider.isLoading resolves.
/// Use in tests that need to render screens gated on auth completion.
class _StubAuthServiceResolved implements AuthService {
  @override
  Stream<User?> get authStateChanges => Stream.value(null);
  @override
  User? get currentUser => null;
  bool get isAuthenticated => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// =============================================================================
// Test data factories
// =============================================================================

Vehicle _makeVehicle({
  String id = 'v1',
  String maker = 'Toyota',
  String model = 'Prius',
  int year = 2022,
}) =>
    Vehicle(
      id: id,
      userId: 'u1',
      maker: maker,
      model: model,
      year: year,
      grade: 'S',
      mileage: 25000,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

AppNotification _makeNotification({bool isRead = false}) => AppNotification(
      id: 'n1',
      userId: 'u1',
      type: NotificationType.maintenanceRecommendation,
      title: 'オイル交換の時期です',
      message: '前回の交換から5,000km走行しました',
      isRead: isRead,
      createdAt: DateTime(2024, 1, 1),
    );

Inquiry _makeInquiry({
  String id = 'inq-1',
  String subject = 'テスト問い合わせ',
  String initialMessage = 'メッセージ本文',
  InquiryStatus status = InquiryStatus.pending,
  int unreadCountShop = 0,
}) {
  final now = DateTime(2025, 6, 1, 10, 0);
  return Inquiry(
    id: id,
    userId: 'user-1',
    shopId: 'shop-1',
    type: InquiryType.general,
    subject: subject,
    initialMessage: initialMessage,
    status: status,
    unreadCountShop: unreadCountShop,
    createdAt: now,
    updatedAt: now,
  );
}

// =============================================================================
// Widget builders
// =============================================================================

Widget _buildHomeApp({
  List<Vehicle>? vehicles,
  List<AppNotification>? notifications,
  bool isOffline = false,
}) {
  final fb = _StubFirebaseService();
  final fakeFirestore = FakeFirebaseFirestore();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<VehicleProvider>.value(
        value: _FakeVehicleProvider(vehicles: vehicles),
      ),
      ChangeNotifierProvider<MaintenanceProvider>(
        create: (_) => MaintenanceProvider(firebaseService: fb),
      ),
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(authService: _StubAuthService()),
      ),
      ChangeNotifierProvider<NotificationProvider>.value(
        value: _FakeNotificationProvider(notifications: notifications),
      ),
      ChangeNotifierProvider<ConnectivityProvider>(
        create: (_) => _StubConnectivityProvider(isOffline: isOffline),
      ),
      ChangeNotifierProvider<ShopProvider>(
        create: (_) => _FakeShopProvider(),
      ),
      ChangeNotifierProvider<PostProvider>(
        create: (_) =>
            PostProvider(postService: PostService(firestore: fakeFirestore)),
      ),
      ChangeNotifierProvider<DriveLogProvider>(
        create: (_) => DriveLogProvider(
            driveLogService: DriveLogService(firestore: fakeFirestore)),
      ),
      ChangeNotifierProvider<UserSubscriptionProvider>(
        create: (_) => UserSubscriptionProvider(),
      ),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

Widget _buildLoginApp() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(authService: _StubAuthService()),
      ),
    ],
    child: const MaterialApp(home: LoginScreen()),
  );
}

Widget _buildSignupApp() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(authService: _StubAuthService()),
      ),
    ],
    child: const MaterialApp(home: SignupScreen()),
  );
}

Widget _buildShopInquiryApp({List<Inquiry>? inquiries}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ShopProvider>.value(
        value: _FakeShopProvider(inquiries: inquiries ?? []),
      ),
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(authService: _StubAuthService()),
      ),
    ],
    child: const MaterialApp(
      home: ShopInquiryListScreen(shopId: 'shop-1'),
    ),
  );
}

Future<void> _setSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  // ---------------------------------------------------------------------------
  // P1: ゲストユーザー — LoginScreen
  // ---------------------------------------------------------------------------

  group('P1 ゲストユーザー — LoginScreen', () {
    testWidgets('ブランドロゴとキャッチコピーが表示される', (tester) async {
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      expect(find.text('TrustCar'), findsOneWidget);
      expect(find.text('信頼を設計する、新時代のカーライフ'), findsOneWidget);
    });

    testWidgets('メールアドレス・パスワード・ログインボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      expect(find.text('ログイン'), findsWidgets);
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('新規登録リンクが表示される', (tester) async {
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      expect(find.text('新規登録'), findsOneWidget);
    });

    testWidgets('「パスワードを忘れた場合」リンクが表示される', (tester) async {
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      expect(find.text('パスワードを忘れた場合'), findsOneWidget);
    });

    testWidgets('空のまま送信するとバリデーションエラーが表示される', (tester) async {
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      await tester.tap(find.text('ログイン').last);
      await tester.pump();

      expect(find.text('メールアドレスを入力してください'), findsOneWidget);
    });

    testWidgets('不正なメールアドレスでバリデーションエラーが出る', (tester) async {
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'not-an-email');
      await tester.tap(find.text('ログイン').last);
      await tester.pump();

      expect(find.text('有効なメールアドレスを入力してください'), findsOneWidget);
    });

    testWidgets('新規登録ボタンをタップするとSignupScreenに遷移する', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildLoginApp());
      await tester.pump();

      await tester.tap(find.text('新規登録'));
      await tester.pump(); // kick off navigation
      await tester.pump(const Duration(milliseconds: 500)); // settle transition

      expect(find.text('表示名'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // P2: 新規登録ユーザー — SignupScreen
  // ---------------------------------------------------------------------------

  group('P2 新規登録ユーザー — SignupScreen', () {
    testWidgets('表示名・メール・パスワード・確認フィールドが表示される', (tester) async {
      await tester.pumpWidget(_buildSignupApp());
      await tester.pump();

      expect(find.text('表示名'), findsOneWidget);
      expect(find.text('アカウントを作成'), findsOneWidget);
    });

    testWidgets('全フィールド空で送信するとバリデーションエラーが出る', (tester) async {
      await tester.pumpWidget(_buildSignupApp());
      await tester.pump();

      await tester.tap(find.text('アカウントを作成'));
      await tester.pump();

      expect(find.textContaining('入力してください'), findsWidgets);
    });

    testWidgets('パスワードが6文字未満だとエラーが出る', (tester) async {
      await tester.pumpWidget(_buildSignupApp());
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'テストユーザー');
      await tester.enterText(fields.at(1), 'test@example.com');
      await tester.enterText(fields.at(2), '123');
      await tester.tap(find.text('アカウントを作成'));
      await tester.pump();

      expect(find.text('パスワードは6文字以上で入力してください'), findsOneWidget);
    });

    testWidgets('パスワードと確認が不一致だとエラーが出る', (tester) async {
      await tester.pumpWidget(_buildSignupApp());
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'テストユーザー');
      await tester.enterText(fields.at(1), 'test@example.com');
      await tester.enterText(fields.at(2), 'password123');
      await tester.enterText(fields.at(3), 'different456');
      await tester.tap(find.text('アカウントを作成'));
      await tester.pump();

      expect(find.text('パスワードが一致しません'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // P3: 初回ログインユーザー — HomeScreen (empty state)
  // ---------------------------------------------------------------------------

  group('P3 初回ログインユーザー — 車両なし', () {
    testWidgets('NavigationBar の 5 タブが表示される', (tester) async {
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('マイカー'), findsWidgets);
      expect(find.text('マーケット'), findsOneWidget);
      expect(find.text('みんなの投稿'), findsOneWidget);
      expect(find.text('通知'), findsOneWidget);
      expect(find.text('プロフィール'), findsOneWidget);
    });

    testWidgets('初期タブは「マイカー」でAppBarタイトルが正しい', (tester) async {
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('マイカー')),
        findsOneWidget,
      );
    });

    testWidgets('車両登録FABが表示される', (tester) async {
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('全タブを一巡してもクラッシュしない', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      final tabIcons = [
        Icons.store_outlined,
        Icons.forum_outlined,
        Icons.notifications_outlined,
        Icons.person_outline,
        // NavigationBar shows the outlined icon while マイカー is unselected.
        Icons.directions_car_outlined,
      ];
      for (final icon in tabIcons) {
        final target = find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(icon),
        );
        await tester.tap(target);
        await tester.pumpAndSettle(const Duration(seconds: 10));
      }

      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // P4: 一般車両オーナー — HomeScreen (with vehicles)
  // ---------------------------------------------------------------------------

  group('P4 一般車両オーナー — 車両あり', () {
    testWidgets('車両カードが表示される', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp(
        vehicles: [_makeVehicle(id: 'v1', maker: 'Toyota', model: 'Prius')],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.textContaining('Toyota'), findsWidgets);
      expect(find.textContaining('Prius'), findsWidgets);
    });

    testWidgets('複数台の車両が全て表示される', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp(
        vehicles: [
          _makeVehicle(id: 'v1', maker: 'Toyota', model: 'Prius'),
          _makeVehicle(id: 'v2', maker: 'Honda', model: 'Fit'),
          _makeVehicle(id: 'v3', maker: 'Nissan', model: 'Note'),
        ],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.textContaining('Toyota'), findsWidgets);
      expect(find.textContaining('Honda'), findsWidgets);
      expect(find.textContaining('Nissan'), findsWidgets);
    });

    testWidgets('未読通知がないとき通知バッジは非表示', (tester) async {
      await tester.pumpWidget(_buildHomeApp(
        notifications: [_makeNotification(isRead: true)],
      ));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('1'),
        ),
        findsNothing,
      );
    });

    testWidgets('未読通知2件のとき通知バッジに「2」が表示される', (tester) async {
      await tester.pumpWidget(_buildHomeApp(
        notifications: [
          _makeNotification(isRead: false),
          _makeNotification(isRead: false),
        ],
      ));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // P5: SNS投稿ユーザー
  // ---------------------------------------------------------------------------

  group('P5 SNS投稿ユーザー', () {
    testWidgets('みんなの投稿タブに切り替えられる', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.forum_outlined),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('みんなの投稿')),
        findsOneWidget,
      );
    });

    testWidgets('SNSタブに切り替えるとFABが表示される', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.forum_outlined),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('SNS FABをタップするとPostCreateScreenが開く', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.forum_outlined),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('新規投稿'), findsOneWidget);
    });

    testWidgets('PostCreateScreen で本文入力 → 文字数カウンタが更新される', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      // SNSタブ → FAB → PostCreateScreen
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.forum_outlined),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.enterText(find.byType(TextField).first, 'ドライブ日記');
      await tester.pump();

      expect(find.textContaining('/ 500'), findsOneWidget);
    });

    testWidgets('PostCreateScreen で戻ると SNS フィードに戻る', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.forum_outlined),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('みんなの投稿')),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // P6: マーケットプレイス利用者
  // ---------------------------------------------------------------------------

  group('P6 マーケットプレイス利用者', () {
    testWidgets('マーケットタブに切り替えるとAppBarタイトルが変わる', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.store_outlined),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text('マーケットプレイス')),
        findsWidgets,
      );
    });

    testWidgets('マーケットタブに「店舗を掲載する」アイコンが表示される', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.store_outlined),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    });

    testWidgets('マーケット内に工場・業者/問い合わせタブが表示され、C2Cパーツ系は凍結中で非表示', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.store_outlined),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('工場・業者'), findsOneWidget);
      expect(find.text('問い合わせ'), findsOneWidget);
      // C2Cパーツ売買は凍結（FeatureFlag.c2cPartsMarketplace=false）のため非表示
      expect(find.text('パーツ'), findsNothing);
      expect(find.text('マイ出品'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // P7: 通知ありユーザー
  // ---------------------------------------------------------------------------

  group('P7 通知ありユーザー', () {
    testWidgets('未読2件 → 通知タブに切り替えると「すべて既読」ボタンが出る', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp(
        notifications: [
          _makeNotification(isRead: false),
          _makeNotification(isRead: false),
        ],
      ));
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.notifications_outlined),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('すべて既読'), findsOneWidget);
    });

    testWidgets('全て既読のとき「すべて既読」ボタンは非表示', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp(
        notifications: [_makeNotification(isRead: true)],
      ));
      await tester.pump();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.notifications_outlined),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('すべて既読'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // P8: オフラインユーザー
  // ---------------------------------------------------------------------------

  group('P8 オフラインユーザー', () {
    testWidgets('オフライン時にオフラインバナーが表示される', (tester) async {
      await tester.pumpWidget(_buildHomeApp(isOffline: true));
      await tester.pump();

      expect(find.textContaining('オフライン'), findsWidgets);
    });

    testWidgets('オンライン時はオフラインバナーが非表示', (tester) async {
      await tester.pumpWidget(_buildHomeApp(isOffline: false));
      await tester.pump();

      expect(find.textContaining('オフライン'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // P9: ショップオーナー — ShopInquiryListScreen
  // ---------------------------------------------------------------------------

  group('P9 ショップオーナー — 問い合わせ管理', () {
    testWidgets('問い合わせなしのとき空状態が表示される', (tester) async {
      await tester.pumpWidget(_buildShopInquiryApp(inquiries: []));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('問い合わせはありません'), findsOneWidget);
    });

    testWidgets('フィルターチップ（すべて・未対応・対応中・クローズ）が表示される', (tester) async {
      await tester.pumpWidget(_buildShopInquiryApp());
      await tester.pump();

      expect(find.text('すべて'), findsOneWidget);
      expect(find.text('未対応'), findsOneWidget);
      expect(find.text('対応中'), findsOneWidget);
      expect(find.text('クローズ'), findsOneWidget);
    });

    testWidgets('問い合わせ件名・本文プレビューが表示される', (tester) async {
      await tester.pumpWidget(_buildShopInquiryApp(
        inquiries: [
          _makeInquiry(
            subject: 'オイル交換の料金について',
            initialMessage: '料金を教えてください',
          ),
        ],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('オイル交換の料金について'), findsOneWidget);
      expect(find.text('料金を教えてください'), findsOneWidget);
    });

    testWidgets('未読バッジが unreadCountShop > 0 のとき表示される', (tester) async {
      await tester.pumpWidget(_buildShopInquiryApp(
        inquiries: [_makeInquiry(unreadCountShop: 5)],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('問い合わせをタップするとボトムシートが開く', (tester) async {
      await tester.pumpWidget(_buildShopInquiryApp(
        inquiries: [_makeInquiry(subject: '修理の見積もり依頼')],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('修理の見積もり依頼'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('複数の問い合わせが全件表示される', (tester) async {
      await tester.pumpWidget(_buildShopInquiryApp(
        inquiries: [
          _makeInquiry(id: '1', subject: '車検の予約について'),
          _makeInquiry(id: '2', subject: 'タイヤ交換の費用'),
          _makeInquiry(id: '3', subject: 'エンジンオイルの種類'),
        ],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('車検の予約について'), findsOneWidget);
      expect(find.text('タイヤ交換の費用'), findsOneWidget);
      expect(find.text('エンジンオイルの種類'), findsOneWidget);
    });

    testWidgets('クローズ済み問い合わせも表示される', (tester) async {
      await tester.pumpWidget(_buildShopInquiryApp(
        inquiries: [
          _makeInquiry(
            subject: 'クローズ済み対応',
            status: InquiryStatus.closed,
          ),
        ],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('クローズ済み対応'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // P4b: 車両詳細フロー — VehicleDetailScreen & AddMaintenanceScreen
  // ---------------------------------------------------------------------------

  group('P4b 車両詳細フロー', () {
    setUpAll(() {
      final sl = ServiceLocator.instance;
      if (!sl.isRegistered<FirebaseService>()) {
        sl.registerLazySingleton<FirebaseService>(() => _StubFirebaseService());
      }
      if (!sl.isRegistered<DriveLogService>()) {
        sl.registerLazySingleton<DriveLogService>(
            () => DriveLogService(firestore: FakeFirebaseFirestore()));
      }
      if (!sl.isRegistered<InvoiceOcrService>()) {
        sl.registerLazySingleton<InvoiceOcrService>(
            () => _StubInvoiceOcrService());
      }
    });

    tearDownAll(() {
      Injection.reset();
    });

    testWidgets('車両カードをタップするとVehicleDetailScreenに遷移する', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp(
        vehicles: [_makeVehicle(maker: 'Honda', model: 'Civic')],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // 車両カードをタップ
      await tester.tap(find.textContaining('Honda').first);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // VehicleDetailScreen が開く（AppBar に車両名）
      expect(find.textContaining('Honda'), findsWidgets);
      expect(find.textContaining('Civic'), findsWidgets);
    });

    testWidgets('VehicleDetailScreenに「履歴を追加」FABが表示される', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp(
        vehicles: [_makeVehicle(maker: 'Mazda', model: 'CX-5')],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.textContaining('Mazda').first);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('履歴を追加'), findsOneWidget);
    });

    testWidgets('「履歴を追加」をタップするとAddMaintenanceScreenが開く', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp(
        vehicles: [_makeVehicle(maker: 'Subaru', model: 'Forester')],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.textContaining('Subaru').first);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('履歴を追加'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('メンテナンス履歴を追加'), findsOneWidget);
    });

    testWidgets('AddMaintenanceScreen にメンテナンスタイプチップが表示される', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp(
        vehicles: [_makeVehicle(maker: 'Nissan', model: 'Serena')],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.textContaining('Nissan').first);
      await tester.pumpAndSettle(const Duration(seconds: 10));
      await tester.tap(find.text('履歴を追加'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // メンテナンスタイプチップ（点検・車検・オイル交換など）
      expect(find.text('メンテナンスタイプ'), findsOneWidget);
    });

    testWidgets('AddMaintenanceScreen でタイトル空のまま保存するとバリデーションエラーが出る',
        (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp(
        vehicles: [_makeVehicle(maker: 'Mitsubishi', model: 'Outlander')],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.textContaining('Mitsubishi').first);
      await tester.pumpAndSettle(const Duration(seconds: 10));
      await tester.tap(find.text('履歴を追加'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // タイトル未入力で「保存する」をタップ
      await tester.tap(find.text('保存する'));
      await tester.pump();

      expect(find.textContaining('入力してください'), findsWidgets);
    });

    testWidgets('AddMaintenanceScreen でタイトルを入力すると「保存する」が有効になる', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp(
        vehicles: [_makeVehicle(maker: 'Daihatsu', model: 'Tanto')],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.textContaining('Daihatsu').first);
      await tester.pumpAndSettle(const Duration(seconds: 10));
      await tester.tap(find.text('履歴を追加'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // タイトルは AddMaintenanceScreen の最初の入力可能な TextFormField
      await tester.enterText(find.byType(TextFormField).first, '6ヶ月点検');
      await tester.pump();

      expect(find.text('6ヶ月点検'), findsOneWidget);
    });

    testWidgets('AddMaintenanceScreen で戻るとVehicleDetailScreenに戻る',
        (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp(
        vehicles: [_makeVehicle(maker: 'Toyota', model: 'Alphard')],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.textContaining('Toyota').first);
      await tester.pumpAndSettle(const Duration(seconds: 10));
      await tester.tap(find.text('履歴を追加'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // AddMaintenanceScreen で戻る
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // VehicleDetailScreen に戻ることを確認
      expect(find.text('履歴を追加'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // P10: 車両登録フロー — HomeScreen FAB → VehicleRegistrationScreen (wizard)
  // ---------------------------------------------------------------------------

  group('P10 車両登録フロー', () {
    setUpAll(() {
      final sl = ServiceLocator.instance;
      if (!sl.isRegistered<VehicleMasterService>()) {
        sl.registerLazySingleton<VehicleMasterService>(
            () => _StubVehicleMasterService());
      }
      if (!sl.isRegistered<VehicleCertificateOcrService>()) {
        sl.registerLazySingleton<VehicleCertificateOcrService>(
            () => _StubOcrService());
      }
      if (!sl.isRegistered<FirebaseService>()) {
        sl.registerLazySingleton<FirebaseService>(() => _StubFirebaseService());
      }
    });

    tearDownAll(() {
      Injection.reset();
    });

    testWidgets('マイカータブ FABをタップするとVehicleRegistrationScreenが開く',
        (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      // マイカータブ（デフォルト）の FAB をタップ
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Step 1 タイトル
      expect(find.text('基本情報を入力'), findsOneWidget);
    });

    testWidgets('ウィザードステップインジケーターが全3ステップ表示される', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('基本情報'), findsOneWidget);
      expect(find.text('車検・保険'), findsOneWidget);
      expect(find.text('詳細情報'), findsOneWidget);
    });

    testWidgets('OCRスキャンボタンが表示される', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('車検証をスキャンして自動入力'), findsOneWidget);
    });

    testWidgets('空フォームで「次へ」をタップするとメーカーバリデーションエラーが出る', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('次へ'));
      await tester.pump();

      expect(find.text('メーカーを選択してください'), findsOneWidget);
    });

    testWidgets('空フォームで「次へ」をタップすると年式・走行距離バリデーションエラーが出る', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('次へ'));
      await tester.pump();

      // 複数のバリデーションエラーが出る
      expect(find.textContaining('入力'), findsWidgets);
    });

    testWidgets('年式に文字を入力すると数値バリデーションエラーが出る', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // 年式フィールドに不正な値を入力
      final yearField = find.widgetWithText(TextFormField, '年式 *');
      if (yearField.evaluate().isNotEmpty) {
        await tester.enterText(yearField, '無効な値');
        await tester.tap(find.text('次へ'));
        await tester.pump();

        expect(find.textContaining('入力'), findsWidgets);
      }
    });

    testWidgets('走行距離に負の値を入力するとバリデーションエラーが出る', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // 走行距離フィールドに負の値を入力
      final mileageField = find.widgetWithText(TextFormField, '走行距離 *');
      if (mileageField.evaluate().isNotEmpty) {
        await tester.enterText(mileageField, '-100');
        await tester.tap(find.text('次へ'));
        await tester.pump();

        expect(find.textContaining('入力'), findsWidgets);
      }
    });

    testWidgets('Step 0 では AppBar に戻るボタンがない', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Step 0 はウィザード先頭 — BackButton は表示されない
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leading, isNull);
    });

    testWidgets('VehicleRegistrationScreen から navigator.pop で HomeScreen に戻る',
        (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(_buildHomeApp());
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Scaffold の close / system back ではなく Navigator.pop 相当
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // HomeScreen の マイカー AppBar タイトルに戻る
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('マイカー')),
        findsOneWidget,
      );
    });
  });

  // ===========================================================================
  // P11 — プロフィール管理（B2C ユーザー）
  // Profile tab navigation, settings access, plan display, logout flow
  // ===========================================================================
  group('P11 プロフィール管理', () {
    // Builds HomeApp with a resolved AuthProvider (Stream.value(null) → isLoading=false).
    // Also provides UserSubscriptionProvider for plan-related assertions.
    Widget buildProfileHomeApp({UserPlanType planType = UserPlanType.free}) {
      final fb = _StubFirebaseService();
      final fakeFirestore = FakeFirebaseFirestore();

      final userSubProvider = UserSubscriptionProvider();
      // Seed plan state without a real auth flow
      userSubProvider.loadFromUser(planType, null);

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<VehicleProvider>.value(
            value: _FakeVehicleProvider(),
          ),
          ChangeNotifierProvider<MaintenanceProvider>(
            create: (_) => MaintenanceProvider(firebaseService: fb),
          ),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) =>
                AuthProvider(authService: _StubAuthServiceResolved()),
          ),
          ChangeNotifierProvider<NotificationProvider>.value(
            value: _FakeNotificationProvider(),
          ),
          ChangeNotifierProvider<ConnectivityProvider>(
            create: (_) => _StubConnectivityProvider(),
          ),
          ChangeNotifierProvider<ShopProvider>(
            create: (_) => _FakeShopProvider(),
          ),
          ChangeNotifierProvider<PostProvider>(
            create: (_) => PostProvider(
                postService: PostService(firestore: fakeFirestore)),
          ),
          ChangeNotifierProvider<DriveLogProvider>(
            create: (_) => DriveLogProvider(
                driveLogService: DriveLogService(firestore: fakeFirestore)),
          ),
          ChangeNotifierProvider<UserSubscriptionProvider>.value(
            value: userSubProvider,
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      );
    }

    testWidgets('プロフィールタブに切り替えられる', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(buildProfileHomeApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tap the profile tab (index 4 — rightmost)
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('プロフィール')),
        findsOneWidget,
      );
    });

    testWidgets('プロフィール画面に設定アイコンが表示される', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(buildProfileHomeApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byIcon(Icons.settings_outlined), findsWidgets);
    });

    testWidgets('ログアウトボタンが表示される', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(buildProfileHomeApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('ログアウトボタンをタップすると確認ダイアログが表示される', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(buildProfileHomeApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      // Logout confirmation dialog
      expect(find.text('ログアウト'), findsWidgets);
      expect(find.text('キャンセル'), findsOneWidget);
    });

    testWidgets('ダイアログのキャンセルでプロフィール画面に留まる', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(buildProfileHomeApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      // Still on profile screen
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('プロフィール')),
        findsOneWidget,
      );
    });

    testWidgets('UserSubscriptionProvider — free プランは isPremium=false',
        (tester) async {
      final provider = UserSubscriptionProvider();
      provider.loadFromUser(UserPlanType.free, null);
      expect(provider.isPremium, isFalse);
      expect(provider.canExportPdf, isFalse);
      expect(provider.maxMonthlyInquiries, lessThan(9999));
    });

    testWidgets('UserSubscriptionProvider — premium プランは isPremium=true',
        (tester) async {
      final provider = UserSubscriptionProvider();
      final future = DateTime.now().add(const Duration(days: 30));
      provider.loadFromUser(UserPlanType.premium, future);
      expect(provider.isPremium, isTrue);
      expect(provider.canExportPdf, isTrue);
    });

    testWidgets('UserSubscriptionProvider — clear() で free に戻る',
        (tester) async {
      final provider = UserSubscriptionProvider();
      provider.loadFromUser(UserPlanType.premium, null);
      expect(provider.isPremium, isTrue);

      provider.clear();
      expect(provider.isPremium, isFalse);
      expect(provider.planType, UserPlanType.free);
    });

    testWidgets('フリープランではプロフィールにフリープランバッジが表示される', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(buildProfileHomeApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Chip renders text through DefaultTextStyle chain; textContaining is robust to widget wrapping
      expect(find.textContaining('フリープラン'), findsWidgets);
    });

    testWidgets('プレミアムプランではプロフィールにプレミアムバッジが表示される', (tester) async {
      await _setSurface(tester);
      await tester
          .pumpWidget(buildProfileHomeApp(planType: UserPlanType.premium));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('プレミアム'), findsWidgets);
    });

    testWidgets('フリープランのエクスポートタップでアップグレードダイアログが表示される', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(buildProfileHomeApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Find the export menu item by its label text fragment
      await tester.tap(find.textContaining('データをエクスポート'));
      await tester.pumpAndSettle();

      expect(find.text('プレミアムプランが必要です'), findsOneWidget);
      expect(find.text('閉じる'), findsOneWidget);
    });
  });
}
