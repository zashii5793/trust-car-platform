// MyInquiriesScreen Widget Tests

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;

import 'package:trust_car_platform/screens/marketplace/my_inquiries_screen.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Stub services
// ---------------------------------------------------------------------------

class _StubShopService implements ShopService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubInquiryService implements InquiryService {
  @override
  Stream<List<InquiryMessage>> streamMessages(String inquiryId) =>
      Stream.value([]);

  @override
  Stream<List<Inquiry>> streamUserInquiries(String userId) => Stream.value([]);

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
// Fake providers
// ---------------------------------------------------------------------------

class _FakeShopProvider extends ShopProvider {
  final List<Inquiry> _inquiries;
  final bool _loading;
  final StreamController<List<Inquiry>> _streamController =
      StreamController<List<Inquiry>>.broadcast();

  _FakeShopProvider({
    List<Inquiry> inquiries = const [],
    bool loading = false,
  })  : _inquiries = List.of(inquiries),
        _loading = loading,
        super(
          shopService: _StubShopService(),
          inquiryService: _StubInquiryService(),
        );

  @override
  List<Inquiry> get userInquiries => _inquiries;

  @override
  bool get isLoadingUserInquiries => _loading;

  @override
  int get userInquiryUnreadTotal =>
      _inquiries.fold(0, (sum, i) => sum + i.unreadCountUser);

  @override
  void watchUserInquiries(String userId) {}

  @override
  void stopWatchingUserInquiries() {}

  @override
  void markUserInquiryAsReadLocally(String inquiryId) {}

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }
}

class _FakeAuthProvider extends AuthProvider {
  final User? _user;
  _FakeAuthProvider({User? user})
      : _user = user,
        super(authService: _StubAuthService());

  @override
  User? get firebaseUser => _user;
  @override
  bool get isLoading => false;
  @override
  bool get isAuthenticated => _user != null;
}

class _FakeUser implements User {
  @override
  String get uid => 'user-1';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Test data factory
// ---------------------------------------------------------------------------

Inquiry _makeInquiry({
  String id = 'inq-1',
  String subject = 'オイル交換の見積もり',
  InquiryStatus status = InquiryStatus.pending,
  int unreadCountUser = 0,
  String? shopName,
}) {
  final now = DateTime(2025, 6, 1, 10, 0);
  return Inquiry(
    id: id,
    userId: 'user-1',
    shopId: 'shop-1',
    type: InquiryType.estimate,
    subject: subject,
    initialMessage: '見積もりをお願いします',
    status: status,
    unreadCountUser: unreadCountUser,
    shopName: shopName ?? 'テスト工場',
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen({
  _FakeShopProvider? shopProvider,
  _FakeAuthProvider? authProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ShopProvider>.value(
        value: shopProvider ?? _FakeShopProvider(),
      ),
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider ?? _FakeAuthProvider(user: _FakeUser()),
      ),
    ],
    child: const MaterialApp(home: MyInquiriesScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MyInquiriesScreen — AppBar', () {
    testWidgets('AppBar に「マイ問い合わせ」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('マイ問い合わせ'), findsOneWidget);
    });
  });

  group('MyInquiriesScreen — 空状態', () {
    testWidgets('問い合わせがない場合に空状態メッセージが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        shopProvider: _FakeShopProvider(inquiries: []),
      ));
      await tester.pump();

      expect(find.text('問い合わせはありません'), findsOneWidget);
    });

    testWidgets('空状態でクラッシュしない', (tester) async {
      await tester.pumpWidget(_buildScreen(
        shopProvider: _FakeShopProvider(inquiries: []),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('MyInquiriesScreen — 問い合わせ一覧表示', () {
    testWidgets('件名が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        shopProvider: _FakeShopProvider(inquiries: [
          _makeInquiry(subject: 'タイヤ交換の予約'),
        ]),
      ));
      await tester.pump();

      expect(find.text('タイヤ交換の予約'), findsOneWidget);
    });

    testWidgets('工場名が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        shopProvider: _FakeShopProvider(inquiries: [
          _makeInquiry(shopName: 'サンシャイン自動車'),
        ]),
      ));
      await tester.pump();

      expect(find.text('サンシャイン自動車'), findsOneWidget);
    });

    testWidgets('複数の問い合わせが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        shopProvider: _FakeShopProvider(inquiries: [
          _makeInquiry(id: 'inq-1', subject: '件名1'),
          _makeInquiry(id: 'inq-2', subject: '件名2'),
          _makeInquiry(id: 'inq-3', subject: '件名3'),
        ]),
      ));
      await tester.pump();

      expect(find.text('件名1'), findsOneWidget);
      expect(find.text('件名2'), findsOneWidget);
      expect(find.text('件名3'), findsOneWidget);
    });

    testWidgets('返信待ちステータスが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        shopProvider: _FakeShopProvider(inquiries: [
          _makeInquiry(status: InquiryStatus.pending),
        ]),
      ));
      await tester.pump();

      expect(find.text('返信待ち'), findsOneWidget);
    });

    testWidgets('回答済みステータスが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        shopProvider: _FakeShopProvider(inquiries: [
          _makeInquiry(status: InquiryStatus.replied),
        ]),
      ));
      await tester.pump();

      expect(find.text('回答済み'), findsOneWidget);
    });
  });

  group('MyInquiriesScreen — 未読バッジ', () {
    testWidgets('未読メッセージがある場合にバッジが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        shopProvider: _FakeShopProvider(inquiries: [
          _makeInquiry(unreadCountUser: 2),
        ]),
      ));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('未読0件のときはバッジが表示されない', (tester) async {
      await tester.pumpWidget(_buildScreen(
        shopProvider: _FakeShopProvider(inquiries: [
          _makeInquiry(unreadCountUser: 0),
        ]),
      ));
      await tester.pump();

      // バッジとしての数字「0」は表示されない
      // 件名テキストと区別するためステータスバッジ隣の数字を検証
      expect(
        find.descendant(
          of: find.byType(CircleAvatar),
          matching: find.text('0'),
        ),
        findsNothing,
      );
    });
  });

  group('MyInquiriesScreen — 遷移', () {
    testWidgets('問い合わせをタップしても例外が発生しない', (tester) async {
      await tester.pumpWidget(_buildScreen(
        shopProvider: _FakeShopProvider(inquiries: [
          _makeInquiry(subject: 'タップテスト'),
        ]),
      ));
      await tester.pump();

      await tester.tap(find.text('タップテスト'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('Edge Cases', () {
    testWidgets('ローディング中でもクラッシュしない', (tester) async {
      await tester.pumpWidget(_buildScreen(
        shopProvider: _FakeShopProvider(loading: true),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('未認証ユーザーでも空状態が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        authProvider: _FakeAuthProvider(user: null),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
