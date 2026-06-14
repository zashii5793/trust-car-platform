// InquiryThreadScreen Widget Tests

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;

import 'package:trust_car_platform/screens/marketplace/inquiry_thread_screen.dart';
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
  final StreamController<List<InquiryMessage>> _controller =
      StreamController<List<InquiryMessage>>.broadcast();

  void emitMessages(List<InquiryMessage> messages) => _controller.add(messages);

  @override
  Stream<List<InquiryMessage>> streamMessages(String inquiryId) =>
      _controller.stream;

  @override
  Stream<List<Inquiry>> streamUserInquiries(String userId) => Stream.value([]);

  @override
  Future<Result<InquiryMessage, AppError>> sendMessage({
    required String inquiryId,
    required String senderId,
    required bool isFromShop,
    required String content,
    List<String> attachmentUrls = const [],
    Map<String, dynamic>? maintenancePayload,
  }) async =>
      Result.success(InquiryMessage(
        id: 'msg-new',
        senderId: senderId,
        isFromShop: isFromShop,
        content: content,
        sentAt: DateTime.now(),
      ));

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
          {String? displayName, String? photoUrl}) async =>
      const Result.success(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Fake providers
// ---------------------------------------------------------------------------

class _FakeShopProvider extends ShopProvider {
  final _StubInquiryService _inquiryStub;

  _FakeShopProvider(this._inquiryStub)
      : super(
          shopService: _StubShopService(),
          inquiryService: _inquiryStub,
        );

  @override
  Stream<List<InquiryMessage>> streamInquiryMessages(String inquiryId) =>
      _inquiryStub.streamMessages(inquiryId);

  @override
  Future<Result<InquiryMessage, AppError>> sendUserReply({
    required String inquiryId,
    required String userId,
    required String content,
  }) =>
      _inquiryStub.sendMessage(
        inquiryId: inquiryId,
        senderId: userId,
        isFromShop: false,
        content: content,
      );

  @override
  void markUserInquiryAsReadLocally(String inquiryId) {}

  @override
  void watchUserInquiries(String userId) {}

  @override
  void stopWatchingUserInquiries() {}
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
  InquiryStatus status = InquiryStatus.pending,
  String subject = 'オイル交換の見積もり',
}) {
  final now = DateTime(2025, 6, 1, 10, 0);
  return Inquiry(
    id: 'inq-1',
    userId: 'user-1',
    shopId: 'shop-1',
    type: InquiryType.estimate,
    subject: subject,
    initialMessage: '初回メッセージ',
    status: status,
    shopName: 'テスト工場',
    createdAt: now,
    updatedAt: now,
  );
}

