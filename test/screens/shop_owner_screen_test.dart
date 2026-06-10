// ShopOwnerScreen Widget Tests
//
// Coverage:
//   Unregistered state:
//     1. Shows invitation headline
//     2. Shows 3 plan summary cards (Free / Standard / Premium)
//     3. Shows '無料で掲載を始める' button
//     4. Tapping button navigates to ShopRegistrationScreen
//   Registered state:
//     5. Shows shop name
//     6. Shows plan badge (Free / Standard / Premium)
//     7. Shows '掲載情報を編集' button
//     8. Shows inquiry count badge (tap to navigate)
//     9. Shows upgrade banner for Free plan
//    10. Hides upgrade banner for paid plans
//    11. '掲載を削除' button shows confirmation dialog
//    12. Confirmation 'キャンセル' → dialog dismissed
//    13. Confirmation '削除する' → deleteMyShop called
//    14. Shows total and unread inquiry counts
//   Loading state:
//    15. Shows AppLoadingCenter while loading

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;

import 'package:trust_car_platform/screens/marketplace/shop_owner_screen.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Stub Services
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
// Fake ShopProvider
// ---------------------------------------------------------------------------

class _FakeShopProvider extends ShopProvider {
  final Shop? _fakeShop;
  final int _fakeTotal;
  final int _fakeUnread;
  final bool _fakeIsLoading;
  final bool _deleteShouldSucceed;

  bool deleteCalled = false;

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
  Future<bool> deleteMyShop(String uid) async {
    deleteCalled = true;
    return _deleteShouldSucceed;
  }
}

