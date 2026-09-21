// ShopInquiryListScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows '問い合わせ一覧' title
//   Filter chips:
//     2. Shows 'すべて' chip (selected by default)
//     3. Shows '未対応' chip
//     4. Shows '対応中' chip
//     5. Shows 'クローズ' chip
//   Loading state:
//     6. Shows loading indicator while loading
//   Empty state (no filter):
//     7. Shows '問い合わせはありません' when no inquiries
//   Empty state (filtered):
//     8. Shows 'このステータスの問い合わせはありません' when filter has no results
//   Inquiries displayed:
//     9. Shows inquiry subject
//    10. Shows inquiry initial message preview
//    11. Shows unread badge when unreadCountShop > 0
//    12. Unread badge hidden when unreadCountShop = 0
//   Bottom sheet:
//    13. Tapping inquiry shows detail bottom sheet
//   Edge Cases:
//    14. Multiple inquiries all displayed
//    15. Inquiry with status 'closed' displayed

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;

import 'package:trust_car_platform/screens/marketplace/shop_inquiry_list_screen.dart';
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
  Future<Result<void, AppError>> markAsRead({
    required String inquiryId,
    required bool isUser,
  }) async =>
      const Result.success(null);

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
          {String? displayName,
          String? photoUrl,
          String? prefecture,
          String? city}) async =>
      const Result.success(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Fake providers
// ---------------------------------------------------------------------------

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

  /// 送信は成功したことにする。サーバ側のステータス遷移（店舗の初回返信で
  /// pending → replied）は `InquiryService.sendMessage` が行うので、ここでは
  /// 画面がその遷移を自分の表示に反映できているかだけを見る。
  @override
  Future<Result<InquiryMessage, AppError>> sendInquiryMessage({
    required String inquiryId,
    required String senderId,
    required String content,
    List<String> attachmentUrls = const [],
    Map<String, dynamic>? maintenancePayload,
  }) async =>
      Result.success(InquiryMessage(
        id: 'msg-sent',
        senderId: senderId,
        isFromShop: true,
        content: content,
        sentAt: DateTime(2026, 9, 22, 8, 0),
      ));
}

class _FakeUser implements User {
  @override
  String get uid => 'shop-1';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider() : super(authService: _StubAuthService());

  @override
  User? get firebaseUser => _FakeUser();

  @override
  bool get isLoading => false;
}

// ---------------------------------------------------------------------------
// Test data factory
// ---------------------------------------------------------------------------

