import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle_listing.dart';
import 'package:trust_car_platform/models/vehicle_search.dart';

void main() {
  group('VehicleSortOption', () {
    test('displayName returns Japanese name', () {
      expect(VehicleSortOption.newest.displayName, '新着順');
      expect(VehicleSortOption.priceAsc.displayName, '価格が安い順');
      expect(VehicleSortOption.priceDesc.displayName, '価格が高い順');
      expect(VehicleSortOption.mileageAsc.displayName, '走行距離が少ない順');
      expect(VehicleSortOption.yearDesc.displayName, '年式が新しい順');
      expect(VehicleSortOption.popular.displayName, '人気順');
    });
  });

  group('VehicleSearchCriteria', () {
    test('creates with default values', () {
      const criteria = VehicleSearchCriteria();

      expect(criteria.makerId, isNull);
      expect(criteria.sortBy, VehicleSortOption.newest);
      expect(criteria.hasFilters, false);
      expect(criteria.filterCount, 0);
    });

    test('hasFilters returns true when filters applied', () {
      const criteria = VehicleSearchCriteria(
        makerId: 'toyota',
        priceMax: 3000000,
      );

      expect(criteria.hasFilters, true);
      expect(criteria.filterCount, 2);
    });

    test('filterCount counts all applied filters', () {
      const criteria = VehicleSearchCriteria(
        makerId: 'toyota',
        modelId: 'prius',
        bodyTypes: ['sedan', 'hatchback'],
        yearMin: 2020,
        mileageMax: 50000,
        priceMin: 1000000,
        priceMax: 3000000,
        transmissionTypes: [TransmissionType.at],
        noAccidentHistory: true,
        shopListingOnly: true,
      );

      // makerId, modelId, bodyTypes, year, mileage, price, transmission, noAccidentHistory, shopListingOnly
      expect(criteria.filterCount, 9);
    });

    test('copyWith creates modified copy', () {
      const criteria = VehicleSearchCriteria(
        makerId: 'toyota',
        priceMax: 3000000,
      );

      final modified = criteria.copyWith(
        modelId: 'prius',
        sortBy: VehicleSortOption.priceAsc,
      );

      expect(modified.makerId, 'toyota');
      expect(modified.modelId, 'prius');
      expect(modified.priceMax, 3000000);
      expect(modified.sortBy, VehicleSortOption.priceAsc);
    });

    test('reset returns empty criteria', () {
      const criteria = VehicleSearchCriteria(
        makerId: 'toyota',
        priceMax: 3000000,
      );

      final reset = criteria.reset();

      expect(reset.makerId, isNull);
      expect(reset.priceMax, isNull);
      expect(reset.hasFilters, false);
    });

    test('toMap converts to map', () {
      const criteria = VehicleSearchCriteria(
        makerId: 'toyota',
        priceMin: 1000000,
        priceMax: 3000000,
        transmissionTypes: [TransmissionType.at, TransmissionType.cvt],
        fuelTypes: [FuelType.hybrid],
        noAccidentHistory: true,
        sortBy: VehicleSortOption.priceAsc,
      );

      final map = criteria.toMap();

      expect(map['makerId'], 'toyota');
      expect(map['priceMin'], 1000000);
      expect(map['priceMax'], 3000000);
      expect(map['transmissionTypes'], ['at', 'cvt']);
      expect(map['fuelTypes'], ['hybrid']);
      expect(map['noAccidentHistory'], true);
      expect(map['sortBy'], 'priceAsc');
    });
  });

  group('VehiclePreference', () {
    test('creates with default values', () {
      const pref = VehiclePreference(userId: 'user1');

      expect(pref.userId, 'user1');
      expect(pref.preferredMakerIds, isEmpty);
      expect(pref.budgetMax, isNull);
      expect(pref.requiresNoAccidentHistory, false);
    });

    test('creates with full preferences', () {
      const pref = VehiclePreference(
        userId: 'user1',
        preferredMakerIds: ['toyota', 'honda'],
        preferredBodyTypes: ['sedan', 'suv'],
        budgetMin: 1000000,
        budgetMax: 3000000,
        maxMileage: 50000,
        minYear: 2020,
        preferredFuelTypes: [FuelType.hybrid],
        requiresNoAccidentHistory: true,
        preferredPrefectures: ['東京都', '神奈川県'],
      );

      expect(pref.preferredMakerIds, ['toyota', 'honda']);
      expect(pref.budgetMax, 3000000);
      expect(pref.requiresNoAccidentHistory, true);
    });

    test('copyWith creates modified copy', () {
      const pref = VehiclePreference(
        userId: 'user1',
        budgetMax: 3000000,
      );

      final modified = pref.copyWith(
        preferredMakerIds: ['toyota'],
        maxMileage: 30000,
      );

      expect(modified.userId, 'user1');
      expect(modified.preferredMakerIds, ['toyota']);
      expect(modified.budgetMax, 3000000);
      expect(modified.maxMileage, 30000);
    });

    test('toSearchCriteria converts to search criteria', () {
      const pref = VehiclePreference(
        userId: 'user1',
        preferredMakerIds: ['toyota', 'honda'],
        preferredBodyTypes: ['sedan'],
        budgetMin: 1000000,
        budgetMax: 3000000,
        maxMileage: 50000,
        minYear: 2020,
        preferredFuelTypes: [FuelType.hybrid],
        requiresNoAccidentHistory: true,
        preferredPrefectures: ['東京都'],
      );

      final criteria = pref.toSearchCriteria();

      expect(criteria.makerId, 'toyota'); // First preferred maker
      expect(criteria.bodyTypes, ['sedan']);
      expect(criteria.priceMin, 1000000);
      expect(criteria.priceMax, 3000000);
      expect(criteria.mileageMax, 50000);
      expect(criteria.yearMin, 2020);
      expect(criteria.fuelTypes, [FuelType.hybrid]);
      expect(criteria.noAccidentHistory, true);
      expect(criteria.prefectures, ['東京都']);
    });
  });

  group('VehicleRecommendation', () {
    test('creates with required fields', () {
      final listing = VehicleListing(
        id: 'listing1',
        sellerId: 'seller1',
        status: ListingStatus.active,
        makerId: 'toyota',
        makerName: 'トヨタ',
        modelId: 'prius',
        modelName: 'プリウス',
        modelYear: 2022,
        mileage: 15000,
        conditionGrade: ConditionGrade.a,
        price: 2500000,
        prefecture: '東京都',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final recommendation = VehicleRecommendation(
        listing: listing,
        relevanceScore: 0.85,
        matchReasons: ['希望メーカー', '予算内'],
      );

      expect(recommendation.relevanceScore, 0.85);
      expect(recommendation.relevancePercent, 85);
      expect(recommendation.matchReasons, ['希望メーカー', '予算内']);
    });

    test('relevancePercent rounds correctly', () {
      final listing = VehicleListing(
        id: 'listing1',
        sellerId: 'seller1',
        status: ListingStatus.active,
        makerId: 'toyota',
        makerName: 'トヨタ',
        modelId: 'prius',
        modelName: 'プリウス',
        modelYear: 2022,
        mileage: 15000,
        conditionGrade: ConditionGrade.a,
        price: 2500000,
        prefecture: '東京都',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final rec1 = VehicleRecommendation(
        listing: listing,
        relevanceScore: 0.756,
      );
      expect(rec1.relevancePercent, 76);

      final rec2 = VehicleRecommendation(
        listing: listing,
        relevanceScore: 0.754,
      );
      expect(rec2.relevancePercent, 75);
    });
  });
}
