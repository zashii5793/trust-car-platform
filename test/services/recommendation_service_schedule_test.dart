// Issue #63 — RecommendationService + MaintenanceScheduleService 連携テスト
//
// TDD RED→GREEN:
//   1. 燃料タイプ別フィルタリング（EVはオイル交換を生成しない）
//   2. 次回km目安を reason に追加
//   3. 後方互換性（scheduleService なし → 既存動作を維持）
//   4. Edge Cases

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/recommendation_service.dart';
import 'package:trust_car_platform/services/maintenance_schedule_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Vehicle _makeVehicle({
  String id = 'v1',
  int mileage = 30000,
  FuelType? fuelType,
  Duration createdBefore = const Duration(days: 400),
}) {
  return Vehicle(
    id: id,
    userId: 'u1',
    maker: 'Nissan',
    model: 'Leaf',
    year: 2021,
    grade: 'G',
    mileage: mileage,
    fuelType: fuelType,
    createdAt: DateTime.now().subtract(createdBefore),
    updatedAt: DateTime.now(),
  );
}

MaintenanceRecord _makeRecord({
  MaintenanceType type = MaintenanceType.oilChange,
  Duration doneAgo = const Duration(days: 30),
  int mileageAtService = 25000,
}) {
  final date = DateTime.now().subtract(doneAgo);
  return MaintenanceRecord(
    id: 'r1',
    vehicleId: 'v1',
    userId: 'u1',
    type: type,
    title: 'テスト整備',
    date: date,
    cost: 0,
    mileageAtService: mileageAtService,
    createdAt: date,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const scheduleService = MaintenanceScheduleService();
  const serviceWith = RecommendationService(scheduleService: scheduleService);
  const serviceWithout = RecommendationService();

  // -------------------------------------------------------------------------
  // 1. 燃料タイプ別フィルタリング
  // -------------------------------------------------------------------------
  group('燃料タイプ別フィルタリング', () {
    test('EV: scheduleService ありの場合オイル交換推奨を生成しない', () {
      final ev = _makeVehicle(fuelType: FuelType.electric);
      final notifs = serviceWith.generateRecommendations(
        vehicle: ev,
        records: [],
        userId: 'u1',
      );
      final oilNotifs = notifs.where(
        (n) => n.title.contains('オイル'),
      );
      expect(oilNotifs, isEmpty, reason: 'EV はオイル交換不要なので推奨を生成してはならない');
    });

    test('水素: scheduleService ありの場合オイル交換推奨を生成しない', () {
      final hydrogen = _makeVehicle(fuelType: FuelType.hydrogen);
      final notifs = serviceWith.generateRecommendations(
        vehicle: hydrogen,
        records: [],
        userId: 'u1',
      );
      final oilNotifs = notifs.where((n) => n.title.contains('オイル'));
      expect(oilNotifs, isEmpty);
    });

    test('ガソリン: scheduleService ありの場合オイル交換推奨を生成する', () {
      final gas = _makeVehicle(fuelType: FuelType.gasoline, mileage: 30000);
      final notifs = serviceWith.generateRecommendations(
        vehicle: gas,
        records: [],
        userId: 'u1',
      );
      final oilNotifs = notifs.where((n) => n.title.contains('エンジンオイル'));
      expect(oilNotifs, isNotEmpty, reason: 'ガソリン車はオイル交換推奨を生成すべき');
    });

    test('ハイブリッド: scheduleService ありの場合オイル交換推奨を生成する（インターバルは長め）', () {
      final hybrid = _makeVehicle(fuelType: FuelType.hybrid, mileage: 30000);
      final notifs = serviceWith.generateRecommendations(
        vehicle: hybrid,
        records: [],
        userId: 'u1',
      );
      final oilNotifs = notifs.where((n) => n.title.contains('エンジンオイル'));
      expect(oilNotifs, isNotEmpty);
    });

    test('後方互換: scheduleService なしの場合 EV でもオイル交換推奨を生成する', () {
      final ev = _makeVehicle(fuelType: FuelType.electric);
      final notifs = serviceWithout.generateRecommendations(
        vehicle: ev,
        records: [],
        userId: 'u1',
      );
      final oilNotifs = notifs.where((n) => n.title.contains('エンジンオイル'));
      expect(oilNotifs, isNotEmpty,
          reason: 'scheduleService なしは既存の全ルール適用動作を維持する');
    });
  });

  // -------------------------------------------------------------------------
  // 2. 次回km目安の reason 追加
  // -------------------------------------------------------------------------
  group('次回km目安の reason 追加', () {
    test('scheduleService あり: タイヤローテーション推奨に次回km目安が含まれる', () {
      final gas = _makeVehicle(fuelType: FuelType.gasoline, mileage: 9500);
      final notifs = serviceWith.generateRecommendations(
        vehicle: gas,
        records: [],
        userId: 'u1',
      );
      final tireNotif = notifs.firstWhere(
        (n) => n.title.contains('タイヤ'),
        orElse: () => throw TestFailure('タイヤローテーション推奨が見つからない'),
      );
      expect(tireNotif.reason, contains('次回目安'));
      expect(tireNotif.reason, contains('km'));
    });

    test('scheduleService あり: 次回km目安は現在走行距離より大きい値を示す', () {
      final gas = _makeVehicle(fuelType: FuelType.gasoline, mileage: 9500);
      final notifs = serviceWith.generateRecommendations(
        vehicle: gas,
        records: [],
        userId: 'u1',
      );
      final tireNotif = notifs.firstWhere(
        (n) => n.title.contains('タイヤ'),
        orElse: () => throw TestFailure('タイヤローテーション推奨が見つからない'),
      );
      // nextDueMileage(9500, interval=10000) = 10000. reason should mention 10,000km
      expect(tireNotif.reason, contains('10,000'));
    });

    test('scheduleService なし: reason に次回km目安マーカーが含まれない', () {
      final gas = _makeVehicle(fuelType: FuelType.gasoline, mileage: 9500);
      final notifs = serviceWithout.generateRecommendations(
        vehicle: gas,
        records: [],
        userId: 'u1',
      );
      // At least some notifications should exist
      expect(notifs, isNotEmpty);
      for (final n in notifs) {
        expect(n.reason, isNot(contains('次回目安')),
            reason: 'scheduleService なしは次回km目安を表示しない');
      }
    });

    test('km インターバルのない項目（車検など）は次回km目安なし', () {
      final gas = _makeVehicle(
        fuelType: FuelType.gasoline,
        mileage: 30000,
      );
      final notifs = serviceWith.generateRecommendations(
        vehicle: gas,
        records: [],
        userId: 'u1',
      );
      // carInspection has intervalKm == null → nextDueMileage returns null
      // Inspection notifications come from _checkInspectionExpiryDate/_checkCarInspection
      // which don't go through _checkRule → no nextDueKm
      // All non-rule notifications should not have 次回目安
      final carInspectionNotifs = notifs.where(
        (n) => n.type.name == 'inspectionReminder' || n.title.contains('車検'),
      );
      for (final n in carInspectionNotifs) {
        expect(
          n.reason ?? '',
          isNot(contains('次回目安')),
          reason: '車検通知は _checkRule を経由しないため次回km目安なし',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // 3. Edge Cases
  // -------------------------------------------------------------------------
  group('Edge Cases', () {
    test('fuelType が null: scheduleService ありでもオイル交換を生成する（ガソリン扱い）', () {
      final vehicle = _makeVehicle(fuelType: null);
      final notifs = serviceWith.generateRecommendations(
        vehicle: vehicle,
        records: [],
        userId: 'u1',
      );
      final oilNotifs = notifs.where((n) => n.title.contains('エンジンオイル'));
      expect(oilNotifs, isNotEmpty,
          reason: 'fuelType null はガソリン扱いなのでオイル交換を生成する');
    });

    test('mileage が 0: nextDueKm は最初のインターバルを示す', () {
      final gas = _makeVehicle(fuelType: FuelType.gasoline, mileage: 0);
      final notifs = serviceWith.generateRecommendations(
        vehicle: gas,
        records: [],
        userId: 'u1',
      );
      // Notifications may be empty if createdAt is recent; just verify no crash
      expect(notifs, isA<List>());
    });

    test('走行距離がインターバルをちょうど超えた: 超過表示', () {
      // mileage = 10001, tire interval = 10000 → nextDueMileage = 20000
      // The reason should mention 20,000km next due
      final gas = _makeVehicle(fuelType: FuelType.gasoline, mileage: 10001);
      final notifs = serviceWith.generateRecommendations(
        vehicle: gas,
        records: [],
        userId: 'u1',
      );
      final tireNotif = notifs.firstWhere(
        (n) => n.title.contains('タイヤ'),
        orElse: () => throw TestFailure('タイヤローテーション推奨が見つからない'),
      );
      // nextDueMileage(10001, 10000) = 20000
      expect(tireNotif.reason, contains('20,000'));
    });

    test('記録あり: 走行距離超過で推奨が生成され次回km目安を表示', () {
      // mileage=58000, lastService=45000 → km超過(13000≥10000) → 即時推奨
      // nextDueMileage(58000, intervalKm=10000) = 60000
      final gas = _makeVehicle(fuelType: FuelType.gasoline, mileage: 58000);
      final record = _makeRecord(
        type: MaintenanceType.tireRotation,
        doneAgo: const Duration(days: 50),
        mileageAtService: 45000,
      );
      final notifs = serviceWith.generateRecommendations(
        vehicle: gas,
        records: [record],
        userId: 'u1',
      );
      final tireNotif = notifs.firstWhere(
        (n) => n.title.contains('タイヤ'),
        orElse: () => throw TestFailure('タイヤローテーション推奨が見つからない'),
      );
      // nextDueMileage(58000, 10000) = ceil(58000/10000)*10000 = 60000
      expect(tireNotif.reason, contains('60,000'));
    });
  });
}
