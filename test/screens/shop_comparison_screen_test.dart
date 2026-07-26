import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/screens/shop/shop_comparison_screen.dart';
import 'package:trust_car_platform/services/shop_comparison_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Shop _makeShop({
  required String id,
  required String name,
  double? rating,
  int reviewCount = 0,
  List<ServiceCategory> services = const [],
}) =>
    Shop(
      id: id,
      name: name,
      type: ShopType.maintenanceShop,
      rating: rating,
      reviewCount: reviewCount,
      services: services,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );

Widget _buildScreen(List<Shop> shops, {ServiceCategory? primaryNeed}) {
  return MaterialApp(
    home: ShopComparisonScreen(shops: shops, primaryNeed: primaryNeed),
  );
}

void main() {
  setUpAll(() {
    final sl = ServiceLocator.instance;
    if (!sl.isRegistered<ShopComparisonService>()) {
      sl.registerLazySingleton<ShopComparisonService>(
          () => const ShopComparisonService());
    }
  });

  // ---------------------------------------------------------------------------
  // 基本レンダリング
  // ---------------------------------------------------------------------------

  group('基本レンダリング', () {
    testWidgets('2工場を渡すと比較リストが2枚表示される', (tester) async {
      final shops = [
        _makeShop(id: 'a', name: '工場A', rating: 4.5, reviewCount: 20),
        _makeShop(id: 'b', name: '工場B', rating: 4.0, reviewCount: 10),
      ];

      await tester.pumpWidget(_buildScreen(shops));

      expect(find.byKey(const Key('comparison_list')), findsOneWidget);
      expect(find.byKey(const Key('comparison_card_a')), findsOneWidget);
      expect(find.byKey(const Key('comparison_card_b')), findsOneWidget);
    });

    testWidgets('工場名がカード内に表示される', (tester) async {
      final shops = [
        _makeShop(id: 'a', name: 'テスト工場'),
        _makeShop(id: 'b', name: 'サンプル工場'),
      ];

      await tester.pumpWidget(_buildScreen(shops));

      expect(find.text('テスト工場'), findsOneWidget);
      expect(find.text('サンプル工場'), findsOneWidget);
    });

    testWidgets('3工場を渡すと3枚すべて表示される', (tester) async {
      final shops = [
        _makeShop(id: 'a', name: '工場A', rating: 4.8, reviewCount: 50),
        _makeShop(id: 'b', name: '工場B', rating: 4.2, reviewCount: 30),
        _makeShop(id: 'c', name: '工場C', rating: 3.9, reviewCount: 15),
      ];

      await tester.pumpWidget(_buildScreen(shops));

      expect(find.byKey(const Key('comparison_card_a')), findsOneWidget);
      expect(find.byKey(const Key('comparison_card_b')), findsOneWidget);
      expect(find.byKey(const Key('comparison_card_c')), findsOneWidget);
    });

    testWidgets('AppBar に工場数が表示される', (tester) async {
      final shops = [
        _makeShop(id: 'a', name: '工場A'),
        _makeShop(id: 'b', name: '工場B'),
      ];

      await tester.pumpWidget(_buildScreen(shops));

      expect(find.text('工場比較 (2件)'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // primaryNeed なし
  // ---------------------------------------------------------------------------

  group('primaryNeed なし', () {
    testWidgets('希望サービスバナーが表示されない', (tester) async {
      final shops = [
        _makeShop(id: 'a', name: '工場A'),
        _makeShop(id: 'b', name: '工場B'),
      ];

      await tester.pumpWidget(_buildScreen(shops));

      expect(find.text('希望サービス: 車検'), findsNothing);
    });

    testWidgets('おすすめバッジが表示されない', (tester) async {
      final shops = [
        _makeShop(id: 'a', name: '工場A', rating: 4.9, reviewCount: 100),
        _makeShop(id: 'b', name: '工場B', rating: 3.0, reviewCount: 5),
      ];

      await tester.pumpWidget(_buildScreen(shops));

      expect(find.text('おすすめ'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // primaryNeed あり
  // ---------------------------------------------------------------------------

  group('primaryNeed あり', () {
    testWidgets('希望サービスバナーに ServiceCategory が表示される', (tester) async {
      final shops = [
        _makeShop(
            id: 'a', name: '車検工場', services: [ServiceCategory.inspection]),
        _makeShop(id: 'b', name: '整備工場'),
      ];

      await tester.pumpWidget(
          _buildScreen(shops, primaryNeed: ServiceCategory.inspection));

      expect(find.textContaining('車検'), findsWidgets);
    });

    testWidgets('希望サービスを提供する工場におすすめバッジが付く', (tester) async {
      final shopWithService = _makeShop(
        id: 'match',
        name: '車検対応工場',
        rating: 4.0,
        reviewCount: 20,
        services: [ServiceCategory.inspection],
      );
      final shopWithout = _makeShop(
        id: 'nomatch',
        name: '整備専門工場',
        rating: 4.9,
        reviewCount: 100,
        services: [ServiceCategory.maintenance],
      );

      await tester.pumpWidget(_buildScreen([shopWithService, shopWithout],
          primaryNeed: ServiceCategory.inspection));

      expect(find.text('おすすめ'), findsOneWidget);
    });

    testWidgets('どの工場も primaryNeed を提供しない場合おすすめバッジなし', (tester) async {
      final shops = [
        _makeShop(
            id: 'a',
            name: '工場A',
            rating: 4.0,
            reviewCount: 10,
            services: [ServiceCategory.maintenance]),
        _makeShop(
            id: 'b',
            name: '工場B',
            rating: 4.5,
            reviewCount: 20,
            services: [ServiceCategory.repair]),
      ];

      await tester.pumpWidget(
          _buildScreen(shops, primaryNeed: ServiceCategory.inspection));

      expect(find.text('おすすめ'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // サービスチップ表示
  // ---------------------------------------------------------------------------

  group('サービスチップ', () {
    testWidgets('工場のサービスがチップとして表示される', (tester) async {
      final shops = [
        _makeShop(
          id: 'a',
          name: '総合工場',
          services: [ServiceCategory.inspection, ServiceCategory.tire],
        ),
        _makeShop(id: 'b', name: '工場B'),
      ];

      await tester.pumpWidget(_buildScreen(shops));

      expect(find.text('車検'), findsOneWidget);
      expect(find.text('タイヤ交換'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge Cases
  // ---------------------------------------------------------------------------

  group('Edge Cases', () {
    testWidgets('評価なしの工場でも表示が崩れない', (tester) async {
      final shops = [
        _makeShop(id: 'a', name: '無評価工場'),
        _makeShop(id: 'b', name: '工場B'),
      ];

      await tester.pumpWidget(_buildScreen(shops));

      expect(find.text('評価なし'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('サービスなしの工場でもクラッシュしない', (tester) async {
      final shops = [
        _makeShop(id: 'a', name: '工場A'),
        _makeShop(id: 'b', name: '工場B'),
      ];

      await tester.pumpWidget(_buildScreen(shops));

      expect(tester.takeException(), isNull);
    });
  });
}