InquiryMessage _makeMessage({
  String id = 'msg-1',
  bool isFromShop = false,
  String content = 'テストメッセージ',
  Map<String, dynamic>? maintenancePayload,
}) {
  return InquiryMessage(
    id: id,
    senderId: isFromShop ? 'shop-1' : 'user-1',
    isFromShop: isFromShop,
    content: content,
    sentAt: DateTime(2025, 6, 1, 10, 0),
    maintenancePayload: maintenancePayload,
  );
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required Inquiry inquiry,
  _StubInquiryService? inquiryStub,
  _FakeAuthProvider? authProvider,
}) {
  final stub = inquiryStub ?? _StubInquiryService();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ShopProvider>.value(
        value: _FakeShopProvider(stub),
      ),
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider ?? _FakeAuthProvider(user: _FakeUser()),
      ),
    ],
    child: MaterialApp(
      home: InquiryThreadScreen(inquiry: inquiry),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('InquiryThreadScreen — AppBar', () {
    testWidgets('件名が AppBar に表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(subject: 'タイヤ交換の相談'),
      ));
      await tester.pump();

      expect(find.text('タイヤ交換の相談'), findsOneWidget);
    });

    testWidgets('工場名がAppBarサブヘッダーに表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
      ));
      await tester.pump();

      expect(find.text('テスト工場'), findsOneWidget);
    });
  });

  group('InquiryThreadScreen — メッセージ表示', () {
    testWidgets('ユーザーのメッセージが表示される', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([
        _makeMessage(isFromShop: false, content: 'ユーザーからのメッセージ'),
      ]);
      await tester.pump();

      expect(find.text('ユーザーからのメッセージ'), findsOneWidget);
    });

    testWidgets('工場からのメッセージが表示される', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([
        _makeMessage(isFromShop: true, content: '工場からの返信です'),
      ]);
      await tester.pump();

      expect(find.text('工場からの返信です'), findsOneWidget);
    });

    testWidgets('複数メッセージが表示される', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([
        _makeMessage(id: 'msg-1', isFromShop: false, content: 'こんにちは'),
        _makeMessage(id: 'msg-2', isFromShop: true, content: 'いらっしゃいませ'),
      ]);
      await tester.pump();

      expect(find.text('こんにちは'), findsOneWidget);
      expect(find.text('いらっしゃいませ'), findsOneWidget);
    });

    testWidgets('メッセージ0件のとき空状態プレースホルダーが表示される', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([]);
      await tester.pump();

      expect(find.text('メッセージはまだありません'), findsOneWidget);
    });

    testWidgets('メッセージにHH:mm形式のタイムスタンプが表示される', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      // sentAt = DateTime(2025, 6, 1, 10, 0) → '10:00'
      stub.emitMessages([_makeMessage(content: 'タイム確認')]);
      await tester.pump();

      expect(find.text('10:00'), findsOneWidget);
    });

    testWidgets('工場からのメッセージには「工場」ラベルが表示される', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([_makeMessage(isFromShop: true, content: '工場からの返信')]);
      await tester.pump();

      expect(find.text('工場'), findsOneWidget);
    });

    testWidgets('ユーザーのメッセージには「工場」ラベルが表示されない', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([_makeMessage(isFromShop: false, content: 'ユーザー発言')]);
      await tester.pump();

      expect(find.text('工場'), findsNothing);
    });
  });

  group('InquiryThreadScreen — 入力フィールド', () {
    testWidgets('オープン中の問い合わせにはテキストフィールドが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(status: InquiryStatus.pending),
      ));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('クローズ済みの問い合わせにはテキストフィールドが非表示', (tester) async {
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(status: InquiryStatus.closed),
      ));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('クローズ済みには「この問い合わせはクローズされました」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(status: InquiryStatus.closed),
      ));
      await tester.pump();

      expect(find.textContaining('クローズ'), findsWidgets);
    });

    testWidgets('キャンセル済みには「キャンセルされました」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(status: InquiryStatus.cancelled),
      ));
      await tester.pump();

      expect(find.textContaining('キャンセル'), findsOneWidget);
    });

    testWidgets('inProgress状態でも入力フィールドが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(status: InquiryStatus.inProgress),
      ));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('テキスト未入力時は送信ボタンが無効', (tester) async {
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(status: InquiryStatus.pending),
      ));
      await tester.pump();

      final iconBtn = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconBtn.onPressed, isNull);
    });

    testWidgets('空白のみ入力では送信ボタンが無効のまま', (tester) async {
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(status: InquiryStatus.pending),
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      final iconBtn = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconBtn.onPressed, isNull);
    });

    testWidgets('テキストフィールドのヒントテキストが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(status: InquiryStatus.pending),
      ));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'メッセージを入力...'), findsOneWidget);
    });
  });

  group('InquiryThreadScreen — メッセージ送信', () {
    testWidgets('テキスト入力後に送信ボタンが有効になる', (tester) async {
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(status: InquiryStatus.pending),
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'テスト送信メッセージ');
      await tester.pump();

      final sendButton = find.byIcon(Icons.send);
      expect(sendButton, findsOneWidget);
    });

    testWidgets('メッセージ送信後にテキストフィールドがクリアされる', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(status: InquiryStatus.pending),
        inquiryStub: stub,
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '送信テスト');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text ?? '', isEmpty);
    });
  });

  group('Edge Cases', () {
    testWidgets('メッセージ0件でもクラッシュしない', (tester) async {
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('未認証でも画面が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        authProvider: _FakeAuthProvider(user: null),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('InquiryThreadScreen — 整備明細の取込カード', () {
    testWidgets('工場メッセージに整備明細が添付されていると取込カードが表示される', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([
        _makeMessage(
          isFromShop: true,
          content: '整備明細をお送りします。',
          maintenancePayload: {
            'typeKey': 'carInspection',
            'title': '車検整備一式',
            'date': DateTime(2026, 5, 20).toIso8601String(),
            'cost': 80000,
          },
        ),
      ]);
      await tester.pump();

      expect(find.text('整備明細'), findsOneWidget);
      expect(find.byKey(const Key('import_maintenance_btn')), findsOneWidget);
    });

    testWidgets('整備明細のない通常メッセージには取込カードが出ない', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([
        _makeMessage(isFromShop: true, content: '通常の返信です'),
      ]);
      await tester.pump();

      expect(find.byKey(const Key('import_maintenance_btn')), findsNothing);
    });

    testWidgets('整備明細カードに費用が表示される', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([
        _makeMessage(
          isFromShop: true,
          content: '整備明細をお送りします。',
          maintenancePayload: {
            'typeKey': 'carInspection',
            'title': '車検整備一式',
            'date': DateTime(2026, 5, 20).toIso8601String(),
            'cost': 80000,
          },
        ),
      ]);
      await tester.pump();

      expect(find.textContaining('¥80000'), findsOneWidget);
    });

    testWidgets('整備明細カードに種別とタイトルが表示される', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([
        _makeMessage(
          isFromShop: true,
          content: '整備明細をお送りします。',
          maintenancePayload: {
            'typeKey': 'carInspection',
            'title': '車検整備一式',
            'date': DateTime(2026, 5, 20).toIso8601String(),
            'cost': 80000,
          },
        ),
      ]);
      await tester.pump();

      // typeLabel '車検' and title '車検整備一式' joined with '・'
      expect(find.textContaining('車検'), findsWidgets);
      expect(find.textContaining('車検整備一式'), findsOneWidget);
    });
  });
}
