// MileageNotificationService Unit Tests

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/mileage_notification_service.dart';

class _RecordingPlugin implements FlutterLocalNotificationsPlugin {
  final List<Invocation> zonedScheduleCalls = [];
  final List<int> cancelledIds = [];

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
    if (invocation.memberName == #resolvePlatformSpecificImplementation) {
      return null;
    }
    return Future<void>.value();
  }
}

void main() {
  late _RecordingPlugin plugin;
  late MileageNotificationService service;

  setUp(() {
    plugin = _RecordingPlugin();
    service = MileageNotificationService(plugin: plugin);
  });

  group('MileageNotificationService.scheduleMonthlyReminder', () {
    test('リマインダーが1件スケジュールされる', () async {
      await service.scheduleMonthlyReminder();

      expect(plugin.zonedScheduleCalls.length, 1);
    });

    test('固定ID 9001 でスケジュールされる（車検レンジと衝突しない）', () async {
      await service.scheduleMonthlyReminder();

      final id = plugin.zonedScheduleCalls.single.positionalArguments[0] as int;
      expect(id, 9001);
    });

    test('連続呼び出しでも同じIDが使われる（置換され重複しない）', () async {
      await service.scheduleMonthlyReminder();
      await service.scheduleMonthlyReminder();

      final ids = plugin.zonedScheduleCalls
          .map((c) => c.positionalArguments[0] as int)
          .toSet();
      expect(ids, {9001});
    });
  });

  group('MileageNotificationService.cancelReminder', () {
    test('ID 9001 がキャンセルされる', () async {
      await service.cancelReminder();

      expect(plugin.cancelledIds, [9001]);
    });
  });
}
