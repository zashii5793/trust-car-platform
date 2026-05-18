// MyListingsScreen Widget Tests
//
// Coverage:
//   Loading state:
//     1. Shows CircularProgressIndicator while loading
//   Empty state:
//     2. Shows 'まだ出品していません'
//     3. Shows '出品する' FilledButton in empty state
//   Error state:
//     4. Shows error message
//     5. Shows '再読み込み' retry button
//   Listings displayed:
//     6. Shows listing title
//     7. Shows price display
//     8. Shows '出品中' status badge for active listing
//     9. Shows '売り切れ' status badge for soldOut listing
//    10. Shows '取り下げ' status badge for cancelled listing
//   FAB:
//    11. Shows '出品する' FAB
//   Action sheet:
//    12. Tapping listing shows action sheet
//    13. Action sheet shows '売り切れにする' for active listing
//    14. Action sheet shows '取り下げる' for active listing
//    15. Action sheet shows '編集' always
//    16. soldOut listing action sheet hides '売り切れにする'
//   AppBar:
//    17. Shows 'マイ出品' title
//   Edge Cases:
//    18. Multiple listings all displayed
//    19. Retry button re-triggers load

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;

import 'package:trust_car_platform/screens/marketplace/my_listings_screen.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/part_listing_service.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/models/user_part_listing.dart';
import 'package:trust_car_platform/models/part_listing.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/di/injection.dart';

// ---------------------------------------------------------------------------
// Stub PartListingService
// ---------------------------------------------------------------------------

class _StubPartListingService implements PartListingService {
  Result<List<UserPartListing>, AppError> myListingsResult =
      const Result.success([]);
  int loadCallCount = 0;

  @override
  Future<Result<List<UserPartListing>, AppError>> getMyListings(
      String userId) async {
    loadCallCount++;
    return myListingsResult;
  }

  @override
  Future<Result<void, AppError>> updateListingStatus(
      String id, PartListingStatus status) async =>
      const Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Stub AuthService + AuthProvider
// ---------------------------------------------------------------------------

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
  Future<Result<void, AppError>> signOut() async =>
      const Result.success(null);
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
  String get uid => 'seller-uid';
  @override
  String? get displayName => null;
  @override
  String? get photoURL => null;
  @override
  String? get email => 'seller@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _LoggedInAuthProvider extends AuthProvider {
  _LoggedInAuthProvider() : super(authService: _StubAuthService());
  @override
  User? get firebaseUser => _FakeUser();
  @override
  bool get isLoading => false;
}

// ---------------------------------------------------------------------------
// Test data factory
// ---------------------------------------------------------------------------

UserPartListing _makeListing({
  String id = 'listing-1',
  String title = 'テストパーツ',
  int price = 10000,
  int payout = 9200,
  PartListingStatus status = PartListingStatus.active,
}) {
  final now = DateTime(2025, 5, 1);
  return UserPartListing(
    id: id,
    sellerId: 'seller-uid',
    title: title,
    category: PartCategory.aero,
    condition: PartCondition.goodCondition,
    price: price,
    payout: payout,
    description: 'テスト説明',
    shippingMethod: ShippingMethod.includedInPrice,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Widget builder + setup helpers
// ---------------------------------------------------------------------------

late _StubPartListingService _stub;

Widget _buildScreen() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => _LoggedInAuthProvider(),
      ),
    ],
    child: const MaterialApp(home: MyListingsScreen()),
  );
}

