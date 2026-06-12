// FleetService Unit Tests
//
// Tests fleet vehicle querying, stats calculation, and vehicle linking.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/fleet_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Vehicle _makeVehicle({
  String id = 'v1',
  String userId = 'u1',
  String? companyId,
  DateTime? inspectionExpiryDate,
  DateTime? leaseContractEndDate,
  String maker = 'トヨタ',
  String model = 'プリウス',
}) =>
    Vehicle(
      id: id,
      userId: userId,
      companyId: companyId,
      maker: maker,
      model: model,
      year: 2022,
      grade: 'S',
      mileage: 30000,
      inspectionExpiryDate: inspectionExpiryDate,
      leaseInfo: leaseContractEndDate != null
          ? LeaseInfo(contractEndDate: leaseContractEndDate)
          : null,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

Future<void> _seedVehicle(
    FakeFirebaseFirestore fakeFirestore, Vehicle vehicle) async {
  await fakeFirestore
      .collection('vehicles')
      .doc(vehicle.id)
      .set(vehicle.toMap());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FleetService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = FleetService(firestore: fakeFirestore);
  });

  // ── getCompanyVehicles ───────────────────────────────────────────────────

  group('FleetService.getCompanyVehicles', () {
    test('指定 companyId の車両を返す', () async {
      await _seedVehicle(
          fakeFirestore, _makeVehicle(id: 'v1', companyId: 'company-A'));
      await _seedVehicle(
          fakeFirestore, _makeVehicle(id: 'v2', companyId: 'company-A'));
      await _seedVehicle(
          fakeFirestore, _makeVehicle(id: 'v3', companyId: 'company-B'));

      final stream = service.getCompanyVehicles('company-A');
      final vehicles = await stream.first;

      expect(vehicles.map((v) => v.id), containsAll(['v1', 'v2']));
      expect(vehicles.map((v) => v.id), isNot(contains('v3')));
    });

    test('一致する車両がない → 空リスト', () async {
      await _seedVehicle(
          fakeFirestore, _makeVehicle(id: 'v1', companyId: 'other'));

      final stream = service.getCompanyVehicles('company-A');
      final vehicles = await stream.first;

      expect(vehicles, isEmpty);
    });

    test('空の companyId → 空リスト', () async {
      await _seedVehicle(
          fakeFirestore, _makeVehicle(id: 'v1', companyId: 'company-A'));

      final stream = service.getCompanyVehicles('');
      final vehicles = await stream.first;

      expect(vehicles, isEmpty);
    });

    test('companyId が null の車両は返さない', () async {
      await _seedVehicle(fakeFirestore, _makeVehicle(id: 'v1', companyId: null));

      final stream = service.getCompanyVehicles('company-A');
      final vehicles = await stream.first;

      expect(vehicles, isEmpty);
    });
  });

  // ── getFleetStats ────────────────────────────────────────────────────────

  group('FleetService.getFleetStats', () {
    test('緊急度別の台数を正しく集計する', () async {
      final now = DateTime.now();
      // critical: ≤7日
      await _seedVehicle(
          fakeFirestore,
          _makeVehicle(
              id: 'v1',
              companyId: 'company-A',
              inspectionExpiryDate: now.add(const Duration(days: 5))));
      // warning: ≤30日
      await _seedVehicle(
          fakeFirestore,
          _makeVehicle(
              id: 'v2',
              companyId: 'company-A',
              inspectionExpiryDate: now.add(const Duration(days: 20))));
      // normal: 期限なし
      await _seedVehicle(
          fakeFirestore, _makeVehicle(id: 'v3', companyId: 'company-A'));

      final result = await service.getFleetStats('company-A');

      result.when(
        success: (stats) {
          expect(stats.total, 3);
          expect(stats.critical, 1);
          expect(stats.warning, 1);
          expect(stats.normal, 1);
        },
        failure: (e) => fail('Expected success but got failure: $e'),
      );
    });

    test('車両なし → すべて0', () async {
      final result = await service.getFleetStats('company-A');

      result.when(
        success: (stats) {
          expect(stats.total, 0);
          expect(stats.critical, 0);
          expect(stats.warning, 0);
          expect(stats.normal, 0);
        },
        failure: (e) => fail('Expected success but got failure: $e'),
      );
    });
  });

  // ── linkVehicleToCompany ─────────────────────────────────────────────────

  group('FleetService.linkVehicleToCompany', () {
    test('車両に companyId を設定できる', () async {
      await _seedVehicle(fakeFirestore, _makeVehicle(id: 'v1'));

      final result =
          await service.linkVehicleToCompany('v1', 'company-A', 'u1');

      expect(result, isA<Success>());
      final doc =
          await fakeFirestore.collection('vehicles').doc('v1').get();
      expect(doc.data()?['companyId'], 'company-A');
    });

    test('存在しない vehicleId → notFound エラー', () async {
      final result = await service.linkVehicleToCompany(
          'nonexistent', 'company-A', 'u1');

      result.when(
        success: (_) => fail('Expected failure'),
        failure: (e) => expect(e, isA<AppError>()),
      );
    });

    test('他ユーザーの車両は変更不可', () async {
      await _seedVehicle(
          fakeFirestore, _makeVehicle(id: 'v1', userId: 'other-user'));

      final result =
          await service.linkVehicleToCompany('v1', 'company-A', 'u1');

      result.when(
        success: (_) => fail('Expected failure'),
        failure: (e) => expect(e, isA<PermissionError>()),
      );
    });
  });

  // ── FleetStats ───────────────────────────────────────────────────────────

  group('FleetStats', () {
    test('urgencyRatio が正しく計算される', () {
      final stats =
          FleetStats(total: 10, critical: 2, warning: 3, normal: 5);
      expect(stats.urgencyRatio, closeTo(0.2, 0.001));
    });

    test('total が 0 のとき urgencyRatio は 0', () {
      final stats =
          FleetStats(total: 0, critical: 0, warning: 0, normal: 0);
      expect(stats.urgencyRatio, 0.0);
    });
  });

  // ── joinFleetByCode ──────────────────────────────────────────────────────

  group('FleetService.joinFleetByCode', () {
    test('正常系: 車両にフリートコードを設定できる', () async {
      await _seedVehicle(fakeFirestore, _makeVehicle(id: 'v1', userId: 'u1'));

      final result = await service.joinFleetByCode('fleet-owner-uid', 'v1', 'u1');
      expect(result, isA<Success>());
      final doc = await fakeFirestore.collection('vehicles').doc('v1').get();
      expect(doc.data()?['companyId'], 'fleet-owner-uid');
    });

    test('空のフリートコード → validation エラー', () async {
      await _seedVehicle(fakeFirestore, _makeVehicle(id: 'v1'));
      final result = await service.joinFleetByCode('', 'v1', 'u1');
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (e) => expect(e, isA<AppError>()),
      );
    });

    test('空白のみのフリートコード → validation エラー', () async {
      await _seedVehicle(fakeFirestore, _makeVehicle(id: 'v1'));
      final result = await service.joinFleetByCode('   ', 'v1', 'u1');
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (e) => expect(e, isA<AppError>()),
      );
    });

    test('他ユーザーの車両には参加できない', () async {
      await _seedVehicle(
          fakeFirestore, _makeVehicle(id: 'v1', userId: 'other-user'));
      final result =
          await service.joinFleetByCode('fleet-owner-uid', 'v1', 'u1');
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (e) => expect(e, isA<PermissionError>()),
      );
    });
  });

  // ── leaveFleet ───────────────────────────────────────────────────────────

  group('FleetService.leaveFleet', () {
    test('車両の companyId をクリアできる', () async {
      await _seedVehicle(
          fakeFirestore, _makeVehicle(id: 'v1', companyId: 'company-A'));
      final result = await service.leaveFleet('v1', 'u1');
      expect(result, isA<Success>());
      final doc = await fakeFirestore.collection('vehicles').doc('v1').get();
      expect(doc.data()?['companyId'], isNull);
    });

    test('他ユーザーの車両からは離脱できない', () async {
      await _seedVehicle(fakeFirestore,
          _makeVehicle(id: 'v1', userId: 'other-user', companyId: 'company-A'));
      final result = await service.leaveFleet('v1', 'u1');
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (e) => expect(e, isA<PermissionError>()),
      );
    });
  });

  // ── assignVehicle ─────────────────────────────────────────────────────────

  group('FleetService.assignVehicle', () {
    test('担当者を設定できる', () async {
      await _seedVehicle(fakeFirestore,
          _makeVehicle(id: 'v1', userId: 'staff', companyId: 'manager-uid'));
      final result = await service.assignVehicle(
          'v1', 'staff-123', '田中太郎', 'manager-uid');
      expect(result, isA<Success>());
      final doc = await fakeFirestore.collection('vehicles').doc('v1').get();
      expect(doc.data()?['assigneeId'], 'staff-123');
      expect(doc.data()?['assigneeName'], '田中太郎');
    });

    test('空の assigneeId はnullとして保存される', () async {
      await _seedVehicle(fakeFirestore,
          _makeVehicle(id: 'v1', userId: 'staff', companyId: 'manager-uid'));
      final result =
          await service.assignVehicle('v1', '', '', 'manager-uid');
      expect(result, isA<Success>());
      final doc = await fakeFirestore.collection('vehicles').doc('v1').get();
      expect(doc.data()?['assigneeId'], isNull);
    });

    test('フリートオーナー以外は担当者を設定できない', () async {
      await _seedVehicle(fakeFirestore,
          _makeVehicle(id: 'v1', userId: 'staff', companyId: 'manager-uid'));
      final result =
          await service.assignVehicle('v1', 'staff-123', '田中太郎', 'other-uid');
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (e) => expect(e, isA<PermissionError>()),
      );
    });

    test('存在しない vehicleId → notFound エラー', () async {
      final result = await service.assignVehicle(
          'nonexistent', 'staff-123', '田中太郎', 'manager-uid');
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (e) => expect(e, isA<AppError>()),
      );
    });
  });

  // ── Edge Cases ───────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('車検切れ車両は critical としてカウントされる', () async {
      final now = DateTime.now();
      await _seedVehicle(
          fakeFirestore,
          _makeVehicle(
              id: 'v1',
              companyId: 'company-A',
              inspectionExpiryDate: now.subtract(const Duration(days: 5))));

      final result = await service.getFleetStats('company-A');
      result.when(
        success: (stats) => expect(stats.critical, 1),
        failure: (e) => fail(e.toString()),
      );
    });

    test('100台の車両でも正しく集計できる', () async {
      for (var i = 0; i < 100; i++) {
        await _seedVehicle(
            fakeFirestore,
            _makeVehicle(id: 'v$i', companyId: 'company-A'));
      }
      final stream = service.getCompanyVehicles('company-A');
      final vehicles = await stream.first;
      expect(vehicles.length, 100);
    });
  });
}
