import 'package:flutter/foundation.dart';
import '../models/follow.dart';
import '../services/follow_service.dart';

/// SNS ソーシャル通知（いいね / コメント / フォロー）プロバイダー
class SocialNotificationProvider with ChangeNotifier {
  final FollowService _followService;
  String? _userId;

  SocialNotificationProvider({required FollowService followService})
      : _followService = followService;

  List<SocialNotification> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;

  List<SocialNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  void init(String userId) {
    if (_userId == userId) return;
    _userId = userId;
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _followService.getNotifications(userId: uid, limit: 50);
    result.when(
      success: (list) {
        _notifications = list;
        _unreadCount = list.where((n) => !n.isRead).length;
      },
      failure: (err) {
        _error = err.userMessage;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    final result =
        await _followService.markNotificationAsRead(notificationId);
    if (result.isSuccess) {
      _notifications = _notifications.map((n) {
        if (n.id == notificationId) return n.copyWith(isRead: true);
        return n;
      }).toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    final uid = _userId;
    if (uid == null) return;
    final result = await _followService.markAllNotificationsAsRead(uid);
    if (result.isSuccess) {
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    }
  }
}
