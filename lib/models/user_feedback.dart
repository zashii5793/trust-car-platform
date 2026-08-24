import 'package:cloud_firestore/cloud_firestore.dart';

/// What the user is telling us.
enum FeedbackType {
  request,
  bug,
  other;

  String get displayName {
    switch (this) {
      case FeedbackType.request:
        return 'こうしてほしい';
      case FeedbackType.bug:
        return 'うまく動かない';
      case FeedbackType.other:
        return 'その他';
    }
  }

  String get storageName => name;

  /// Unknown values fall back to [other] so a type added later by the server
  /// never crashes an older client.
  static FeedbackType fromStorage(String? value) {
    return FeedbackType.values.firstWhere(
      (t) => t.storageName == value,
      orElse: () => FeedbackType.other,
    );
  }
}

/// A message from a user — a request, a bug report, or anything else.
///
/// The only contact route used to be "email support@trustcar.jp", which meant
/// small observations ("the inspection reminder comes too late") never reached
/// us: nobody writes an email for that. This is the in-app path.
///
/// Named [UserFeedback] rather than `Feedback` to avoid colliding with
/// Flutter's own `Feedback` helper in material.
class UserFeedback {
  final String id;
  final String userId;
  final FeedbackType type;
  final String message;

  /// App version and platform, so a bug report can be tied to a build.
  final String appVersion;
  final String platform;

  /// Which screen the user was on. Optional — sent when we know it.
  final String? screen;

  /// Where to reply. Optional: the account email is not always reachable.
  final String? contactEmail;

  final DateTime createdAt;

  const UserFeedback({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.appVersion,
    required this.platform,
    this.screen,
    this.contactEmail,
    required this.createdAt,
  });

  /// 長文をそのまま受けても読み切れないので上限を置く。
  /// 詳細が要るときは返信して聞く前提。
  static const int maxMessageLength = 2000;

  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  /// Returns an error message, or null when the input is acceptable.
  static String? validateMessage(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '内容を入力してください';
    if (text.length > maxMessageLength) {
      return '$maxMessageLength文字以内で入力してください';
    }
    return null;
  }

  /// Optional field: empty is fine, but a malformed address is not.
  static String? validateContactEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (!_emailPattern.hasMatch(text)) {
      return 'メールアドレスの形式で入力してください';
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.storageName,
      'message': message,
      'appVersion': appVersion,
      'platform': platform,
      if (screen != null) 'screen': screen,
      if (contactEmail != null) 'contactEmail': contactEmail,
      // 受付済みだが未対応。運用側で triage する。
      'status': 'open',
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserFeedback.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserFeedback(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: FeedbackType.fromStorage(data['type'] as String?),
      message: data['message'] ?? '',
      appVersion: data['appVersion'] ?? '',
      platform: data['platform'] ?? '',
      screen: data['screen'],
      contactEmail: data['contactEmail'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