Inquiry _makeInquiry({
  String id = 'inquiry-1',
  String subject = 'テスト問い合わせ件名',
  String initialMessage = 'テスト問い合わせ本文',
  InquiryStatus status = InquiryStatus.pending,
  int unreadCountShop = 0,
  DateTime? updatedAt,
  DateTime? repliedAt,
}) {
  final now = updatedAt ?? DateTime(2025, 6, 1, 10, 0);
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
    repliedAt: repliedAt,
  );
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen({
  _FakeShopProvider? shopProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ShopProvider>.value(
        value: shopProvider ?? _FakeShopProvider(),
      ),
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuthProvider(),
      ),
    ],
    child: const MaterialApp(
      home: ShopInquiryListScreen(shopId: 'shop-1'),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ShopInquiryListScreen — AppBar', () {
    testWidgets('1. shows 問い合わせ一覧 title', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('問い合わせ一覧'), findsOneWidget);
    });
  });

  group('ShopInquiryListScreen — Filter chips', () {
    testWidgets('2. shows すべて chip', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('すべて'), findsOneWidget);
    });

    testWidgets('3. shows 未対応 chip', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('未対応'), findsOneWidget);
    });

    testWidgets('4. shows 対応中 chip', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('対応中'), findsOneWidget);
    });

    testWidgets('5. shows クローズ chip', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('クローズ'), findsOneWidget);
    });
  });

  group('ShopInquiryListScreen — Loading state', () {
    testWidgets('6. shows loading indicator while loading', (tester) async {
      await tester.pumpWidget(
        _buildScreen(shopProvider: _FakeShopProvider(loading: true)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ShopInquiryListScreen — Empty state', () {
    testWidgets('7. shows 問い合わせはありません when no inquiries', (tester) async {
      await tester.pumpWidget(
        _buildScreen(shopProvider: _FakeShopProvider(inquiries: [])),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('問い合わせはありません'), findsOneWidget);
    });
  });

  // 1年つき合った店の一覧には去年のスレッドが並ぶ。月日だけだと
  // 「11/15」が去年なのか今年なのか分からない（今年なら未来の日付に見える）。
  group('ShopInquiryListScreen — 日付の出し方', () {
    testWidgets('今年のやりとりは月日だけ', (tester) async {
      final thisYear = DateTime(DateTime.now().year, 1, 20, 10, 0);
      await tester.pumpWidget(
        _buildScreen(
          shopProvider: _FakeShopProvider(
            inquiries: [_makeInquiry(updatedAt: thisYear)],
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('1/20'), findsOneWidget);
    });

    testWidgets('去年のやりとりには年が付く', (tester) async {
      final lastYear = DateTime(DateTime.now().year - 1, 11, 15, 10, 0);
      await tester.pumpWidget(
        _buildScreen(
          shopProvider: _FakeShopProvider(
            inquiries: [_makeInquiry(updatedAt: lastYear)],
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('${lastYear.year}/11/15'), findsOneWidget);
    });
  });

  group('ShopInquiryListScreen — Inquiries displayed', () {
    testWidgets('9. shows inquiry subject', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          shopProvider: _FakeShopProvider(
            inquiries: [_makeInquiry(subject: 'オイル交換について質問')],
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('オイル交換について質問'), findsOneWidget);
    });

    testWidgets('10. shows initial message preview', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          shopProvider: _FakeShopProvider(
            inquiries: [_makeInquiry(initialMessage: 'オイル交換の料金を教えてください')],
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('オイル交換の料金を教えてください'), findsOneWidget);
    });

    testWidgets('11. shows unread badge when unreadCountShop > 0',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          shopProvider: _FakeShopProvider(
            inquiries: [_makeInquiry(unreadCountShop: 3)],
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Unread badge shows the count
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('12. unread badge hidden when unreadCountShop = 0',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          shopProvider: _FakeShopProvider(
            inquiries: [_makeInquiry(unreadCountShop: 0)],
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // No numeric badge should appear
      expect(find.text('0'), findsNothing);
    });
  });

  // 返信を送ると、サーバ側では pending → replied に変わる
  // （InquiryService.sendMessage の「店舗の初回返信」の分岐）。
  // 画面が持っているのはローカルのコピーなので、**送っただけでは
  // 「未対応」のままになる。** 実画面で確認して分かった（2026-09-22）。
  group('ShopInquiryListScreen — 返信後のステータス', () {
    testWidgets('未対応に返信すると「回答済み」になる', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          shopProvider: _FakeShopProvider(
            inquiries: [
              _makeInquiry(subject: '異音の相談', status: InquiryStatus.pending),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('異音の相談'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // '回答済み' はフィルタチップには無いので、シートの表示だけを見ている。
      expect(find.text('回答済み'), findsNothing);

      await tester.enterText(find.byType(TextField).last, '土曜9時で承ります');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send).last);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // シートのメタ行と下部のステータスバーの2か所に出る。
      expect(
        find.text('回答済み'),
        findsWidgets,
        reason: '返信を送ってもステータスが「未対応」のまま',
      );
    });

    testWidgets('すでに店舗が返信していれば、状態は変えない', (tester) async {
      // 判定は status ではなく `repliedAt`。サーバ側も同じ条件で見ている
      // （status が inProgress でも、店舗がまだ返していなければ初回返信）。
      await tester.pumpWidget(
        _buildScreen(
          shopProvider: _FakeShopProvider(
            inquiries: [
              _makeInquiry(
                subject: '対応中の件',
                status: InquiryStatus.inProgress,
                repliedAt: DateTime(2026, 9, 1, 10, 0),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('対応中の件'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.enterText(find.byType(TextField).last, '追加のご案内です');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send).last);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // 初回返信ではないので replied には遷移しない（サーバ側の分岐と揃える）。
      expect(find.text('回答済み'), findsNothing);
      expect(find.text('対応中'), findsWidgets);
    });
  });

  group('ShopInquiryListScreen — Bottom sheet', () {
    testWidgets('13. tapping inquiry shows detail bottom sheet',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          shopProvider: _FakeShopProvider(
            inquiries: [_makeInquiry(subject: 'ボトムシートテスト')],
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('ボトムシートテスト'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Bottom sheet is now open — there should be a Material with elevation
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    // 開いたシートを、開いた位置から閉じられること。
    // ハンドルのドラッグしか出口が無いと、閉じ方が分からず詰まる。
    testWidgets('13b. detail bottom sheet closes from its header button',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          shopProvider: _FakeShopProvider(
            inquiries: [_makeInquiry(subject: 'ボトムシートテスト')],
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('ボトムシートテスト'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final closeButton = find.byKey(const Key('inquiry_detail_close'));
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(BottomSheet), findsNothing);
    });
  });

  group('ShopInquiryListScreen — Edge Cases', () {
    testWidgets('14. multiple inquiries all displayed', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          shopProvider: _FakeShopProvider(
            inquiries: [
              _makeInquiry(id: '1', subject: '問い合わせA'),
              _makeInquiry(id: '2', subject: '問い合わせB'),
              _makeInquiry(id: '3', subject: '問い合わせC'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('問い合わせA'), findsOneWidget);
      expect(find.text('問い合わせB'), findsOneWidget);
      expect(find.text('問い合わせC'), findsOneWidget);
    });

    testWidgets('15. closed inquiry displayed', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          shopProvider: _FakeShopProvider(
            inquiries: [
              _makeInquiry(
                subject: 'クローズ済み問い合わせ',
                status: InquiryStatus.closed,
              )
            ],
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('クローズ済み問い合わせ'), findsOneWidget);
    });
  });
}
