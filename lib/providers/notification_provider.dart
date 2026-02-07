import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../models/vehicle.dart';
import '../models/maintenance_record.dart';
import '../services/recommendation_service.dart';
import '../services/firebase_service.dart';

/// 通知状態管理Provider
class NotificationProvider extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final RecommendationService _recommendationService;

  NotificationProvider({
    required FirebaseService firebaseService,
    required RecommendationService recommendationService,
  })  : _firebaseService = firebaseService,
        _recommendationService = recommendationService;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _error;

  /// 通知一覧
  List<AppNotification> get notifications => _notifications;

  /// 未読通知数
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// 高優先度の未読通知数
  int get highPriorityUnreadCount => _notifications
      .where((n) => !n.isRead && n.priority == NotificationPriority.high)
      .length;

  /// ローディング状態
  bool get isLoading => _isLoading;

  /// エラーメッセージ
  String? get error => _error;

  /// 車両リストから通知を生成（整備記録も自動取得）
  Future<void> generateNotificationsForVehicles(List<Vehicle> vehicles) async {
    final userId = _firebaseService.currentUserId;
    if (userId == null || vehicles.isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 各車両の整備記録を取得（FirebaseService経由）
      final maintenanceRecords = <String, List<MaintenanceRecord>>{};
      for (final vehicle in vehicles) {
        final result = await _firebaseService.getMaintenanceRecordsForVehicle(
          vehicle.id,
          limit: 20, // 直近20件で十分
        );
        result.when(
          success: (records) => maintenanceRecords[vehicle.id] = records,
          failure: (_) => maintenanceRecords[vehicle.id] = [],
        );
      }

      // レコメンドを生成
      await generateRecommendations(
        vehicles: vehicles,
        maintenanceRecords: maintenanceRecords,
      );
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 車両リストからレコメンドを生成して通知を更新
  Future<void> generateRecommendations({
    required List<Vehicle> vehicles,
    required Map<String, List<MaintenanceRecord>> maintenanceRecords,
  }) async {
    final userId = _firebaseService.currentUserId;
    if (userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final allRecommendations = <AppNotification>[];

      for (final vehicle in vehicles) {
        final records = maintenanceRecords[vehicle.id] ?? [];
        final recommendations = _recommendationService.generateRecommendations(
          vehicle: vehicle,
          records: records,
          userId: userId,
        );
        allRecommendations.addAll(recommendations);
      }

      // 優先度と日付でソート
      allRecommendations.sort((a, b) {
        final priorityCompare = b.priority.index.compareTo(a.priority.index);
        if (priorityCompare != 0) return priorityCompare;
        return (a.actionDate ?? DateTime.now())
            .compareTo(b.actionDate ?? DateTime.now());
      });

      _notifications = allRecommendations;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 通知を既読にする
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  /// すべての通知を既読にする
  Future<void> markAllAsRead() async {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  /// 通知を削除
  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  /// 通知をクリア
  void clearNotifications() {
    _notifications = [];
    notifyListeners();
  }

  /// ログアウト時のクリーンアップ
  void clear() {
    _notifications = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// 特定の車両の通知を取得
  List<AppNotification> getNotificationsForVehicle(String vehicleId) {
    return _notifications.where((n) => n.vehicleId == vehicleId).toList();
  }

  /// 種類別の通知を取得
  List<AppNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }
}
