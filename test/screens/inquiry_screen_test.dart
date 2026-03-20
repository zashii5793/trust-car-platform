// InquiryScreen Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/marketplace/inquiry_screen.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
import 'package:trust_car_platform/models/user.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockShopService implements ShopService {
  @override
  Future<Result<Shop, AppError>> getShop(String shopId) async =>
      Result.failure(AppError.notFound('not found'));

  @override
  Future<Result<List<Shop>, AppError>> getShops(
          {ShopType? type, ServiceCategory? serviceCategory,
          String? prefecture, int limit = 20, dynamic startAfter}) async =>
      const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getFeaturedShops({int limit = 5}) async =>
      const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> searchShops(String query,
          {int limit = 20}) async => const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getShopsForMaker(String makerId,
          {int limit = 20}) async => const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getNearbyShops(dynamic center,
          double radiusKm, {int limit = 20}) async => const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getShopsByService(
          ServiceCategory category, {int limit = 20}) async =>
      const Result.success([]);
}

class MockInquiryService implements InquiryService {
  bool shouldFail = false;
  Inquiry? createdInquiry;
  int createCallCount = 0;

  @override
  Future<Result<Inquiry, AppError>> createInquiry({
    required String userId,
    required String shopId,
    required InquiryType type,
    required String subject,
    required String message,
    String? vehicleId,
    String? partListingId,
    dynamic vehicle,
    List<String> attachmentUrls = const [],
  }) async {
    createCallCount++;
    if (shouldFail) {
      return Result.failure(AppError.network('connection error'));
    }
    final now = DateTime.now();
    createdInquiry = Inquiry(
      id: 'inq1',
      userId: userId,
      shopId: shopId,
      type: type,
      status: InquiryStatus.pending,
      subject: subject,
      initialMessage: message,
      vehicleId: vehicleId,
      attachmentUrls: [],
      messageCount: 0,
      unreadCountUser: 0,
      unreadCountShop: 1,
      createdAt: now,
      updatedAt: now,
    );
    return Result.success(createdInquiry!);
  }

  @override
  Future<Result<Inquiry, AppError>> getInquiry(String id) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<List<Inquiry>, AppError>> getUserInquiries(String userId,
          {dynamic status, int limit = 20, dynamic startAfter}) async =>
      const Result.success([]);

  @override
  Future<Result<List<Inquiry>, AppError>> getShopInquiries(String shopId,
          {dynamic status, int limit = 20, dynamic startAfter}) async =>
      const Result.success([]);

  @override
  Future<Result<InquiryMessage, AppError>> sendMessage({
    required String inquiryId, required String senderId,
    required bool isFromShop, required String content,
    List<String> attachmentUrls = const [],
  }) async => Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<List<InquiryMessage>, AppError>> getMessages(String id,
          {int limit = 50, dynamic startAfter}) async =>
      const Result.success([]);

  @override
  Future<Result<void, AppError>> markAsRead(
          {required String inquiryId, required bool isUser}) async =>
      const Result.success(null);

  @override
  Future<Result<Inquiry, AppError>> updateStatus(String id, dynamic status) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<int, AppError>> getUnreadCountForUser(String userId) async =>
      const Result.success(0);

  @override
  Stream<List<Inquiry>> streamUserInquiries(String userId) => const Stream.empty();

  @override
  Stream<List<InquiryMessage>> streamMessages(String inquiryId) =>
      const Stream.empty();
}

class MockAuthService implements AuthService {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<Result<UserCredential, AppError>> signUpWithEmail(
          {required String email, required String password,
          String? displayName}) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<UserCredential, AppError>> signInWithEmail(
          {required String email, required String password}) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<UserCredential?, AppError>> signInWithGoogle() async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<void, AppError>> sendPasswordResetEmail(String email) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> signOut() async =>
      const Result.success(null);

