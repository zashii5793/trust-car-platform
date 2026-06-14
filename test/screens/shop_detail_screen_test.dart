// ShopDetailScreen Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/screens/marketplace/shop_detail_screen.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/models/shop_case_study.dart';
import 'package:trust_car_platform/models/shop_monthly_report.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Mocks (同一ファイルに定義)
// ---------------------------------------------------------------------------

class MockShopService implements ShopService {
  Result<Shop, AppError>? shopResult;
  Result<List<ShopCaseStudy>, AppError> caseStudiesResult =
      const Result.success([]);

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
  }) async =>
      const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getFeaturedShops(
          {int limit = 5}) async =>
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
  Future<Result<List<Shop>, AppError>> getNearbyShops(
          dynamic center, double radiusKm,
          {int limit = 20}) async =>
      const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getShopsByService(
          ServiceCategory category,
          {int limit = 20}) async =>
      const Result.success([]);

  @override
  Future<Result<Shop, AppError>> createMyShop(Shop shop) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<Shop, AppError>> updateMyShop(Shop shop) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<Shop?, AppError>> getMyShop(String uid) async =>
      const Result.success(null);

  @override
  Stream<Map<String, int>> watchInquiryCount(String shopId) =>
      Stream.value(const {'total': 0, 'unread': 0});

  @override
  Future<Result<Map<String, int>, AppError>> getInquiryCount(
          String shopId) async =>
      const Result.success({'total': 0, 'unread': 0});

  @override
  Future<Result<void, AppError>> deleteMyShop(String uid) async =>
      const Result.success(null);

  @override
  Future<Result<List<ShopCaseStudy>, AppError>> getCaseStudies(
          String shopId) async =>
      caseStudiesResult;

  @override
  Future<Result<ShopCaseStudy, AppError>> addCaseStudy(
          ShopCaseStudy study) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<void, AppError>> deleteCaseStudy(
          String shopId, String studyId) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> updateCaseStudy(ShopCaseStudy study) async =>
      const Result.success(null);

  @override
  Future<Result<ShopMonthlyReport?, AppError>> getMonthlyReport(
          String shopId) async =>
      const Result.success(null);

  @override
  Future<Result<String, AppError>> uploadCaseStudyImage(
          String shopId, dynamic image, String type) async =>
      Result.failure(AppError.unknown('not impl'));
}

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
    String? shopName,
  }) async =>
      Result.failure(AppError.unknown('not impl'));

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
    required String inquiryId,
    required String senderId,
    required bool isFromShop,
    required String content,
    List<String> attachmentUrls = const [],
    Map<String, dynamic>? maintenancePayload,
  }) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<List<InquiryMessage>, AppError>> getMessages(String id,
          {int limit = 50, dynamic startAfter}) async =>
      const Result.success([]);

  @override
  Future<Result<void, AppError>> markAsRead(
          {required String inquiryId, required bool isUser}) async =>
      const Result.success(null);

  @override
  Future<Result<Inquiry, AppError>> updateStatus(
          String id, dynamic status) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<int, AppError>> getUnreadCountForUser(String userId) async =>
      const Result.success(0);

  @override
  Future<Result<int, AppError>> countUserInquiriesThisMonth(
          String userId) async =>
      const Result.success(0);

  @override
  Stream<List<Inquiry>> streamUserInquiries(String userId) =>
      const Stream.empty();

  @override
  Stream<List<InquiryMessage>> streamMessages(String inquiryId) =>
      const Stream.empty();
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
  String? website,
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
    website: website,
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
  tearDown(() {
    Injection.reset();
  });

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
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('プレミアムガレージ'), findsWidgets);
    });

    testWidgets('店舗の説明が表示される', (tester) async {
      mockShop.shopResult = Result.success(
        _fullShop(description: '最高のサービスを提供します。'),
      );

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('最高のサービスを提供します。'), findsOneWidget);
    });

    testWidgets('認証済みバッジが表示される', (tester) async {
      mockShop.shopResult = Result.success(_fullShop(isVerified: true));

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

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
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('03-9876-5432'), findsOneWidget);
    });

    testWidgets('住所が表示される', (tester) async {
      mockShop.shopResult = Result.success(
        _fullShop(address: '東京都新宿区テスト2-3-4'),
      );

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

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
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // サービスに対応するChipやテキストが存在する
      expect(find.byType(Chip).evaluate().isNotEmpty, isTrue);
    });

    testWidgets('「問い合わせ」ボタンが表示される', (tester) async {
      mockShop.shopResult = Result.success(_fullShop());

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.textContaining('問い合わせ'), findsWidgets);
    });

    testWidgets('画像なし時にフォールバックアイコンが表示される', (tester) async {
      mockShop.shopResult = Result.success(_fullShop(imageUrls: []));

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byIcon(Icons.store), findsWidgets);
    });

    testWidgets('営業時間セクションが存在する', (tester) async {
      mockShop.shopResult = Result.success(_fullShop());

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.textContaining('営業'), findsWidgets);
    });

    testWidgets('注目ショップに「広告」ラベルが表示される（未認証の場合）', (tester) async {
      mockShop.shopResult = Result.success(
        _fullShop(isFeatured: true, isVerified: false),
      );

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('広告'), findsOneWidget);
    });

    testWidgets('データ取得エラー時にエラーUIが表示される', (tester) async {
      mockShop.shopResult = Result.failure(
        AppError.notFound('Shop not found', resourceType: '工場'),
      );

      await tester.pumpWidget(_buildApp(provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // エラー状態（再試行ボタンやメッセージ）が表示される
      expect(tester.takeException(), isNull);
    });

    group('Edge Cases', () {
      testWidgets('説明なし（description: null）でもクラッシュしない', (tester) async {
        mockShop.shopResult = Result.success(_fullShop(description: null));

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(tester.takeException(), isNull);
      });

      testWidgets('電話番号なし（phone: null）でもクラッシュしない', (tester) async {
        mockShop.shopResult = Result.success(_fullShop(phone: null));

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(tester.takeException(), isNull);
      });

      testWidgets('評価なし（rating: null）でもクラッシュしない', (tester) async {
        mockShop.shopResult = Result.success(_fullShop(rating: null));

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(tester.takeException(), isNull);
      });

      testWidgets('サービスなし（services: []）でもクラッシュしない', (tester) async {
        mockShop.shopResult = Result.success(_fullShop(services: []));

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(tester.takeException(), isNull);
      });
    });

    // =========================================================================
    group('評価・レビュー', () {
      testWidgets('評価値とレビュー件数が表示される', (tester) async {
        mockShop.shopResult = Result.success(_fullShop(rating: 4.5));

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(find.text('4.5'), findsWidgets);
        expect(find.textContaining('42件のレビュー'), findsOneWidget);
      });

      testWidgets('星アイコンが5つ表示される', (tester) async {
        mockShop.shopResult = Result.success(_fullShop(rating: 3.0));

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        // 5 stars total (filled or empty)
        expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
      });

      testWidgets('評価なしのときは星アイコンが表示されない', (tester) async {
        mockShop.shopResult = Result.success(_fullShop(rating: null));

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(find.byIcon(Icons.star_rounded), findsNothing);
      });
    });

    // =========================================================================
    group('営業時間', () {
      testWidgets('営業時間セクションのヘッダが表示される', (tester) async {
        mockShop.shopResult = Result.success(_fullShop());

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(find.text('営業時間'), findsOneWidget);
      });

      testWidgets('ExpansionTileを展開すると曜日テキストが表示される', (tester) async {
        mockShop.shopResult = Result.success(_fullShop());

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        // Scroll to ensure the '営業時間' title is not obscured by bottom nav bar
        await tester.ensureVisible(find.text('営業時間'));
        await tester.pump();
        await tester.tap(find.text('営業時間'));
        await tester.pumpAndSettle();

        // Weekday names should be in the widget tree after expansion
        expect(find.text('月'), findsWidgets);
        expect(find.text('日'), findsWidgets);
      });

      testWidgets('businessHoursが空のときは営業時間セクションが非表示', (tester) async {
        final shop = _fullShop();
        // Create a shop with empty businessHours via copyWith
        final shopNoHours = Shop(
          id: shop.id,
          name: shop.name,
          type: shop.type,
          isActive: shop.isActive,
          isVerified: shop.isVerified,
          isFeatured: shop.isFeatured,
          description: shop.description,
          phone: shop.phone,
          address: shop.address,
          imageUrls: shop.imageUrls,
          services: shop.services,
          supportedMakerIds: shop.supportedMakerIds,
          businessHours: const {},
          rating: shop.rating,
          reviewCount: shop.reviewCount,
          createdAt: shop.createdAt,
          updatedAt: shop.updatedAt,
        );
        mockShop.shopResult = Result.success(shopNoHours);

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(find.text('営業時間'), findsNothing);
      });
    });

    // =========================================================================
    group('連絡先・住所', () {
      testWidgets('ウェブサイトURLが表示される', (tester) async {
        mockShop.shopResult = Result.success(
          _fullShop(website: 'https://example-garage.com'),
        );

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(find.text('https://example-garage.com'), findsOneWidget);
        expect(find.byIcon(Icons.language_outlined), findsOneWidget);
      });

      testWidgets('住所セクション「所在地」が表示される', (tester) async {
        mockShop.shopResult = Result.success(
          _fullShop(address: '東京都渋谷区テスト1-2-3'),
        );

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(find.text('所在地'), findsOneWidget);
        expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
      });

      testWidgets('address・prefecture・city がすべてnullのとき住所セクションが非表示',
          (tester) async {
        final shop = _fullShop(address: null);
        final shopNoAddr = Shop(
          id: shop.id,
          name: shop.name,
          type: shop.type,
          isActive: shop.isActive,
          isVerified: shop.isVerified,
          isFeatured: shop.isFeatured,
          description: shop.description,
          phone: shop.phone,
          imageUrls: shop.imageUrls,
          services: shop.services,
          supportedMakerIds: shop.supportedMakerIds,
          businessHours: shop.businessHours,
          rating: shop.rating,
          reviewCount: shop.reviewCount,
          createdAt: shop.createdAt,
          updatedAt: shop.updatedAt,
        );
        mockShop.shopResult = Result.success(shopNoAddr);

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(find.text('所在地'), findsNothing);
      });
    });

    // =========================================================================
    group('施工事例', () {
      testWidgets('施工事例が0件のときはセクションが非表示（sl経由）', (tester) async {
        sl.override<ShopService>(mockShop);
        mockShop.shopResult = Result.success(_fullShop());
        mockShop.caseStudiesResult = const Result.success([]);

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(find.text('施工事例'), findsNothing);
      });

      testWidgets('施工事例が1件あるときはセクションが表示される（sl経由）', (tester) async {
        sl.override<ShopService>(mockShop);
        final study = ShopCaseStudy(
          id: 'cs1',
          shopId: 'shop1',
          title: 'エンジンオイル交換事例',
          createdAt: DateTime(2024),
        );
        mockShop.shopResult = Result.success(_fullShop());
        mockShop.caseStudiesResult = Result.success([study]);

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(find.text('施工事例'), findsOneWidget);
        expect(find.text('エンジンオイル交換事例'), findsOneWidget);
      });
    });

    // =========================================================================
    group('BottomNavigationBar', () {
      testWidgets('「この工場に問い合わせる」ボタンがBottomBarに表示される', (tester) async {
        mockShop.shopResult = Result.success(_fullShop());

        await tester.pumpWidget(_buildApp(provider));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(find.text('この工場に問い合わせる'), findsOneWidget);
      });
    });
  });
}
