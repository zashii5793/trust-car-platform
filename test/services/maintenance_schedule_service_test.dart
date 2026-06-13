// MaintenanceScheduleService Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/services/maintenance_schedule_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Vehicle _makeVehicle({
  FuelType? fuelType,
  int mileage = 10000,
}) =>
    Vehicle(
      id: 'v1',
      userId: 'u1',
      maker: 'トヨタ',
      model: 'プリウス',
      year: 2020,
      grade: 'S',
      mileage: mileage,
      fuelType: fuelType,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MaintenanceScheduleService service;

  setUp(() {
    service = const MaintenanceScheduleService();
  });

  group('MaintenanceScheduleService', () {
    group('generateSchedule', () {
      test('ガソリン車でオイル交換が含まれる', () {
        final vehicle = _makeVehicle(fuelType: FuelType.gasoline);
        final schedule = service.generateSchedule(vehicle);
        expect(
            schedule.map((s) => s.type), contains(MaintenanceType.oilChange));
      });

      test('EV車でオイル交換が含まれない', () {
        final vehicle = _makeVehicle(fuelType: FuelType.electric);
        final schedule = service.generateSchedule(vehicle);
        expect(schedule.map((s) => s.type),
            isNot(contains(MaintenanceType.oilChange)));
      });

      test('水素車でオイル交換が含まれない', () {
        final vehicle = _makeVehicle(fuelType: FuelType.hydrogen);
        final schedule = service.generateSchedule(vehicle);
        expect(schedule.map((s) => s.type),
            isNot(contains(MaintenanceType.oilChange)));
      });

      test('全燃料タイプで車検が含まれる', () {
        for (final fuel in FuelType.values) {
          final vehicle = _makeVehicle(fuelType: fuel);
          final schedule = service.generateSchedule(vehicle);
          expect(
            schedule.map((s) => s.type),
            contains(MaintenanceType.carInspection),
            reason: '$fuel 車には車検が必要',
          );
        }
      });

      test('全燃料タイプで12ヶ月点検が含まれる', () {
        final vehicle = _makeVehicle(fuelType: FuelType.gasoline);
        final schedule = service.generateSchedule(vehicle);
        expect(schedule.map((s) => s.type),
            contains(MaintenanceType.legalInspection12));
      });

      test('fuelTypeがnullの場合でも標準スケジュールを返す', () {
        final vehicle = _makeVehicle(fuelType: null);
        final schedule = service.generateSchedule(vehicle);
        expect(schedule, isNotEmpty);
        expect(schedule.map((s) => s.type),
            contains(MaintenanceType.carInspection));
      });

      test('ハイブリッド車でオイル交換インターバルがガソリン車より長い', () {
        final hybrid = _makeVehicle(fuelType: FuelType.hybrid);
        final gasoline = _makeVehicle(fuelType: FuelType.gasoline);

        final hybridSchedule = service.generateSchedule(hybrid);
        final gasolineSchedule = service.generateSchedule(gasoline);

        final hybridOil = hybridSchedule
            .firstWhere((s) => s.type == MaintenanceType.oilChange);
        final gasolineOil = gasolineSchedule
            .firstWhere((s) => s.type == MaintenanceType.oilChange);

        expect(hybridOil.intervalKm! >= gasolineOil.intervalKm!, isTrue);
      });

      test('ディーゼル車でオイル交換月次インターバルがガソリン車より短い', () {
        final diesel = _makeVehicle(fuelType: FuelType.diesel);
        final gasoline = _makeVehicle(fuelType: FuelType.gasoline);

        final dieselOil = service
            .generateSchedule(diesel)
            .firstWhere((s) => s.type == MaintenanceType.oilChange);
        final gasolineOil = service
            .generateSchedule(gasoline)
            .firstWhere((s) => s.type == MaintenanceType.oilChange);

        expect(
            dieselOil.intervalMonths! <= gasolineOil.intervalMonths!, isTrue);
      });

      test('各アイテムにintervalKmかintervalMonthsが少なくとも一方ある', () {
        final vehicle = _makeVehicle(fuelType: FuelType.gasoline);
        final schedule = service.generateSchedule(vehicle);
        for (final item in schedule) {
          expect(
            item.intervalKm != null || item.intervalMonths != null,
            isTrue,
            reason: '${item.type.displayName} にはインターバル指定が必要',
          );
        }
      });

      test('各アイテムのdescriptionが空でない', () {
        final vehicle = _makeVehicle(fuelType: FuelType.gasoline);
        for (final item in service.generateSchedule(vehicle)) {
          expect(item.description, isNotEmpty,
              reason: '${item.type.displayName} のdescriptionが空');
        }
      });

      test('スケジュールに重複するMaintenanceTypeがない', () {
        final vehicle = _makeVehicle(fuelType: FuelType.gasoline);
        final schedule = service.generateSchedule(vehicle);
        final types = schedule.map((s) => s.type).toList();
        expect(types.toSet().length, types.length, reason: '重複するメンテナンスタイプがある');
      });
    });

    group('nextDueMileage', () {
      test('ガソリン車オイル交換の次回走行距離が現在走行距離より大きい', () {
        final vehicle =
            _makeVehicle(fuelType: FuelType.gasoline, mileage: 10000);
        final schedule = service.generateSchedule(vehicle);
        final oilChange =
            schedule.firstWhere((s) => s.type == MaintenanceType.oilChange);
        final next = service.nextDueMileage(vehicle, oilChange);
        expect(next, isNotNull);
        expect(next! >= vehicle.mileage, isTrue);
      });

      test('intervalKmがnullのアイテムはnullを返す', () {
        final vehicle = _makeVehicle(fuelType: FuelType.gasoline);
        const item = ScheduledMaintenance(
          type: MaintenanceType.carInspection,
          intervalMonths: 24,
          description: '車検',
        );
        expect(service.nextDueMileage(vehicle, item), isNull);
      });

      test('走行距離ちょうどのとき次回距離がintervalKmの倍数', () {
        final vehicle = _makeVehicle(mileage: 15000);
        const item = ScheduledMaintenance(
          type: MaintenanceType.oilChange,
          intervalKm: 5000,
          intervalMonths: 6,
          description: 'テスト',
        );
        final next = service.nextDueMileage(vehicle, item);
        expect(next, isNotNull);
        expect(next! % 5000, 0);
      });
    });

    group('PHEVとハイブリッドは同等スケジュール', () {
      test('PHEV はハイブリッドと同じオイル交換タイプを持つ', () {
        final phev = _makeVehicle(fuelType: FuelType.phev);
        final hybrid = _makeVehicle(fuelType: FuelType.hybrid);

        expect(
          service.generateSchedule(phev).map((s) => s.type).toSet(),
          equals(service.generateSchedule(hybrid).map((s) => s.type).toSet()),
        );
      });
    });

    group('Edge Cases', () {
      test('走行距離0でも正常に動作する', () {
        final vehicle = _makeVehicle(mileage: 0);
        final schedule = service.generateSchedule(vehicle);
        expect(schedule, isNotEmpty);
      });

      test('高走行距離車（200,000km）でも正常に動作する', () {
        final vehicle = _makeVehicle(mileage: 200000);
        final schedule = service.generateSchedule(vehicle);
        expect(schedule, isNotEmpty);
      });

      test('車検インターバルは24ヶ月', () {
        final vehicle = _makeVehicle(fuelType: FuelType.gasoline);
        final inspection = service
            .generateSchedule(vehicle)
            .firstWhere((s) => s.type == MaintenanceType.carInspection);
        expect(inspection.intervalMonths, 24);
      });

      test('12ヶ月点検インターバルは12ヶ月', () {
        final vehicle = _makeVehicle(fuelType: FuelType.gasoline);
        final legal12 = service
            .generateSchedule(vehicle)
            .firstWhere((s) => s.type == MaintenanceType.legalInspection12);
        expect(legal12.intervalMonths, 12);
      });
    });
  });
}