void main() {
  setUp(() {
    _stub = _StubPartListingService();
    ServiceLocator.instance.override<PartListingService>(_stub);
  });

  tearDown(() {
    ServiceLocator.instance.unregister<PartListingService>();
  });

  group('MyListingsScreen — AppBar', () {
    testWidgets('17. shows マイ出品 title', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('マイ出品'), findsOneWidget);
    });
  });

  group('MyListingsScreen — Loading state', () {
    testWidgets('1. shows spinner while loading', (tester) async {
      // Use a slow stub that doesn't complete
      _stub.myListingsResult = const Result.success([]);

      await tester.pumpWidget(_buildScreen());
      await tester.pump(); // Don't settle — catch loading frame

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('MyListingsScreen — Empty state', () {
    testWidgets('2. shows まだ出品していません', (tester) async {
      _stub.myListingsResult = const Result.success([]);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('まだ出品していません'), findsOneWidget);
    });

    testWidgets('3. shows 出品する button in empty state', (tester) async {
      _stub.myListingsResult = const Result.success([]);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('出品する'), findsWidgets);
    });
  });

  group('MyListingsScreen — Error state', () {
    testWidgets('4. shows error message on failure', (tester) async {
      _stub.myListingsResult =
          Result.failure(AppError.server('読み込みに失敗しました'));

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(SnackBar), findsNothing);
      // Error shown inline
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('5. shows 再読み込み retry button', (tester) async {
      _stub.myListingsResult =
          Result.failure(AppError.server('エラー'));

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('再読み込み'), findsOneWidget);
    });
  });

  group('MyListingsScreen — Listings displayed', () {
    testWidgets('6. shows listing title', (tester) async {
      _stub.myListingsResult =
          Result.success([_makeListing(title: 'BLITZ車高調 ZZ-R')]);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('BLITZ車高調 ZZ-R'), findsOneWidget);
    });

    testWidgets('7. shows price display', (tester) async {
      _stub.myListingsResult =
          Result.success([_makeListing(price: 15000, payout: 13800)]);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // priceDisplay formats price with ¥
      expect(find.textContaining('¥'), findsWidgets);
    });

    testWidgets('8. shows 出品中 badge for active listing', (tester) async {
      _stub.myListingsResult =
          Result.success([_makeListing(status: PartListingStatus.active)]);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('出品中'), findsOneWidget);
    });

    testWidgets('9. shows 売り切れ badge for soldOut listing', (tester) async {
      _stub.myListingsResult =
          Result.success([_makeListing(status: PartListingStatus.soldOut)]);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('売り切れ'), findsOneWidget);
    });

    testWidgets('10. shows 取り下げ badge for cancelled listing', (tester) async {
      _stub.myListingsResult =
          Result.success([_makeListing(status: PartListingStatus.cancelled)]);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('取り下げ'), findsOneWidget);
    });
  });

  group('MyListingsScreen — FAB', () {
    testWidgets('11. shows 出品する FAB', (tester) async {
      _stub.myListingsResult = const Result.success([]);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('MyListingsScreen — Action sheet', () {
    testWidgets('12. tapping listing shows action sheet', (tester) async {
      _stub.myListingsResult =
          Result.success([_makeListing(title: 'アクションテスト')]);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('アクションテスト'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Action sheet appeared
      expect(find.text('売り切れにする'), findsOneWidget);
    });

    testWidgets('13. active listing action sheet has 売り切れにする', (tester) async {
      _stub.myListingsResult =
          Result.success([_makeListing(status: PartListingStatus.active)]);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('売り切れにする'), findsOneWidget);
    });

    testWidgets('14. active listing action sheet has 取り下げる', (tester) async {
      _stub.myListingsResult =
          Result.success([_makeListing(status: PartListingStatus.active)]);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('取り下げる'), findsOneWidget);
    });

    testWidgets('15. action sheet always has 編集', (tester) async {
      _stub.myListingsResult =
          Result.success([_makeListing(status: PartListingStatus.active)]);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('編集'), findsOneWidget);
    });

    testWidgets('16. soldOut listing action sheet hides 売り切れにする',
        (tester) async {
      _stub.myListingsResult =
          Result.success([_makeListing(status: PartListingStatus.soldOut)]);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('売り切れにする'), findsNothing);
      expect(find.text('取り下げる'), findsNothing);
      expect(find.text('編集'), findsOneWidget);
    });
  });

  group('MyListingsScreen — Edge Cases', () {
    testWidgets('18. multiple listings all displayed', (tester) async {
      _stub.myListingsResult = Result.success([
        _makeListing(id: '1', title: 'パーツA'),
        _makeListing(id: '2', title: 'パーツB'),
        _makeListing(id: '3', title: 'パーツC'),
      ]);

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('パーツA'), findsOneWidget);
      expect(find.text('パーツB'), findsOneWidget);
      expect(find.text('パーツC'), findsOneWidget);
    });

    testWidgets('19. retry button re-triggers load', (tester) async {
      _stub.myListingsResult = Result.failure(AppError.server('エラー'));

      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final countBefore = _stub.loadCallCount;
      await tester.tap(find.text('再読み込み'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(_stub.loadCallCount, greaterThan(countBefore));
    });
  });
}
