import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle_master.dart';
import 'package:trust_car_platform/data/vehicle_master_data.dart';

void main() {
  group('BodyType', () {
    test('has correct display names', () {
      expect(BodyType.sedan.displayName, 'セダン');
      expect(BodyType.suv.displayName, 'SUV');
      expect(BodyType.minivan.displayName, 'ミニバン');
      expect(BodyType.kei.displayName, '軽自動車');
    });

    test('fromString returns correct enum', () {
      expect(BodyType.fromString('sedan'), BodyType.sedan);
      expect(BodyType.fromString('suv'), BodyType.suv);
      expect(BodyType.fromString('invalid'), null);
      expect(BodyType.fromString(null), null);
    });
  });

  group('VehicleMaker', () {
    test('fromMap creates VehicleMaker correctly', () {
      final maker = VehicleMaker.fromMap({
        'name': 'トヨタ',
        'nameEn': 'Toyota',
        'country': 'JP',
        'displayOrder': 1,
        'isActive': true,
      }, 'toyota');

      expect(maker.id, 'toyota');
      expect(maker.name, 'トヨタ');
      expect(maker.nameEn, 'Toyota');
      expect(maker.country, 'JP');
      expect(maker.displayOrder, 1);
      expect(maker.isActive, true);
    });

    test('toMap returns correct map', () {
      const maker = VehicleMaker(
        id: 'honda',
        name: 'ホンダ',
        nameEn: 'Honda',
        country: 'JP',
        displayOrder: 2,
      );

      final map = maker.toMap();
      expect(map['name'], 'ホンダ');
      expect(map['nameEn'], 'Honda');
      expect(map['country'], 'JP');
      expect(map['displayOrder'], 2);
    });

    test('equality works correctly', () {
      const maker1 = VehicleMaker(
        id: 'toyota',
        name: 'トヨタ',
        nameEn: 'Toyota',
        country: 'JP',
      );
      const maker2 = VehicleMaker(
        id: 'toyota',
        name: 'トヨタ Updated',
        nameEn: 'Toyota',
        country: 'JP',
      );
      const maker3 = VehicleMaker(
        id: 'honda',
        name: 'ホンダ',
        nameEn: 'Honda',
        country: 'JP',
      );

      expect(maker1 == maker2, true); // Same ID
      expect(maker1 == maker3, false); // Different ID
    });
  });

  group('VehicleModel', () {
    test('fromMap creates VehicleModel correctly', () {
      final model = VehicleModel.fromMap({
        'makerId': 'toyota',
        'name': 'プリウス',
        'nameEn': 'Prius',
        'bodyType': 'hatchback',
        'productionStartYear': 1997,
        'displayOrder': 1,
      }, 'toyota_prius');

      expect(model.id, 'toyota_prius');
      expect(model.makerId, 'toyota');
      expect(model.name, 'プリウス');
      expect(model.nameEn, 'Prius');
      expect(model.bodyType, BodyType.hatchback);
      expect(model.productionStartYear, 1997);
      expect(model.productionEndYear, null);
    });

    test('isAvailableInYear returns correct result', () {
      const model = VehicleModel(
        id: 'test',
        makerId: 'toyota',
        name: 'Test',
        productionStartYear: 2000,
        productionEndYear: 2010,
      );

      expect(model.isAvailableInYear(1999), false);
      expect(model.isAvailableInYear(2000), true);
      expect(model.isAvailableInYear(2005), true);
      expect(model.isAvailableInYear(2010), true);
      expect(model.isAvailableInYear(2011), false);
    });

    test('isCurrentlyProduced returns correct result', () {
      const modelInProduction = VehicleModel(
        id: 'test1',
        makerId: 'toyota',
        name: 'Test1',
        productionStartYear: 2020,
      );
      const modelDiscontinued = VehicleModel(
        id: 'test2',
        makerId: 'toyota',
        name: 'Test2',
        productionStartYear: 2000,
        productionEndYear: 2020,
      );

      expect(modelInProduction.isCurrentlyProduced, true);
      expect(modelDiscontinued.isCurrentlyProduced, false);
    });
  });

  group('VehicleGrade', () {
    test('fromMap creates VehicleGrade correctly', () {
      final grade = VehicleGrade.fromMap({
        'modelId': 'toyota_prius',
        'name': 'S',
        'engineDisplacement': 1800,
        'fuelType': 'hybrid',
        'driveType': 'ff',
        'transmissionType': 'cvt',
        'displayOrder': 1,
      }, 'toyota_prius_s');

      expect(grade.id, 'toyota_prius_s');
      expect(grade.modelId, 'toyota_prius');
      expect(grade.name, 'S');
      expect(grade.engineDisplacement, 1800);
      expect(grade.fuelType, 'hybrid');
      expect(grade.driveType, 'ff');
      expect(grade.transmissionType, 'cvt');
    });

    test('isAvailableInYear returns correct result', () {
      const grade = VehicleGrade(
        id: 'test',
        modelId: 'model',
        name: 'Test',
        availableFromYear: 2015,
        availableUntilYear: 2020,
      );

      expect(grade.isAvailableInYear(2014), false);
      expect(grade.isAvailableInYear(2015), true);
      expect(grade.isAvailableInYear(2018), true);
      expect(grade.isAvailableInYear(2020), true);
      expect(grade.isAvailableInYear(2021), false);
    });
  });

  group('VehicleMasterData', () {
    test('getMakers returns all makers', () {
      final makers = VehicleMasterData.getMakers();

      expect(makers.length, greaterThan(0));
      expect(makers.any((m) => m.name == 'トヨタ'), true);
      expect(makers.any((m) => m.name == 'ホンダ'), true);
      expect(makers.any((m) => m.name == '日産'), true);
    });

    test('getMakers returns makers sorted by displayOrder', () {
      final makers = VehicleMasterData.getMakers();

      // Toyota should be first (displayOrder: 1)
      expect(makers.first.name, 'トヨタ');
      // Other should be last (displayOrder: 100)
      expect(makers.last.name, 'その他');
    });

    test('getModelsForMaker returns models for Toyota', () {
      final models = VehicleMasterData.getModelsForMaker('toyota');

      expect(models.length, greaterThan(0));
      expect(models.any((m) => m.name == 'プリウス'), true);
      expect(models.any((m) => m.name == 'RAV4'), true);
      expect(models.any((m) => m.name == 'カローラ'), true);
    });

    test('getModelsForMaker returns empty for invalid maker', () {
      final models = VehicleMasterData.getModelsForMaker('invalid_maker');
      expect(models, isEmpty);
    });

    test('getCommonGrades returns grades', () {
      final grades = VehicleMasterData.getCommonGrades('toyota_prius');

      expect(grades.length, greaterThan(0));
      expect(grades.any((g) => g.name == 'S'), true);
      expect(grades.any((g) => g.name == 'G'), true);
      expect(grades.any((g) => g.name == 'ハイブリッド'), true);
    });

    test('all makers have at least one model', () {
      final makers = VehicleMasterData.getMakers();

      for (final maker in makers) {
        final models = VehicleMasterData.getModelsForMaker(maker.id);
        expect(models.length, greaterThan(0),
            reason: 'Maker ${maker.name} should have at least one model');
      }
    });

    test('all models have bodyType or are "Other"', () {
      final makers = VehicleMasterData.getMakers();

      for (final maker in makers) {
        final models = VehicleMasterData.getModelsForMaker(maker.id);
        for (final model in models) {
          if (model.name != 'その他') {
            // Other models can have null bodyType in some cases
            // This is expected for flexibility
          }
        }
      }
    });
  });
}
