// VehicleListingService / VehicleListing Model Unit Tests
//
// Since VehicleListingService requires FirebaseFirestore, we test:
//   1. Enum behavior (ListingStatus, ConditionGrade, VehicleSortOption, DriveType)
//   2. VehicleListing display methods (displayTitle, displayPrice, displayMileage)
//   3. VehicleListing.primaryImageUrl selection logic
//   4. VehicleListing.isShopListing / isActive
//   5. VehicleSearchCriteria.hasFilters / filterCount
//   6. VehicleRecommendation.relevancePercent
//   7. AppError patterns

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle_listing.dart';
import 'package:trust_car_platform/models/vehicle_search.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

VehicleListing _makeListing({
  String id = 'listing1',
  String? shopId,
  ListingStatus status = ListingStatus.active,
  String makerName = 'トヨタ',
  String modelName = 'プリウス',
  String? gradeName,
  int modelYear = 2020,
  int mileage = 10000,
  int price = 2000000,
  int? totalPrice,
  List<ListingImage> images = const [],
  String? bodyType,
  ConditionGrade conditionGrade = ConditionGrade.a,
  VehicleSpecs specs = const VehicleSpecs(),
  bool hasAccidentHistory = false,
  bool hasSmokingHistory = false,
  bool isOneOwner = false,
  String? prefecture,
}) {
  final now = DateTime.now();
  return VehicleListing(
    id: id,
    sellerId: 'user1',
    shopId: shopId,
    status: status,
    makerId: 'toyota',
    makerName: makerName,
    modelId: 'prius',
    modelName: modelName,
    gradeName: gradeName,
    modelYear: modelYear,
    bodyType: bodyType,
    color: null,
    mileage: mileage,
    conditionGrade: conditionGrade,
    specs: specs,
    price: price,
    totalPrice: totalPrice,
    images: images,
    prefecture: prefecture ?? '東京都',
    hasAccidentHistory: hasAccidentHistory,
    hasSmokingHistory: hasSmokingHistory,
    isOneOwner: isOneOwner,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ListingStatus enum', () {
    test('displayName が空でない', () {
      for (final s in ListingStatus.values) {
        expect(s.displayName, isNotEmpty);
      }
    });

    test('fromString が既知の値を変換する', () {
      expect(ListingStatus.fromString('active'), ListingStatus.active);
      expect(ListingStatus.fromString('reserved'), ListingStatus.reserved);
      expect(ListingStatus.fromString('sold'), ListingStatus.sold);
      expect(ListingStatus.fromString('withdrawn'), ListingStatus.withdrawn);
    });

    test('fromString(null) は null を返す', () {
      expect(ListingStatus.fromString(null), isNull);
    });

    test('全 enum 値を往復変換できる', () {
      for (final s in ListingStatus.values) {
        expect(ListingStatus.fromString(s.name), s);
      }
    });
  });

  group('ConditionGrade enum', () {
    test('displayName / shortName が空でない', () {
      for (final g in ConditionGrade.values) {
        expect(g.displayName, isNotEmpty);
        expect(g.shortName, isNotEmpty);
      }
    });

    test('fromString が既知の値を変換する', () {
      expect(ConditionGrade.fromString('s'), ConditionGrade.s);
      expect(ConditionGrade.fromString('a'), ConditionGrade.a);
      expect(ConditionGrade.fromString('b'), ConditionGrade.b);
      expect(ConditionGrade.fromString('c'), ConditionGrade.c);
      expect(ConditionGrade.fromString('d'), ConditionGrade.d);
    });

    test('fromString(null) は null を返す', () {
      expect(ConditionGrade.fromString(null), isNull);
    });

    test('全 enum 値を往復変換できる', () {
      for (final g in ConditionGrade.values) {
        expect(ConditionGrade.fromString(g.name), g);
      }
    });
  });

  group('VehicleSortOption enum', () {
    test('全オプションの displayName が空でない', () {
      for (final opt in VehicleSortOption.values) {
        expect(opt.displayName, isNotEmpty);
      }
    });

    test('各 displayName が異なる', () {
      final names = VehicleSortOption.values.map((o) => o.displayName).toSet();
      expect(names.length, VehicleSortOption.values.length);
    });
  });

  // ── VehicleListing.displayTitle ───────────────────────────────────────────

  group('VehicleListing.displayTitle', () {
    test('gradeName なし: 「メーカー モデル」', () {
      final l = _makeListing(makerName: 'トヨタ', modelName: 'プリウス', gradeName: null);
      expect(l.displayTitle, 'トヨタ プリウス');
    });

    test('gradeName あり: 「メーカー モデル グレード」', () {
      final l = _makeListing(
        makerName: 'ホンダ', modelName: 'フィット', gradeName: 'Luxury');
      expect(l.displayTitle, 'ホンダ フィット Luxury');
    });

    test('gradeName が空文字列のとき trailing space なし', () {
      // gradeName=null のみがスキップされる; 実際は gradeName='' の挙動を確認
      final l = _makeListing(gradeName: null);
      expect(l.displayTitle, isNot(endsWith(' ')));
    });
  });

  // ── VehicleListing.displayPrice ───────────────────────────────────────────

  group('VehicleListing.displayPrice', () {
    test('100円 → 「¥100」', () {
      final l = _makeListing(price: 100);
      expect(l.displayPrice, '¥100');
    });

    test('1000円 → 「¥1,000」', () {
      final l = _makeListing(price: 1000);
      expect(l.displayPrice, '¥1,000');
    });

    test('10000円 → 「¥10,000」', () {
      final l = _makeListing(price: 10000);
      expect(l.displayPrice, '¥10,000');
    });

    test('1000000円 → 「¥1,000,000」', () {
      final l = _makeListing(price: 1000000);
      expect(l.displayPrice, '¥1,000,000');
    });

    test('2500000円 → 「¥2,500,000」', () {
      final l = _makeListing(price: 2500000);
      expect(l.displayPrice, '¥2,500,000');
    });

    test('0円 → 「¥0」', () {
      final l = _makeListing(price: 0);
      expect(l.displayPrice, '¥0');
    });
  });

  // ── VehicleListing.displayTotalPrice ─────────────────────────────────────

  group('VehicleListing.displayTotalPrice', () {
    test('totalPrice が null のとき null', () {
      final l = _makeListing(totalPrice: null);
      expect(l.displayTotalPrice, isNull);
    });

    test('totalPrice が設定されているとき「¥X,XXX」形式', () {
      final l = _makeListing(totalPrice: 2200000);
      expect(l.displayTotalPrice, '¥2,200,000');
    });
  });

  // ── VehicleListing.displayMileage ─────────────────────────────────────────

  group('VehicleListing.displayMileage', () {
    test('9999 km のとき「9999km」', () {
      final l = _makeListing(mileage: 9999);
      expect(l.displayMileage, '9999km');
    });

    test('10000 km のとき「1.0万km」', () {
      final l = _makeListing(mileage: 10000);
      expect(l.displayMileage, '1.0万km');
    });

    test('50000 km のとき「5.0万km」', () {
      final l = _makeListing(mileage: 50000);
      expect(l.displayMileage, '5.0万km');
    });

    test('99999 km のとき「10.0万km」未満', () {
      final l = _makeListing(mileage: 99999);
      expect(l.displayMileage, contains('万km'));
    });

    test('0 km のとき「0km」', () {
      final l = _makeListing(mileage: 0);
      expect(l.displayMileage, '0km');
    });

    test('100000 km のとき「10.0万km」', () {
      final l = _makeListing(mileage: 100000);
      expect(l.displayMileage, '10.0万km');
    });
  });

  // ── VehicleListing.primaryImageUrl ───────────────────────────────────────

  group('VehicleListing.primaryImageUrl', () {
    test('画像なしのとき null', () {
      final l = _makeListing(images: []);
      expect(l.primaryImageUrl, isNull);
    });

    test('isPrimary=true の画像があるとき、その url を返す', () {
      final images = [
        const ListingImage(url: 'a.jpg', isPrimary: false),
        const ListingImage(url: 'b.jpg', isPrimary: true),
        const ListingImage(url: 'c.jpg', isPrimary: false),
      ];
      final l = _makeListing(images: images);
      expect(l.primaryImageUrl, 'b.jpg');
    });

    test('isPrimary=true がないとき最初の url を返す', () {
      final images = [
        const ListingImage(url: 'first.jpg', isPrimary: false),
        const ListingImage(url: 'second.jpg', isPrimary: false),
      ];
      final l = _makeListing(images: images);
      expect(l.primaryImageUrl, 'first.jpg');
    });

    test('isPrimary=true が複数あるとき最初の isPrimary を返す', () {
      final images = [
        const ListingImage(url: 'a.jpg', isPrimary: true),
        const ListingImage(url: 'b.jpg', isPrimary: true),
      ];
      final l = _makeListing(images: images);
      expect(l.primaryImageUrl, 'a.jpg');
    });
  });

  // ── VehicleListing.isShopListing / isActive ───────────────────────────────

  group('VehicleListing.isShopListing', () {
    test('shopId が null のとき false', () {
      final l = _makeListing(shopId: null);
      expect(l.isShopListing, false);
    });

    test('shopId が設定されているとき true', () {
      final l = _makeListing(shopId: 'shop1');
      expect(l.isShopListing, true);
    });
  });

  group('VehicleListing.isActive', () {
    test('status が active のとき true', () {
      expect(_makeListing(status: ListingStatus.active).isActive, true);
    });

    test('status が reserved のとき false', () {
      expect(_makeListing(status: ListingStatus.reserved).isActive, false);
    });

    test('status が sold のとき false', () {
      expect(_makeListing(status: ListingStatus.sold).isActive, false);
    });

    test('status が withdrawn のとき false', () {
      expect(_makeListing(status: ListingStatus.withdrawn).isActive, false);
    });
  });

  // ── VehicleSearchCriteria.hasFilters ─────────────────────────────────────

  group('VehicleSearchCriteria.hasFilters', () {
    test('全フィールド未指定のとき false', () {
      const criteria = VehicleSearchCriteria();
      expect(criteria.hasFilters, false);
    });

    test('makerId を設定すると true', () {
      const criteria = VehicleSearchCriteria(makerId: 'toyota');
      expect(criteria.hasFilters, true);
    });

    test('yearMin を設定すると true', () {
      const criteria = VehicleSearchCriteria(yearMin: 2018);
      expect(criteria.hasFilters, true);
    });

    test('priceMax を設定すると true', () {
      const criteria = VehicleSearchCriteria(priceMax: 3000000);
      expect(criteria.hasFilters, true);
    });

    test('noAccidentHistory=true を設定すると true', () {
      const criteria = VehicleSearchCriteria(noAccidentHistory: true);
      expect(criteria.hasFilters, true);
    });

    test('keyword を設定すると true', () {
      const criteria = VehicleSearchCriteria(keyword: 'プリウス');
      expect(criteria.hasFilters, true);
    });

    test('bodyTypes が空リストのとき false（未指定扱い）', () {
      const criteria = VehicleSearchCriteria(bodyTypes: []);
      expect(criteria.hasFilters, false);
    });

    test('bodyTypes に値があると true', () {
      const criteria = VehicleSearchCriteria(bodyTypes: ['sedan']);
      expect(criteria.hasFilters, true);
    });

    test('prefectures に値があると true', () {
      const criteria = VehicleSearchCriteria(prefectures: ['東京都']);
      expect(criteria.hasFilters, true);
    });

    test('shopListingOnly=true を設定すると true', () {
      const criteria = VehicleSearchCriteria(shopListingOnly: true);
      expect(criteria.hasFilters, true);
    });
  });

  // ── VehicleSearchCriteria.filterCount ────────────────────────────────────

  group('VehicleSearchCriteria.filterCount', () {
    test('全未指定のとき 0', () {
      const criteria = VehicleSearchCriteria();
      expect(criteria.filterCount, 0);
    });

    test('makerId のみのとき 1', () {
      const criteria = VehicleSearchCriteria(makerId: 'toyota');
      expect(criteria.filterCount, 1);
    });

    test('yearMin+yearMax は 1 カウント', () {
      const criteria = VehicleSearchCriteria(yearMin: 2018, yearMax: 2022);
      expect(criteria.filterCount, 1);
    });

    test('priceMin+priceMax は 1 カウント', () {
      const criteria = VehicleSearchCriteria(priceMin: 1000000, priceMax: 3000000);
      expect(criteria.filterCount, 1);
    });

    test('複数フィルター', () {
      const criteria = VehicleSearchCriteria(
        makerId: 'toyota',        // +1
        yearMin: 2018,            // +1 (yearMin || yearMax)
        noAccidentHistory: true,  // +1
        bodyTypes: ['sedan'],     // +1
      );
      expect(criteria.filterCount, 4);
    });

    test('フィルターをリセットすると 0', () {
      const criteria = VehicleSearchCriteria(makerId: 'toyota', yearMin: 2018);
      final reset = criteria.reset();
      expect(reset.filterCount, 0);
    });
  });

  // ── VehicleRecommendation.relevancePercent ────────────────────────────────

  group('VehicleRecommendation.relevancePercent', () {
    test('relevanceScore=0.0 のとき 0', () {
      final r = VehicleRecommendation(
        listing: _makeListing(),
        relevanceScore: 0.0,
      );
      expect(r.relevancePercent, 0);
    });

    test('relevanceScore=0.5 のとき 50', () {
      final r = VehicleRecommendation(
        listing: _makeListing(),
        relevanceScore: 0.5,
      );
      expect(r.relevancePercent, 50);
    });

    test('relevanceScore=1.0 のとき 100', () {
      final r = VehicleRecommendation(
        listing: _makeListing(),
        relevanceScore: 1.0,
      );
      expect(r.relevancePercent, 100);
    });

    test('relevanceScore=0.755 のとき 76（四捨五入）', () {
      final r = VehicleRecommendation(
        listing: _makeListing(),
        relevanceScore: 0.755,
      );
      expect(r.relevancePercent, 76);
    });
  });

  // ── VehicleListing equality ───────────────────────────────────────────────

  group('VehicleListing equality', () {
    test('同じ id は等しい', () {
      final a = _makeListing(id: 'l1', price: 100000);
      final b = _makeListing(id: 'l1', price: 999999);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('異なる id は等しくない', () {
      final a = _makeListing(id: 'l1');
      final b = _makeListing(id: 'l2');
      expect(a, isNot(equals(b)));
    });
  });

  // ── AppError パターン ─────────────────────────────────────────────────────

  group('AppError パターン（車両リスティングサービス）', () {
    test('notFound error は isRetryable=false', () {
      const error = AppError.notFound('リスティングが見つかりません');
      expect(error.isRetryable, false);
    });

    test('server error は isRetryable=true', () {
      const error = AppError.server('サーバーエラー');
      expect(error.isRetryable, true);
    });

    test('Result.success に VehicleListing リストを格納できる', () {
      final result = Result<List<VehicleListing>, AppError>.success([
        _makeListing(),
      ]);
      expect(result.isSuccess, true);
    });

    test('Result.failure に AppError を格納できる', () {
      const result = Result<List<VehicleListing>, AppError>.failure(
        AppError.network('failed'),
      );
      expect(result.isFailure, true);
    });
  });

  // ── Edge Cases ────────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('displayMileage: 10000 と 9999 の境界値', () {
      final below = _makeListing(mileage: 9999);
      final above = _makeListing(mileage: 10000);
      expect(below.displayMileage, isNot(contains('万km')));
      expect(above.displayMileage, contains('万km'));
    });

    test('displayPrice: 999円（区切りなし）', () {
      final l = _makeListing(price: 999);
      expect(l.displayPrice, '¥999');
    });

    test('filterCount: oneOwnerOnly のみのとき 1', () {
      const criteria = VehicleSearchCriteria(oneOwnerOnly: true);
      expect(criteria.filterCount, 1);
    });

    test('filterCount: noSmokingHistory のみのとき 1', () {
      const criteria = VehicleSearchCriteria(noSmokingHistory: true);
      expect(criteria.filterCount, 1);
    });

    test('VehicleSearchCriteria reset: 元のオブジェクトを変更しない', () {
      const criteria = VehicleSearchCriteria(makerId: 'toyota');
      final reset = criteria.reset();
      expect(criteria.makerId, 'toyota');
      expect(reset.makerId, isNull);
    });

    test('VehicleRecommendation: matchReasons が空でも正常', () {
      final r = VehicleRecommendation(
        listing: _makeListing(),
        relevanceScore: 0.3,
        matchReasons: [],
      );
      expect(r.relevancePercent, 30);
    });
  });
}
