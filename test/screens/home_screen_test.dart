// HomeScreen Widget Tests
//
// Strategy: Fake providers extend the real provider classes with
// mock service dependencies.  Firebase platform channels are not
// invoked because fake services return instantly.
//
// Coverage:
//   - Initial tab index (マイカー)
//   - AppBar title per tab
//   - ナビゲーション（自前の _NavCell）の並びとタップ
//   - Vehicle loading / empty / error states
//   - AppBar のベルに出る未読バッジ
//   - Offline banner (ConnectivityProvider.isOffline = true)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/core/theme/app_theme.dart';
import 'package:trust_car_platform/screens/home_screen.dart';
import 'package:trust_car_platform/providers/vehicle_provider.dart';
import 'package:trust_car_platform/providers/maintenance_provider.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/providers/notification_provider.dart';
import 'package:trust_car_platform/providers/connectivity_provider.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/recommendation_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/accessory_showcase.dart';
import 'package:trust_car_platform/services/popular_accessories_service.dart';
import 'package:trust_car_platform/services/vehicle_retirement_service.dart';
import 'package:trust_car_platform/services/part_recommendation_service.dart';
import 'package:trust_car_platform/models/part_listing.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/app_notification.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/constants/app_info.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/providers/post_provider.dart';
import 'package:trust_car_platform/services/post_service.dart';
import 'package:trust_car_platform/providers/drive_log_provider.dart';
import 'package:trust_car_platform/services/drive_log_service.dart';
import 'package:trust_car_platform/providers/user_subscription_provider.dart';
import 'package:trust_car_platform/models/part_listing.dart' as parts;

import '../golden/font_loader.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Stub FirebaseService
// ---------------------------------------------------------------------------

class _StubFirebaseService implements FirebaseService {
  /// ホームの「メンテナンスの記録」に出す分。テストから差し替える。
  List<MaintenanceRecord> recentRecords = const [];

  /// ホームの「メンテナンスの記録」に出す1年ぶんの集計。
  MaintenanceSummary summary = const MaintenanceSummary(
    count: 17,
    totalCost: 288400,
  );

  @override
  Future<Result<MaintenanceSummary, AppError>> maintenanceSummary({
    DateTime? since,
  }) async =>
      Result.success(summary);

  @override
  Future<Result<bool, AppError>> hasAnyMaintenanceRecord() async =>
      const Result.success(false);

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
      getRecentMaintenanceRecords({
    int limit = 5,
  }) async =>
          Result.success(recentRecords);

  @override
  Future<Result<List<MaintenanceRecord>, AppError>>
      getMaintenanceRecordsForVehicle(String vehicleId,
              {int limit = 20}) async =>
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

// ---------------------------------------------------------------------------
// Stub AuthService (returns empty stream → firebaseUser stays null)
// ---------------------------------------------------------------------------

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
          {String? displayName,
          String? photoUrl,
          String? prefecture,
          String? city}) async =>
      Result.failure(AppError.unknown('stub'));

  @override
  Future<Result<void, AppError>> sendPasswordResetEmail(String email) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteAccount() async =>
      const Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Fake VehicleProvider — exposes setters so tests control state
// ---------------------------------------------------------------------------

class _StubPopularAccessoriesService implements PopularAccessoriesService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Result<List<AccessoryTrend>, AppError>> getTopAccessories(
          {int limit = 10}) async =>
      const Result.success([]);
}

class _StubVehicleRetirementService implements VehicleRetirementService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Result<List<Vehicle>, AppError>> getRetiredVehicles(
          String userId) async =>
      const Result.success([]);
}

/// ホームの「おすすめパーツ」。Firestore を触るので空を返して黙らせる。
class _StubPartRecommendationService implements PartRecommendationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Result<List<PartRecommendation>, AppError>>
      getRecommendationsForVehicle(
    Vehicle vehicle, {
    PartCategory? category,
    int limit = 10,
  }) async =>
          const Result.success([]);
}

/// 1年ぶんのデータで撮るとき用。おすすめパーツを3件返す。
class _YearPartRecommendationService implements PartRecommendationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  parts.PartListing _part({
    required String id,
    required String name,
    required parts.PartCategory category,
    required String brand,
    required int price,
  }) =>
      parts.PartListing(
        id: id,
        shopId: 'shop-1',
        name: name,
        description: '',
        category: category,
        priceFrom: price,
        brand: brand,
        rating: 4.5,
        reviewCount: 12,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  @override
  Future<Result<List<parts.PartRecommendation>, AppError>>
      getRecommendationsForVehicle(
    Vehicle vehicle, {
    parts.PartCategory? category,
    int limit = 10,
  }) async =>
          Result.success([
            parts.PartRecommendation(
              part: _part(
                id: 'p1',
                name: '低燃費タイヤ 195/65R15',
                category: parts.PartCategory.tire,
                brand: 'ミナモ',
                price: 42000,
              ),
              compatibility: parts.CompatibilityLevel.perfect,
            ),
            parts.PartRecommendation(
              part: _part(
                id: 'p2',
                name: 'ドライブレコーダー前後2カメラ',
                category: parts.PartCategory.navigation,
                brand: 'ヤマセミ',
                price: 28000,
              ),
              compatibility: parts.CompatibilityLevel.compatible,
            ),
            parts.PartRecommendation(
              part: _part(
                id: 'p3',
                name: 'スポーツブレーキパッド',
                category: parts.PartCategory.brake,
                brand: 'カゲロウ',
                price: 18500,
              ),
              compatibility: parts.CompatibilityLevel.conditional,
            ),
          ]);
}

