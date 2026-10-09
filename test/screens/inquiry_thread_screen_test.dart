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
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:trust_car_platform/services/shop_detail_inbox_service.dart';

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
  DateTime? importedAt,
}) {
  return InquiryMessage(
    id: id,
    senderId: isFromShop ? 'shop-1' : 'user-1',
    isFromShop: isFromShop,
    content: content,
    sentAt: DateTime(2025, 6, 1, 10, 0),
    maintenancePayload: maintenancePayload,
    importedAt: importedAt,
  );
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required Inquiry inquiry,
  _StubInquiryService? inquiryStub,
  _FakeAuthProvider? authProvider,
  ShopDetailInboxService? detailInbox,
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
      home: InquiryThreadScreen(inquiry: inquiry, detailInbox: detailInbox),
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
  });

  // 1年つき合った店とのスレッドは月をまたぐ。時刻だけだと 6/29 の発言と
  // 7/11 の発言が見分けられない（店舗側の画面は前から「6/29 10:15」と
  // 出していて、お客様側だけ日付が抜けていた）。
  group('InquiryThreadScreen — 送信日時', () {
    testWidgets('日付と時刻の両方が出る', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([
        InquiryMessage(
          id: 'm1',
          senderId: 'shop-1',
          isFromShop: true,
          content: '見積もりをお送りします',
          sentAt: DateTime(2026, 6, 29, 10, 15),
        ),
      ]);
      await tester.pump();

      expect(find.text('6/29 10:15'), findsOneWidget);
    });

    testWidgets('別の年のやりとりには年も付く', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));

      final lastYear = DateTime(DateTime.now().year - 1, 11, 12, 9, 5);
      stub.emitMessages([
        InquiryMessage(
          id: 'm1',
          senderId: 'shop-1',
          isFromShop: true,
          content: 'はじめまして',
          sentAt: lastYear,
        ),
      ]);
      await tester.pump();

      expect(find.text('${lastYear.year}/11/12 09:05'), findsOneWidget);
    });

    group('Edge Cases', () {
      testWidgets('0時台・1桁の分でも桁が崩れない', (tester) async {
        final stub = _StubInquiryService();
        await tester.pumpWidget(_buildScreen(
          inquiry: _makeInquiry(),
          inquiryStub: stub,
        ));
        stub.emitMessages([
          InquiryMessage(
            id: 'm1',
            senderId: 'user-1',
            isFromShop: false,
            content: '夜分に失礼します',
            sentAt: DateTime(2026, 1, 3, 0, 7),
          ),
        ]);
        await tester.pump();

        expect(find.text('1/3 00:07'), findsOneWidget);
      });
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
  });

  // 使用感テスト 2026-10-09: 差出人が「工場」だけ・車名が無い・変えられない
  // ことが書かれていない・開き直すと再び「記録に追加」が押せる。
  group('InquiryThreadScreen — 店から届いた明細（2026-10-09）', () {
    Map<String, dynamic> detail({String? vehicleLabel, String? plate}) => {
          'typeKey': 'oilChange',
          'title': 'オイル交換',
          'date': DateTime(2026, 10, 8).toIso8601String(),
          'cost': 16500,
          'mileageAtService': 45100,
          if (vehicleLabel != null) 'vehicleLabel': vehicleLabel,
          if (plate != null) 'licensePlate': plate,
        };

    testWidgets('差出人は店の名前で出る', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([_makeMessage(isFromShop: true, content: 'こんにちは')]);
      await tester.pump();

      expect(find.byKey(const Key('thread_shop_sender')), findsOneWidget);
      expect(find.text('テスト工場'), findsWidgets);
      expect(find.text('工場'), findsNothing);
    });

    testWidgets('カードに車名・桁区切りの金額・変えられないことが出る', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([
        _makeMessage(
          isFromShop: true,
          maintenancePayload:
              detail(vehicleLabel: 'トヨタ ハイエース', plate: '岡山 400 な 44-44'),
        ),
      ]);
      await tester.pump();

      expect(find.text('トヨタ ハイエース・岡山 400 な 44-44'), findsOneWidget);
      expect(find.textContaining('¥16,500'), findsOneWidget);
      expect(find.textContaining('45,100km'), findsOneWidget);
      expect(find.byKey(const Key('detail_locked_notice')), findsOneWidget);
    });

    testWidgets('同じ語を重ねない（オイル交換・オイル交換 にしない）', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([
        _makeMessage(isFromShop: true, maintenancePayload: detail()),
      ]);
      await tester.pump();
      expect(find.text('オイル交換'), findsOneWidget);
      expect(find.text('オイル交換・オイル交換'), findsNothing);
    });

    testWidgets('取り込み済みの印があれば、開き直しても「追加済み」', (tester) async {
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
      ));
      stub.emitMessages([
        _makeMessage(
          isFromShop: true,
          maintenancePayload: detail(),
          importedAt: DateTime(2026, 10, 9),
        ),
      ]);
      await tester.pump();

      expect(find.byKey(const Key('import_maintenance_done')), findsOneWidget);
      expect(find.byKey(const Key('import_maintenance_btn')), findsNothing);
    });

    testWidgets('印の無い以前の取り込みも、記録から見つけて「追加済み」', (tester) async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('maintenance_records').add({
        'userId': 'user-1',
        'inquiryId': 'inq-1',
        'title': 'オイル交換',
        'cost': 16500,
        'date': Timestamp.fromDate(DateTime(2026, 10, 8)),
      });
      final stub = _StubInquiryService();
      await tester.pumpWidget(_buildScreen(
        inquiry: _makeInquiry(),
        inquiryStub: stub,
        detailInbox: ShopDetailInboxService(firestore: fs),
      ));
      stub.emitMessages([
        _makeMessage(isFromShop: true, maintenancePayload: detail()),
      ]);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(find.byKey(const Key('import_maintenance_done')), findsOneWidget);
    });

    group('Edge Cases', () {
      testWidgets('店の名前が無いスレッドでは「工場」と出す', (tester) async {
        final stub = _StubInquiryService();
        await tester.pumpWidget(_buildScreen(
          inquiry: Inquiry(
            id: 'inq-1',
            userId: 'user-1',
            shopId: 'shop-1',
            type: InquiryType.general,
            subject: 's',
            initialMessage: 'm',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          inquiryStub: stub,
        ));
        stub.emitMessages([_makeMessage(isFromShop: true)]);
        await tester.pump();
        expect(find.text('工場'), findsOneWidget);
      });

      testWidgets('車の指定が無い明細でも出せる（車の行が無いだけ）', (tester) async {
        final stub = _StubInquiryService();
        await tester.pumpWidget(_buildScreen(
          inquiry: _makeInquiry(),
          inquiryStub: stub,
        ));
        stub.emitMessages([
          _makeMessage(isFromShop: true, maintenancePayload: detail()),
        ]);
        await tester.pump();
        expect(find.byKey(const Key('detail_card_vehicle')), findsNothing);
        expect(find.byKey(const Key('import_maintenance_btn')), findsOneWidget);
      });
    });
  });
}
