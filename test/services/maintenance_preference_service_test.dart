import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/maintenance_preferences.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/maintenance_preference_service.dart';
import 'package:trust_car_platform/services/maintenance_schedule_service.dart';

Vehicle _vehicle() => Vehicle(
      id: 'v1',
      userId: 'u1',
      maker: 'トヨタ',
      model: 'カローラ',
      year: 2020,
      grade: 'G',
      mileage: 30000,
      fuelType: FuelType.gasoline,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

void main() {
  group('MaintenancePreferences model', () {
    test('withOverride / forType でタイプ別に上書きできる', () {
      var prefs = MaintenancePreferences.empty('v1', 'u1');
      expect(prefs.forType(MaintenanceType.oilChange), isNull);

      prefs = prefs.withOverride(
        MaintenanceType.oilChange,
        const IntervalOverride(intervalKm: 3000, intervalMonths: 4),
      );
      expect(prefs.forType(MaintenanceType.oilChange)?.intervalKm, 3000);
      expect(prefs.forType(MaintenanceType.oilChange)?.intervalMonths, 4);
    });

    test('空の上書きはキーを削除する（標準値に戻す）', () {
      var prefs = MaintenancePreferences.empty('v1', 'u1').withOverride(
        MaintenanceType.oilChange,
        const IntervalOverride(intervalKm: 3000),
      );
      prefs = prefs.withOverride(
          MaintenanceType.oilChange, const IntervalOverride());
      expect(
          prefs.overrides.containsKey(MaintenanceType.oilChange.name), isFalse);
    });
  });

  group('MaintenancePreferenceService', () {
    late FakeFirebaseFirestore fs;
    late MaintenancePreferenceService service;

    setUp(() {
      fs = FakeFirebaseFirestore();
      service = MaintenancePreferenceService(firestore: fs);
    });

    test('未設定なら空の設定を返す', () async {
      final result = await service.getPreferences('v1', 'u1');
      expect(result.isSuccess, true);
      expect(result.valueOrNull!.overrides, isEmpty);
    });

    test('保存→取得で round-trip する', () async {
      final prefs = MaintenancePreferences.empty('v1', 'u1').withOverride(
        MaintenanceType.tireRotation,
        const IntervalOverride(intervalKm: 8000),
      );
      final saveResult = await service.savePreferences(prefs);
      expect(saveResult.isSuccess, true);

      final loaded = await service.getPreferences('v1', 'u1');
      expect(
          loaded.valueOrNull!.forType(MaintenanceType.tireRotation)?.intervalKm,
          8000);
      expect(loaded.valueOrNull!.userId, 'u1');
    });
  });

  group('generateSchedule は preferences を適用する', () {
    const scheduleService = MaintenanceScheduleService();

    test('標準値（上書きなし）はガソリン車でオイル5000km', () {
      final schedule = scheduleService.generateSchedule(_vehicle());
      final oil =
          schedule.firstWhere((s) => s.type == MaintenanceType.oilChange);
      expect(oil.intervalKm, 5000);
      expect(oil.intervalMonths, 6);
    });

    test('上書きありはユーザー値で置き換わる', () {
      final prefs = MaintenancePreferences.empty('v1', 'u1').withOverride(
        MaintenanceType.oilChange,
        const IntervalOverride(intervalKm: 3000, intervalMonths: 3),
      );
      final schedule =
          scheduleService.generateSchedule(_vehicle(), preferences: prefs);
      final oil =
          schedule.firstWhere((s) => s.type == MaintenanceType.oilChange);
      expect(oil.intervalKm, 3000);
      expect(oil.intervalMonths, 3);
    });

    test('片方のみ上書きした場合、他方は標準値を維持する', () {
      final prefs = MaintenancePreferences.empty('v1', 'u1').withOverride(
        MaintenanceType.oilChange,
        const IntervalOverride(intervalKm: 4000),
      );
      final schedule =
          scheduleService.generateSchedule(_vehicle(), preferences: prefs);
      final oil =
          schedule.firstWhere((s) => s.type == MaintenanceType.oilChange);
      expect(oil.intervalKm, 4000);
      expect(oil.intervalMonths, 6); // 標準維持
    });
  });
}
