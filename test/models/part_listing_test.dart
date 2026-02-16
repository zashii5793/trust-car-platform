import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/part_listing.dart';

void main() {
  group('PartCategory', () {
    test('has correct display names', () {
      expect(PartCategory.aero.displayName, 'エアロパーツ');
      expect(PartCategory.wheel.displayName, 'ホイール');
      expect(PartCategory.exhaust.displayName, 'マフラー・排気系');
    });

    test('fromString returns correct enum', () {
      expect(PartCategory.fromString('aero'), PartCategory.aero);
      expect(PartCategory.fromString('wheel'), PartCategory.wheel);
      expect(PartCategory.fromString('invalid'), null);
      expect(PartCategory.fromString(null), null);
    });
  });

  group('CompatibilityLevel', () {
    test('has correct display names and descriptions', () {
      expect(CompatibilityLevel.perfect.displayName, '完全対応');
      expect(CompatibilityLevel.perfect.description, 'ボルトオンで取付可能');
      expect(CompatibilityLevel.conditional.displayName, '条件付き');
    });

    test('fromString returns correct enum', () {
      expect(CompatibilityLevel.fromString('perfect'), CompatibilityLevel.perfect);
      expect(CompatibilityLevel.fromString('conditional'), CompatibilityLevel.conditional);
      expect(CompatibilityLevel.fromString('invalid'), null);
    });
  });

  group('VehicleSpec', () {
    test('fromMap creates VehicleSpec correctly', () {
      final spec = VehicleSpec.fromMap({
        'makerId': 'toyota',
        'modelId': 'toyota_prius',
        'yearFrom': 2015,
        'yearTo': 2023,
      });

      expect(spec.makerId, 'toyota');
      expect(spec.modelId, 'toyota_prius');
      expect(spec.yearFrom, 2015);
      expect(spec.yearTo, 2023);
    });

    test('matchesVehicle returns true for matching spec', () {
      const spec = VehicleSpec(
        makerId: 'toyota',
        modelId: 'toyota_prius',
        yearFrom: 2015,
        yearTo: 2023,
      );

      expect(
        spec.matchesVehicle(
          makerId: 'toyota',
          modelId: 'toyota_prius',
          year: 2020,
        ),
        true,
      );
    });

    test('matchesVehicle returns false for wrong maker', () {
      const spec = VehicleSpec(
        makerId: 'toyota',
      );

      expect(
        spec.matchesVehicle(
          makerId: 'honda',
          modelId: 'honda_fit',
          year: 2020,
        ),
        false,
      );
    });

    test('matchesVehicle returns false for year out of range', () {
      const spec = VehicleSpec(
        makerId: 'toyota',
        yearFrom: 2015,
        yearTo: 2020,
      );

      expect(
        spec.matchesVehicle(
          makerId: 'toyota',
          modelId: 'toyota_prius',
          year: 2010,
        ),
        false,
      );

      expect(
        spec.matchesVehicle(
          makerId: 'toyota',
          modelId: 'toyota_prius',
          year: 2025,
        ),
        false,
      );
    });

    test('matchesVehicle with null constraints matches any', () {
      const spec = VehicleSpec();

      expect(
        spec.matchesVehicle(
          makerId: 'any_maker',
          modelId: 'any_model',
          year: 2020,
        ),
        true,
      );
    });
  });

  group('PartProCon', () {
    test('fromMap creates PartProCon correctly', () {
      final pro = PartProCon.fromMap({
        'text': 'Good quality',
        'isPro': true,
      });

      expect(pro.text, 'Good quality');
      expect(pro.isPro, true);
    });

    test('toMap returns correct map', () {
      const con = PartProCon(text: 'Expensive', isPro: false);
      final map = con.toMap();

      expect(map['text'], 'Expensive');
      expect(map['isPro'], false);
    });
  });

  group('PartListing', () {
    final testListing = PartListing(
      id: 'part1',
      shopId: 'shop1',
      name: 'Test Part',
      description: 'A test part',
      category: PartCategory.wheel,
      priceFrom: 50000,
      priceTo: 80000,
      compatibleVehicles: const [
        VehicleSpec(makerId: 'toyota', modelId: 'toyota_prius'),
      ],
      prosAndCons: const [
        PartProCon(text: 'Light weight', isPro: true),
        PartProCon(text: 'Premium quality', isPro: true),
        PartProCon(text: 'High price', isPro: false),
      ],
      rating: 4.5,
      reviewCount: 100,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

    test('priceDisplay shows range correctly', () {
      expect(testListing.priceDisplay, '¥50,000〜¥80,000');
    });

    test('priceDisplay shows single price', () {
      final singlePrice = testListing.copyWith(priceTo: 50000);
      expect(singlePrice.priceDisplay, '¥50,000');
    });

    test('priceDisplay shows 要問合せ when null', () {
      final noPrice = testListing.copyWith(priceFrom: null, priceTo: null);
      // copyWith doesn't allow setting to null, so create new instance
      final noPriceListing = PartListing(
        id: 'part1',
        shopId: 'shop1',
        name: 'Test',
        description: 'Test',
        category: PartCategory.wheel,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(noPriceListing.priceDisplay, '要問合せ');
    });

    test('pros returns only pros', () {
      final pros = testListing.pros;
      expect(pros.length, 2);
      expect(pros.every((p) => p.isPro), true);
    });

    test('cons returns only cons', () {
      final cons = testListing.cons;
      expect(cons.length, 1);
      expect(cons.every((c) => !c.isPro), true);
    });

    test('getCompatibilityFor returns perfect for matching vehicle', () {
      final compatibility = testListing.getCompatibilityFor(
        makerId: 'toyota',
        modelId: 'toyota_prius',
        year: 2020,
      );

      expect(compatibility, CompatibilityLevel.perfect);
    });

    test('getCompatibilityFor returns conditional for same maker', () {
      final compatibility = testListing.getCompatibilityFor(
        makerId: 'toyota',
        modelId: 'toyota_corolla',  // Different model
        year: 2020,
      );

      expect(compatibility, CompatibilityLevel.conditional);
    });

    test('getCompatibilityFor returns default for different maker', () {
      final compatibility = testListing.getCompatibilityFor(
        makerId: 'honda',
        modelId: 'honda_fit',
        year: 2020,
      );

      expect(compatibility, CompatibilityLevel.compatible);  // default
    });

    test('equality works correctly', () {
      final part1 = testListing;
      final part2 = testListing.copyWith(name: 'Different Name');
      final part3 = PartListing(
        id: 'different_id',
        shopId: 'shop1',
        name: 'Test Part',
        description: 'A test part',
        category: PartCategory.wheel,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(part1 == part2, true);  // Same ID
      expect(part1 == part3, false);  // Different ID
    });
  });

  group('PartRecommendation', () {
    test('compare sorts by compatibility then relevance', () {
      final perfectLow = PartRecommendation(
        part: PartListing(
          id: '1',
          shopId: 's',
          name: 'P1',
          description: 'd',
          category: PartCategory.wheel,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        compatibility: CompatibilityLevel.perfect,
        relevanceScore: 0.3,
      );

      final perfectHigh = PartRecommendation(
        part: PartListing(
          id: '2',
          shopId: 's',
          name: 'P2',
          description: 'd',
          category: PartCategory.wheel,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        compatibility: CompatibilityLevel.perfect,
        relevanceScore: 0.8,
      );

      final conditional = PartRecommendation(
        part: PartListing(
          id: '3',
          shopId: 's',
          name: 'P3',
          description: 'd',
          category: PartCategory.wheel,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        compatibility: CompatibilityLevel.conditional,
        relevanceScore: 0.9,
      );

      final list = [conditional, perfectLow, perfectHigh];
      list.sort(PartRecommendation.compare);

      // Perfect compatibility should come first, then sorted by relevance
      expect(list[0].part.id, '2');  // perfectHigh
      expect(list[1].part.id, '1');  // perfectLow
      expect(list[2].part.id, '3');  // conditional (lower compatibility)
    });
  });
}
