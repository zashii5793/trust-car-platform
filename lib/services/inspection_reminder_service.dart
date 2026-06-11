import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../models/vehicle.dart';

/// Schedules local notifications ahead of each vehicle's inspection (車検)
/// deadline so users are reminded even when the app is not opened.
///
/// Reminders fire 30 / 7 / 1 days before `inspectionExpiryDate`.
/// Notification ids are deterministic per vehicle+offset and live in the
/// reserved range 7000–7899, so re-scheduling replaces stale entries and
/// never collides with other reminder services (e.g. mileage = 9001).
class InspectionReminderService {
  static const String _channelId = 'inspection_reminder';

  /// Days before the deadline at which a reminder fires.
  static const List<int> reminderDaysBefore = [30, 7, 1];

  static const int _idBase = 7000;
  static const int _idBuckets = 300; // 300 buckets × 3 offsets = 7000..7899

  final FlutterLocalNotificationsPlugin _plugin;

  InspectionReminderService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Deterministic notification id for a vehicle + reminder offset.
  ///
  /// Uses FNV-1a so the id is stable across app restarts (String.hashCode
  /// is not guaranteed stable between runs). Bucket collisions between
  /// vehicles are possible but rare and only cause a reminder overwrite.
  static int notificationId(String vehicleId, int offsetIndex) {
    var hash = 0x811c9dc5;
    for (final unit in vehicleId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return _idBase +
        (hash % _idBuckets) * reminderDaysBefore.length +
        offsetIndex;
  }

  /// Re-schedules inspection reminders for [vehicles].
  ///
  /// Cancels all previously scheduled inspection reminders first so
  /// deleted vehicles or changed dates never leave stale notifications.
  Future<void> scheduleForVehicles(List<Vehicle> vehicles) async {
    tz_data.initializeTimeZones();

    // Clear previously scheduled reminders in our reserved id range.
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id >= _idBase &&
          request.id < _idBase + _idBuckets * reminderDaysBefore.length) {
        await _plugin.cancel(request.id);
      }
    }

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        '車検期限リマインダー',
        channelDescription: '車検満了日が近づいたときにお知らせします',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        categoryIdentifier: _channelId,
      ),
    );

    final now = tz.TZDateTime.now(tz.local);

    for (final vehicle in vehicles) {
      final expiry = vehicle.inspectionExpiryDate;
      if (expiry == null) continue;

      for (var i = 0; i < reminderDaysBefore.length; i++) {
        final daysBefore = reminderDaysBefore[i];
        final fireAt = tz.TZDateTime.from(
          expiry.subtract(Duration(days: daysBefore)),
          tz.local,
        );
        if (!fireAt.isAfter(now)) continue;

        await _plugin.zonedSchedule(
          notificationId(vehicle.id, i),
          '車検満了が近づいています',
          '${vehicle.maker} ${vehicle.model} の車検満了日まで'
              'あと$daysBefore日です。整備工場の予約をご検討ください。',
          fireAt,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }
}
