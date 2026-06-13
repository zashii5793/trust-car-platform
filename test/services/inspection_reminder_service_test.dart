// InspectionReminderService Unit Tests
//
// Verifies local notification scheduling for vehicle inspection deadlines.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/inspection_reminder_service.dart';

// ---------------------------------------------------------------------------
// Recording fake plugin
// ---------------------------------------------------------------------------

class _RecordingPlugin implements FlutterLocalNotificationsPlugin {
  final List<Invocation> zonedScheduleCalls = [];
  final List<int> cancelledIds = [];
  List<PendingNotificationRequest> pending = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #zonedSchedule) {
      zonedScheduleCalls.add(invocation);
      return Future<void>.value();
    }
    if (invocation.memberName == #cancel) {
      cancelledIds.add(invocation.positionalArguments[0] as int);
      return Future<void>.value();
    }
    if (invocation.memberName == #pendingNotificationRequests) {
      return Future<List<PendingNotificationRequest>>.value(pending);
    }
    // Permission request resolves the platform implementation; returning
    // null means "platform unavailable" and the request is skipped.
    if (invocation.memberName == #resolvePlatformSpecificImplementation) {
      return null;
    }
    return Future<void>.value();
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

Vehicle _makeVehicle({
  String id = 'v1',
  DateTime? inspectionExpiryDate,
  DateTime? voluntaryInsuranceExpiryDate,
  DateTime? leaseContractEndDate,
}) =>
    Vehicle(
      id: id,
      userId: 'u1',
      maker: 'トヨタ',
      model: 'プリウス',
      year: 2021,
      grade: 'S',
      mileage: 30000,
      inspectionExpiryDate: inspectionExpiryDate,
      voluntaryInsurance: voluntaryInsuranceExpiryDate != null
          ? VoluntaryInsurance(expiryDate: voluntaryInsuranceExpiryDate)
          : null,
      leaseInfo: leaseContractEndDate != null
          ? LeaseInfo(contractEndDate: leaseContractEndDate)
          : null,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

void main() {
  late _RecordingPlugin plugin;
  late InspectionReminderService service;

  setUp(() {
    plugin = _RecordingPlugin();
    service = InspectionReminderService(plugin: plugin);
  });

  group('InspectionReminderService.scheduleForVehicles', () {
    test('車検60日後 → 30/7日前の2件がスケジュールされる', () async {
      final vehicle = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 60)),
      );

      await service.scheduleForVehicles([vehicle]);

      expect(plugin.zonedScheduleCalls.length, 2);
    });

    test('車検5日後 → 30/7日前とも過去なのでスケジュールなし（1日前通知は廃止）', () async {
      final vehicle = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 5)),
      );

      await service.scheduleForVehicles([vehicle]);

      expect(plugin.zonedScheduleCalls, isEmpty);
    });

    test('車検10日後 → 7日前リマインダーのみスケジュールされる', () async {
      final vehicle = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 10)),
      );

      await service.scheduleForVehicles([vehicle]);

      expect(plugin.zonedScheduleCalls.length, 1);
    });

    test('複数車両分が合算してスケジュールされる', () async {
      final vehicles = [
        _makeVehicle(
          id: 'v1',
          inspectionExpiryDate: DateTime.now().add(const Duration(days: 60)),
        ),
        _makeVehicle(
          id: 'v2',
          inspectionExpiryDate: DateTime.now().add(const Duration(days: 10)),
        ),
      ];

      await service.scheduleForVehicles(vehicles);

      expect(plugin.zonedScheduleCalls.length, 3); // 2 + 1
    });

    test('既存の車検リマインダーは再スケジュール前にキャンセルされる', () async {
      plugin.pending = [
        const PendingNotificationRequest(7100, 'old', 'old', null),
        // Outside the reserved range — must NOT be cancelled
        const PendingNotificationRequest(9001, 'mileage', 'keep', null),
      ];

      await service.scheduleForVehicles([]);

      expect(plugin.cancelledIds, [7100]);
    });

    group('Edge Cases', () {
      test('車検日未設定の車両 → スケジュールなし', () async {
        await service.scheduleForVehicles([_makeVehicle()]);

        expect(plugin.zonedScheduleCalls, isEmpty);
      });

      test('車検日が過去 → スケジュールなし', () async {
        final vehicle = _makeVehicle(
          inspectionExpiryDate:
              DateTime.now().subtract(const Duration(days: 10)),
        );

        await service.scheduleForVehicles([vehicle]);

        expect(plugin.zonedScheduleCalls, isEmpty);
      });

      test('空リスト → スケジュールなし・クラッシュなし', () async {
        await service.scheduleForVehicles([]);

        expect(plugin.zonedScheduleCalls, isEmpty);
      });
    });
  });

  group('InspectionReminderService — 任意保険リマインダー', () {
    test('任意保険60日後 → 30/7日前の2件がスケジュールされる', () async {
      final vehicle = _makeVehicle(
        voluntaryInsuranceExpiryDate:
            DateTime.now().add(const Duration(days: 60)),
      );

      await service.scheduleForVehicles([vehicle]);

      expect(plugin.zonedScheduleCalls.length, 2);
    });

    test('車検と任意保険の両方がある車両 → 合計4件', () async {
      final vehicle = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 90)),
        voluntaryInsuranceExpiryDate:
            DateTime.now().add(const Duration(days: 60)),
      );

      await service.scheduleForVehicles([vehicle]);

      expect(plugin.zonedScheduleCalls.length, 4);
    });

    test('任意保険IDレンジ（8000-8599）の既存通知もキャンセルされる', () async {
      plugin.pending = [
        const PendingNotificationRequest(8100, 'old', 'old', null),
        const PendingNotificationRequest(9001, 'mileage', 'keep', null),
      ];

      await service.scheduleForVehicles([]);

      expect(plugin.cancelledIds, [8100]);
    });

    test('任意保険の満期が過去 → スケジュールなし', () async {
      final vehicle = _makeVehicle(
        voluntaryInsuranceExpiryDate:
            DateTime.now().subtract(const Duration(days: 10)),
      );

      await service.scheduleForVehicles([vehicle]);

      expect(plugin.zonedScheduleCalls, isEmpty);
    });
  });

  group('InspectionReminderService — リースリマインダー', () {
    test('リース満了60日後 → 30/7日前の2件がスケジュールされる', () async {
      final vehicle = _makeVehicle(
        leaseContractEndDate: DateTime.now().add(const Duration(days: 60)),
      );

      await service.scheduleForVehicles([vehicle]);

      expect(plugin.zonedScheduleCalls.length, 2);
    });

    test('車検・任意保険・リースすべてあり → 合計6件', () async {
      final vehicle = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 90)),
        voluntaryInsuranceExpiryDate:
            DateTime.now().add(const Duration(days: 60)),
        leaseContractEndDate: DateTime.now().add(const Duration(days: 45)),
      );

      await service.scheduleForVehicles([vehicle]);

      expect(plugin.zonedScheduleCalls.length, 6);
    });

    test('リースIDレンジ（6000-6599）の既存通知もキャンセルされる', () async {
      plugin.pending = [
        const PendingNotificationRequest(6100, 'old', 'old', null),
        const PendingNotificationRequest(9001, 'mileage', 'keep', null),
      ];

      await service.scheduleForVehicles([]);

      expect(plugin.cancelledIds, [6100]);
    });

    test('リースIDは予約レンジ内（6000-6599）に収まり車検と重ならない', () {
      final leaseId =
          InspectionReminderService.leaseNotificationId('vehicle-abc', 0);
      expect(leaseId, inInclusiveRange(6000, 6599));
    });
  });

  group('InspectionReminderService.insuranceNotificationId', () {
    test('車検IDと任意保険IDはレンジが重ならない', () {
      final inspectionId =
          InspectionReminderService.notificationId('vehicle-abc', 0);
      final insuranceId =
          InspectionReminderService.insuranceNotificationId('vehicle-abc', 0);
      expect(inspectionId, inInclusiveRange(7000, 7599));
      expect(insuranceId, inInclusiveRange(8000, 8599));
    });

    test('同じ入力には常に同じIDを返す（決定的）', () {
      final a =
          InspectionReminderService.insuranceNotificationId('vehicle-abc', 1);
      final b =
          InspectionReminderService.insuranceNotificationId('vehicle-abc', 1);
      expect(a, b);
    });
  });

  group('InspectionReminderService.notificationId', () {
    test('同じ入力には常に同じIDを返す（決定的）', () {
      final a = InspectionReminderService.notificationId('vehicle-abc', 0);
      final b = InspectionReminderService.notificationId('vehicle-abc', 0);
      expect(a, b);
    });

    test('オフセットが異なればIDも異なる', () {
      final a = InspectionReminderService.notificationId('vehicle-abc', 0);
      final b = InspectionReminderService.notificationId('vehicle-abc', 1);
      expect({a, b}.length, 2);
    });

    test('IDは予約レンジ内（7000〜7599）に収まる', () {
      for (final id in ['v1', 'long-vehicle-id-12345', '日本語ID']) {
        for (var i = 0; i < 2; i++) {
          final n = InspectionReminderService.notificationId(id, i);
          expect(n, inInclusiveRange(7000, 7599));
        }
      }
    });
  });
}
