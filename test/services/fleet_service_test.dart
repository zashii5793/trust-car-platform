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
      await _seedVehicle(
          fakeFirestore, _makeVehicle(id: 'v1', companyId: null));

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

    group('Edge Cases', () {
      test('しきい値の境界で緊急度が切り替わる（0/7/8/30/31日・期限切れ）', () async {
        final now = DateTime.now();
        // Buckets mirror inspectionUrgencyForDays:
        //   critical: overdue, day 0, and day 7
        //   warning:  day 8 and day 30
        //   normal:   day 31 and beyond
        final cases = <String, int>{
          'overdue': -3, // critical
          'today': 0, // critical
          'day7': 7, // critical
          'day8': 8, // warning
          'day30': 30, // warning
          'day31': 31, // normal
        };
        for (final entry in cases.entries) {
          await _seedVehicle(
            fakeFirestore,
            _makeVehicle(
              id: entry.key,
              companyId: 'company-B',
              // Days are counted date to date (2026-10-09), so pin the
              // calendar day; the hour no longer matters.
              inspectionExpiryDate:
                  DateTime(now.year, now.month, now.day + entry.value, 12),
            ),
          );
        }

        final result = await service.getFleetStats('company-B');

        result.when(
          success: (stats) {
            expect(stats.total, 6);
            expect(stats.critical, 3); // overdue, day0, day7
            expect(stats.warning, 2); // day8, day30
            expect(stats.normal, 1); // day31
          },
          failure: (e) => fail('Expected success but got failure: $e'),
        );
      });
    });
  });

  // ── linkVehicleToCompany ─────────────────────────────────────────────────

  group('FleetService.linkVehicleToCompany', () {
    test('車両に companyId を設定できる', () async {
      await _seedVehicle(fakeFirestore, _makeVehicle(id: 'v1'));

      final result =
          await service.linkVehicleToCompany('v1', 'company-A', 'u1');

      expect(result, isA<Success>());
      final doc = await fakeFirestore.collection('vehicles').doc('v1').get();
      expect(doc.data()?['companyId'], 'company-A');
    });

    test('存在しない vehicleId → notFound エラー', () async {
      final result =
          await service.linkVehicleToCompany('nonexistent', 'company-A', 'u1');

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
      final stats = FleetStats(total: 10, critical: 2, warning: 3, normal: 5);
      expect(stats.urgencyRatio, closeTo(0.2, 0.001));
    });

    test('total が 0 のとき urgencyRatio は 0', () {
      final stats = FleetStats(total: 0, critical: 0, warning: 0, normal: 0);
      expect(stats.urgencyRatio, 0.0);
    });
  });

  // ── joinFleetByCode ──────────────────────────────────────────────────────

  group('FleetService.joinFleetByCode', () {
    test('正常系: 車両にフリートコードを設定できる', () async {
      await _seedVehicle(fakeFirestore, _makeVehicle(id: 'v1', userId: 'u1'));

      final result =
          await service.joinFleetByCode('fleet-owner-uid', 'v1', 'u1');
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
      final result =
          await service.assignVehicle('v1', 'staff-123', '田中太郎', 'manager-uid');
      expect(result, isA<Success>());
      final doc = await fakeFirestore.collection('vehicles').doc('v1').get();
      expect(doc.data()?['assigneeId'], 'staff-123');
      expect(doc.data()?['assigneeName'], '田中太郎');
    });

    test('空の assigneeId はnullとして保存される', () async {
      await _seedVehicle(fakeFirestore,
          _makeVehicle(id: 'v1', userId: 'staff', companyId: 'manager-uid'));
      final result = await service.assignVehicle('v1', '', '', 'manager-uid');
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
            fakeFirestore, _makeVehicle(id: 'v$i', companyId: 'company-A'));
      }
      final stream = service.getCompanyVehicles('company-A');
      final vehicles = await stream.first;
      expect(vehicles.length, 100);
    });
  });

  group('getMaintenanceSummaries', () {
    // 集計は Cloud Functions が fleet_maintenance_summaries/{vehicleId} に
    // 書く（functions/src/fleetMaintenanceSummary.ts）。ここではその形を置く。
    Future<void> seedSummary(
      String vehicleId, {
      DateTime? last,
      int totalCost = 0,
      int recordCount = 1,
    }) async {
      await fakeFirestore
          .collection('fleet_maintenance_summaries')
          .doc(vehicleId)
          .set({
        'vehicleId': vehicleId,
        'ownerId': 'member-$vehicleId',
        'lastMaintenanceDate': last == null ? null : Timestamp.fromDate(last),
        'totalCost': totalCost,
        'recordCount': recordCount,
        'updatedAt': Timestamp.now(),
      });
    }

    test('車両ごとに直近整備日・累計費用・件数を返す', () async {
      await seedSummary('v1',
          last: DateTime(2026, 5, 20), totalCost: 17000, recordCount: 2);
      await seedSummary('v2', last: DateTime(2026, 1, 10), totalCost: 30000);

      final result = await service.getMaintenanceSummaries(['v1', 'v2']);

      expect(result.isSuccess, isTrue);
      final summaries = result.valueOrNull!;
      expect(summaries['v1']!.lastMaintenanceDate, DateTime(2026, 5, 20));
      expect(summaries['v1']!.totalCost, 17000);
      expect(summaries['v1']!.recordCount, 2);
      expect(summaries['v2']!.totalCost, 30000);
    });

    test('集計の無い車両（整備記録なし）→ マップに含まれない', () async {
      await seedSummary('v1', totalCost: 1000);

      final result = await service.getMaintenanceSummaries(['v1', 'v2']);
      final summaries = result.valueOrNull!;
      expect(summaries.containsKey('v1'), isTrue);
      expect(summaries.containsKey('v2'), isFalse);
    });

    test('11台以上でも全部返す（whereIn の件数制限に縛られない）', () async {
      final ids = <String>[];
      for (var i = 0; i < 35; i++) {
        ids.add('v$i');
        await seedSummary('v$i', totalCost: 1000);
      }

      final result = await service.getMaintenanceSummaries(ids);
      expect(result.valueOrNull!.length, 35);
    });

    // 管理者はメンバーの maintenance_records を読めない（本人だけ）。
    // 生の記録を直接引いていた頃は、本番で CSV の整備欄が常に空だった。
    test('生の maintenance_records は読まない（集計の文書だけを見る）', () async {
      await fakeFirestore.collection('maintenance_records').add({
        'vehicleId': 'v1',
        'userId': 'member',
        'date': Timestamp.fromDate(DateTime(2026, 3, 1)),
        'cost': 5000,
      });

      final result = await service.getMaintenanceSummaries(['v1']);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!, isEmpty);
    });

    group('Edge Cases', () {
      test('空リスト → 空マップ', () async {
        final result = await service.getMaintenanceSummaries([]);
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, isEmpty);
      });

      test('空の車両IDは無視する（不正なパスで落ちない）', () async {
        await seedSummary('v1', totalCost: 1000);

        final result = await service.getMaintenanceSummaries(['', 'v1', '']);

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.keys, ['v1']);
      });

      test('同じ車両IDが重なっても1件', () async {
        await seedSummary('v1', totalCost: 1000);

        final result = await service.getMaintenanceSummaries(['v1', 'v1']);

        expect(result.valueOrNull!.length, 1);
      });

      test('存在しない車両ID → 空マップ', () async {
        final result = await service.getMaintenanceSummaries(['no-such-car']);
        expect(result.valueOrNull!, isEmpty);
      });

      test('項目が欠けた集計でも 0 / null として読む', () async {
        await fakeFirestore
            .collection('fleet_maintenance_summaries')
            .doc('v1')
            .set({'vehicleId': 'v1'});

        final result = await service.getMaintenanceSummaries(['v1']);

        final s = result.valueOrNull!['v1']!;
        expect(s.lastMaintenanceDate, isNull);
        expect(s.totalCost, 0);
        expect(s.recordCount, 0);
      });

      test('最終日が null（日付の無い記録だけ）でも読める', () async {
        await seedSummary('v1', last: null, totalCost: 500);

        final result = await service.getMaintenanceSummaries(['v1']);

        expect(result.valueOrNull!['v1']!.lastMaintenanceDate, isNull);
        expect(result.valueOrNull!['v1']!.totalCost, 500);
      });
    });
  });
}
