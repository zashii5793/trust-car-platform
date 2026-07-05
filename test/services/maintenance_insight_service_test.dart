// MaintenanceInsightService Unit Tests
//
// Pure logic — no Firebase, no mocks needed.
//
// Coverage:
//   1. 意味分類（baseline / onTime / late / informational）
//   2. 法定点検は informational（timing 判定しない）
//   3. 資産メモ（assetNote）
//   4. 「断言しない」不変条件（断定語の禁止・理由必須）
//   5. Edge Cases（ルール外 null / mileage null / 別車両の履歴無視）

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/services/maintenance_insight_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _baseDate = DateTime(2026, 6, 7);

Vehicle _makeVehicle({
  FuelType? fuelType = FuelType.gasoline,
  int mileage = 30000,
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

MaintenanceRecord _makeRecord({
  String id = 'r1',
  String vehicleId = 'v1',
  String userId = 'u1',
  MaintenanceType type = MaintenanceType.oilChange,
  String title = 'オイル交換',
  required DateTime date,
  int? mileageAtService,
}) =>
    MaintenanceRecord(
      id: id,
      vehicleId: vehicleId,
      userId: userId,
      type: type,
      title: title,
      cost: 3500,
      date: date,
      mileageAtService: mileageAtService,
      createdAt: date,
    );

void main() {
  late MaintenanceInsightService service;

  setUp(() {
    service = MaintenanceInsightService();
  });

  // ==========================================================================
  // Group 1: 意味分類
  // ==========================================================================
  group('意味分類', () {
    test('1件目（履歴なし）→ baseline / 意味と次の目安が返る', () {
      final record = _makeRecord(date: _baseDate, mileageAtService: 30000);

      final insight = service.explain(
        record: record,
        vehicle: _makeVehicle(),
        allRecords: [record],
        currentMileage: 30000,
      );

      expect(insight, isNotNull);
      expect(insight!.meaning, InsightMeaning.baseline);
      // 1件目でも「意味」が返る（空箱でない）
      expect(insight.reasons, isNotEmpty);
      expect(insight.nextStep, isNotNull);
      expect(insight.knowledge, isNotNull);
    });

    test('前回から5ヶ月・4,500km → onTime', () {
      final prev = _makeRecord(
        id: 'r0',
        date: _baseDate.subtract(const Duration(days: 150)),
        mileageAtService: 25500,
      );
      final record = _makeRecord(date: _baseDate, mileageAtService: 30000);

      final insight = service.explain(
        record: record,
        vehicle: _makeVehicle(),
        allRecords: [prev, record],
        currentMileage: 30000,
      );

      expect(insight, isNotNull);
      expect(insight!.meaning, InsightMeaning.onTime);
    });

    test('前回から10ヶ月・8,000km → late / リスク説明が理由に含まれる', () {
      final prev = _makeRecord(
        id: 'r0',
        date: _baseDate.subtract(const Duration(days: 300)),
        mileageAtService: 22000,
      );
      final record = _makeRecord(date: _baseDate, mileageAtService: 30000);

      final insight = service.explain(
        record: record,
        vehicle: _makeVehicle(),
        allRecords: [prev, record],
        currentMileage: 30000,
      );

      expect(insight, isNotNull);
      expect(insight!.meaning, InsightMeaning.overdue);
      // 遅れの場合は放置リスクの説明を添える
      expect(
        insight.reasons.any((r) => r.contains('言われています')),
        isTrue,
      );
    });
  });

  // ==========================================================================
  // Group 2: 法定点検は informational
  // ==========================================================================
  group('法定点検 / 車検', () {
    test('車検 → informational（timing 判定しない）', () {
      final record = _makeRecord(
        type: MaintenanceType.carInspection,
        title: '車検',
        date: _baseDate,
        mileageAtService: 30000,
      );

      final insight = service.explain(
        record: record,
        vehicle: _makeVehicle(),
        allRecords: [record],
        currentMileage: 30000,
      );

      expect(insight, isNotNull);
      expect(insight!.meaning, InsightMeaning.informational);
      expect(insight.headline, contains('法律'));
    });
  });

  // ==========================================================================
  // Group 3: 資産メモ
  // ==========================================================================
  group('資産メモ', () {
    test('通常の整備 → assetNote が返る', () {
      final record = _makeRecord(date: _baseDate, mileageAtService: 30000);

      final insight = service.explain(
        record: record,
        vehicle: _makeVehicle(),
        allRecords: [record],
        currentMileage: 30000,
      );

      expect(insight, isNotNull);
      expect(insight!.assetNote, isNotNull);
      expect(insight.assetNote, contains('記録'));
    });
  });

  // ==========================================================================
  // Group 4: 「断言しない」不変条件
  // ==========================================================================
  group('断言しない不変条件', () {
    // 断定・命令・不安を煽る語は使わない
    const forbidden = ['必ず', '絶対', '危険です', 'してください', '故障します'];

    final ruledSamples = <MaintenanceType>[
      MaintenanceType.oilChange,
      MaintenanceType.tireChange,
      MaintenanceType.batteryChange,
      MaintenanceType.brakePadChange,
      MaintenanceType.carInspection,
    ];

    for (final type in ruledSamples) {
      test('$type: 断定語を含まない & 理由が必ず添えられる', () {
        final record = _makeRecord(
          type: type,
          title: type.displayName,
          date: _baseDate,
          mileageAtService: 30000,
        );

        final insight = service.explain(
          record: record,
          vehicle: _makeVehicle(),
          allRecords: [record],
          currentMileage: 30000,
        );

        expect(insight, isNotNull);

        final text = [insight!.headline, ...insight.reasons].join(' ');
        for (final word in forbidden) {
          expect(text, isNot(contains(word)),
              reason: '$type の解説に断定語「$word」が含まれている');
        }

        // 理由（根拠）が必ず添えられている
        expect(insight.reasons, isNotEmpty);
        // 次の一手 or 情報提供のいずれかで、片方向の断言に閉じない
        expect(
          insight.nextStep != null ||
              insight.meaning == InsightMeaning.informational,
          isTrue,
        );
      });
    }
  });

  // ==========================================================================
  // Group 5: Edge Cases
  // ==========================================================================
  group('Edge Cases', () {
    test('ルールも知識も無いタイプ（洗車）→ null', () {
      final record = _makeRecord(
        type: MaintenanceType.washing,
        title: '洗車',
        date: _baseDate,
        mileageAtService: 30000,
      );

      final insight = service.explain(
        record: record,
        vehicle: _makeVehicle(),
        allRecords: [record],
        currentMileage: 30000,
      );

      expect(insight, isNull);
    });

    test('mileageAtService が null でも crash しない', () {
      final record = _makeRecord(date: _baseDate, mileageAtService: null);

      expect(
        () => service.explain(
          record: record,
          vehicle: _makeVehicle(),
          allRecords: [record],
          currentMileage: 0,
        ),
        returnsNormally,
      );
    });

    test('別車両（vehicleId 違い）の履歴は前回に使われない → baseline', () {
      final otherVehiclePrev = _makeRecord(
        id: 'r_other',
        vehicleId: 'v2',
        date: _baseDate.subtract(const Duration(days: 150)),
        mileageAtService: 25000,
      );
      final record = _makeRecord(
        id: 'r1',
        vehicleId: 'v1',
        date: _baseDate,
        mileageAtService: 30000,
      );

      final insight = service.explain(
        record: record,
        vehicle: _makeVehicle(),
        allRecords: [otherVehiclePrev, record],
        currentMileage: 30000,
      );

      expect(insight, isNotNull);
      expect(insight!.meaning, InsightMeaning.baseline);
    });
  });
}
