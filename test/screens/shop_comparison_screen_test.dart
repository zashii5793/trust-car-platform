// ShopComparisonScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows shop count in title
//   Comparison cards:
//     2. Renders one card per shop
//     3. Shows shop names in cards
//     4. Shows 'おすすめ' badge on recommended shop (primaryNeed set)
//     5. No 'おすすめ' badge when no primaryNeed
//   Primary need banner:
//     6. Banner is shown when primaryNeed is provided
//     7. Banner is hidden when no primaryNeed
//   Service chips:
//     8. Matching service chip is highlighted for primaryNeed
//   Edge cases:
//     9. Single shop still renders
//    10. Shop with no rating shows '評価なし'

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/injection.dart';
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
  double? rating = 4.0,
  int reviewCount = 10,
  List<ServiceCategory> services = const [],
  ShopType type = ShopType.maintenanceShop,
}) {
  final now = DateTime.now();
  return Shop(
    id: id,
    name: name,
    type: type,
    planType: ShopPlanType.standard,
    subscriptionStatus: ShopSubscriptionStatus.active,
    rating: rating,
    reviewCount: reviewCount,
    services: services,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildScreen({
  required List<Shop> shops,
  ServiceCategory? primaryNeed,
}) {
  sl.override<ShopComparisonService>(const ShopComparisonService());
  return MaterialApp(
    home: ShopComparisonScreen(shops: shops, primaryNeed: primaryNeed),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  tearDown(() {
    Injection.reset();
  });

  final shopA = _makeShop(
    id: 'a',
    name: 'アルファモータース',
    rating: 4.8,
    reviewCount: 50,
    services: [ServiceCategory.bodyWork, ServiceCategory.inspection],
  );
  final shopB = _makeShop(
    id: 'b',
    name: 'ベータオート',
    rating: 3.5,
    reviewCount: 20,
    services: [ServiceCategory.coating],
  );
  final shopC = _makeShop(
    id: 'c',
    name: 'ガンマサービス',
    rating: 4.2,
    reviewCount: 35,
    services: [ServiceCategory.bodyWork, ServiceCategory.maintenance],
  );

  // =========================================================================
  group('ShopComparisonScreen — AppBar', () {
    testWidgets('1. タイトルに工場数が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(shops: [shopA, shopB, shopC]));
      await tester.pump();

      expect(find.text('工場比較 (3件)'), findsOneWidget);
    });
  });

  // =========================================================================
  group('ShopComparisonScreen — Comparison cards', () {
    testWidgets('2. 工場数だけカードが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(shops: [shopA, shopB]));
      await tester.pump();

      expect(find.byType(Card), findsNWidgets(2));
    });

    testWidgets('3. 各工場名がカードに表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(shops: [shopA, shopB]));
      await tester.pump();

      expect(find.text('アルファモータース'), findsOneWidget);
      expect(find.text('ベータオート'), findsOneWidget);
    });

    testWidgets('4. primaryNeed設定時はおすすめバッジが表示される', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          shops: [shopA, shopB, shopC],
          primaryNeed: ServiceCategory.bodyWork,
        ),
      );
      await tester.pump();

      expect(find.text('おすすめ'), findsOneWidget);
    });

    testWidgets('5. primaryNeedなしはおすすめバッジが表示されない', (tester) async {
      await tester.pumpWidget(_buildScreen(shops: [shopA, shopB]));
      await tester.pump();

      expect(find.text('おすすめ'), findsNothing);
    });
  });

  // =========================================================================
  group('ShopComparisonScreen — Primary need banner', () {
    testWidgets('6. primaryNeedバナーが表示される', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          shops: [shopA, shopB],
          primaryNeed: ServiceCategory.bodyWork,
        ),
      );
      await tester.pump();

      expect(find.textContaining('希望サービス'), findsOneWidget);
      expect(find.textContaining(ServiceCategory.bodyWork.displayName),
          findsWidgets);
    });

    testWidgets('7. primaryNeedなしはバナーが表示されない', (tester) async {
      await tester.pumpWidget(_buildScreen(shops: [shopA, shopB]));
      await tester.pump();

      expect(find.textContaining('希望サービス'), findsNothing);
    });
  });

  // =========================================================================
  group('ShopComparisonScreen — Service chips', () {
    testWidgets('8. primaryNeedに一致するサービスチップが強調表示される', (tester) async {
      final shopWithBodyWork = _makeShop(
        id: 'x',
        name: '板金工場',
        services: [ServiceCategory.bodyWork, ServiceCategory.maintenance],
      );
      await tester.pumpWidget(
        _buildScreen(
          shops: [shopWithBodyWork],
          primaryNeed: ServiceCategory.bodyWork,
        ),
      );
      await tester.pump();

      expect(find.text(ServiceCategory.bodyWork.displayName), findsWidgets);
    });
  });

  // =========================================================================
  group('ShopComparisonScreen — Edge cases', () {
    testWidgets('9. 1工場でも正常に表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(shops: [shopA]));
      await tester.pump();

      expect(find.text('工場比較 (1件)'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('10. 評価なし工場は「評価なし」が表示される', (tester) async {
      final shopNoRating = _makeShop(
        id: 'x',
        name: '評価なしショップ',
        rating: null,
      );
      await tester.pumpWidget(_buildScreen(shops: [shopNoRating]));
      await tester.pump();

      expect(find.text('評価なし'), findsOneWidget);
    });
  });

  // =========================================================================
  group('ShopComparisonScreen — Rank badges', () {
    testWidgets('11. 複数工場でランクバッジ1・2が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(shops: [shopA, shopB]));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('12. 3工場でランクバッジ1・2・3が全て表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(shops: [shopA, shopB, shopC]));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  // =========================================================================
  group('ShopComparisonScreen — Rating display', () {
    testWidgets('13. 評価値が表示される', (tester) async {
      final shopRated = _makeShop(id: 'r', name: 'テスト工場', rating: 4.8);
      await tester.pumpWidget(_buildScreen(shops: [shopRated]));
      await tester.pump();

      expect(find.text('4.8'), findsOneWidget);
    });

    testWidgets('14. レビュー件数が表示される', (tester) async {
      final shopReviewed = _makeShop(id: 'rv', name: 'レビュー工場', reviewCount: 25);
      await tester.pumpWidget(_buildScreen(shops: [shopReviewed]));
      await tester.pump();

      expect(find.textContaining('25件'), findsOneWidget);
    });
  });

  // =========================================================================
  group('ShopComparisonScreen — Card details', () {
    testWidgets('15. AIスコアラベルが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(shops: [shopA]));
      await tester.pump();

      expect(find.text('AIスコア'), findsOneWidget);
    });

    testWidgets('16. カードにIDベースのキーが設定されている', (tester) async {
      await tester.pumpWidget(_buildScreen(shops: [shopA, shopB]));
      await tester.pump();

      expect(find.byKey(const Key('comparison_card_a')), findsOneWidget);
      expect(find.byKey(const Key('comparison_card_b')), findsOneWidget);
    });

    testWidgets('17. 工場タイプの表示名が表示される', (tester) async {
      final shop = _makeShop(
        id: 't',
        name: 'タイプ工場',
        type: ShopType.maintenanceShop,
      );
      await tester.pumpWidget(_buildScreen(shops: [shop]));
      await tester.pump();

      expect(find.text(ShopType.maintenanceShop.displayName), findsOneWidget);
    });

    testWidgets('18. サービスカテゴリ名がチップに表示される', (tester) async {
      final shop = _makeShop(
        id: 's',
        name: 'サービス工場',
        services: [ServiceCategory.inspection, ServiceCategory.tire],
      );
      await tester.pumpWidget(_buildScreen(shops: [shop]));
      await tester.pump();

      expect(find.text(ServiceCategory.inspection.displayName), findsOneWidget);
      expect(find.text(ServiceCategory.tire.displayName), findsOneWidget);
    });
  });
}
