// NotificationListScreen Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/notifications/notification_list_screen.dart';
import 'package:trust_car_platform/providers/notification_provider.dart';
import 'package:trust_car_platform/models/app_notification.dart';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/providers/vehicle_provider.dart';
import 'package:trust_car_platform/services/firebase_service.dart';

// ---------------------------------------------------------------------------
// Stub FirebaseService
// ---------------------------------------------------------------------------

class _StubFirebaseService implements FirebaseService {
  @override
  String? get currentUserId => null;

  @override
  Stream<List<Vehicle>> getUserVehicles() => const Stream.empty();

  @override
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(String vehicleId) =>
      const Stream.empty();

  @override
  Future<Result<String, AppError>> addVehicle(Vehicle vehicle) async =>
      const Result.success('id');

  @override
  Future<Result<void, AppError>> updateVehicle(String vehicleId, Vehicle vehicle) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteVehicle(String vehicleId) async =>
      const Result.success(null);

  @override
  Future<Result<Vehicle?, AppError>> getVehicle(String vehicleId) async =>
      const Result.success(null);

  @override
  Future<Result<bool, AppError>> isLicensePlateExists(String licensePlate,
          {String? excludeVehicleId}) async =>
      const Result.success(false);

  @override
  Future<Result<String, AppError>> addMaintenanceRecord(MaintenanceRecord record) async =>
      const Result.success('id');

  @override
  Future<Result<void, AppError>> updateMaintenanceRecord(String recordId, MaintenanceRecord record) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteMaintenanceRecord(String recordId) async =>
      const Result.success(null);

  @override
  Future<Result<Map<String, List<MaintenanceRecord>>, AppError>>
      getMaintenanceRecordsForVehicles(List<String> vehicleIds,
              {int limitPerVehicle = 20}) async =>
          const Result.success({});

  @override
  Future<Result<List<MaintenanceRecord>, AppError>> getMaintenanceRecordsForVehicle(
          String vehicleId, {int limit = 20}) async =>
      const Result.success([]);

  @override
  Future<Result<String, AppError>> uploadImage(io.File imageFile, String path) async =>
      const Result.success('url');

  @override
  Future<Result<String, AppError>> uploadImageBytes(Uint8List imageBytes, String path) async =>
      const Result.success('url');

  @override
  Future<Result<List<String>, AppError>> uploadImages(List<io.File> imageFiles, String basePath) async =>
      const Result.success([]);

  @override
  Future<Result<String, AppError>> uploadProcessedImage(Uint8List imageBytes, String path,
          {required dynamic imageService}) async =>
      const Result.success('url');
}

// ---------------------------------------------------------------------------
// Mock NotificationProvider
// ---------------------------------------------------------------------------

