// _MonthlyReportCard Widget Tests
//
// Strategy: pump the full ShopOwnerScreen with a _FakeShopProvider that exposes
// a monthlyReport.  Because _MonthlyReportCard is private it cannot be
// instantiated directly; instead we verify its rendered output through the
// screen's widget tree.  Purely in-memory (tag "widget", not "emulator").

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
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/models/shop_monthly_report.dart';
import 'package:trust_car_platform/models/user.dart';
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
// Fake ShopProvider — exposes myShop and monthlyReport without Firestore
// ---------------------------------------------------------------------------

class _FakeShopProvider extends ShopProvider {
  final Shop? _fakeShop;
  final ShopMonthlyReport? _fakeReport;

  _FakeShopProvider({
    required Shop shop,
    ShopMonthlyReport? report,
  })  : _fakeShop = shop,
        _fakeReport = report,
        super(
          shopService: _StubShopService(),
          inquiryService: _StubInquiryService(),
        );

  @override
  Shop? get myShop => _fakeShop;

  @override
  ShopMonthlyReport? get monthlyReport => _fakeReport;

  @override
  int get inquiryTotal => 0;

  @override
  int get inquiryUnread => 0;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadMyShop(String uid) async {}

  @override
  Future<void> loadMonthlyReport(String shopId) async {}

  @override
  void startWatchingInquiries(String shopId) {}

  @override
  void stopWatchingInquiries() {}
}

Shop _makeShop() {
  final now = DateTime.now();
  return Shop(
    id: 'shop1',
    name: 'テストモータース',
    type: ShopType.maintenanceShop,
    planType: ShopPlanType.standard,
    subscriptionStatus: ShopSubscriptionStatus.active,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

ShopMonthlyReport _makeReport({
  int total = 5,
  int previousTotal = 3,
  int pending = 2,
  int replied = 1,
  int proposalCount = 0,
  int proposalValue = 0,
}) {
  return ShopMonthlyReport(
    month: DateTime(2026, 6, 1),
    total: total,
    previousTotal: previousTotal,
    byStatus: {
      InquiryStatus.pending: pending,
      InquiryStatus.replied: replied,
    },
    maintenanceProposalCount: proposalCount,
    maintenanceProposalValue: proposalValue,
  );
}

Widget _buildScreen(_FakeShopProvider shopProvider) {
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

void main() {
  group('ShopOwnerScreen _MonthlyReportCard', () {
    testWidgets('renders heading and counts when a report is present',
        (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(),
        report: _makeReport(total: 5, pending: 2, replied: 1),
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('今月の問い合わせ'), findsOneWidget);
      expect(find.text('5 件'), findsOneWidget); // total
      expect(find.text('2 件'), findsOneWidget); // pending
      expect(find.text('1 件'), findsOneWidget); // replied
    });

    testWidgets('shows positive month-over-month change', (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(),
        report: _makeReport(total: 5, previousTotal: 3),
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('前月比 +2 件'), findsOneWidget);
    });

    testWidgets('shows "前月と同じ" when unchanged', (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(),
        report: _makeReport(total: 4, previousTotal: 4),
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('前月と同じ'), findsOneWidget);
    });

    testWidgets('renders maintenance proposal count and total value',
        (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(),
        report: _makeReport(proposalCount: 3, proposalValue: 45000),
      );

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('今月の整備提案（成果）'), findsOneWidget);
      expect(find.text('3 件'), findsOneWidget); // proposal count
      expect(find.text('¥45,000'), findsOneWidget); // formatted total value
    });

    testWidgets('renders nothing when report is null', (tester) async {
      final provider = _FakeShopProvider(shop: _makeShop());

      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('今月の問い合わせ'), findsNothing);
    });
  });
}
