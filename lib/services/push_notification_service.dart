import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../core/result/result.dart';
import '../core/error/app_error.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages here
  // Note: This runs in a separate isolate, so we can't access app state
}

/// Service for handling push notifications via Firebase Cloud Messaging
class PushNotificationService {
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;

  // Notification channel for Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'trust_car_high_importance',
    '車両管理通知',
    description: '車検・保険期限などの重要な通知',
    importance: Importance.high,
  );

  PushNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  /// Initialize the push notification service
  Future<Result<void, AppError>> initialize() async {
    try {
      // Set up background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Initialize local notifications for Android
      if (Platform.isAndroid) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);
      }

      // Initialize local notifications
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Listen for foreground messages
      _foregroundSubscription =
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Listen for when app is opened from notification
      _openedAppSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

      // Check if app was opened from a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationOpen(initialMessage);
      }

      return const Result.success(null);
    } catch (e) {
      return Result.failure(ServerError('Failed to initialize push notifications: $e'));
    }
  }

  /// Request notification permissions from the user
  Future<Result<bool, AppError>> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      return Result.success(granted);
    } catch (e) {
      return Result.failure(ServerError('Failed to request notification permission: $e'));
    }
  }

  /// Get the current FCM token
  Future<Result<String?, AppError>> getToken() async {
    try {
      final token = await _messaging.getToken();
      return Result.success(token);
    } catch (e) {
      return Result.failure(ServerError('Failed to get FCM token: $e'));
    }
  }

  /// Subscribe to a topic for targeted notifications
  Future<Result<void, AppError>> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ServerError('Failed to subscribe to topic: $e'));
    }
  }

  /// Unsubscribe from a topic
  Future<Result<void, AppError>> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ServerError('Failed to unsubscribe from topic: $e'));
    }
  }

  /// Show a local notification
  Future<Result<void, AppError>> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'trust_car_high_importance',
        '車両管理通知',
        channelDescription: '車検・保険期限などの重要な通知',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );

      return const Result.success(null);
    } catch (e) {
      return Result.failure(ServerError('Failed to show local notification: $e'));
    }
  }

  /// Schedule a local notification
  Future<Result<void, AppError>> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'trust_car_high_importance',
        '車両管理通知',
        channelDescription: '車検・保険期限などの重要な通知',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Use zonedSchedule for scheduled notifications
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        _convertToTZDateTime(scheduledDate),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      return const Result.success(null);
    } catch (e) {
      return Result.failure(ServerError('Failed to schedule notification: $e'));
    }
  }

  /// Cancel a scheduled notification
  Future<Result<void, AppError>> cancelNotification(int id) async {
    try {
      await _localNotifications.cancel(id);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ServerError('Failed to cancel notification: $e'));
    }
  }

  /// Cancel all scheduled notifications
  Future<Result<void, AppError>> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ServerError('Failed to cancel all notifications: $e'));
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      showLocalNotification(
        title: notification.title ?? '',
        body: notification.body ?? '',
        payload: message.data['payload'],
      );
    }
  }

  // Handle notification tap when app was in background
  void _handleNotificationOpen(RemoteMessage message) {
    // This can be extended to navigate to specific screens
    // based on the notification data
  }

  // Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle navigation based on payload
    // This can be extended to navigate to specific screens
  }

  // Convert DateTime to TZDateTime for scheduling
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// Initialize timezone data (call once at app start)
  static void initializeTimezone() {
    tz_data.initializeTimeZones();
  }

  /// Dispose subscriptions
  void dispose() {
    _foregroundSubscription?.cancel();
    _openedAppSubscription?.cancel();
  }
}
