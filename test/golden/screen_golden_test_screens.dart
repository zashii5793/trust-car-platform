// Golden Tests — DriveRecordingScreen & ShopOwnerScreen
//
// Captures key UI states as PNG baselines for visual regression testing.
// Run: flutter test --update-goldens test/golden/screen_golden_test_screens.dart
// Images saved to: test/golden/goldens/
//
// States captured:
//   DriveRecordingScreen:
//     1. recording_normal     — default stat cards
//     2. recording_loading    — CircularProgressIndicator overlay
//     3. recording_dialog     — stop confirmation dialog open
//     4. recording_error      — permission denied snackbar
//     5. recording_km         — distance formatted as km (>= 1 km)
//
//   ShopOwnerScreen:
//     6. shop_unregistered    — invitation + 3 plan cards
//     7. shop_registered_free — registered shop, free plan + upgrade banner
//     8. shop_registered_std  — registered shop, standard plan (no banner)
//     9. shop_loading         — loading indicator
//    10. shop_delete_dialog   — delete confirmation dialog open
//    11. shop_inquiry_badge   — inquiry count with unread badge

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;

// Screens
import 'package:trust_car_platform/screens/drive/drive_recording_screen.dart';
import 'package:trust_car_platform/screens/marketplace/shop_owner_screen.dart';

// Providers
import 'package:trust_car_platform/providers/drive_recording_provider.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';

// Services
import 'package:trust_car_platform/services/drive_log_service.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';

// Models
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/user.dart';

// Core
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// =============================================================================
// Shared stubs
// =============================================================================

