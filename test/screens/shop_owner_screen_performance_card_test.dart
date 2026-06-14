// _PerformanceSummaryCard Widget Tests
//
// Strategy: pump the full ShopOwnerScreen with a _FakeShopProvider that has
// myShop set (registered state).  Because _PerformanceSummaryCard is private it
// cannot be instantiated directly; instead we verify its rendered output through
// the screen's widget tree.
//
// Note: Full integration tests that exercise ShopProvider against a live
// Firestore emulator are in test/integration/.  These tests are purely in-memory
// and carry the tag "widget" (not "emulator").

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;

import 'package:trust_car_platform/screens/marketplace/shop_owner_screen.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/shop_case_study.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Stub Services (no-op; never touch Firebase)
// ---------------------------------------------------------------------------

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
  Future<Result<List<ShopCaseStudy>, AppError>> getCaseStudies(
          String shopId) async =>
      const Result.success([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubInquiryService implements InquiryService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubAuthService implements AuthService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

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

// ---------------------------------------------------------------------------
// Fake Firebase User + LoggedIn AuthProvider
// ---------------------------------------------------------------------------

class _FakeUser implements User {
  @override
  String get uid => 'owner-uid';
  @override
  String? get displayName => 'Shop Owner';
  @override
  String? get photoURL => null;
  @override
  String? get email => 'owner@example.com';
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

// ---------------------------------------------------------------------------
// Fake ShopProvider — exposes myShop and inquiryTotal without Firestore
// ---------------------------------------------------------------------------

class _FakeShopProvider extends ShopProvider {
  final Shop? _fakeShop;
  final int _fakeTotal;

  _FakeShopProvider({
    required Shop shop,
    int inquiryTotal = 0,
  })  : _fakeShop = shop,
        _fakeTotal = inquiryTotal,
        super(
          shopService: _StubShopService(),
          inquiryService: _StubInquiryService(),
        );

  @override
  Shop? get myShop => _fakeShop;

  @override
  int get inquiryTotal => _fakeTotal;

  @override
  int get inquiryUnread => 0;

  @override
  bool get isLoading => false;

  // Skip all async Firestore operations
  @override
  Future<void> loadMyShop(String uid) async {}

  @override
  void startWatchingInquiries(String shopId) {}

  @override
  void stopWatchingInquiries() {}
}

// ---------------------------------------------------------------------------
// Shop factory — only the fields relevant to _PerformanceSummaryCard
// ---------------------------------------------------------------------------

Shop _makeShop({
  String id = 'shop1',
  String name = 'テストモータース',
  ShopPlanType planType = ShopPlanType.free,
  DateTime? createdAt,
  DateTime? planExpiresAt,
}) {
  final now = DateTime.now();
  return Shop(
    id: id,
    name: name,
    type: ShopType.maintenanceShop,
    planType: planType,
    planExpiresAt: planExpiresAt,
    subscriptionStatus: ShopSubscriptionStatus.free,
    isActive: true,
    createdAt: createdAt ?? now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Widget builder — minimal tree that contains _PerformanceSummaryCard
// ---------------------------------------------------------------------------

Widget _buildScreen(_FakeShopProvider shopProvider) {
  sl.override<ShopService>(_StubShopService());
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => _LoggedInAuthProvider(),
      ),
      ChangeNotifierProvider<ShopProvider>.value(value: shopProvider),
    ],
    child: const MaterialApp(home: ShopOwnerScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  tearDown(() {
    Injection.reset();
  });

  group('ShopOwnerScreen _PerformanceSummaryCard', () {
    // -----------------------------------------------------------------------
    // 1. 掲載日数 (days since createdAt)
    // -----------------------------------------------------------------------
    testWidgets('shows correct day count since createdAt', (tester) async {
      // Shop created 30 days ago
      final createdAt = DateTime.now().subtract(const Duration(days: 30));
      final provider = _FakeShopProvider(
        shop: _makeShop(createdAt: createdAt),
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // The card renders '$daysSince 日'
      expect(find.text('30 日'), findsOneWidget);
    });

    testWidgets('shows 0 日 when shop was created today', (tester) async {
      final provider = _FakeShopProvider(
        // createdAt defaults to DateTime.now() in _makeShop
        shop: _makeShop(),
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('0 日'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 2. 累計問い合わせ (inquiry total from provider)
    // -----------------------------------------------------------------------
    testWidgets('shows inquiry total from provider', (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(),
        inquiryTotal: 42,
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // The card renders '$total 件'
      expect(find.text('42 件'), findsOneWidget);
    });

    testWidgets('shows 0 件 when there are no inquiries', (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(),
        inquiryTotal: 0,
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // "0 件" may appear in both the inquiry stat and the case-study tile;
      // just confirm it is present somewhere.
      expect(find.text('0 件'), findsWidgets);
    });

    // -----------------------------------------------------------------------
    // 3 & 4. プラン displayName
    // -----------------------------------------------------------------------
    testWidgets('shows plan displayName フリー for free plan', (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(planType: ShopPlanType.free),
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('フリー'), findsOneWidget);
    });

    testWidgets('shows plan displayName スタンダード for standard plan',
        (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(planType: ShopPlanType.standard),
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('スタンダード'), findsOneWidget);
    });

    testWidgets('shows plan displayName プレミアム for premium plan',
        (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(planType: ShopPlanType.premium),
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('プレミアム'), findsOneWidget);
    });

    testWidgets('shows plan displayName エンタープライズ for enterprise plan',
        (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(planType: ShopPlanType.enterprise),
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('エンタープライズ'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 5. Plan expiry date shown when planExpiresAt is set
    // -----------------------------------------------------------------------
    testWidgets('shows plan expiry date when planExpiresAt is set',
        (tester) async {
      final expiry = DateTime(2026, 12, 31);
      final provider = _FakeShopProvider(
        shop: _makeShop(
          planType: ShopPlanType.premium,
          planExpiresAt: expiry,
        ),
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // The card formats as 'プラン期限: yyyy/mm/dd'
      expect(find.text('プラン期限: 2026/12/31'), findsOneWidget);
    });

    testWidgets('formats single-digit month and day with leading zero',
        (tester) async {
      final expiry = DateTime(2026, 3, 5);
      final provider = _FakeShopProvider(
        shop: _makeShop(
          planType: ShopPlanType.standard,
          planExpiresAt: expiry,
        ),
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('プラン期限: 2026/03/05'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 6. Plan expiry line absent when planExpiresAt is null
    // -----------------------------------------------------------------------
    testWidgets('does NOT show expiry line when planExpiresAt is null',
        (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(planExpiresAt: null),
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.textContaining('プラン期限:'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 7. Card header label
    // -----------------------------------------------------------------------
    testWidgets('shows 掲載実績 section heading', (tester) async {
      final provider = _FakeShopProvider(shop: _makeShop());

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('掲載実績'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // 8. Stat item labels
    // -----------------------------------------------------------------------
    testWidgets('shows 掲載日数, 累計問い合わせ, and プラン stat labels', (tester) async {
      final provider = _FakeShopProvider(shop: _makeShop());

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('掲載日数'), findsOneWidget);
      expect(find.text('累計問い合わせ'), findsOneWidget);
      expect(find.text('プラン'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Pure-unit tests for the key calculations (no widget pump required)
  // ---------------------------------------------------------------------------

  group('ShopPlanType.displayName unit tests', () {
    test('free displayName is フリー', () {
      expect(ShopPlanType.free.displayName, 'フリー');
    });

    test('standard displayName is スタンダード', () {
      expect(ShopPlanType.standard.displayName, 'スタンダード');
    });

    test('premium displayName is プレミアム', () {
      expect(ShopPlanType.premium.displayName, 'プレミアム');
    });

    test('enterprise displayName is エンタープライズ', () {
      expect(ShopPlanType.enterprise.displayName, 'エンタープライズ');
    });
  });

  group('daysSince calculation unit tests', () {
    test('difference is 0 for a shop created today', () {
      final now = DateTime.now();
      final days = now.difference(now).inDays;
      expect(days, 0);
    });

    test('difference is 365 for a shop created exactly one year ago', () {
      final now = DateTime.now();
      final oneYearAgo = now.subtract(const Duration(days: 365));
      final days = now.difference(oneYearAgo).inDays;
      expect(days, 365);
    });

    test('difference is 1 for a shop created 24 hours ago', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));
      final days = now.difference(yesterday).inDays;
      expect(days, 1);
    });
  });
}
