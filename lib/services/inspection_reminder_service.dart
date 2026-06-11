import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../models/vehicle.dart';

/// Schedules local notifications ahead of each vehicle's inspection (車検)
/// and voluntary insurance (任意保険) deadlines so users are reminded even
/// when the app is not opened.
///
/// Reminders fire 30 / 7 / 1 days before each deadline.
/// Notification ids are deterministic per vehicle+offset and live in the
/// reserved ranges 7000–7899 (inspection) and 8000–8899 (insurance), so
/// re-scheduling replaces stale entries and never collides with other
/// reminder services (e.g. mileage = 9001).
class InspectionReminderService {
  static const String _channelId = 'inspection_reminder';

  /// Days before the deadline at which a reminder fires.
  static const List<int> reminderDaysBefore = [30, 7, 1];

  static const int _idBase = 7000;
  static const int _insuranceIdBase = 8000;
  static const int _idBuckets = 300; // 300 buckets × 3 offsets per range

  final FlutterLocalNotificationsPlugin _plugin;

  InspectionReminderService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Deterministic notification id for a vehicle + reminder offset.
  ///
  /// Uses FNV-1a so the id is stable across app restarts (String.hashCode
  /// is not guaranteed stable between runs). Bucket collisions between
  /// vehicles are possible but rare and only cause a reminder overwrite.
  static int notificationId(String vehicleId, int offsetIndex) {
    return _idBase + _bucketOffset(vehicleId, offsetIndex);
  }

  /// Deterministic id for a voluntary-insurance reminder (range 8000–8899).
  static int insuranceNotificationId(String vehicleId, int offsetIndex) {
    return _insuranceIdBase + _bucketOffset(vehicleId, offsetIndex);
  }

  static int _bucketOffset(String vehicleId, int offsetIndex) {
    var hash = 0x811c9dc5;
    for (final unit in vehicleId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return (hash % _idBuckets) * reminderDaysBefore.length + offsetIndex;
  }

  /// Requests OS notification permission (Android 13+ / iOS).
  ///
  /// The system dialog is only ever shown once by the OS; subsequent calls
  /// return the stored status without UI, so calling on every schedule is
  /// safe. Returns silently on platforms without a runtime permission.
  Future<void> _requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Re-schedules inspection and voluntary-insurance reminders for
  /// [vehicles].
  ///
  /// Cancels all previously scheduled reminders in both reserved id ranges
  /// first so deleted vehicles or changed dates never leave stale
  /// notifications.
  Future<void> scheduleForVehicles(List<Vehicle> vehicles) async {
    tz_data.initializeTimeZones();

    // Reminders are the app's core promise — make sure the OS will
    // actually deliver them.
    await _requestPermission();

    // Clear previously scheduled reminders in our reserved id ranges.
    final rangeLength = _idBuckets * reminderDaysBefore.length;
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      final isInspection =
          request.id >= _idBase && request.id < _idBase + rangeLength;
      final isInsurance = request.id >= _insuranceIdBase &&
          request.id < _insuranceIdBase + rangeLength;
      if (isInspection || isInsurance) {
        await _plugin.cancel(request.id);
      }
    }

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        '期限リマインダー',
        channelDescription: '車検や保険の期限が近づいたときにお知らせします',
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
      await _scheduleDeadline(
        deadline: vehicle.inspectionExpiryDate,
        now: now,
        details: notificationDetails,
        idFor: (i) => notificationId(vehicle.id, i),
        title: '車検満了が近づいています',
        body: (daysBefore) => '${vehicle.maker} ${vehicle.model} の車検満了日まで'
            'あと$daysBefore日です。整備工場の予約をご検討ください。',
      );

      await _scheduleDeadline(
        deadline: vehicle.voluntaryInsurance?.expiryDate,
        now: now,
        details: notificationDetails,
        idFor: (i) => insuranceNotificationId(vehicle.id, i),
        title: '任意保険の満期が近づいています',
        body: (daysBefore) => '${vehicle.maker} ${vehicle.model} の任意保険満期日まで'
            'あと$daysBefore日です。更新や見直しをご検討ください。',
      );
    }
  }

  Future<void> _scheduleDeadline({
    required DateTime? deadline,
    required tz.TZDateTime now,
    required NotificationDetails details,
    required int Function(int offsetIndex) idFor,
    required String title,
    required String Function(int daysBefore) body,
  }) async {
    if (deadline == null) return;

    for (var i = 0; i < reminderDaysBefore.length; i++) {
      final daysBefore = reminderDaysBefore[i];
      final fireAt = tz.TZDateTime.from(
        deadline.subtract(Duration(days: daysBefore)),
        tz.local,
      );
      if (!fireAt.isAfter(now)) continue;

      await _plugin.zonedSchedule(
        idFor(i),
        title,
        body(daysBefore),
        fireAt,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