class _StubAuthService implements AuthService {
  @override
  User? get currentUser => null;
  @override
  Stream<User?> get authStateChanges => const Stream.empty();
  @override
  Future<Result<UserCredential, AppError>> signUpWithEmail(
          {required String email,
          required String password,
          String? displayName}) async =>
      Result.failure(AppError.server('stub'));
  @override
  Future<Result<UserCredential, AppError>> signInWithEmail(
          {required String email, required String password}) async =>
      Result.failure(AppError.server('stub'));
  @override
  Future<Result<UserCredential?, AppError>> signInWithGoogle() async =>
      const Result.success(null);
  @override
  Future<Result<void, AppError>> sendPasswordResetEmail(String email) async =>
      const Result.success(null);
  @override
  Future<Result<void, AppError>> signOut() async => const Result.success(null);
  @override
  Future<Result<AppUser?, AppError>> getUserProfile() async =>
      const Result.success(null);
  @override
  Future<Result<void, AppError>> updateUserProfile(
          {String? displayName, String? photoUrl}) async =>
      const Result.success(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeUser implements User {
  @override
  String get uid => 'test-uid';
  @override
  String? get displayName => 'Test User';
  @override
  String? get photoURL => null;
  @override
  String? get email => 'test@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _LoggedInAuthProvider extends AuthProvider {
  _LoggedInAuthProvider() : super(authService: _StubAuthService());
  @override
  User? get firebaseUser => _FakeUser();
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => false;
}

// =============================================================================
// DriveRecordingScreen stubs
// =============================================================================

class _StubDriveLogService implements DriveLogService {
  @override
  Future<Result<DriveLog, AppError>> startDrive({
    required String userId,
    String? vehicleId,
    GeoPoint2D? startLocation,
    String? startAddress,
  }) async =>
      Result.success(_makeLog());

  @override
  Future<Result<DriveLog, AppError>> endDrive({
    required String driveLogId,
    required String userId,
    GeoPoint2D? endLocation,
    String? endAddress,
    required DriveStatistics statistics,
    String? title,
    String? description,
    WeatherCondition? weather,
    List<RoadType>? roadTypes,
    List<String>? tags,
    bool isPublic = false,
  }) async =>
      Result.success(_makeLog());

  @override
  Future<Result<void, AppError>> addWaypoint({
    required String driveLogId,
    required DriveWaypoint waypoint,
  }) async =>
      const Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

DriveLog _makeLog() {
  final now = DateTime.now();
  return DriveLog(
    id: 'drive1',
    userId: 'user1',
    status: DriveLogStatus.recording,
    startTime: now,
    statistics: const DriveStatistics(
      totalDistance: 0,
      totalDuration: 0,
      averageSpeed: 0,
      maxSpeed: 0,
    ),
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeDriveProvider extends DriveRecordingProvider {
  final bool _isRecording;
  final bool _isLoading;
  final bool _startShouldFail;
  final String? _errorMessage;
  final double _distanceKm;
  final double _currentSpeed;
  final double _maxSpeed;

  _FakeDriveProvider({
    bool isRecording = true,
    bool isLoading = false,
    bool startShouldFail = false,
    String? errorMessage,
    double distanceKm = 0.0,
    double currentSpeed = 42.0,
    double maxSpeed = 68.0,
  })  : _isRecording = isRecording,
        _isLoading = isLoading,
        _startShouldFail = startShouldFail,
        _errorMessage = errorMessage,
        _distanceKm = distanceKm,
        _currentSpeed = currentSpeed,
        _maxSpeed = maxSpeed,
        super(
          driveLogService: _StubDriveLogService(),
          permissionChecker: () async => true,
          positionStreamFactory: Stream.empty,
        );

  @override
  bool get isRecording => _isRecording;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;
  @override
  String get formattedElapsed => '12:34';
  @override
  double get distanceKm => _distanceKm;
  @override
  double get currentSpeedKmh => _currentSpeed;
  @override
  double get maxSpeedKmh => _maxSpeed;

  @override
  Future<bool> startRecording({
    required String userId,
    String? vehicleId,
  }) async =>
      !_startShouldFail;

  @override
  Future<void> stopRecording() async {}
}

Widget _buildDriveScreen(_FakeDriveProvider provider,
    {String? vehicleId, String? vehicleName}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
          create: (_) => _LoggedInAuthProvider()),
      ChangeNotifierProvider<DriveRecordingProvider>.value(value: provider),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true),
      home: DriveRecordingScreen(
        vehicleId: vehicleId,
        vehicleName: vehicleName,
      ),
    ),
  );
}

// =============================================================================
// ShopOwnerScreen stubs
// =============================================================================

class _StubShopService implements ShopService {
  @override
  Future<Result<Shop?, AppError>> getMyShop(String uid) async =>
      const Result.success(null);
  @override
  Future<Result<void, AppError>> deleteMyShop(String uid) async =>
      const Result.success(null);
  @override
  Stream<Map<String, int>> watchInquiryCount(String shopId) =>
      const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubInquiryService implements InquiryService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeShopProvider extends ShopProvider {
  final Shop? _fakeShop;
  final int _fakeTotal;
  final int _fakeUnread;
  final bool _fakeIsLoading;
  final bool _deleteShouldSucceed;

  _FakeShopProvider({
    Shop? shop,
    int inquiryTotal = 0,
    int inquiryUnread = 0,
    bool isLoading = false,
    bool deleteShouldSucceed = true,
  })  : _fakeShop = shop,
        _fakeTotal = inquiryTotal,
        _fakeUnread = inquiryUnread,
        _fakeIsLoading = isLoading,
        _deleteShouldSucceed = deleteShouldSucceed,
        super(
          shopService: _StubShopService(),
          inquiryService: _StubInquiryService(),
        );

  @override
  Shop? get myShop => _fakeShop;
  @override
  int get inquiryTotal => _fakeTotal;
  @override
  int get inquiryUnread => _fakeUnread;
  @override
  bool get isLoading => _fakeIsLoading;
  @override
  Future<void> loadMyShop(String uid) async {}
  @override
  void startWatchingInquiries(String shopId) {}
  @override
  void stopWatchingInquiries() {}
  @override
  Future<bool> deleteMyShop(String uid) async => _deleteShouldSucceed;
}

Shop _makeShop({
  String id = 'shop1',
  String name = 'テストモータース',
  ShopPlanType planType = ShopPlanType.free,
  double? rating,
  String? prefecture,
  String? city,
}) {
  final now = DateTime.now();
  return Shop(
    id: id,
    name: name,
    type: ShopType.maintenanceShop,
    planType: planType,
    subscriptionStatus: ShopSubscriptionStatus.active,
    rating: rating,
    prefecture: prefecture,
    city: city,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildShopScreen(_FakeShopProvider shopProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
          create: (_) => _LoggedInAuthProvider()),
      ChangeNotifierProvider<ShopProvider>.value(value: shopProvider),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true),
      home: const ShopOwnerScreen(),
    ),
  );
}

