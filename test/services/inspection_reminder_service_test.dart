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
    return Future<void>.value();
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

Vehicle _makeVehicle({
  String id = 'v1',
  DateTime? inspectionExpiryDate,
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
    test('車検60日後 → 30/7/1日前の3件がスケジュールされる', () async {
      final vehicle = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 60)),
      );

      await service.scheduleForVehicles([vehicle]);

      expect(plugin.zonedScheduleCalls.length, 3);
    });

    test('車検5日後 → 1日前リマインダーのみスケジュールされる', () async {
      final vehicle = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 5)),
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
          inspectionExpiryDate: DateTime.now().add(const Duration(days: 5)),
        ),
      ];

      await service.scheduleForVehicles(vehicles);

      expect(plugin.zonedScheduleCalls.length, 4); // 3 + 1
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

  group('InspectionReminderService.notificationId', () {
    test('同じ入力には常に同じIDを返す（決定的）', () {
      final a = InspectionReminderService.notificationId('vehicle-abc', 0);
      final b = InspectionReminderService.notificationId('vehicle-abc', 0);
      expect(a, b);
    });

    test('オフセットが異なればIDも異なる', () {
      final a = InspectionReminderService.notificationId('vehicle-abc', 0);
      final b = InspectionReminderService.notificationId('vehicle-abc', 1);
      final c = InspectionReminderService.notificationId('vehicle-abc', 2);
      expect({a, b, c}.length, 3);
    });

    test('IDは予約レンジ内（7000〜7899）に収まる', () {
      for (final id in ['v1', 'long-vehicle-id-12345', '日本語ID']) {
        for (var i = 0; i < 3; i++) {
          final n = InspectionReminderService.notificationId(id, i);
          expect(n, inInclusiveRange(7000, 7899));
        }
      }
    });
  });
}
