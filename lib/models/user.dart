import 'package:cloud_firestore/cloud_firestore.dart';

/// ユーザーモデル
class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final NotificationSettings notificationSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    NotificationSettings? notificationSettings,
    required this.createdAt,
    required this.updatedAt,
  }) : notificationSettings = notificationSettings ?? NotificationSettings();

  /// Firestore ドキュメントからモデルを生成
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      notificationSettings: data['notificationSettings'] != null
          ? NotificationSettings.fromMap(data['notificationSettings'])
          : NotificationSettings(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Firestore に保存するための Map に変換
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'notificationSettings': notificationSettings.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// イミュータブルな更新用
  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    NotificationSettings? notificationSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 通知設定
class NotificationSettings {
  final bool pushEnabled;
  final bool inspectionReminder;
  final bool maintenanceReminder;
  final bool oilChangeReminder;
  final bool tireChangeReminder;
  final bool carInspectionReminder;

  NotificationSettings({
    this.pushEnabled = true,
    this.inspectionReminder = true,
    this.maintenanceReminder = true,
    this.oilChangeReminder = true,
    this.tireChangeReminder = true,
    this.carInspectionReminder = true,
  });

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      pushEnabled: map['pushEnabled'] ?? true,
      inspectionReminder: map['inspectionReminder'] ?? true,
      maintenanceReminder: map['maintenanceReminder'] ?? true,
      oilChangeReminder: map['oilChangeReminder'] ?? true,
      tireChangeReminder: map['tireChangeReminder'] ?? true,
      carInspectionReminder: map['carInspectionReminder'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pushEnabled': pushEnabled,
      'inspectionReminder': inspectionReminder,
      'maintenanceReminder': maintenanceReminder,
      'oilChangeReminder': oilChangeReminder,
      'tireChangeReminder': tireChangeReminder,
      'carInspectionReminder': carInspectionReminder,
    };
  }

  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? inspectionReminder,
    bool? maintenanceReminder,
    bool? oilChangeReminder,
    bool? tireChangeReminder,
    bool? carInspectionReminder,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      inspectionReminder: inspectionReminder ?? this.inspectionReminder,
      maintenanceReminder: maintenanceReminder ?? this.maintenanceReminder,
      oilChangeReminder: oilChangeReminder ?? this.oilChangeReminder,
      tireChangeReminder: tireChangeReminder ?? this.tireChangeReminder,
      carInspectionReminder: carInspectionReminder ?? this.carInspectionReminder,
    );
  }
}
