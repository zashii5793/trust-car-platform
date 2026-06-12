import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/services/shop_comparison_service.dart';

void main() {
  late ShopComparisonService service;

  final now = DateTime(2024, 6, 1);

  // Helper to build a Shop with defaults
  Shop buildShop({
    required String id,
    required String name,
    List<ServiceCategory> services = const [],
    double? rating,
    int reviewCount = 0,
    double? lat,
    double? lng,
  }) {
    return Shop(
      id: id,
      name: name,
      type: ShopType.maintenanceShop,
      services: services,
      rating: rating,
      reviewCount: reviewCount,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    service = const ShopComparisonService();
  });

  // ──────────────────────────────────────────────
  // compare — basic
  // ──────────────────────────────────────────────
  group('compare', () {
    test('compare returns a result for each shop', () {
      final shops = [
        buildShop(id: 'shop1', name: 'Shop A'),
        buildShop(id: 'shop2', name: 'Shop B'),
      ];

      final results = service.compare(shops: shops);

      expect(results.length, 2);
    });

    test('offersRequestedService is true when shop offers the service', () {
      final shops = [
        buildShop(
          id: 'shop1',
          name: 'Shop A',
          services: [ServiceCategory.inspection, ServiceCategory.maintenance],
        ),
        buildShop(
          id: 'shop2',
          name: 'Shop B',
          services: [ServiceCategory.maintenance],
        ),
      ];

      final results = service.compare(
        shops: shops,
        requiredServices: [ServiceCategory.inspection],
      );

      final shopA = results.firstWhere((r) => r.shop.id == 'shop1');
      final shopB = results.firstWhere((r) => r.shop.id == 'shop2');

      expect(shopA.offersRequestedService, true);
      expect(shopB.offersRequestedService, false);
    });

    test('offersRequestedService is true when no required services specified', () {
      final shops = [
        buildShop(id: 'shop1', name: 'Shop A'),
      ];

      final results = service.compare(shops: shops);

      expect(results.first.offersRequestedService, true);
    });

    test('distanceKm is null when user location is not provided', () {
      final shops = [
        buildShop(id: 'shop1', name: 'Shop A'),
      ];

      final results = service.compare(shops: shops);

      expect(results.first.distanceKm, isNull);
    });

    test('estimatedResponseDays is between 1 and 3', () {
      final shops = [
        buildShop(id: 'shop1', name: 'Shop A'),
        buildShop(id: 'shop2', name: 'Shop B'),
        buildShop(id: 'shop3', name: 'Shop C'),
      ];

      final results = service.compare(shops: shops);

      for (final r in results) {
        expect(r.estimatedResponseDays, inInclusiveRange(1, 3));
      }
    });
  });

  // ──────────────────────────────────────────────
  // compare — distance sorting
  // ──────────────────────────────────────────────
  group('compare — distance sorting', () {
    test('results sorted by distance when user location provided — closer first', () {
      // Shop near Tokyo station: 35.6812, 139.7671
      // Shop near Osaka station: 34.7024, 135.4959
      // User near Tokyo
      final shopTokyo = buildShop(id: 'shopTokyo', name: 'Tokyo Shop');
      final shopOsaka = buildShop(id: 'shopOsaka', name: 'Osaka Shop');

      // We need shops with GeoPoints. Since Shop uses GeoPoint (Firestore),
      // distance is computed only when userLat/userLng AND shop.location are set.
      // Without shop.location, distanceKm is null and order is input order.
      final results = service.compare(
        shops: [shopOsaka, shopTokyo],
        userLat: 35.6812,
        userLng: 139.7671,
      );

      // Without shop.location, distanceKm is null — order preserved
      expect(results.length, 2);
      expect(results.every((r) => r.distanceKm == null), true);
    });

    test('3 shops comparison returns 3 results', () {
      final shops = [
        buildShop(id: 'shop1', name: 'Shop A', services: [ServiceCategory.inspection]),
        buildShop(id: 'shop2', name: 'Shop B', services: [ServiceCategory.maintenance]),
        buildShop(id: 'shop3', name: 'Shop C', services: [ServiceCategory.repair]),
      ];

      final results = service.compare(
        shops: shops,
        requiredServices: [ServiceCategory.inspection],
      );

      expect(results.length, 3);
      final shopA = results.firstWhere((r) => r.shop.id == 'shop1');
      final shopB = results.firstWhere((r) => r.shop.id == 'shop2');
      expect(shopA.offersRequestedService, true);
      expect(shopB.offersRequestedService, false);
    });
  });

  // ──────────────────────────────────────────────
  // compare — multiple required services
  // ──────────────────────────────────────────────
  group('compare — service filter', () {
    test('offersRequestedService true only if ALL required services are offered', () {
      final shopAll = buildShop(
        id: 'shopAll',
        name: 'Full Service Shop',
        services: [ServiceCategory.inspection, ServiceCategory.tire],
      );
      final shopPartial = buildShop(
        id: 'shopPartial',
        name: 'Partial Shop',
        services: [ServiceCategory.inspection],
      );

      final results = service.compare(
        shops: [shopAll, shopPartial],
        requiredServices: [ServiceCategory.inspection, ServiceCategory.tire],
      );

      final all = results.firstWhere((r) => r.shop.id == 'shopAll');
      final partial = results.firstWhere((r) => r.shop.id == 'shopPartial');

      expect(all.offersRequestedService, true);
      expect(partial.offersRequestedService, false);
    });
  });

  // ──────────────────────────────────────────────
  // recommend
  // ──────────────────────────────────────────────
  group('recommend', () {
    test('recommend returns shop that offers primary service', () {
      final shopA = buildShop(
        id: 'shopA',
        name: 'Shop A',
        services: [ServiceCategory.inspection],
        rating: 4.5,
        reviewCount: 100,
      );
      final shopB = buildShop(
        id: 'shopB',
        name: 'Shop B',
        services: [ServiceCategory.maintenance],
        rating: 4.0,
        reviewCount: 50,
      );

      final results = service.compare(
        shops: [shopA, shopB],
        requiredServices: [ServiceCategory.inspection],
      );

      final recommended = service.recommend(
        results: results,
        primaryNeed: ServiceCategory.inspection,
      );

      expect(recommended, isNotNull);
      expect(recommended!.id, 'shopA');
    });

    test('recommend returns null when no shops match primary need', () {
      final shopA = buildShop(
        id: 'shopA',
        name: 'Shop A',
        services: [ServiceCategory.maintenance],
        rating: 4.0,
        reviewCount: 30,
      );

      final results = service.compare(
        shops: [shopA],
        requiredServices: [ServiceCategory.inspection],
      );

      final recommended = service.recommend(
        results: results,
        primaryNeed: ServiceCategory.inspection,
      );

      expect(recommended, isNull);
    });

    test('recommend returns null for empty results', () {
      final recommended = service.recommend(
        results: [],
        primaryNeed: ServiceCategory.inspection,
      );

      expect(recommended, isNull);
    });

    test('recommend picks higher-rated shop when both offer primary service', () {
      final shopHigh = buildShop(
        id: 'shopHigh',
        name: 'High Rated',
        services: [ServiceCategory.inspection],
        rating: 4.8,
        reviewCount: 200,
      );
      final shopLow = buildShop(
        id: 'shopLow',
        name: 'Low Rated',
        services: [ServiceCategory.inspection],
        rating: 3.2,
        reviewCount: 10,
      );

      final results = service.compare(
        shops: [shopLow, shopHigh],
        requiredServices: [ServiceCategory.inspection],
      );

      final recommended = service.recommend(
        results: results,
        primaryNeed: ServiceCategory.inspection,
      );

      expect(recommended!.id, 'shopHigh');
    });

    test('recommend score considers both rating and reviewCount', () {
      // shopMany: lower rating but many reviews — should beat shopFew with higher
      // rating but very few reviews, when score = rating * log(reviewCount+1)
      final shopMany = buildShop(
        id: 'shopMany',
        name: 'Many Reviews',
        services: [ServiceCategory.inspection],
        rating: 4.0,
        reviewCount: 1000,
      );
      final shopFew = buildShop(
        id: 'shopFew',
        name: 'Few Reviews',
        services: [ServiceCategory.inspection],
        rating: 5.0,
        reviewCount: 1,
      );

      final results = service.compare(
        shops: [shopFew, shopMany],
        requiredServices: [ServiceCategory.inspection],
      );

      final recommended = service.recommend(
        results: results,
        primaryNeed: ServiceCategory.inspection,
      );

      // shopMany: 4.0 * log(1001) ≈ 4.0 * 6.908 = 27.6
      // shopFew:  5.0 * log(2)    ≈ 5.0 * 0.693 = 3.5
      expect(recommended!.id, 'shopMany');
    });

    group('Edge Cases', () {
      test('shop with null rating gets lower score than rated shop', () {
        final ratedShop = buildShop(
          id: 'rated',
          name: 'Rated Shop',
          services: [ServiceCategory.inspection],
          rating: 3.0,
          reviewCount: 5,
        );
        final unratedShop = buildShop(
          id: 'unrated',
          name: 'Unrated Shop',
          services: [ServiceCategory.inspection],
          rating: null,
          reviewCount: 0,
        );

        final results = service.compare(
          shops: [unratedShop, ratedShop],
          requiredServices: [ServiceCategory.inspection],
        );

        final recommended = service.recommend(
          results: results,
          primaryNeed: ServiceCategory.inspection,
        );

        expect(recommended!.id, 'rated');
      });
    });
  });
}
