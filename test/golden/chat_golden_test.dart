@Tags(['golden'])
library;

// 店舗とお客様のチャットの見え方。
//
// なぜ要るか:
//   このアプリの売りは「店と続く付き合い」だが、**チャット画面のゴールデンは
//   1枚も無かった**。ウィジェットテストは「件名が出る」「送信で入力欄が空になる」
//   といった個別の確認で、**並んだときの見え方**は誰も見ていない。
//
//   会話の中身は scripts/seed_year_of_use.js が入れている車検スレッドと同じ。
//   シードを変えたらここも合わなくなるので、突き合わせの目印になる。
//
// 撮り直し:
//   flutter test --update-goldens test/golden/chat_golden_test.dart

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
import 'package:trust_car_platform/core/theme/app_theme.dart';

import 'font_loader.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _StubShopService implements ShopService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubInquiryService implements InquiryService {
  _StubInquiryService(this.messages);

  final List<InquiryMessage> messages;

  @override
  Stream<List<InquiryMessage>> streamMessages(String inquiryId) =>
      Stream<List<InquiryMessage>>.value(messages);

  @override
  Stream<List<Inquiry>> streamUserInquiries(String userId) => Stream.value([]);

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
  Future<Result<UserCredential, AppError>> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async =>
      Result.failure(AppError.server('stub'));
  @override
  Future<Result<UserCredential, AppError>> signInWithEmail({
    required String email,
    required String password,
  }) async =>
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
  Future<Result<void, AppError>> updateUserProfile({
    String? displayName,
    String? photoUrl,
    String? prefecture,
    String? city,
  }) async =>
      const Result.success(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeShopProvider extends ShopProvider {
  _FakeShopProvider(this._stub)
      : super(shopService: _StubShopService(), inquiryService: _stub);

  final _StubInquiryService _stub;

  @override
  Stream<List<InquiryMessage>> streamInquiryMessages(String inquiryId) =>
      _stub.streamMessages(inquiryId);

  @override
  void markUserInquiryAsReadLocally(String inquiryId) {}
  @override
  void watchUserInquiries(String userId) {}
  @override
  void stopWatchingUserInquiries() {}
}

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider() : super(authService: _StubAuthService());
  @override
  User? get firebaseUser => _FakeUser();
  @override
  bool get isLoading => false;
  @override
  bool get isAuthenticated => true;
}

class _FakeUser implements User {
  @override
  String get uid => 'user-a';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// seed_year_of_use.js の inq-yu-03-hiace-shaken と同じ会話
// ---------------------------------------------------------------------------

const _shopId = 'shop_takaya_motor_okayama';
final _opened = DateTime(2026, 6, 28, 9, 30);

final _inquiry = Inquiry(
  id: 'inq-yu-03-hiace-shaken',
  userId: 'user-a',
  shopId: _shopId,
  type: InquiryType.estimate,
  status: InquiryStatus.closed,
  subject: 'ハイエースの車検見積もりをお願いします',
  initialMessage: 'ハイエースの車検が来月末で切れます。貨物なので毎年で、今年もお願いしたいです。'
      '概算をいただけますか。ブレーキの効きが少し甘い気がします。',
  shopName: 'タカヤモーター株式会社',
  vehicleMaker: 'Toyota',
  vehicleModel: 'Hiace',
  vehicleYear: 2022,
  messageCount: 7,
  createdAt: _opened,
  updatedAt: DateTime(2026, 7, 11, 17, 0),
);

InquiryMessage _msg(
  int i, {
  required bool fromShop,
  required String content,
  required DateTime at,
  bool isRead = true,
}) =>
    InquiryMessage(
      id: 'msg-yu-${i.toString().padLeft(2, '0')}',
      senderId: fromShop ? _shopId : 'user-a',
      isFromShop: fromShop,
      content: content,
      sentAt: at,
      isRead: isRead,
    );

final _messages = <InquiryMessage>[
  _msg(0,
      fromShop: true,
      at: DateTime(2026, 6, 29, 10, 15),
      content: '承知しました。貨物の継続検査は法定費用込みで 128,000〜148,000円が目安です。'
          'ブレーキは入庫時に点検します。パッドが残り2mmを切っていれば交換をご提案します。'),
  _msg(1,
      fromShop: false,
      at: DateTime(2026, 6, 29, 12, 40),
      content: 'ありがとうございます。パッド交換込みだといくらぐらいになりますか。'),
  _msg(2,
      fromShop: true,
      at: DateTime(2026, 6, 30, 9, 5),
      content: '前後パッド交換で +22,000円ほどです。見てからのご相談でも間に合います。'),
  _msg(3,
      fromShop: false,
      at: DateTime(2026, 7, 4, 20, 10),
      content: '来週の火曜に入庫でお願いします。代車はお借りできますか。'),
  _msg(4,
      fromShop: true,
      at: DateTime(2026, 7, 5, 8, 50),
      content: '火曜9時で承りました。代車をご用意します。車検証と自賠責をお持ちください。'),
  _msg(5,
      fromShop: true,
      at: DateTime(2026, 7, 11, 17, 0),
      content: '車検が完了しました。ブレーキパッドは前後とも交換しています。'
          '明細をこのスレッドに添付しました。次回は来年の同じ時期です。'),
];

Widget _buildThread({required ThemeData theme}) {
  final stub = _StubInquiryService(_messages);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ShopProvider>.value(
          value: _FakeShopProvider(stub)),
      ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuthProvider()),
    ],
    child: MaterialApp(
      // goldenTheme を通さないと、テーマが持つ「書体名の無い TextStyle」が
      // 日本語を持たない書体に落ちて豆腐（□）で写る（font_loader.dart 参照）。
      theme: goldenTheme(theme),
      home: InquiryThreadScreen(inquiry: _inquiry),
    ),
  );
}

void main() {
  // 呼ばないと文字もアイコンも豆腐（□）で写る。
  setUpAll(() async {
    await loadMaterialIcons();
    await loadJapaneseFont();
  });

  group('チャット（お客様側）', () {
    testWidgets('1年つき合った店との車検スレッド — ライト', (tester) async {
      await tester.pumpWidget(_buildThread(theme: AppTheme.lightTheme));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/chat_thread_light.png'),
      );
    });

    testWidgets('1年つき合った店との車検スレッド — ダーク', (tester) async {
      await tester.pumpWidget(_buildThread(theme: AppTheme.darkTheme));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/chat_thread_dark.png'),
      );
    });
  });
}
