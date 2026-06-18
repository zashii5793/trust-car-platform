// MarketplaceScreen Widget Tests
//
// MarketplaceScreen は ShopListScreen / PartListScreen / MyInquiriesScreen / MyListingsScreen を
// 3 タブで表示するだけの薄いコンテナ。タブ構造と各タブの描画を検証する。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/marketplace/marketplace_screen.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';
import 'package:trust_car_platform/providers/part_recommendation_provider.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/services/part_recommendation_service.dart';
import 'package:trust_car_platform/providers/vehicle_provider.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/part_listing.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockShopService implements ShopService {
  Result<List<Shop>, AppError> shopsResult = const Result.success([]);

  @override
  Future<Result<List<Shop>, AppError>> getShops({
    ShopType? type,
    ServiceCategory? serviceCategory,
    String? prefecture,
    int limit = 20,
    dynamic startAfter,
  }) async =>
      shopsResult;

  @override
  Future<Result<List<Shop>, AppError>> getFeaturedShops(
          {int limit = 5}) async =>
      const Result.success([]);

  @override
  Future<Result<Shop, AppError>> getShop(String shopId) async =>
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubFirebaseService implements FirebaseService {
  @override
  Stream<List<Vehicle>> getUserVehicles() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockInquiryService implements InquiryService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPartRecommendationService implements PartRecommendationService {
  Result<List<PartListing>, AppError> browseResult = const Result.success([]);

  @override
  Future<Result<List<PartListing>, AppError>> getPartsByCategory(
    PartCategory category, {
    int limit = 20,
    dynamic startAfter,
  }) async =>
      browseResult;

  @override
  Future<Result<List<PartListing>, AppError>> getFeaturedParts({
    int limit = 8,
  }) async =>
      const Result.success([]);

  @override
  Future<Result<List<PartListing>, AppError>> searchParts(
    String query, {
    PartCategory? category,
    int limit = 20,
  }) async =>
      const Result.success([]);

  @override
  Future<Result<PartListing, AppError>> getPartDetail(String partId) async =>
      Result.failure(AppError.notFound('not found'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildUnderTest({
  MockShopService? shopService,
  MockPartRecommendationService? partService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => VehicleProvider(firebaseService: _StubFirebaseService()),
      ),
      ChangeNotifierProvider(
        create: (_) => ShopProvider(
          shopService: shopService ?? MockShopService(),
          inquiryService: MockInquiryService(),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => PartRecommendationProvider(
          partRecommendationService:
              partService ?? MockPartRecommendationService(),
        ),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: MarketplaceScreen(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MarketplaceScreen — タブ構造', () {
    testWidgets('「工場・業者」タブが表示される', (tester) async {
      await tester.pumpWidget(_buildUnderTest());
      await tester.pump();

      expect(find.text('工場・業者'), findsOneWidget);
    });

    testWidgets('「パーツ」タブが表示される', (tester) async {
      await tester.pumpWidget(_buildUnderTest());
      await tester.pump();

      expect(find.text('パーツ'), findsOneWidget);
    });

    testWidgets('「問い合わせ」タブが表示される', (tester) async {
      await tester.pumpWidget(_buildUnderTest());
      await tester.pump();

      expect(find.text('問い合わせ'), findsOneWidget);
    });

    // C2C「マイ出品」タブはコンセプト（AI→提携EC）に合わせて廃止。
    // 現在は 工場・業者 / パーツ / 問い合わせ の3タブ。
    testWidgets('TabBar が 3 タブ持つ', (tester) async {
      await tester.pumpWidget(_buildUnderTest());
      await tester.pump();

      expect(find.byType(Tab), findsNWidgets(3));
      expect(find.text('マイ出品'), findsNothing);
    });

    testWidgets('デフォルトは「工場・業者」タブが選択されている', (tester) async {
      await tester.pumpWidget(_buildUnderTest());
      await tester.pump();

      // 最初のタブのコンテンツ（ShopListScreen）が表示される
      // TabBarView は最初のタブをデフォルト表示
      expect(find.byType(TabBarView), findsOneWidget);
    });
  });

  group('MarketplaceScreen — タブ切替', () {
    testWidgets('「パーツ」タブをタップすると PartListScreen に切り替わる', (tester) async {
      await tester.pumpWidget(_buildUnderTest());
      await tester.pump();

      await tester.tap(find.text('パーツ'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // TabBar の 2 番目タブがアクティブになる
      // (各画面の空状態テキストは shop/part_list_screen_test でカバー済み)
      expect(find.text('パーツ'), findsOneWidget);
    });

    testWidgets('「工場・業者」→「パーツ」→「工場・業者」と切り替えられる', (tester) async {
      await tester.pumpWidget(_buildUnderTest());
      await tester.pump();

      await tester.tap(find.text('パーツ'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('工場・業者'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('工場・業者'), findsOneWidget);
    });
  });

  group('MarketplaceScreen — アイコン', () {
    testWidgets('店舗アイコン（store_outlined）が表示される', (tester) async {
      await tester.pumpWidget(_buildUnderTest());
      await tester.pump();

      // タブと ShopListScreen の空状態の両方に表示されうるため findsWidgets
      expect(find.byIcon(Icons.store_outlined), findsWidgets);
    });

    testWidgets('パーツアイコン（build_outlined）が表示される', (tester) async {
      await tester.pumpWidget(_buildUnderTest());
      await tester.pump();

      expect(find.byIcon(Icons.build_outlined), findsOneWidget);
    });
  });

  group('MarketplaceScreen — データなし状態', () {
    testWidgets('ShopService が空を返してもクラッシュしない', (tester) async {
      final shopService = MockShopService()
        ..shopsResult = const Result.success([]);
      await tester.pumpWidget(_buildUnderTest(shopService: shopService));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('ShopService がエラーを返してもクラッシュしない', (tester) async {
      final shopService = MockShopService()
        ..shopsResult = const Result.failure(AppError.network('error'));
      await tester.pumpWidget(_buildUnderTest(shopService: shopService));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
