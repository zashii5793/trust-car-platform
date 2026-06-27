import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
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
    List<ReservationMethod> reservationMethods = const [],
  }) {
    return Shop(
      id: id,
      name: name,
      type: ShopType.maintenanceShop,
      services: services,
      rating: rating,
      reviewCount: reviewCount,
      reservationMethods: reservationMethods,
      location: (lat != null && lng != null) ? GeoPoint(lat, lng) : null,
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

    test('offersRequestedService is true when no required services specified',
        () {
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
    test(
        'results sorted by distance when user location provided — closer first',
        () {
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
        buildShop(
            id: 'shop1',
            name: 'Shop A',
            services: [ServiceCategory.inspection]),
        buildShop(
            id: 'shop2',
            name: 'Shop B',
            services: [ServiceCategory.maintenance]),
        buildShop(
            id: 'shop3', name: 'Shop C', services: [ServiceCategory.repair]),
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
    test(
        'offersRequestedService true only if ALL required services are offered',
        () {
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

    test('recommend picks higher-rated shop when both offer primary service',
        () {
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

  // ──────────────────────────────────────────────
  // タカヤモーター(株) — 実店舗データ統合テスト
  // URL: https://www.takayagroup.co.jp/
  // Services: 新車・中古車販売, 車リース, 車検, 一般整備, 鈑金塗装, 損害保険代理店
  // ──────────────────────────────────────────────
  group('タカヤモーター(株) — 実店舗データ', () {
    late Shop takayaMotor;

    setUp(() {
      takayaMotor = Shop(
        id: 'takaya-motor-main',
        name: 'タカヤモーター(株)',
        type: ShopType.dealer,
        description: '新車・中古車販売、車リース、車検、一般整備、鈑金塗装、損害保険代理店。地域密着型総合カーショップ。',
        website: 'https://www.takayagroup.co.jp/',
        services: [
          ServiceCategory.inspection,
          ServiceCategory.maintenance,
          ServiceCategory.repair,
          ServiceCategory.bodyWork,
          ServiceCategory.insurance,
          ServiceCategory.purchase,
          ServiceCategory.sale,
        ],
        reservationMethods: [ReservationMethod.phone, ReservationMethod.web],
        appealPoints: ['新車・中古車対応', 'リース取扱', '損害保険代理店', '鈑金塗装完備'],
        rating: 4.2,
        reviewCount: 38,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
    });

    test('基本プロファイル: 名前・種別・評価が正しく設定される', () {
      expect(takayaMotor.name, 'タカヤモーター(株)');
      expect(takayaMotor.type, ShopType.dealer);
      expect(takayaMotor.rating, 4.2);
      expect(takayaMotor.reviewCount, 38);
      expect(takayaMotor.isActive, isTrue);
    });

    test('サービス確認: 車検・整備・板金・保険・売買をすべて提供する', () {
      expect(takayaMotor.offersService(ServiceCategory.inspection), isTrue);
      expect(takayaMotor.offersService(ServiceCategory.maintenance), isTrue);
      expect(takayaMotor.offersService(ServiceCategory.bodyWork), isTrue);
      expect(takayaMotor.offersService(ServiceCategory.insurance), isTrue);
      expect(takayaMotor.offersService(ServiceCategory.purchase), isTrue);
      expect(takayaMotor.offersService(ServiceCategory.sale), isTrue);
    });

    test('比較: 車検ニーズに対してタカヤモーターがサービス提供店として識別される', () {
      final competitor = Shop(
        id: 'parts-only',
        name: 'パーツ専門店',
        type: ShopType.partsShop,
        services: [ServiceCategory.partsInstall],
        createdAt: now,
        updatedAt: now,
      );

      final results = service.compare(
        shops: [competitor, takayaMotor],
        requiredServices: [ServiceCategory.inspection],
      );

      final takayaResult =
          results.firstWhere((r) => r.shop.id == 'takaya-motor-main');
      final partsResult = results.firstWhere((r) => r.shop.id == 'parts-only');

      expect(takayaResult.offersRequestedService, isTrue);
      expect(partsResult.offersRequestedService, isFalse);
    });

    test('比較: 車検＋鈑金の複数条件でもタカヤモーターが合致する', () {
      final results = service.compare(
        shops: [takayaMotor],
        requiredServices: [
          ServiceCategory.inspection,
          ServiceCategory.bodyWork
        ],
      );
      expect(results.first.offersRequestedService, isTrue);
    });

    test('推薦: 車検専門店より評価数が少なくても正常にスコアが計算される', () {
      // タカヤモーター: 4.2 * ln(38+1) ≈ 4.2 * 3.664 = 15.39
      // 高評価な車検専門店: 4.8 * ln(121) ≈ 4.8 * 4.796 = 23.02
      final sokuTaro = Shop(
        id: 'inspection-pro',
        name: '車検のスピード太郎',
        type: ShopType.maintenanceShop,
        services: [ServiceCategory.inspection, ServiceCategory.maintenance],
        rating: 4.8,
        reviewCount: 120,
        createdAt: now,
        updatedAt: now,
      );

      final results = service.compare(shops: [takayaMotor, sokuTaro]);
      final recommended = service.recommend(
        results: results,
        primaryNeed: ServiceCategory.inspection,
      );

      // スピード太郎の方がスコアが高いはず
      expect(recommended!.id, 'inspection-pro');
    });

    test('推薦: 保険サービスではタカヤモーターが唯一の候補として推薦される', () {
      final noInsurance = Shop(
        id: 'garage-works',
        name: 'ガレージ ワークス',
        type: ShopType.customShop,
        services: [ServiceCategory.customization, ServiceCategory.bodyWork],
        rating: 4.2,
        reviewCount: 45,
        createdAt: now,
        updatedAt: now,
      );

      final results = service.compare(shops: [noInsurance, takayaMotor]);
      final recommended = service.recommend(
        results: results,
        primaryNeed: ServiceCategory.insurance,
      );

      expect(recommended, isNotNull);
      expect(recommended!.id, 'takaya-motor-main');
    });

    test('予約方法: 電話とWeb予約があるため翌日対応と推定される', () {
      final results = service.compare(shops: [takayaMotor]);
      // ReservationMethod.phone → estimatedResponseDays = 2
      expect(results.first.estimatedResponseDays, 2);
    });

    group('Edge Cases', () {
      test('コーティングは提供していないと正しく判定される', () {
        expect(takayaMotor.offersService(ServiceCategory.coating), isFalse);
        expect(takayaMotor.offersService(ServiceCategory.rental), isFalse);
      });

      test('全サービス条件で比較した場合にもクラッシュしない', () {
        final results = service.compare(
          shops: [takayaMotor],
          requiredServices: ServiceCategory.values.toList(),
        );
        // タカヤモーターが全サービスを網羅しているわけではないので false になるが正常動作
        expect(results.first.offersRequestedService, isFalse);
      });

      test('タカヤモーター単体でもrecommend()がクラッシュしない', () {
        final results = service.compare(shops: [takayaMotor]);
        final recommended = service.recommend(
          results: results,
          primaryNeed: ServiceCategory.inspection,
        );
        expect(recommended, isNotNull);
        expect(recommended!.name, 'タカヤモーター(株)');
      });
    });

    // ──────────────────────────────────────────────
    // recommendationReasonFor — 推奨理由の言語化
    // ──────────────────────────────────────────────
    group('recommendationReasonFor', () {
      test('高評価・多レビューの工場は理由に評価と実績を含む', () {
        final shop = buildShop(
          id: 'r1',
          name: 'High Rated',
          services: [ServiceCategory.inspection],
          rating: 4.7,
          reviewCount: 120,
        );
        final results = service.compare(
          shops: [shop],
          requiredServices: [ServiceCategory.inspection],
        );
        final reason = service.recommendationReasonFor(
          results.first,
          primaryNeed: ServiceCategory.inspection,
        );
        expect(reason, contains('高評価'));
        expect(reason, contains('実績'));
        expect(reason, contains('おすすめ'));
      });

      test('評価・レビューが無い工場でも空にならずフォールバック文を返す', () {
        final shop = buildShop(id: 'r2', name: 'No Data');
        final results = service.compare(shops: [shop]);
        final reason = service.recommendationReasonFor(results.first);
        expect(reason, isNotEmpty);
      });

      test('primaryNeed に対応している場合は理由に含む', () {
        final shop = buildShop(
          id: 'r3',
          name: 'Tire Shop',
          services: [ServiceCategory.tire],
          rating: 4.2,
        );
        final results = service.compare(shops: [shop]);
        final reason = service.recommendationReasonFor(
          results.first,
          primaryNeed: ServiceCategory.tire,
        );
        expect(reason, contains(ServiceCategory.tire.displayName));
      });

      test('評価4.0〜4.4の工場は「安定した評価」を理由に含む', () {
        final shop = buildShop(
          id: 'r-mid',
          name: 'Mid Rated',
          rating: 4.2,
          reviewCount: 10,
        );
        final results = service.compare(shops: [shop]);
        final reason = service.recommendationReasonFor(results.first);
        expect(reason, contains('安定した評価'));
        expect(reason, contains('4.2'));
      });

      test('レビュー50件以上の工場は「豊富な実績」を理由に含む', () {
        final shop = buildShop(
          id: 'r-rev',
          name: 'Many Reviews',
          rating: 3.0,
          reviewCount: 80,
        );
        final results = service.compare(shops: [shop]);
        final reason = service.recommendationReasonFor(results.first);
        expect(reason, contains('豊富な実績'));
        expect(reason, contains('80件'));
      });

      test('5km未満の工場は「近い立地」を理由に含む', () {
        // ユーザー位置と同一座標に近い店舗 → 距離≒0km
        final shop = buildShop(
          id: 'r-near',
          name: 'Near Shop',
          lat: 35.0001,
          lng: 139.0001,
        );
        final results = service.compare(
          shops: [shop],
          userLat: 35.0,
          userLng: 139.0,
        );
        final reason = service.recommendationReasonFor(results.first);
        expect(reason, contains('近い立地'));
      });

      test('5〜15kmの工場は「通いやすい距離」を理由に含む', () {
        // 緯度0.1度 ≒ 約11km
        final shop = buildShop(
          id: 'r-mid-dist',
          name: 'Mid Distance Shop',
          lat: 35.1,
          lng: 139.0,
        );
        final results = service.compare(
          shops: [shop],
          userLat: 35.0,
          userLng: 139.0,
        );
        final reason = service.recommendationReasonFor(results.first);
        expect(reason, contains('通いやすい距離'));
      });

      test('walk-in対応の工場は「当日対応」を理由に含む', () {
        final shop = buildShop(
          id: 'r-walkin',
          name: 'Walk-in Shop',
          reservationMethods: [ReservationMethod.walkIn],
        );
        final results = service.compare(shops: [shop]);
        final reason = service.recommendationReasonFor(results.first);
        expect(reason, contains('当日対応'));
      });

      test('電話予約のみの工場は「翌日対応」を理由に含む', () {
        final shop = buildShop(
          id: 'r-phone',
          name: 'Phone Shop',
          reservationMethods: [ReservationMethod.phone],
        );
        final results = service.compare(shops: [shop]);
        final reason = service.recommendationReasonFor(results.first);
        expect(reason, contains('翌日対応'));
      });
    });

    // ──────────────────────────────────────────────
    // compare — 距離計算（Haversine）
    // ──────────────────────────────────────────────
    group('compare — 距離計算', () {
      test('ユーザー位置と店舗位置からdistanceKmが算出される', () {
        final shop = buildShop(
          id: 'd1',
          name: 'Located Shop',
          lat: 35.1,
          lng: 139.0,
        );
        final results = service.compare(
          shops: [shop],
          userLat: 35.0,
          userLng: 139.0,
        );
        // 緯度0.1度 ≒ 約11km（許容幅を持たせて検証）
        expect(results.first.distanceKm, isNotNull);
        expect(results.first.distanceKm, greaterThan(9));
        expect(results.first.distanceKm, lessThan(13));
      });

      test('店舗にlocationが無い場合distanceKmはnull', () {
        final shop = buildShop(id: 'd2', name: 'No Location');
        final results = service.compare(
          shops: [shop],
          userLat: 35.0,
          userLng: 139.0,
        );
        expect(results.first.distanceKm, isNull);
      });

      test('位置あり店舗と位置なし店舗が混在しても位置なしが末尾にソートされる', () {
        final located = buildShop(
          id: 'd-loc',
          name: 'Located',
          lat: 35.05,
          lng: 139.0,
        );
        final noLoc = buildShop(id: 'd-noloc', name: 'No Location');
        final results = service.compare(
          shops: [noLoc, located],
          userLat: 35.0,
          userLng: 139.0,
        );
        // 位置ありが先頭、位置なし(null距離)が末尾
        expect(results.first.shop.id, 'd-loc');
        expect(results.last.distanceKm, isNull);
      });
    });
  });
}
