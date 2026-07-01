// Tests for PdfExportService.generateCarteReport (Issue #64: 愛車カルテ)
//
// The pdf package is pure Dart (no platform channels), so generateCarteReport
// can be called directly.  The mileage-consistency helper is also tested as a
// pure function.
//
// Coverage:
//   1. Returns non-empty Uint8List for various inputs
//   2. Handles null vehicle fields gracefully (VIN, licensePlate, inspection date)
//   3. detectMileageAnomalies: monotone-increase → 0 anomalies
//   4. detectMileageAnomalies: retrograde mileage → detected
//   5. detectMileageAnomalies: records with null mileage are skipped
//   6. Edge cases (empty records, zero cost, very long name, all types)

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/pdf_export_service.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import '../fixtures/test_data.dart';

void main() {
  late PdfExportService service;

  Future<Uint8List> generateCarte({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
  }) async {
    final result = await service.generateCarteReport(
      vehicle: vehicle,
      records: records,
    );
    expect(result.isSuccess, isTrue,
        reason: 'generateCarteReport should succeed');
    return result.valueOrNull!;
  }

  setUp(() {
    service = PdfExportService();
  });

  // ── ヘルパー ──────────────────────────────────────────────────────────────

  /// TestData.makeMaintenanceRecord は mileageAtService が非nullable なので、
  /// null を渡したい場合は MaintenanceRecord コンストラクタを直接使う。
  MaintenanceRecord makeRecord({
    MaintenanceType type = MaintenanceType.oilChange,
    int cost = 5000,
    int? mileageAtService = 30000,
    DateTime? date,
    String? shopName,
  }) {
    final d = date ?? DateTime(2024, 6, 1);
    return MaintenanceRecord(
      id: 'rec-${d.millisecondsSinceEpoch}',
      vehicleId: 'vehicle-001',
      userId: 'user-001',
      type: type,
      title: type.displayName,
      date: d,
      cost: cost,
      mileageAtService: mileageAtService,
      shopName: shopName,
      createdAt: d,
    );
  }

  // ── generateCarteReport 基本動作 ──────────────────────────────────────────

  group('generateCarteReport 基本動作', () {
    test('空記録でも非空のPDFバイトを返す', () async {
      final vehicle = TestData.makeVehicle();
      final bytes = await generateCarte(vehicle: vehicle, records: []);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('単一記録で非空のPDFバイトを返す', () async {
      final vehicle = TestData.makeVehicle();
      final records = [makeRecord(cost: 3000)];
      final bytes = await generateCarte(vehicle: vehicle, records: records);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('複数記録で非空のPDFバイトを返す', () async {
      final vehicle = TestData.makeVehicle();
      final records = [
        makeRecord(date: DateTime(2024, 1, 1), cost: 1000),
        makeRecord(
            date: DateTime(2024, 3, 1),
            cost: 2000,
            type: MaintenanceType.tireChange),
        makeRecord(
            date: DateTime(2024, 6, 1),
            cost: 5000,
            type: MaintenanceType.legalInspection24),
      ];
      final bytes = await generateCarte(vehicle: vehicle, records: records);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('Resultは成功を返す', () async {
      final vehicle = TestData.makeVehicle();
      final result = await service.generateCarteReport(
        vehicle: vehicle,
        records: [],
      );
      expect(result.isSuccess, isTrue);
    });
  });

  // ── 車両詳細情報のnullフィールド ─────────────────────────────────────────

  group('車両詳細情報（nullフィールド対応）', () {
    test('車台番号なしで正常生成', () async {
      final vehicle = TestData.makeVehicle(vinNumber: null);
      final bytes = await generateCarte(vehicle: vehicle, records: []);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('車台番号ありで正常生成', () async {
      final vehicle = TestData.makeVehicle(vinNumber: 'ZZZ000000A0000000');
      final bytes = await generateCarte(vehicle: vehicle, records: []);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('ナンバープレートなしで正常生成', () async {
      final vehicle = TestData.makeVehicle(licensePlate: null);
      final bytes = await generateCarte(vehicle: vehicle, records: []);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('ナンバープレートありで正常生成', () async {
      final vehicle = TestData.makeVehicle(licensePlate: '品川 500 あ 1234');
      final bytes = await generateCarte(vehicle: vehicle, records: []);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('車検満了日なしで正常生成', () async {
      final vehicle = TestData.makeVehicle(inspectionExpiryDate: null);
      final bytes = await generateCarte(vehicle: vehicle, records: []);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('車検満了日ありで正常生成', () async {
      final vehicle = TestData.makeVehicle(
        inspectionExpiryDate: DateTime(2025, 11, 30),
      );
      final bytes = await generateCarte(vehicle: vehicle, records: []);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('自賠責保険満期日なしで正常生成', () async {
      final vehicle = TestData.makeVehicle(insuranceExpiryDate: null);
      final bytes = await generateCarte(vehicle: vehicle, records: []);
      expect(bytes.isNotEmpty, isTrue);
    });
  });

  // ── detectMileageAnomalies ────────────────────────────────────────────────

  group('detectMileageAnomalies（走行距離一貫性チェック）', () {
    test('空リストは異常0件', () {
      expect(service.detectMileageAnomalies([]), equals(0));
    });

    test('走行距離なし1件は異常0件', () {
      final records = [makeRecord(mileageAtService: null)];
      expect(service.detectMileageAnomalies(records), equals(0));
    });

    test('単調増加の記録は異常0件', () {
      final records = [
        makeRecord(date: DateTime(2023, 1, 1), mileageAtService: 10000),
        makeRecord(date: DateTime(2023, 6, 1), mileageAtService: 15000),
        makeRecord(date: DateTime(2024, 1, 1), mileageAtService: 22000),
      ];
      expect(service.detectMileageAnomalies(records), equals(0));
    });

    test('走行距離逆行を1件検出する', () {
      final records = [
        makeRecord(date: DateTime(2023, 1, 1), mileageAtService: 10000),
        makeRecord(date: DateTime(2023, 6, 1), mileageAtService: 9000), // 逆行
        makeRecord(date: DateTime(2024, 1, 1), mileageAtService: 12000),
      ];
      expect(service.detectMileageAnomalies(records), equals(1));
    });

    test('走行距離逆行を複数件検出する', () {
      final records = [
        makeRecord(date: DateTime(2023, 1, 1), mileageAtService: 10000),
        makeRecord(date: DateTime(2023, 4, 1), mileageAtService: 8000), // 逆行
        makeRecord(date: DateTime(2023, 8, 1), mileageAtService: 7000), // 逆行
        makeRecord(date: DateTime(2024, 1, 1), mileageAtService: 20000),
      ];
      expect(service.detectMileageAnomalies(records), equals(2));
    });

    test('走行距離nullのレコードをスキップして残りを正常に検証', () {
      final records = [
        makeRecord(date: DateTime(2023, 1, 1), mileageAtService: 10000),
        makeRecord(date: DateTime(2023, 4, 1), mileageAtService: null), // スキップ
        makeRecord(date: DateTime(2023, 8, 1), mileageAtService: 15000),
      ];
      expect(service.detectMileageAnomalies(records), equals(0));
    });

    test('同一日付の記録は順番不問で異常なし', () {
      // 同日複数施工（車検+油交換）は走行距離が同値で正常
      final records = [
        makeRecord(date: DateTime(2024, 1, 1), mileageAtService: 30000),
        makeRecord(date: DateTime(2024, 1, 1), mileageAtService: 30000),
      ];
      expect(service.detectMileageAnomalies(records), equals(0));
    });
  });

  // ── Edge Cases ────────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('費用0円の記録を正常に処理する', () async {
      final vehicle = TestData.makeVehicle();
      final records = [makeRecord(cost: 0)];
      final bytes = await generateCarte(vehicle: vehicle, records: records);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('非常に長い車種名でも正常生成', () async {
      final vehicle = TestData.makeVehicle(
        maker: 'A' * 50,
        model: 'B' * 50,
      );
      final bytes = await generateCarte(vehicle: vehicle, records: []);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('走行距離が極端に大きい（999,999km）でも正常生成', () async {
      final vehicle = TestData.makeVehicle(mileage: 999999);
      final records = [
        makeRecord(mileageAtService: 999999, cost: 50000),
      ];
      final bytes = await generateCarte(vehicle: vehicle, records: records);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('全メンテナンスタイプを含む場合', () async {
      final vehicle = TestData.makeVehicle();
      final records = [
        makeRecord(type: MaintenanceType.oilChange, cost: 3000),
        makeRecord(type: MaintenanceType.tireChange, cost: 40000),
        makeRecord(type: MaintenanceType.batteryChange, cost: 15000),
        makeRecord(type: MaintenanceType.legalInspection24, cost: 80000),
        makeRecord(type: MaintenanceType.brakeFluidChange, cost: 5000),
      ];
      final bytes = await generateCarte(vehicle: vehicle, records: records);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('工場名つき記録を正常に処理する', () async {
      final vehicle = TestData.makeVehicle();
      final records = [
        makeRecord(shopName: 'トヨタ販売店 渋谷', cost: 5000),
        makeRecord(shopName: null, cost: 3000),
      ];
      final bytes = await generateCarte(vehicle: vehicle, records: records);
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
