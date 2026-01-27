import 'package:cloud_firestore/cloud_firestore.dart';

/// 通知の種類
enum NotificationType {
  /// メンテナンス推奨
  maintenanceRecommendation,

  /// 車検リマインダー
  inspectionReminder,

  /// 消耗品交換推奨
  partsReplacement,

  /// システム通知
  system,
}

/// 通知の優先度
enum NotificationPriority {
  low,
  medium,
  high,
}

/// アプリ内通知モデル
class AppNotification {
  final String id;
  final String userId;
  final String? vehicleId;
  final NotificationType type;
  final String title;
  final String message;
  final NotificationPriority priority;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? actionDate;
  final Map<String, dynamic>? metadata;

  const AppNotification({
    required this.id,
    required this.userId,
    this.vehicleId,
    required this.type,
    required this.title,
    required this.message,
    this.priority = NotificationPriority.medium,
    this.isRead = false,
    required this.createdAt,
    this.actionDate,
    this.metadata,
  });

  /// Firestoreドキュメントからの変換
  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      vehicleId: data['vehicleId'],
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.system,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => NotificationPriority.medium,
      ),
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actionDate: (data['actionDate'] as Timestamp?)?.toDate(),
      metadata: data['metadata'],
    );
  }

  /// Firestoreへの変換
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'vehicleId': vehicleId,
      'type': type.name,
      'title': title,
      'message': message,
      'priority': priority.name,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'actionDate': actionDate != null ? Timestamp.fromDate(actionDate!) : null,
      'metadata': metadata,
    };
  }

  /// 既読状態を更新したコピーを作成
  AppNotification copyWith({
    String? id,
    String? userId,
    String? vehicleId,
    NotificationType? type,
    String? title,
    String? message,
    NotificationPriority? priority,
    bool? isRead,
    DateTime? createdAt,
    DateTime? actionDate,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vehicleId: vehicleId ?? this.vehicleId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      actionDate: actionDate ?? this.actionDate,
      metadata: metadata ?? this.metadata,
    );
  }

  /// 通知タイプの表示名
  String get typeDisplayName {
    switch (type) {
      case NotificationType.maintenanceRecommendation:
        return 'メンテナンス推奨';
      case NotificationType.inspectionReminder:
        return '車検リマインダー';
      case NotificationType.partsReplacement:
        return '消耗品交換';
      case NotificationType.system:
        return 'お知らせ';
    }
  }
}