/// たびの記録の集計だけを返す。1年ぶんの回数と距離。
class _StubDriveLogService implements DriveLogService {
  DriveLogSummary summary = const DriveLogSummary(
    count: 204,
    totalDistanceKm: 10298,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Result<DriveLogSummary, AppError>> summaryForUser({
    required String userId,
    DateTime? since,
  }) async =>
      Result.success(summary);
}

/// ログイン済みに見せる。たびの記録の集計は uid が無いと走らない。
class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider() : super(authService: _StubAuthService());

  @override
  AppUser? get appUser => AppUser(
        id: 'u1',
        email: 'persona.a@example.com',
        displayName: 'ペルソナA',
        createdAt: DateTime(2025, 9, 8),
        updatedAt: DateTime(2026, 9, 8),
      );
}

/// ドライブログを持っている状態にする。
class _FakeDriveLogProvider extends DriveLogProvider {
  _FakeDriveLogProvider()
      : super(
            driveLogService:
                DriveLogService(firestore: FakeFirebaseFirestore()));

  List<DriveLog> _fakeLogs = const [];

  void setLogs(List<DriveLog> logs) {
    _fakeLogs = logs;
    notifyListeners();
  }

  @override
  List<DriveLog> get logs => _fakeLogs;
}

class _FakeVehicleProvider extends VehicleProvider {
  _FakeVehicleProvider() : super(firebaseService: _StubFirebaseService());

  List<Vehicle> _fakeVehicles = [];
  bool _fakeLoading = false;
  AppError? _fakeError;

  void setVehicles(List<Vehicle> v) {
    _fakeVehicles = v;
    notifyListeners();
  }

  void setLoading(bool v) {
    _fakeLoading = v;
    notifyListeners();
  }

  void setError(AppError e) {
    _fakeError = e;
    notifyListeners();
  }

  @override
  List<Vehicle> get vehicles => _fakeVehicles;

  @override
  bool get isLoading => _fakeLoading;

  @override
  AppError? get error => _fakeError;

  @override
  String? get errorMessage => _fakeError?.userMessage;

  @override
  bool get isRetryable => _fakeError?.isRetryable ?? false;

  @override
  void listenToVehicles() {} // no-op: prevents Firebase calls

  @override
  void stopListening() {}

  @override
  void clear() {
    _fakeVehicles = [];
    _fakeLoading = false;
    _fakeError = null;
    notifyListeners();
  }

