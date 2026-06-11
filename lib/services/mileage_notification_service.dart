import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Service that schedules a local notification reminding the user
/// to update their vehicle's mileage every 30 days.
class MileageNotificationService {
  static const int _notificationId = 9001;
  static const String _channelId = 'mileage_reminder';

  final FlutterLocalNotificationsPlugin _plugin;

  MileageNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Schedules a one-shot notification 30 days from now.
  /// Call this after the user successfully updates their mileage.
  Future<void> scheduleMonthlyReminder() async {
    // Ensure timezone database is initialized
    tz_data.initializeTimeZones();

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        '走行距離リマインダー',
        channelDescription: '走行距離の更新をお知らせします',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        categoryIdentifier: _channelId,
      ),
    );

    // Schedule 30 days from now
    final scheduledDate = tz.TZDateTime.now(tz.local).add(
      const Duration(days: 30),
    );

    await _plugin.zonedSchedule(
      _notificationId,
      '走行距離の更新をお願いします',
      '正確なメンテナンス提案のために、最新の走行距離を入力してください',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels any previously scheduled mileage reminder.
  Future<void> cancelReminder() async {
    await _plugin.cancel(_notificationId);
  }
}