class MockNotificationProvider extends ChangeNotifier
    implements NotificationProvider {
  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  AppError? _error;

  // --- setters for test control ---
  set mockNotifications(List<AppNotification> list) {
    _notifications = list;
    notifyListeners();
  }

  set mockLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  set mockError(AppError? e) {
    _error = e;
    notifyListeners();
  }

  @override
  List<AppNotification> get notifications => _notifications;

  @override
  bool get isLoading => _isLoading;

  @override
  AppError? get error => _error;

  @override
  String? get errorMessage => _error?.userMessage;

  @override
  bool get isRetryable => _error?.isRetryable ?? false;

  @override
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  int get highPriorityUnreadCount =>
      _notifications
          .where((n) => !n.isRead && n.priority == NotificationPriority.high)
          .length;

  @override
  List<AppNotification> get topSuggestions => _notifications.take(3).toList();

  // --- tracked calls ---
  String? lastMarkedReadId;
  int markAllReadCallCount = 0;
  String? lastRemovedId;

  @override
  Future<void> markAsRead(String notificationId) async {
    lastMarkedReadId = notificationId;
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  @override
  Future<void> markAllAsRead() async {
    markAllReadCallCount++;
  }

  @override
  void removeNotification(String notificationId) {
    lastRemovedId = notificationId;
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  @override
  void clearNotifications() => _notifications.clear();

  @override
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void clear() {
    _notifications.clear();
    _error = null;
    notifyListeners();
  }

  @override
  List<AppNotification> getNotificationsForVehicle(String vehicleId) =>
      _notifications.where((n) => n.vehicleId == vehicleId).toList();

  @override
  List<AppNotification> getNotificationsByType(NotificationType type) =>
      _notifications.where((n) => n.type == type).toList();

  @override
  Future<void> generateRecommendations({
    required List<dynamic> vehicles,
    required Map<String, List<dynamic>> maintenanceRecords,
  }) async {}

  @override
  Future<void> generateNotificationsForVehicles(
      List<dynamic> vehicles) async {}

  // Needed by ChangeNotifier interface
  @override
  // ignore: must_call_super
  void dispose() {}
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

AppNotification _makeNotification({
  String id = 'n1',
  String vehicleId = 'v1',
  NotificationType type = NotificationType.maintenanceRecommendation,
  NotificationPriority priority = NotificationPriority.medium,
  bool isRead = false,
  String title = 'オイル交換推奨',
  String message = '走行距離から交換時期を超えています',
}) {
  return AppNotification(
    id: id,
    userId: 'user1',
    vehicleId: vehicleId,
    type: type,
    title: title,
    message: message,
    priority: priority,
    isRead: isRead,
    createdAt: DateTime.now(),
  );
}

Widget _buildUnderTest(MockNotificationProvider provider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NotificationProvider>.value(value: provider),
      ChangeNotifierProvider<VehicleProvider>(
        create: (_) => VehicleProvider(firebaseService: _StubFirebaseService()),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: NotificationListScreen(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockNotificationProvider provider;

  setUp(() {
    provider = MockNotificationProvider();
  });

  group('NotificationListScreen — ローディング状態', () {
    testWidgets('isLoading=true のとき ローディングインジケーターを表示する', (tester) async {
      provider.mockLoading = true;

      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      // AppLoadingCenter or CircularProgressIndicator
      expect(
        find.byType(CircularProgressIndicator),
        findsAtLeast(1),
      );
    });
  });

  group('NotificationListScreen — 空状態', () {
    testWidgets('通知なし のとき空状態メッセージを表示する', (tester) async {
      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      expect(find.text('通知はありません'), findsOneWidget);
    });

    testWidgets('空状態の説明文を表示する', (tester) async {
      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      expect(
        find.text('メンテナンスの推奨がある場合はここに表示されます'),
        findsOneWidget,
      );
    });
  });

  group('NotificationListScreen — 通知一覧', () {
    testWidgets('通知リストが表示される', (tester) async {
      provider.mockNotifications = [
        _makeNotification(id: 'n1', title: 'オイル交換推奨'),
        _makeNotification(id: 'n2', title: 'タイヤ点検推奨'),
      ];

      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      expect(find.text('オイル交換推奨'), findsOneWidget);
      expect(find.text('タイヤ点検推奨'), findsOneWidget);
    });

    testWidgets('通知が1件のとき1件だけ表示される', (tester) async {
      provider.mockNotifications = [
        _makeNotification(id: 'n1', title: '車検リマインダー'),
      ];

      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      expect(find.text('車検リマインダー'), findsOneWidget);
    });

    testWidgets('通知をタップすると markAsRead が呼ばれる', (tester) async {
      provider.mockNotifications = [
        _makeNotification(id: 'n1', title: 'オイル交換推奨'),
      ];

      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      await tester.tap(find.text('オイル交換推奨'));
      await tester.pumpAndSettle();

      expect(provider.lastMarkedReadId, 'n1');
    });
  });

  group('NotificationListScreen — スワイプ削除', () {
    testWidgets('スワイプすると removeNotification が呼ばれる', (tester) async {
      provider.mockNotifications = [
        _makeNotification(id: 'n1', title: '消耗品交換推奨'),
      ];

      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();

      // Dismissible でスワイプ（dismiss threshold を超える距離）
      await tester.drag(
        find.text('消耗品交換推奨'),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(provider.lastRemovedId, 'n1');
    });
  });

  group('Edge Cases', () {
    testWidgets('通知が空→データ追加で一覧に切り替わる', (tester) async {
      await tester.pumpWidget(_buildUnderTest(provider));
      await tester.pump();
      expect(find.text('通知はありません'), findsOneWidget);

      provider.mockNotifications = [
        _makeNotification(id: 'n1', title: '新しい通知'),
      ];
      await tester.pump();

      expect(find.text('新しい通知'), findsOneWidget);
      expect(find.text('通知はありません'), findsNothing);
    });
  });
}
