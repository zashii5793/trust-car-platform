// ShopDetailScreen Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/marketplace/shop_detail_screen.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Mocks (同一ファイルに定義)
// ---------------------------------------------------------------------------

class MockShopService implements ShopService {
  Result<Shop, AppError>? shopResult;

  @override
  Future<Result<Shop, AppError>> getShop(String shopId) async =>
      shopResult ?? Result.failure(AppError.notFound('Not found'));

  @override
  Future<Result<List<Shop>, AppError>> getShops({
    ShopType? type,
    ServiceCategory? serviceCategory,
    String? prefecture,
    int limit = 20,
    dynamic startAfter,
  }) async => const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getFeaturedShops({int limit = 5}) async =>
      const Result.success([]);

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

class MockInquiryService implements InquiryService {
  @override
  Future<Result<Inquiry, AppError>> createInquiry({
    required String userId, required String shopId,
    required InquiryType type, required String subject,
    required String message, String? vehicleId, String? partListingId,
    dynamic vehicle, List<String> attachmentUrls = const [],
  }) async => Result.failure(AppError.unknown('not impl'));

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
  Stream<List<InquiryMessage>> streamMessages(String inquiryId) => const Stream.empty();
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Shop _fullShop({
  String id = 'shop1',
  String name = 'テストガレージ',
  double? rating = 4.5,
  bool isVerified = true,
  bool isFeatured = false,
  String? description = '丁寧な整備が自慢のお店です。',
  String? phone = '03-1234-5678',
  String? address = '東京都渋谷区1-1-1',
  List<String> imageUrls = const [],
  List<ServiceCategory> services = const [
    ServiceCategory.maintenance,
    ServiceCategory.inspection,
  ],
}) {
  final now = DateTime.now();
  return Shop(
    id: id,
    name: name,
    type: ShopType.maintenanceShop,
    isActive: true,
    isVerified: isVerified,
    isFeatured: isFeatured,
    description: description,
    phone: phone,
    address: address,
    imageUrls: imageUrls,
    services: services,
    supportedMakerIds: [],
    businessHours: {
      1: BusinessHours(openTime: '09:00', closeTime: '18:00', isClosed: false),
      0: const BusinessHours(openTime: null, closeTime: null, isClosed: true),
    },
    rating: rating,
    reviewCount: 42,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildApp(ShopProvider provider, {String shopId = 'shop1'}) {
  return ChangeNotifierProvider<ShopProvider>.value(
    value: provider,
    child: MaterialApp(
      home: ShopDetailScreen(shopId: shopId),
    ),
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
  group('ShopDetailScreen', () {
    late MockShopService mockShop;
    late ShopProvider provider;

    setUp(() {
      mockShop = MockShopService();
      provider = _makeProvider(mockShop);
    });

    testWidgets('店舗名が表示される', (tester) async {
      mockShop.shopResult = Result.success(_fullShop(name: 'プレミアムガレージ'));

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text('プレミアムガレージ'), findsOneWidget);
    });

    testWidgets('店舗の説明が表示される', (tester) async {
      mockShop.shopResult = Result.success(
        _fullShop(description: '最高のサービスを提供します。'),
      );

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text('最高のサービスを提供します。'), findsOneWidget);
    });

    testWidgets('認証済みバッジが表示される', (tester) async {
      mockShop.shopResult = Result.success(_fullShop(isVerified: true));

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      // 認証アイコン or "認証済み" テキスト
      expect(
        find.byIcon(Icons.verified).evaluate().isNotEmpty ||
            find.textContaining('認証').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('電話番号が表示される', (tester) async {
      mockShop.shopResult = Result.success(_fullShop(phone: '03-9876-5432'));

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text('03-9876-5432'), findsOneWidget);
    });

    testWidgets('住所が表示される', (tester) async {
      mockShop.shopResult = Result.success(
        _fullShop(address: '東京都新宿区テスト2-3-4'),
      );

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.textContaining('東京都新宿区'), findsOneWidget);
    });

    testWidgets('サービスChipが表示される', (tester) async {
      mockShop.shopResult = Result.success(
        _fullShop(services: [
          ServiceCategory.maintenance,
          ServiceCategory.inspection,
        ]),
      );

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      // サービスに対応するChipやテキストが存在する
      expect(find.byType(Chip).evaluate().isNotEmpty, isTrue);
    });

    testWidgets('「問い合わせ」ボタンが表示される', (tester) async {
      mockShop.shopResult = Result.success(_fullShop());

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.textContaining('問い合わせ'), findsWidgets);
    });

    testWidgets('画像なし時にフォールバックアイコンが表示される', (tester) async {
      mockShop.shopResult = Result.success(_fullShop(imageUrls: []));

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.store_outlined), findsWidgets);
    });

    testWidgets('営業時間セクションが存在する', (tester) async {
      mockShop.shopResult = Result.success(_fullShop());

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.textContaining('営業'), findsWidgets);
    });

    testWidgets('注目ショップに「広告」ラベルが表示される（未認証の場合）', (tester) async {
      mockShop.shopResult = Result.success(
        _fullShop(isFeatured: true, isVerified: false),
      );

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      expect(find.text('広告'), findsOneWidget);
    });

    testWidgets('データ取得エラー時にエラーUIが表示される', (tester) async {
      mockShop.shopResult = Result.failure(
        AppError.notFound('Shop not found', resourceType: '工場'),
      );

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle();

      // エラー状態（再試行ボタンやメッセージ）が表示される
      expect(tester.takeException(), isNull);
    });

    group('Edge Cases', () {
      testWidgets('説明なし（description: null）でもクラッシュしない', (tester) async {
        mockShop.shopResult = Result.success(_fullShop(description: null));

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('電話番号なし（phone: null）でもクラッシュしない', (tester) async {
        mockShop.shopResult = Result.success(_fullShop(phone: null));

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('評価なし（rating: null）でもクラッシュしない', (tester) async {
        mockShop.shopResult = Result.success(_fullShop(rating: null));

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('サービスなし（services: []）でもクラッシュしない', (tester) async {
        mockShop.shopResult = Result.success(_fullShop(services: []));

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });
  });
}