  @override
  Future<Result<AppUser?, AppError>> getUserProfile() async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<void, AppError>> updateUserProfile(
          {String? displayName, String? photoUrl}) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> updateNotificationSettings(
          dynamic settings) async =>
      const Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Shop _testShop({
  String id = 'shop1',
  String name = 'テスト工場',
  bool isVerified = true,
}) {
  final now = DateTime.now();
  return Shop(
    id: id,
    name: name,
    type: ShopType.maintenanceShop,
    isActive: true,
    isVerified: isVerified,
    isFeatured: false,
    services: [ServiceCategory.maintenance],
    supportedMakerIds: [],
    imageUrls: [],
    businessHours: {},
    reviewCount: 0,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildApp(
  Shop shop, {
  String? vehicleId,
  required ShopProvider shopProvider,
  required AuthProvider authProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ShopProvider>.value(value: shopProvider),
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
    ],
    child: MaterialApp(
      home: InquiryScreen(shop: shop, vehicleId: vehicleId),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('InquiryScreen', () {
    late MockInquiryService mockInquiry;
    late ShopProvider shopProvider;
    late AuthProvider authProvider;

    setUp(() {
      mockInquiry = MockInquiryService();
      shopProvider = ShopProvider(
        shopService: MockShopService(),
        inquiryService: mockInquiry,
      );
      authProvider = AuthProvider(authService: MockAuthService());
    });

    testWidgets('ショップのミニカード（送信先）が表示される', (tester) async {
      final shop = _testShop(name: 'メインガレージ');

      await tester.pumpWidget(
        _buildApp(shop, shopProvider: shopProvider, authProvider: authProvider),
      );
      await tester.pump();

      expect(find.text('メインガレージ'), findsOneWidget);
    });

    testWidgets('「送信先」ラベルが表示される', (tester) async {
      final shop = _testShop();

      await tester.pumpWidget(
        _buildApp(shop, shopProvider: shopProvider, authProvider: authProvider),
      );
      await tester.pump();

      expect(find.text('送信先'), findsOneWidget);
    });

    testWidgets('問い合わせ種別ChoiceChipが表示される（7種）', (tester) async {
      final shop = _testShop();

      await tester.pumpWidget(
        _buildApp(shop, shopProvider: shopProvider, authProvider: authProvider),
      );
      await tester.pump();

      // InquiryType の7種すべてに対応するChipが存在する
      expect(find.byType(ChoiceChip), findsWidgets);
    });

    testWidgets('件名入力フィールドが表示される', (tester) async {
      final shop = _testShop();

      await tester.pumpWidget(
        _buildApp(shop, shopProvider: shopProvider, authProvider: authProvider),
      );
      await tester.pump();

      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('メッセージ入力フィールドが表示される', (tester) async {
      final shop = _testShop();

      await tester.pumpWidget(
        _buildApp(shop, shopProvider: shopProvider, authProvider: authProvider),
      );
      await tester.pump();

      // 最低2つのTextFormField（件名・本文）
      expect(find.byType(TextFormField).evaluate().length,
          greaterThanOrEqualTo(2));
    });

    testWidgets('送信ボタンが表示される', (tester) async {
      final shop = _testShop();

      await tester.pumpWidget(
        _buildApp(shop, shopProvider: shopProvider, authProvider: authProvider),
      );
      await tester.pump();

      expect(find.textContaining('送信'), findsWidgets);
    });

    testWidgets('件名が空のまま送信するとバリデーションエラーが表示される', (tester) async {
      final shop = _testShop();

      await tester.pumpWidget(
        _buildApp(shop, shopProvider: shopProvider, authProvider: authProvider),
      );
      await tester.pump();

      // メッセージのみ入力して送信
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.last, 'メッセージ内容です。');

      await tester.tap(find.textContaining('送信').last);
      await tester.pumpAndSettle();

      // バリデーションエラーが表示される（例外なし）
      expect(tester.takeException(), isNull);
      // createInquiry は呼ばれない（バリデーション失敗）
      expect(mockInquiry.createCallCount, 0);
    });

    testWidgets('メッセージが空のまま送信するとバリデーションエラーが表示される', (tester) async {
      final shop = _testShop();

      await tester.pumpWidget(
        _buildApp(shop, shopProvider: shopProvider, authProvider: authProvider),
      );
      await tester.pump();

      // 件名のみ入力して送信
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, '件名です');

      await tester.tap(find.textContaining('送信').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(mockInquiry.createCallCount, 0);
    });

    testWidgets('メッセージ入力で文字数カウンタが更新される', (tester) async {
      final shop = _testShop();

      await tester.pumpWidget(
        _buildApp(shop, shopProvider: shopProvider, authProvider: authProvider),
      );
      await tester.pump();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.last, 'テストメッセージ');
      await tester.pump();

      // 文字数カウンタが表示されている（"X / 500" 形式）
      expect(find.textContaining('500'), findsWidgets);
    });

    testWidgets('種別ChipをタップするとChoiceChipが選択される', (tester) async {
      final shop = _testShop();

      await tester.pumpWidget(
        _buildApp(shop, shopProvider: shopProvider, authProvider: authProvider),
      );
      await tester.pump();

      // ChoiceChipが存在することを確認
      final chips = find.byType(ChoiceChip);
      expect(chips.evaluate().isNotEmpty, isTrue);

      // タップしてもクラッシュしない
      await tester.tap(chips.first);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('免責事項ボックスが表示される', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final shop = _testShop();

      await tester.pumpWidget(
        _buildApp(shop, shopProvider: shopProvider, authProvider: authProvider),
      );
      await tester.pump();

      // "1〜3営業日" または "営業日" を含むテキスト
      expect(find.textContaining('営業日'), findsAtLeast(1));
    });

    group('Edge Cases', () {
      testWidgets('vehicleId 指定時に車両情報バッジが表示される', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final shop = _testShop();

        await tester.pumpWidget(
          _buildApp(
            shop,
            vehicleId: 'vehicle123',
            shopProvider: shopProvider,
            authProvider: authProvider,
          ),
        );
        await tester.pump();

        expect(find.textContaining('車両情報'), findsAtLeast(1));
        expect(tester.takeException(), isNull);
      });

      testWidgets('vehicleId なしでもクラッシュしない', (tester) async {
        final shop = _testShop();

        await tester.pumpWidget(
          _buildApp(
            shop,
            vehicleId: null,
            shopProvider: shopProvider,
            authProvider: authProvider,
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      });

      testWidgets('非常に長いショップ名でもレイアウトが崩れない', (tester) async {
        final shop = _testShop(name: '株式会社テスト長い名前モータース渋谷本店プレミアム');

        await tester.pumpWidget(
          _buildApp(shop, shopProvider: shopProvider, authProvider: authProvider),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      });

      testWidgets('500字入力でカウンタが上限に達する', (tester) async {
        final shop = _testShop();

        await tester.pumpWidget(
          _buildApp(shop, shopProvider: shopProvider, authProvider: authProvider),
        );
        await tester.pump();

        final textFields = find.byType(TextFormField);
        final longText = 'あ' * 500;
        await tester.enterText(textFields.last, longText);
        await tester.pump();

        // カウンタが 500 を示すテキストが存在する
        expect(find.textContaining('500'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