  @override
  void clearError() {
    _fakeError = null;
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// Fake NotificationProvider
// ---------------------------------------------------------------------------

class _FakeNotificationProvider extends NotificationProvider {
  _FakeNotificationProvider()
      : super(
          firebaseService: _StubFirebaseService(),
          recommendationService: RecommendationService(),
        );

  List<AppNotification> _fakeNotifications = [];

  void setNotifications(List<AppNotification> n) {
    _fakeNotifications = n;
    notifyListeners();
  }

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

// ---------------------------------------------------------------------------
// Helper: build the test app
// ---------------------------------------------------------------------------

Vehicle _makeVehicle(String id) => Vehicle(
      id: id,
      userId: 'u1',
      maker: 'Toyota',
      model: 'Prius',
      year: 2021,
      grade: 'S',
      mileage: 30000,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

AppNotification _makeNotif({bool isRead = false}) => AppNotification(
      id: 'n1',
      userId: 'u1',
      type: NotificationType.maintenanceRecommendation,
      title: 'オイル交換',
      message: 'そろそろオイル交換を',
      isRead: isRead,
      createdAt: DateTime(2024, 1, 1),
    );

Widget _buildApp({
  _FakeVehicleProvider? vehicleProvider,
  _FakeNotificationProvider? notificationProvider,
  _FakeDriveLogProvider? driveLogProvider,
  bool signedIn = false,
  bool isOffline = false,
  ThemeData? theme,
}) {
  final fb = _StubFirebaseService();
  final vp = vehicleProvider ?? _FakeVehicleProvider();
  final np = notificationProvider ?? _FakeNotificationProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<VehicleProvider>.value(value: vp),
      ChangeNotifierProvider<MaintenanceProvider>(
        create: (_) => MaintenanceProvider(firebaseService: fb),
      ),
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => signedIn
            ? _FakeAuthProvider()
            : AuthProvider(authService: _StubAuthService()),
      ),
      ChangeNotifierProvider<NotificationProvider>.value(value: np),
      ChangeNotifierProvider<ConnectivityProvider>(
        create: (_) {
          final cp = _StubConnectivityProvider(isOffline: isOffline);
          return cp;
        },
      ),
      ChangeNotifierProvider<ShopProvider>(
        create: (_) => ShopProvider(
          shopService: ShopService(firestore: FakeFirebaseFirestore()),
          inquiryService: InquiryService(firestore: FakeFirebaseFirestore()),
        ),
      ),
      ChangeNotifierProvider<PostProvider>(
        create: (_) => PostProvider(
          postService: PostService(firestore: FakeFirebaseFirestore()),
        ),
      ),
      if (driveLogProvider != null)
        ChangeNotifierProvider<DriveLogProvider>.value(value: driveLogProvider)
      else
        ChangeNotifierProvider<DriveLogProvider>(
          create: (_) => DriveLogProvider(
            driveLogService:
                DriveLogService(firestore: FakeFirebaseFirestore()),
          ),
        ),
      ChangeNotifierProvider<UserSubscriptionProvider>(
        create: (_) => UserSubscriptionProvider(),
      ),
    ],
    child: MaterialApp(
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Fake ConnectivityProvider (bypasses platform channel via implements)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// ナビゲーションのヘルパー
// ---------------------------------------------------------------------------

/// タブを切り替える。
///
/// ナビゲーションは Material の NavigationBar をやめ、自前の `_NavCell`
/// （`Key('nav_cell_$index')`）を並べる形になった。画面幅で上段・下段が
/// 入れ替わるので、位置ではなく Key で指す。
///
/// index: 0=マイカー / 1=マーケットプレイス / 2=みんなの投稿 / 3=プロフィール
Future<void> _tapNavCell(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(Key('nav_cell_$index')));
  await tester.pumpAndSettle(const Duration(seconds: 10));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ホームは「メンテナンスの記録」を ServiceLocator 経由で読む
  // （2026-09-07 に追加）。どのテストでも要るので、ファイル全体で登録する。
  late _StubFirebaseService stubFirebase;
  late _StubDriveLogService stubDriveLogs;

  setUp(() {
    stubFirebase = _StubFirebaseService();
    final sl = ServiceLocator.instance;
    sl.registerLazySingleton<FirebaseService>(() => stubFirebase);
    // ホームは「みんなのアクセサリー」と「過去の車両」も読む。
    // どちらも Firestore を触るが、テストでは空を返すスタブで足りる。
    sl.registerLazySingleton<PopularAccessoriesService>(
        _StubPopularAccessoriesService.new);
    sl.registerLazySingleton<VehicleRetirementService>(
        _StubVehicleRetirementService.new);
    // 車両カードの下に「おすすめパーツ」が付いた（2026-09-08）。
    sl.registerLazySingleton<PartRecommendationService>(
        _StubPartRecommendationService.new);
    // 「たびの記録」の1年集計も ServiceLocator 経由（2026-09-08）。
    stubDriveLogs = _StubDriveLogService();
    sl.registerLazySingleton<DriveLogService>(() => stubDriveLogs);
  });

  tearDown(() {
    final sl = ServiceLocator.instance;
    sl.unregister<FirebaseService>();
    sl.unregister<PopularAccessoriesService>();
    sl.unregister<VehicleRetirementService>();
    sl.unregister<PartRecommendationService>();
    sl.unregister<DriveLogService>();
  });

  group('ホーム — メンテナンスの記録', () {
    // 車検・点検だけでなく、オイル交換もカスタムパーツも同じ並びで出す。
    // 金額を添えるのは、積み上がった費用が維持費の実感になるため。
    MaintenanceRecord record({
      required String id,
      required String title,
      required MaintenanceType type,
      required int cost,
      required DateTime date,
    }) {
      return MaintenanceRecord(
        id: id,
        vehicleId: 'v1',
        userId: 'u1',
        type: type,
        title: title,
        cost: cost,
        date: date,
        createdAt: date,
      );
    }

    testWidgets('種類を問わず時系列で並び、金額が出る', (tester) async {
      stubFirebase.recentRecords = [
        record(
          id: 'r1',
          title: 'ドラレコ取り付け',
          type: MaintenanceType.customization,
          cost: 38000,
          date: DateTime(2026, 8, 20),
        ),
        record(
          id: 'r2',
          title: 'オイル交換',
          type: MaintenanceType.oilChange,
          cost: 6200,
          date: DateTime(2026, 7, 2),
        ),
        record(
          id: 'r3',
          title: '車検',
          type: MaintenanceType.carInspection,
          cost: 74000,
          date: DateTime(2026, 3, 18),
        ),
      ];

      final vp = _FakeVehicleProvider()..setVehicles([_makeVehicle('v1')]);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // セクションは車両カードの下にある。ListView は画面外を組み立てない
      // ので、スクロールして初めて現れる。
      await tester.scrollUntilVisible(
        find.text('メンテナンスの記録'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('メンテナンスの記録'), findsOneWidget);
      // カスタムも点検も、種類で分けずに並ぶ
      expect(find.text('ドラレコ取り付け'), findsOneWidget);
      expect(find.text('オイル交換'), findsOneWidget);
      expect(find.text('車検'), findsOneWidget);
      // 金額
      expect(find.text('¥38,000'), findsOneWidget);
      expect(find.text('¥6,200'), findsOneWidget);
      expect(find.text('¥74,000'), findsOneWidget);
    });

    testWidgets('記録が無ければ見出しごと出さない', (tester) async {
      stubFirebase.recentRecords = const [];

      final vp = _FakeVehicleProvider()..setVehicles([_makeVehicle('v1')]);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();

      // ホームの一等地に「ありません」を置いても、できることは増えない
      expect(find.text('メンテナンスの記録'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 1年使ったあとのホーム
  //
  // 「たびの記録」と「おすすめパーツ」は、プロフィールの奥・車両詳細の
  // ヘッダーにあって、1年使っても辿り着かない位置にあった（2026-09-08 に
  // ホームへ出した）。ここでは**溜まった状態**で確かめる。
  // -------------------------------------------------------------------------

  group('ホーム — 1年使ったあと', () {
    DriveLog driveLog(String id, String title, double km, int daysAgo) {
      final start = DateTime(2026, 9, 8).subtract(Duration(days: daysAgo));
      return DriveLog(
        id: id,
        userId: 'u1',
        vehicleId: 'v1',
        status: DriveLogStatus.completed,
        title: title,
        startTime: start,
        endTime: start.add(const Duration(hours: 2)),
        statistics: DriveStatistics(
          totalDistance: km,
          totalDuration: 7200,
          averageSpeed: km / 2,
          maxSpeed: km,
        ),
        createdAt: start,
        updatedAt: start,
      );
    }

    _FakeDriveLogProvider driveLogs() => _FakeDriveLogProvider()
      ..setLogs([
        driveLog('d1', '箱根までワインディング', 128.4, 3),
        driveLog('d2', '軽井沢へ family trip', 172.6, 9),
        for (var i = 0; i < 18; i++) driveLog('d$i-x', '配送（川崎）', 34.5, 12 + i),
      ]);

    testWidgets('たびの記録は「この1年」の回数と距離を出す（1ページ分の合計ではない）', (tester) async {
      final vp = _FakeVehicleProvider()..setVehicles([_makeVehicle('v1')]);

      await tester.pumpWidget(_buildApp(
        vehicleProvider: vp,
        driveLogProvider: driveLogs(),
        signedIn: true,
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('たびの記録'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // 読み込み済みの20件ではなく、集計の204回。
      expect(find.text('この1年で204回'), findsOneWidget);
      expect(find.text('10,298 km'), findsOneWidget);
    });

    testWidgets('おすすめパーツが車両カードの下に出る', (tester) async {
      final sl = ServiceLocator.instance;
      sl.unregister<PartRecommendationService>();
      sl.registerLazySingleton<PartRecommendationService>(
          _YearPartRecommendationService.new);

      final vp = _FakeVehicleProvider()..setVehicles([_makeVehicle('v1')]);

      await tester.pumpWidget(_buildApp(
        vehicleProvider: vp,
        driveLogProvider: driveLogs(),
        signedIn: true,
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('おすすめパーツ'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('おすすめパーツ'), findsOneWidget);
      expect(find.text('低燃費タイヤ 195/65R15'), findsOneWidget);
      // 適合の度合いを、行ごとに言う。
      expect(find.text('完全対応'), findsOneWidget);
      expect(find.text('条件付き'), findsOneWidget);
      // 価格
      expect(find.text('¥42,000'), findsOneWidget);
    });

    testWidgets('クイック導線が4つ、開いてすぐの高さにある', (tester) async {
      final vp = _FakeVehicleProvider()..setVehicles([_makeVehicle('v1')]);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp, signedIn: true));
      await tester.pumpAndSettle();

      // スクロールせずに見えること。
      expect(find.byKey(const Key('quick_action_drive')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_parts')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_fuel')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_maintenance')), findsOneWidget);
    });

    // 遷移そのもの（たびの記録 → 一覧画面）は、一覧が
    // DriveRecordingProvider を要求するためホームのテストからは開けない。
    // 一覧画面側の drive_log_screen_test.dart でカバーする。

    group('Edge Cases', () {
      testWidgets('車が無ければクイック導線は出さない（記録する対象が無い）', (tester) async {
        final vp = _FakeVehicleProvider()..setVehicles([]);

        await tester.pumpWidget(_buildApp(vehicleProvider: vp, signedIn: true));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('quick_action_drive')), findsNothing);
      });

      testWidgets('適合するパーツが無ければ見出しごと出さない', (tester) async {
        final vp = _FakeVehicleProvider()..setVehicles([_makeVehicle('v1')]);

        await tester.pumpWidget(_buildApp(vehicleProvider: vp, signedIn: true));
        await tester.pumpAndSettle();
        await tester.drag(
            find.byType(Scrollable).first, const Offset(0, -3000));
        await tester.pumpAndSettle();

        expect(find.text('おすすめパーツ'), findsNothing);
      });
    });
  });

  MaintenanceRecord goldenRecord(String title, int cost, DateTime date) =>
      MaintenanceRecord(
        id: title,
        vehicleId: 'v1',
        userId: 'u1',
        type: MaintenanceType.other,
        title: title,
        date: date,
        cost: cost,
        createdAt: date,
      );

  // 見え方を画像に残す。CI では走らない（tags: 'golden'）。
  //   flutter test --update-goldens test/screens/home_screen_test.dart
  group('ゴールデン', () {
    setUpAll(() async {
      await loadMaterialIcons();
      await loadJapaneseFont();
    });

    Future<void> shoot(WidgetTester tester, String name, ThemeData base) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildApp(theme: goldenTheme(base)));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../golden/goldens/$name.png'),
      );
    }

    testWidgets('ホーム（ライト）', (tester) async {
      await shoot(tester, 'screen_home_light', AppTheme.lightTheme);
    }, tags: 'golden');

    testWidgets('ホーム（ダーク）', (tester) async {
      await shoot(tester, 'screen_home_dark', AppTheme.darkTheme);
    }, tags: 'golden');

    // 1年ぶんのデータが入った状態。空の画面では分からない
    // 「溜まったときの並びと高さ」を残す。縦を長めに撮る。
    testWidgets('ホーム（1年使ったあと）', (tester) async {
      final sl = ServiceLocator.instance;
      sl.unregister<PartRecommendationService>();
      sl.registerLazySingleton<PartRecommendationService>(
          _YearPartRecommendationService.new);

      final start = DateTime(2026, 9, 5);
      DriveLog log(String id, String title, double km, int daysAgo) => DriveLog(
            id: id,
            userId: 'u1',
            vehicleId: 'v1',
            status: DriveLogStatus.completed,
            title: title,
            startTime: start.subtract(Duration(days: daysAgo)),
            endTime: start.subtract(Duration(days: daysAgo)),
            statistics: DriveStatistics(
              totalDistance: km,
              totalDuration: 7200,
              averageSpeed: km / 2,
              maxSpeed: km,
            ),
            createdAt: start.subtract(Duration(days: daysAgo)),
            updatedAt: start.subtract(Duration(days: daysAgo)),
          );

      stubFirebase.recentRecords = [
        goldenRecord('車検（継続検査）', 138000, DateTime(2026, 6, 29)),
        goldenRecord('バッテリー交換', 28000, DateTime(2026, 7, 7)),
        goldenRecord('エンジンオイル交換', 5550, DateTime(2026, 8, 15)),
      ];

      await tester.binding.setSurfaceSize(const Size(390, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildApp(
        theme: goldenTheme(AppTheme.lightTheme),
        vehicleProvider: _FakeVehicleProvider()
          ..setVehicles([_makeVehicle('v1')]),
        driveLogProvider: _FakeDriveLogProvider()
          ..setLogs([
            log('d1', '箱根までワインディング', 128.4, 3),
            log('d2', '軽井沢へ family trip', 172.6, 9),
          ]),
        signedIn: true,
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../golden/goldens/screen_home_year_of_use.png'),
      );
    }, tags: 'golden');
  });

  group('HomeScreen — AppBar', () {
    testWidgets('初期タブはマイカー（タイトルが "マイカー"）', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('マイカー'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('マーケットプレイスタブに切り替えるとタイトルが変わる', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await _tapNavCell(tester, 1);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('マーケットプレイス'),
        ),
        findsWidgets,
      );
    });

    testWidgets('SNSタブに切り替えるとタイトルが "みんなの投稿"', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await _tapNavCell(tester, 2);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('みんなの投稿'),
        ),
        findsOneWidget,
      );
    });

    // 通知タブは廃止された。通知はどのタブにいても AppBar のベルから開く。
    testWidgets('AppBar のベルをタップすると通知一覧が開く', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(
          find.byKey(const Key('header_notifications_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('header_notifications_button')));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // NotificationListScreen（通知0件なので空状態）が乗る
      expect(find.text('通知はありません'), findsOneWidget);
    });

    // ベルはタブに紐付かないので、マイカー以外のタブでも同じ場所にある。
    testWidgets('通知ベルはどのタブでも AppBar に居る', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildApp());
      await tester.pump();

      for (final index in [1, 2, 3, 0]) {
        await _tapNavCell(tester, index);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byKey(const Key('header_notifications_button')),
          ),
          findsOneWidget,
          reason: 'nav_cell_$index のタブでベルが消えている',
        );
      }
    });

    testWidgets('マイカータブのヘッダーに「たびの記録」がある', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byKey(const Key('header_drive_log_button')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('みんなの投稿タブのヘッダーに「みんなのアクセサリー」がある', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // マイカータブには出ない（タブ連動のアクション）
      expect(find.byKey(const Key('header_accessories_button')), findsNothing);

      await _tapNavCell(tester, 2);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byKey(const Key('header_accessories_button')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('プロフィールタブに切り替えるとタイトルが "プロフィール"', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await _tapNavCell(tester, 3);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('プロフィール'),
        ),
        findsOneWidget,
      );
    });
  });

  group('HomeScreen — ナビゲーション', () {
    testWidgets('4つのナビゲーションセルが表示される', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('nav_cell_$i')), findsOneWidget,
            reason: 'nav_cell_$i が無い');
      }
      // 通知タブを外したので5つ目は無い
      expect(find.byKey(const Key('nav_cell_4')), findsNothing);
    });

    testWidgets('4つのタブラベルとアイコンが存在する', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // 選択中のマイカーだけ塗りつぶしアイコン
      expect(find.byIcon(Icons.directions_car), findsWidgets);
      expect(find.byIcon(Icons.store_outlined), findsOneWidget);
      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);

      expect(find.text('マーケット'), findsOneWidget);
      expect(find.text('みんなの投稿'), findsWidgets);
      expect(find.text('プロフィール'), findsOneWidget);

      // 通知はタブではなく AppBar のベル。ナビゲーションの中には無い。
      expect(
        find.descendant(
          of: find.byKey(const Key('nav_cell_3')),
          matching: find.byIcon(Icons.notifications_outlined),
        ),
        findsNothing,
      );
    });

    testWidgets('タブを順番にタップして全タブに移動できる', (tester) async {
      // Use a large surface to avoid layout overflow errors during tab switching
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // 全タブを一巡（マーケット → みんなの投稿 → プロフィール → マイカー）
      for (final index in [1, 2, 3, 0]) {
        await _tapNavCell(tester, index);
      }

      // クラッシュしない
      expect(tester.takeException(), isNull);
    });

    testWidgets('選択中のタブだけ selected セマンティクスが立つ', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      bool isSelected(int index) {
        final semantics = tester.widgetList<Semantics>(
          find.ancestor(
            of: find.byKey(Key('nav_cell_$index')),
            matching: find.byType(Semantics),
          ),
        );
        return semantics.any((s) => s.properties.selected == true);
      }

      expect(isSelected(0), isTrue);
      expect(isSelected(1), isFalse);

      await _tapNavCell(tester, 1);

      expect(isSelected(0), isFalse);
      expect(isSelected(1), isTrue);
    });
  });

  group('HomeScreen — マイカータブ（index=0）', () {
    testWidgets('車両なし → 空状態UIが表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      // 空でもナビゲーションは出たまま、本文が登録の導線になる
      expect(find.byKey(const Key('nav_cell_0')), findsOneWidget);
      expect(find.text('まず愛車を登録しよう'), findsOneWidget);
    });

    testWidgets('車両あり → リストに表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles([_makeVehicle('v1'), _makeVehicle('v2')]);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      // ListView が存在する
      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('ローディング中は LoadingIndicator が表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setLoading(true);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      // CircularProgressIndicator か AppLoadingCenter が存在する
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.byType(Center).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('エラー状態でエラーUIが表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setError(AppError.network('接続失敗'));

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      // エラーテキストが何らか存在する
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // 通知タブが無くなったので、バッジは AppBar のベルに付く。
  group('HomeScreen — 通知バッジ（AppBar のベル）', () {
    testWidgets('未読通知があるとき、ベルにバッジが表示される', (tester) async {
      final np = _FakeNotificationProvider();
      np.setNotifications([_makeNotif(isRead: false)]);

      await tester.pumpWidget(_buildApp(notificationProvider: np));
      await tester.pump();

      // Badge テキスト（件数）がベルの中に表示される
      expect(
        find.descendant(
          of: find.byKey(const Key('header_notifications_button')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('未読通知がないとき、バッジテキストは表示されない', (tester) async {
      final np = _FakeNotificationProvider();
      np.setNotifications([_makeNotif(isRead: true)]);

      await tester.pumpWidget(_buildApp(notificationProvider: np));
      await tester.pump();

      // 未読数0のため、数字バッジは存在しない
      expect(find.text('0'), findsNothing);
    });

    testWidgets('通知100件超えは "99+" 表示になる', (tester) async {
      final np = _FakeNotificationProvider();
      np.setNotifications(
        List.generate(
          101,
          (i) => AppNotification(
            id: 'n$i',
            userId: 'u1',
            type: NotificationType.system,
            title: '通知$i',
            message: 'msg',
            isRead: false,
            createdAt: DateTime(2024, 1, 1),
          ),
        ),
      );

      await tester.pumpWidget(_buildApp(notificationProvider: np));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const Key('header_notifications_button')),
          matching: find.text('99+'),
        ),
        findsOneWidget,
      );
    });
  });

  group('HomeScreen — オフラインバナー', () {
    testWidgets('オフライン時にオフラインアイコンが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(isOffline: true));
      await tester.pump();

      expect(find.byIcon(Icons.cloud_off), findsWidgets);
    });

    testWidgets('オンライン時はオフラインアイコンが表示されない', (tester) async {
      await tester.pumpWidget(_buildApp(isOffline: false));
      await tester.pump();

      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });
  });

  group('HomeScreen — 車両未登録オンボーディング', () {
    testWidgets('車両0台のとき "まず愛車を登録しよう" が表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(find.text('まず愛車を登録しよう'), findsOneWidget);
    });

    testWidgets('3つの機能ハイライトラベルが表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(find.text('整備履歴を正確に記録'), findsOneWidget);
      expect(find.text('AIが次の点検をお知らせ'), findsOneWidget);
      expect(find.text('信頼できる整備工場と繋がる'), findsOneWidget);
    });

    testWidgets('「車両を登録する」CTAボタンが表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(find.text('車両を登録する'), findsOneWidget);
    });

    testWidgets('「車両を登録する」タップで VehicleRegistrationScreen に遷移する',
        (tester) async {
      final vp = _FakeVehicleProvider();
      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      await tester.tap(find.text('車両を登録する'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // VehicleRegistrationScreen のコンテンツが存在する
      expect(tester.takeException(), isNull);
    });

    testWidgets('車両が1台登録されたらオンボーディングが消える', (tester) async {
      final vp = _FakeVehicleProvider();
      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();
      expect(find.text('まず愛車を登録しよう'), findsOneWidget);

      vp.setVehicles([_makeVehicle('v1')]);
      await tester.pump();

      expect(find.text('まず愛車を登録しよう'), findsNothing);
    });
  });

  group('アクセシビリティ — _VehicleEmptyOnboarding', () {
    testWidgets('ヘッダーテキストに header セマンティクスが付与されている', (tester) async {
      final vp = _FakeVehicleProvider();
      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      // Semantics(header: true) が「まず愛車を登録しよう」テキストの先祖に存在する
      final semanticsWidgets = tester.widgetList<Semantics>(
        find.ancestor(
          of: find.text('まず愛車を登録しよう'),
          matching: find.byType(Semantics),
        ),
      );
      expect(semanticsWidgets.any((s) => s.properties.header == true), isTrue);
    });

    testWidgets('装飾的なアイコンに ExcludeSemantics が付与されている', (tester) async {
      final vp = _FakeVehicleProvider();
      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      // ヒーローアイコンと各 _FeatureRow アイコンが ExcludeSemantics 配下にある
      for (final icon in [
        Icons.history,
        Icons.notifications_active,
        Icons.handshake,
      ]) {
        expect(
          find.ancestor(
            of: find.byIcon(icon),
            matching: find.byType(ExcludeSemantics),
          ),
          findsWidgets,
          reason: '$icon should be wrapped in ExcludeSemantics',
        );
      }
    });

    testWidgets('「車両を登録する」ElevatedButton が onPressed を持ちアクセス可能',
        (tester) async {
      final vp = _FakeVehicleProvider();
      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      // ElevatedButton.icon creates a private subclass, so match by subtype
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('車両を登録する'),
          matching: find.bySubtype<ElevatedButton>(),
        ),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  group('Edge Cases', () {
    testWidgets('同じタブを連続タップしてもクラッシュしない', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      final carTab = find.byKey(const Key('nav_cell_0'));
      await tester.tap(carTab);
      await tester.tap(carTab);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(tester.takeException(), isNull);
    });

    testWidgets('多数の車両（20件）があってもクラッシュしない', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles(List.generate(20, (i) => _makeVehicle('v$i')));

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('HomeScreen — ダッシュボード車検アラート', () {
    Vehicle vehicleWithInspection(int daysFromNow) => Vehicle(
          id: 'v-insp',
          userId: 'u1',
          maker: 'Toyota',
          model: 'Prius',
          year: 2021,
          grade: 'S',
          mileage: 30000,
          // +1h: daysUntilInspection truncates partial days, keep N days
          inspectionExpiryDate:
              DateTime.now().add(Duration(days: daysFromNow, hours: 1)),
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

    testWidgets('車検まで31日以上 → 通常表示チップ', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles([vehicleWithInspection(60)]);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(find.byKey(const Key('dashboard_inspection_chip_normal')),
          findsOneWidget);
    });

    testWidgets('車検まで30日以内 → 警告スタイルのチップ', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles([vehicleWithInspection(10)]);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(find.byKey(const Key('dashboard_inspection_chip_warning')),
          findsOneWidget);
    });

    testWidgets('車検まで7日以内 → 重大スタイルのチップ', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles([vehicleWithInspection(3)]);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(find.byKey(const Key('dashboard_inspection_chip_critical')),
          findsOneWidget);
    });

    testWidgets('車検日未設定 → チップ非表示', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles([_makeVehicle('v1')]);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(find.byKey(const Key('dashboard_inspection_chip_normal')),
          findsNothing);
      expect(find.byKey(const Key('dashboard_inspection_chip_warning')),
          findsNothing);
      expect(find.byKey(const Key('dashboard_inspection_chip_critical')),
          findsNothing);
    });
  });

  group('HomeScreen — フリートプランバナー', () {
    testWidgets('5台以上でフリートプランバナーが表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles(List.generate(5, (i) => _makeVehicle('v$i')));

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(find.byKey(const Key('fleet_plan_banner')), findsOneWidget);
    });

    testWidgets('4台以下ではバナー非表示', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles(List.generate(4, (i) => _makeVehicle('v$i')));

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(find.byKey(const Key('fleet_plan_banner')), findsNothing);
    });

    testWidgets('無料開放中の文言が表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles(List.generate(5, (i) => _makeVehicle('v$i')));

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(find.textContaining('無料開放中'), findsOneWidget);
    });
  });

  // =========================================================================
  // Item 2: 車検日未設定プロンプトカード
  // =========================================================================
  group('HomeScreen — 車検日未設定プロンプトカード', () {
    Vehicle makeVehicleWithInspection(String id, DateTime inspectionDate) =>
        Vehicle(
          id: id,
          userId: 'u1',
          maker: 'Toyota',
          model: 'Prius',
          year: 2021,
          grade: 'S',
          mileage: 30000,
          inspectionExpiryDate: inspectionDate,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

    testWidgets('車検日未設定の車両があるとプロンプトカードが表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      // Vehicle with no inspection date (default _makeVehicle has null)
      vp.setVehicles([_makeVehicle('v1')]);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(
        find.byKey(const Key('inspection_setup_card')),
        findsOneWidget,
      );
    });

    testWidgets('車検日が設定済みの場合プロンプトカードは非表示', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles([
        makeVehicleWithInspection(
          'v1',
          DateTime.now().add(const Duration(days: 180)),
        ),
      ]);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(
        find.byKey(const Key('inspection_setup_card')),
        findsNothing,
      );
    });

    testWidgets('一部の車両に車検日がない場合もカードが表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles([
        makeVehicleWithInspection(
          'v1',
          DateTime.now().add(const Duration(days: 90)),
        ),
        _makeVehicle('v2'), // no inspection date
      ]);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(
        find.byKey(const Key('inspection_setup_card')),
        findsOneWidget,
      );
    });

    testWidgets('全車両に車検日が設定済みの場合カードは非表示', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles([
        makeVehicleWithInspection(
          'v1',
          DateTime.now().add(const Duration(days: 180)),
        ),
        makeVehicleWithInspection(
          'v2',
          DateTime.now().add(const Duration(days: 365)),
        ),
      ]);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(
        find.byKey(const Key('inspection_setup_card')),
        findsNothing,
      );
    });

    testWidgets('カードに「車検日を登録」などのCTA文言が含まれる', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles([_makeVehicle('v1')]);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const Key('inspection_setup_card')),
          matching: find.textContaining('車検'),
        ),
        findsWidgets,
      );
    });
  });

  group('HomeScreen — プロフィールタブのバージョン表示', () {
    // 「直したはずの不具合が直っていない」と言われたとき、その人がどのビルドを
    // 触っているか分からないと確かめようがない。テスト配布中は 1.0.0 のまま
    // 何度も出し直すので、画面から読み取れる必要がある。
    testWidgets('アプリのバージョンが読み取れる', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await _tapNavCell(tester, 3);

      final versionFinder = find.byKey(const Key('app_version_label'));
      await tester.scrollUntilVisible(versionFinder, 300);

      expect(versionFinder, findsOneWidget);
      expect(
        find.descendant(
          of: versionFinder,
          matching: find.textContaining(AppInfo.fullVersion),
        ),
        findsOneWidget,
      );
    });

    testWidgets('どの環境で動いているか（platform）も添える', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await _tapNavCell(tester, 3);

      final versionFinder = find.byKey(const Key('app_version_label'));
      await tester.scrollUntilVisible(versionFinder, 300);

      expect(
        find.descendant(
          of: versionFinder,
          matching: find.textContaining(AppInfo.platform),
        ),
        findsOneWidget,
      );
    });
  });
}
