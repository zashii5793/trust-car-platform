import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../models/vehicle.dart';
import '../models/maintenance_record.dart';
import '../services/recommendation_service.dart';
import '../services/firebase_service.dart';
import '../services/inspection_reminder_service.dart';
import '../services/notification_state_store.dart';
import '../core/error/app_error.dart';

/// 通知状態管理Provider
class NotificationProvider extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final RecommendationService _recommendationService;
  final InspectionReminderService? _inspectionReminderService;

  /// Persists read/dismissed suggestion ids so the user's actions survive app
  /// restarts. Optional — when null the provider behaves as in-memory only.
  final NotificationStateStore? _stateStore;

  NotificationProvider({
    required FirebaseService firebaseService,
    required RecommendationService recommendationService,
    InspectionReminderService? inspectionReminderService,
    NotificationStateStore? stateStore,
  })  : _firebaseService = firebaseService,
        _recommendationService = recommendationService,
        _inspectionReminderService = inspectionReminderService,
        _stateStore = stateStore;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  AppError? _error;

  // Persisted suggestion state (deterministic notification ids).
  Set<String> _readIds = {};
  Set<String> _dismissedIds = {};
  bool _stateLoaded = false;

  /// Loads persisted read/dismissed ids once (no-op if no store configured).
  Future<void> _ensureStateLoaded() async {
    final store = _stateStore;
    if (_stateLoaded || store == null) {
      _stateLoaded = true;
      return;
    }
    try {
      _readIds = await store.loadReadIds();
      _dismissedIds = await store.loadDismissedIds();
    } catch (_) {
      // Persistence is best-effort; fall back to in-memory only.
    }
    _stateLoaded = true;
  }

  /// 通知一覧
  List<AppNotification> get notifications => _notifications;

  /// 未読通知数
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// 高優先度の未読通知数
  int get highPriorityUnreadCount => _notifications
      .where((n) => !n.isRead && n.priority == NotificationPriority.high)
      .length;

  /// ホーム画面「AIからの提案」用：高・中優先度かつシステム通知を除外した上位3件
  /// 優先度順（high → medium）にソート済み
  List<AppNotification> get topSuggestions {
    const priorityOrder = {
      NotificationPriority.high: 0,
      NotificationPriority.medium: 1,
      NotificationPriority.low: 2,
    };
    final filtered = _notifications
        .where(
          (n) =>
              n.type != NotificationType.system &&
              (n.priority == NotificationPriority.high ||
                  n.priority == NotificationPriority.medium),
        )
        .toList()
      ..sort(
        (a, b) => (priorityOrder[a.priority] ?? 2)
            .compareTo(priorityOrder[b.priority] ?? 2),
      );
    return filtered.take(3).toList();
  }

  /// ローディング状態
  bool get isLoading => _isLoading;

  /// エラー
  AppError? get error => _error;

  /// エラーメッセージ（UI表示用）
  String? get errorMessage => _error?.userMessage;

  /// リトライ可能かどうか
  bool get isRetryable => _error?.isRetryable ?? false;

  /// 車両リストから通知を生成（整備記録も自動取得）
  /// バッチ取得でN+1クエリを最適化
  Future<void> generateNotificationsForVehicles(List<Vehicle> vehicles) async {
    final userId = _firebaseService.currentUserId;
    if (userId == null || vehicles.isEmpty) return;

    // Schedule OS-level inspection reminders so the user is notified even
    // when the app stays closed. Fire-and-forget: scheduling failures must
    // never block in-app notification generation.
    _inspectionReminderService
        ?.scheduleForVehicles(vehicles)
        .catchError((_) {});

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 全車両の整備記録を一括取得（N+1クエリ最適化）
      final vehicleIds = vehicles.map((v) => v.id).toList();
      final result = await _firebaseService.getMaintenanceRecordsForVehicles(
        vehicleIds,
        limitPerVehicle: 20,
      );

      final maintenanceRecords = result.getOrElse({});

      // レコメンドを生成
      await generateRecommendations(
        vehicles: vehicles,
        maintenanceRecords: maintenanceRecords,
      );
    } catch (e) {
      _error = ServerError('通知の生成に失敗しました: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// エラーをクリア
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 車両リストからレコメンドを生成して通知を更新
  Future<void> generateRecommendations({
    required List<Vehicle> vehicles,
    required Map<String, List<MaintenanceRecord>> maintenanceRecords,
  }) async {
    final userId = _firebaseService.currentUserId;
    if (userId == null) return;

    await _ensureStateLoaded();

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

      // Apply persisted state: drop dismissed, mark previously-read as read so
      // suggestions the user already handled don't reappear as unread.
      _notifications = allRecommendations
          .where((n) => !_dismissedIds.contains(n.id))
          .map((n) => _readIds.contains(n.id) ? n.copyWith(isRead: true) : n)
          .toList();
    } catch (e) {
      _error = ServerError('レコメンドの生成に失敗しました: $e');
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
    _readIds.add(notificationId);
    _persistRead();
  }

  /// すべての通知を既読にする
  Future<void> markAllAsRead() async {
    _notifications =
        _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
    _readIds.addAll(_notifications.map((n) => n.id));
    _persistRead();
  }

  /// 通知を削除
  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
    _dismissedIds.add(notificationId);
    final store = _stateStore;
    if (store != null) {
      store.saveDismissedIds(_dismissedIds).catchError((_) {});
    }
  }

  /// Fire-and-forget persistence of the read-id set.
  void _persistRead() {
    final store = _stateStore;
    if (store != null) {
      store.saveReadIds(_readIds).catchError((_) {});
    }
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
    // Reset in-memory persisted state so the next user reloads fresh.
    _readIds = {};
    _dismissedIds = {};
    _stateLoaded = false;
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