// =============================================================================
// Golden Tests — DriveRecordingScreen
// =============================================================================

void main() {
  group('Golden — DriveRecordingScreen', () {
    testWidgets('recording_normal: stat cards and GPS indicator',
        (tester) async {
      await tester.pumpWidget(_buildDriveScreen(
        _FakeDriveProvider(currentSpeed: 42, maxSpeed: 68, distanceKm: 0.3),
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/drive_recording_normal.png'),
      );
    });

    testWidgets('recording_loading: CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
          _buildDriveScreen(_FakeDriveProvider(isLoading: true)));
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/drive_recording_loading.png'),
      );
    });

    testWidgets('recording_dialog: stop confirmation dialog open',
        (tester) async {
      await tester.pumpWidget(_buildDriveScreen(_FakeDriveProvider()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('記録を終了'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/drive_recording_dialog.png'),
      );
    });

    testWidgets('recording_error: permission denied snackbar', (tester) async {
      final provider = _FakeDriveProvider(
        isRecording: false,
        startShouldFail: true,
        errorMessage: '位置情報の権限が必要です',
      );
      await tester.pumpWidget(_buildDriveScreen(provider));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/drive_recording_error.png'),
      );
    });

    testWidgets('recording_km: distance shown as km (12.34 km)', (tester) async {
      await tester.pumpWidget(_buildDriveScreen(
        _FakeDriveProvider(distanceKm: 12.34),
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/drive_recording_km.png'),
      );
    });

    testWidgets('recording_vehicle: vehicle name in AppBar', (tester) async {
      await tester.pumpWidget(_buildDriveScreen(
        _FakeDriveProvider(),
        vehicleId: 'v1',
        vehicleName: 'GR86',
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/drive_recording_vehicle.png'),
      );
    });
  });

  // ===========================================================================
  // Golden Tests — ShopOwnerScreen
  // ===========================================================================

  group('Golden — ShopOwnerScreen', () {
    testWidgets('shop_unregistered: invitation + 3 plan cards', (tester) async {
      await tester.pumpWidget(_buildShopScreen(_FakeShopProvider()));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shop_owner_unregistered.png'),
      );
    });

    testWidgets('shop_loading: loading indicator', (tester) async {
      await tester.pumpWidget(
          _buildShopScreen(_FakeShopProvider(isLoading: true)));
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shop_owner_loading.png'),
      );
    });

    testWidgets('shop_registered_free: shop card + upgrade banner',
        (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(
          name: 'テストモータース',
          planType: ShopPlanType.free,
          prefecture: '東京都',
          city: '渋谷区',
          rating: 4.5,
        ),
        inquiryTotal: 3,
        inquiryUnread: 1,
      );
      await tester.pumpWidget(_buildShopScreen(provider));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shop_owner_registered_free.png'),
      );
    });

    testWidgets('shop_registered_standard: standard badge, no upgrade banner',
        (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(
          name: 'スタンダードモータース',
          planType: ShopPlanType.standard,
          prefecture: '大阪府',
          city: '中央区',
          rating: 4.8,
        ),
        inquiryTotal: 15,
        inquiryUnread: 5,
      );
      await tester.pumpWidget(_buildShopScreen(provider));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shop_owner_registered_standard.png'),
      );
    });

    testWidgets('shop_registered_premium: premium badge, no upgrade banner',
        (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(
          name: 'プレミアムモータース',
          planType: ShopPlanType.premium,
          prefecture: '愛知県',
          city: '名古屋市',
          rating: 5.0,
        ),
        inquiryTotal: 42,
        inquiryUnread: 0,
      );
      await tester.pumpWidget(_buildShopScreen(provider));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shop_owner_registered_premium.png'),
      );
    });

    testWidgets('shop_delete_dialog: delete confirmation dialog open',
        (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(planType: ShopPlanType.free),
      );
      await tester.pumpWidget(_buildShopScreen(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('掲載を削除'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shop_owner_delete_dialog.png'),
      );
    });

    testWidgets('shop_inquiry_badge: total + unread counts visible',
        (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(planType: ShopPlanType.standard),
        inquiryTotal: 10,
        inquiryUnread: 3,
      );
      await tester.pumpWidget(_buildShopScreen(provider));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shop_owner_inquiry_badge.png'),
      );
    });
  });
}
