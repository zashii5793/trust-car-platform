import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../models/vehicle.dart';
import '../models/maintenance_record.dart';
import '../services/recommendation_service.dart';
import '../services/firebase_service.dart';
import '../services/inspection_reminder_service.dart';
import '../services/notification_state_store.dart';
import '../services/inquiry_maintenance_importer.dart';
import '../services/shop_detail_inbox_service.dart';
import '../core/error/app_error.dart';

/// 通知状態管理Provider
class NotificationProvider extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final RecommendationService _recommendationService;
  final InspectionReminderService? _inspectionReminderService;

  /// Persists read/dismissed suggestion ids so the user's actions survive app
  /// restarts. Optional — when null the provider behaves as in-memory only.
  final NotificationStateStore? _stateStore;

  /// Maintenance details shops sent to the user. Optional — when null no
  /// shop-detail notifications are produced.
  final ShopDetailInboxService? _detailInbox;

  NotificationProvider({
    required FirebaseService firebaseService,
    required RecommendationService recommendationService,
    InspectionReminderService? inspectionReminderService,
    NotificationStateStore? stateStore,
    ShopDetailInboxService? detailInbox,
  })  : _firebaseService = firebaseService,
        _recommendationService = recommendationService,
        _inspectionReminderService = inspectionReminderService,
        _stateStore = stateStore,
        _detailInbox = detailInbox;

  /// Generated suggestions (inspection, maintenance, ...).
  List<AppNotification> _notifications = [];

  /// Shop-sent details not yet added to the records, newest first.
  List<ReceivedShopDetail> _pendingShopDetails = [];

  /// Notifications for [_pendingShopDetails] (dismissed ones left out).
  List<AppNotification> _detailNotifications = [];
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

  /// 通知一覧（店から届いた明細を先頭に）
  List<AppNotification> get notifications =>
      [..._detailNotifications, ..._notifications];

  /// 店から届いて、まだ記録に追加していない明細（ホームのカード用）。
  List<ReceivedShopDetail> get pendingShopDetails => _pendingShopDetails;

  /// The shop detail behind a notification, or null for other notifications.
  ReceivedShopDetail? shopDetailFor(AppNotification notification) {
    final meta = notification.metadata;
    if (meta?['kind'] != shopDetailKind) return null;
    for (final d in _pendingShopDetails) {
      if (d.message.id == meta?['messageId']) return d;
    }
    return null;
  }

  /// Metadata `kind` of a shop-detail notification.
  static const String shopDetailKind = 'shopDetail';

  /// Deterministic ID, so read / dismissed state survives reloads.
  static String shopDetailNotificationId(String messageId) =>
      'shop_detail_$messageId';

  /// 店から届いた明細を読み直す（未取り込みの件数と通知）。
  ///
  /// Shown as `system` notifications so existing screens that switch on the
  /// type need no change, and kept out of [topSuggestions].
  Future<void> refreshShopDetails() async {
    final inbox = _detailInbox;
    final userId = _firebaseService.currentUserId;
    if (inbox == null || userId == null || userId.isEmpty) return;
    await _ensureStateLoaded();

    final result = await inbox.pendingDetails(userId);
    final details = result.valueOrNull;
    if (details == null) return; // keep what we had; not worth an error

    _pendingShopDetails = details;
    _detailNotifications = [
      for (final d in details)
        if (!_dismissedIds.contains(shopDetailNotificationId(d.message.id)))
          _toNotification(d, userId),
    ];
    notifyListeners();
  }

  AppNotification _toNotification(ReceivedShopDetail d, String userId) {
    final id = shopDetailNotificationId(d.message.id);
    final p = d.payload;
    final what = [
      p.vehicleDisplay ?? d.inquiry.vehicleDisplay,
      p.title.isEmpty ? null : p.title,
      if (p.cost > 0) formatYen(p.cost),
    ].whereType<String>().join('・');
    return AppNotification(
      id: id,
      userId: userId,
      vehicleId: p.vehicleId,
      type: NotificationType.system,
      title: '${d.shopName}から整備明細が届きました',
      message: what.isEmpty ? '「記録に追加」で整備記録に入れられます' : what,
      reason: '店が出した記録です。記録に追加すると、金額・日付・作業内容は変えられません。',
      priority: NotificationPriority.high,
      isRead: _readIds.contains(id),
      createdAt: d.message.sentAt,
      metadata: {
        'kind': shopDetailKind,
        'inquiryId': d.inquiry.id,
        'messageId': d.message.id,
      },
    );
  }

  /// 未読通知数
  int get unreadCount => notifications.where((n) => !n.isRead).length;

  /// 高優先度の未読通知数
  int get highPriorityUnreadCount => notifications
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
    // Shop details do not depend on the cars; load them alongside.
    if (userId != null) unawaited(refreshShopDetails());
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
    if (_setRead(notificationId, true)) notifyListeners();
    _readIds.add(notificationId);
    _persistRead();
  }

  /// 通知を未読に戻す。
  ///
  /// カードをタップすると既読になる設計なので、取り消せないと
  /// 「読もうと思っていた通知」を戻す手段が無くなる。
  Future<void> markAsUnread(String notificationId) async {
    if (_setRead(notificationId, false)) notifyListeners();
    _readIds.remove(notificationId);
    _persistRead();
  }

  /// すべての通知を既読にする
  Future<void> markAllAsRead() async {
    _notifications =
        _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _detailNotifications =
        _detailNotifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
    _readIds.addAll(notifications.map((n) => n.id));
    _persistRead();
  }

  /// 通知を削除
  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _detailNotifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
    _dismissedIds.add(notificationId);
    final store = _stateStore;
    if (store != null) {
      store.saveDismissedIds(_dismissedIds).catchError((_) {});
    }
  }

  /// Sets the read flag in whichever list holds [id]. True when found.
  bool _setRead(String id, bool isRead) {
    for (final list in [_notifications, _detailNotifications]) {
      final index = list.indexWhere((n) => n.id == id);
      if (index != -1) {
        list[index] = list[index].copyWith(isRead: isRead);
        return true;
      }
    }
    return false;
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
    _pendingShopDetails = [];
    _detailNotifications = [];
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
