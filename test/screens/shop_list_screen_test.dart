// ShopListScreen Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/marketplace/shop_list_screen.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Mock ShopService
// ---------------------------------------------------------------------------

class MockShopService implements ShopService {
  Result<List<Shop>, AppError> shopsResult = const Result.success([]);
  Result<Shop, AppError>? shopDetailResult;
  int getShopsCallCount = 0;
  ShopType? lastType;
  ServiceCategory? lastService;
  String? lastPrefecture;

  @override
  Future<Result<List<Shop>, AppError>> getShops({
    ShopType? type,
    ServiceCategory? serviceCategory,
    String? prefecture,
    int limit = 20,
    dynamic startAfter,
  }) async {
    lastType = type;
    lastService = serviceCategory;
    lastPrefecture = prefecture;
    getShopsCallCount++;
    return shopsResult;
  }

  @override
  Future<Result<List<Shop>, AppError>> getFeaturedShops({int limit = 5}) async =>
      const Result.success([]);

  @override
  Future<Result<Shop, AppError>> getShop(String shopId) async =>
      shopDetailResult ??
      Result.failure(AppError.notFound('Not found', resourceType: '工場'));

  @override
  Future<Result<List<Shop>, AppError>> searchShops(String query,
          {int limit = 20}) async =>
      const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getShopsForMaker(String makerId,
          {int limit = 20}) async =>
      const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getNearbyShops(dynamic center,
          double radiusKm, {int limit = 20}) async =>
      const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getShopsByService(
          ServiceCategory category, {int limit = 20}) async =>
      const Result.success([]);
}

// ---------------------------------------------------------------------------
// Mock InquiryService
// ---------------------------------------------------------------------------

class MockInquiryService implements InquiryService {
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
  }) async =>
      Result.failure(AppError.unknown('not implemented'));

  @override
  Future<Result<Inquiry, AppError>> getInquiry(String inquiryId) async =>
      Result.failure(AppError.unknown('not implemented'));

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
    required String inquiryId,
    required String senderId,
    required bool isFromShop,
    required String content,
    List<String> attachmentUrls = const [],
  }) async =>
      Result.failure(AppError.unknown('not implemented'));

  @override
  Future<Result<List<InquiryMessage>, AppError>> getMessages(String inquiryId,
          {int limit = 50, dynamic startAfter}) async =>
      const Result.success([]);

  @override
  Future<Result<void, AppError>> markAsRead(
          {required String inquiryId, required bool isUser}) async =>
      const Result.success(null);

  @override
  Future<Result<Inquiry, AppError>> updateStatus(
          String inquiryId, dynamic status) async =>
      Result.failure(AppError.unknown('not implemented'));

  @override
  Future<Result<int, AppError>> getUnreadCountForUser(String userId) async =>
      const Result.success(0);

  @override
  Stream<List<Inquiry>> streamUserInquiries(String userId) => const Stream.empty();

  @override
  Stream<List<InquiryMessage>> streamMessages(String inquiryId) =>
      const Stream.empty();
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Shop _makeShop({
  String id = 'shop1',
  String name = 'テストモータース',
  ShopType type = ShopType.maintenanceShop,
  String prefecture = '東京都',
  double? rating = 4.5,
  int reviewCount = 100,
  bool isVerified = true,
  bool isFeatured = false,
  bool isActive = true,
}) {
  final now = DateTime.now();
  return Shop(
    id: id,
    name: name,
    type: type,
    isActive: isActive,
    isVerified: isVerified,
    isFeatured: isFeatured,
    prefecture: prefecture,
    services: [ServiceCategory.maintenance, ServiceCategory.inspection],
    supportedMakerIds: [],
    imageUrls: [],
    businessHours: {},
    reviewCount: reviewCount,
    rating: rating,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildApp(ShopProvider provider) {
  return ChangeNotifierProvider<ShopProvider>.value(
    value: provider,
    child: const MaterialApp(home: ShopListScreen()),
  );
}

ShopProvider _makeProvider(MockShopService shopService) {
  return ShopProvider(
    shopService: shopService,
    inquiryService: MockInquiryService(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ShopListScreen', () {
    late MockShopService mockShop;
    late ShopProvider provider;

    setUp(() {
      mockShop = MockShopService();
      provider = _makeProvider(mockShop);
    });

    testWidgets('ショップが0件のとき空状態が表示される', (tester) async {
      mockShop.shopsResult = const Result.success([]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text('工場が見つかりません'), findsOneWidget);
    });

    testWidgets('ショップリストが正常に表示される', (tester) async {
      mockShop.shopsResult = Result.success([
        _makeShop(id: 's1', name: 'ガレージA'),
        _makeShop(id: 's2', name: 'ガレージB'),
      ]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text('ガレージA'), findsOneWidget);
      expect(find.text('ガレージB'), findsOneWidget);
    });

    testWidgets('件数テキストが表示される', (tester) async {
      mockShop.shopsResult = Result.success([
        _makeShop(id: 's1'),
        _makeShop(id: 's2'),
        _makeShop(id: 's3'),
      ]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.textContaining('3'), findsWidgets);
    });

    testWidgets('エラー時にエラーUIが表示される', (tester) async {
      mockShop.shopsResult = Result.failure(
          AppError.network('connection failed'));

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      // エラー状態のUI（リトライボタンなど）が存在する
      expect(find.byIcon(Icons.refresh), findsWidgets);
    });

    testWidgets('検索バーが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('フィルタ行のDropdownChipが3つ表示される', (tester) async {
      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      // 業種・サービス・地域の3ラベルが存在する
      expect(find.text('業種'), findsOneWidget);
      expect(find.text('サービス'), findsOneWidget);
      expect(find.text('地域'), findsOneWidget);
    });

    testWidgets('検索テキスト入力でclearアイコンが出現する', (tester) async {
      mockShop.shopsResult = const Result.success([]);
      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'トヨタ');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clearアイコンタップで検索テキストがクリアされる', (tester) async {
      mockShop.shopsResult = const Result.success([]);
      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'テスト');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      final textField =
          tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('認証済みショップに認証バッジが表示される', (tester) async {
      mockShop.shopsResult = Result.success([
        _makeShop(name: '認証ショップ', isVerified: true),
      ]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('注目ショップに「広告」ラベルが表示される', (tester) async {
      mockShop.shopsResult = Result.success([
        _makeShop(name: 'スポンサー店', isFeatured: true, isVerified: false),
      ]);

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text('広告'), findsOneWidget);
    });

    group('Edge Cases', () {
      testWidgets('ショップ名が非常に長くてもクラッシュしない', (tester) async {
        mockShop.shopsResult = Result.success([
          _makeShop(name: 'あ' * 50),
        ]);

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('評価なし（rating: null）でもクラッシュしない', (tester) async {
        mockShop.shopsResult = Result.success([
          _makeShop(rating: null),
        ]);

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('多数のショップ（20件）でもスクロール可能', (tester) async {
        mockShop.shopsResult = Result.success(
          List.generate(
            20,
            (i) => _makeShop(id: 'shop_$i', name: 'ショップ$i'),
          ),
        );

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