// ---------------------------------------------------------------------------
// Test shop factory
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ShopOwnerScreen — Loading state', () {
    testWidgets('shows loading indicator while loading', (tester) async {
      final provider = _FakeShopProvider(isLoading: true);
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pump();

      expect(find.text('店舗情報を読み込み中...'), findsOneWidget);
    });

    testWidgets('AppBar shows 掲載管理 during loading', (tester) async {
      final provider = _FakeShopProvider(isLoading: true);
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pump();

      expect(find.text('掲載管理'), findsOneWidget);
    });
  });

  group('ShopOwnerScreen — Unregistered state (myShop == null)', () {
    testWidgets('shows invitation headline', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeShopProvider()));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('あなたの店舗を掲載しましょう'), findsOneWidget);
    });

    testWidgets('shows description text', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeShopProvider()));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(
        find.textContaining('整備工場・ディーラー'),
        findsOneWidget,
      );
    });

    testWidgets('shows Free plan card', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeShopProvider()));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('Free'), findsOneWidget);
      expect(find.text('0円'), findsOneWidget);
    });

    testWidgets('shows Standard plan card with price', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeShopProvider()));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('9,800円 / 月'), findsOneWidget);
    });

    testWidgets('shows Premium plan card with price', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeShopProvider()));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('29,800円 / 月'), findsOneWidget);
    });

    testWidgets('shows register button', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeShopProvider()));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('無料で掲載を始める'), findsOneWidget);
    });

    testWidgets('プランを選択 section heading is shown', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeShopProvider()));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('プランを選択'), findsOneWidget);
    });

    testWidgets('Free plan shows features', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeShopProvider()));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('基本情報を掲載'), findsOneWidget);
      expect(find.text('問い合わせ受付'), findsOneWidget);
    });
  });

  group('ShopOwnerScreen — Registered state (myShop != null)', () {
    testWidgets('shows shop name', (tester) async {
      final provider = _FakeShopProvider(shop: _makeShop(name: 'タカヤモータース'));
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('タカヤモータース'), findsOneWidget);
    });

    testWidgets('shows Free plan badge', (tester) async {
      final provider =
          _FakeShopProvider(shop: _makeShop(planType: ShopPlanType.free));
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // One badge in summary card, possibly one in unregistered cards — but
      // in registered mode only the summary card badge is shown.
      expect(find.text('Free'), findsOneWidget);
    });

    testWidgets('shows Standard plan badge', (tester) async {
      final provider =
          _FakeShopProvider(shop: _makeShop(planType: ShopPlanType.standard));
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('Standard'), findsOneWidget);
    });

    testWidgets('shows Premium plan badge', (tester) async {
      final provider =
          _FakeShopProvider(shop: _makeShop(planType: ShopPlanType.premium));
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('Premium'), findsOneWidget);
    });

    testWidgets('shows prefecture and city when set', (tester) async {
      final provider = _FakeShopProvider(
        shop: _makeShop(prefecture: '東京都', city: '渋谷区'),
      );
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('東京都 渋谷区'), findsOneWidget);
    });

    testWidgets('shows star rating when available', (tester) async {
      final provider = _FakeShopProvider(shop: _makeShop(rating: 4.3));
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('4.3'), findsOneWidget);
    });

    testWidgets('shows 掲載情報を編集 button', (tester) async {
      final provider = _FakeShopProvider(shop: _makeShop());
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('掲載情報を編集'), findsOneWidget);
    });

    testWidgets('shows 掲載を削除 button', (tester) async {
      final provider = _FakeShopProvider(shop: _makeShop());
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('掲載を削除'), findsOneWidget);
    });
  });

  group('ShopOwnerScreen — Inquiry count badge', () {
    testWidgets('shows inquiry count when no unread', (tester) async {
      final provider = _FakeShopProvider(
          shop: _makeShop(), inquiryTotal: 5, inquiryUnread: 0);
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('問い合わせ 5 件'), findsOneWidget);
    });

    testWidgets('shows total and unread count when there are unread inquiries',
        (tester) async {
      final provider = _FakeShopProvider(
          shop: _makeShop(), inquiryTotal: 10, inquiryUnread: 3);
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // RichText spans — use textContaining to match partial span text
      expect(find.textContaining('全 10 件'), findsOneWidget);
      expect(find.textContaining('未読 3 件'), findsOneWidget);
    });

    testWidgets('shows 問い合わせ section', (tester) async {
      final provider = _FakeShopProvider(shop: _makeShop());
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('問い合わせ'), findsOneWidget);
    });
  });

  group('ShopOwnerScreen — Upgrade banner (Free plan)', () {
    testWidgets('shows upgrade banner for Free plan shop', (tester) async {
      final provider =
          _FakeShopProvider(shop: _makeShop(planType: ShopPlanType.free));
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('プランをアップグレードしませんか?'), findsOneWidget);
    });

    testWidgets('hides upgrade banner for Standard plan', (tester) async {
      final provider =
          _FakeShopProvider(shop: _makeShop(planType: ShopPlanType.standard));
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('プランをアップグレードしませんか?'), findsNothing);
    });

    testWidgets('hides upgrade banner for Premium plan', (tester) async {
      final provider =
          _FakeShopProvider(shop: _makeShop(planType: ShopPlanType.premium));
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('プランをアップグレードしませんか?'), findsNothing);
    });
  });

  group('ShopOwnerScreen — Delete listing dialog', () {
    testWidgets('tapping 掲載を削除 shows confirmation dialog', (tester) async {
      final provider = _FakeShopProvider(shop: _makeShop());
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('掲載を削除'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('掲載を削除しますか?'), findsOneWidget);
      expect(
          find.text('この操作は取り消せません。\n掲載情報・問い合わせ履歴はすべて削除されます。'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
      expect(find.text('削除する'), findsOneWidget);
    });

    testWidgets("tapping 'キャンセル' dismisses dialog without deleting",
        (tester) async {
      final provider = _FakeShopProvider(shop: _makeShop());
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('掲載を削除'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(provider.deleteCalled, isFalse);
      expect(find.text('掲載を削除しますか?'), findsNothing);
    });

    testWidgets("tapping '削除する' calls deleteMyShop", (tester) async {
      final provider =
          _FakeShopProvider(shop: _makeShop(), deleteShouldSucceed: true);
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('掲載を削除'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('削除する'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(provider.deleteCalled, isTrue);
    });

    testWidgets('shows success snackbar after delete', (tester) async {
      final provider =
          _FakeShopProvider(shop: _makeShop(), deleteShouldSucceed: true);
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('掲載を削除'));
      await tester.pumpAndSettle(const Duration(seconds: 10));
      await tester.tap(find.text('削除する'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('掲載を削除しました'), findsOneWidget);
    });
  });

  group('ShopOwnerScreen — Edge cases', () {
    testWidgets('no crash when shop has no rating', (tester) async {
      final provider = _FakeShopProvider(shop: _makeShop(rating: null));
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(tester.takeException(), isNull);
      expect(find.text('テストモータース'), findsOneWidget);
    });

    testWidgets('shows store icon when no logoUrl', (tester) async {
      final provider = _FakeShopProvider(shop: _makeShop());
      await tester.pumpWidget(_buildScreen(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byIcon(Icons.store), findsOneWidget);
    });
  });
}
