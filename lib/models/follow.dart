import 'package:cloud_firestore/cloud_firestore.dart';

/// Follow relationship between users
class Follow {
  final String id;
  final String followerId;  // User who follows
  final String followingId; // User being followed
  final DateTime createdAt;

  const Follow({
    required this.id,
    required this.followerId,
    required this.followingId,
    required this.createdAt,
  });

  factory Follow.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Follow(
      id: doc.id,
      followerId: data['followerId'] ?? '',
      followingId: data['followingId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'followerId': followerId,
      'followingId': followingId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Follow && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Follow($followerId → $followingId)';
}

/// User profile summary for social features
class UserProfile {
  final String userId;
  final String? displayName;
  final String? photoUrl;
  final String? bio;
  final int followerCount;
  final int followingCount;
  final int postCount;
  final bool isVerified;
  final DateTime? createdAt;

  const UserProfile({
    required this.userId,
    this.displayName,
    this.photoUrl,
    this.bio,
    this.followerCount = 0,
    this.followingCount = 0,
    this.postCount = 0,
    this.isVerified = false,
    this.createdAt,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfile(
      userId: doc.id,
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      followerCount: data['followerCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      postCount: data['postCount'] ?? 0,
      isVerified: data['isVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'postCount': postCount,
      'isVerified': isVerified,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  UserProfile copyWith({
    String? userId,
    String? displayName,
    String? photoUrl,
    String? bio,
    int? followerCount,
    int? followingCount,
    int? postCount,
    bool? isVerified,
    DateTime? createdAt,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      postCount: postCount ?? this.postCount,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() => 'UserProfile($displayName)';
}

/// Notification types for social features
enum NotificationType {
  like,           // Someone liked your post
  comment,        // Someone commented on your post
  follow,         // Someone followed you
  mention,        // Someone mentioned you
  reply,          // Someone replied to your comment
  ;

  static NotificationType? fromString(String? value) {
    if (value == null) return null;
    return NotificationType.values.where((e) => e.name == value).firstOrNull;
  }

  String get displayName {
    switch (this) {
      case NotificationType.like:
        return 'いいね';
      case NotificationType.comment:
        return 'コメント';
      case NotificationType.follow:
        return 'フォロー';
      case NotificationType.mention:
        return 'メンション';
      case NotificationType.reply:
        return '返信';
    }
  }
}

/// Social notification model
class SocialNotification {
  final String id;
  final String userId;        // Recipient
  final String actorId;       // Who triggered the notification
  final String? actorDisplayName;
  final String? actorPhotoUrl;
  final NotificationType type;
  final String? postId;
  final String? commentId;
  final String? previewText;
  final bool isRead;
  final DateTime createdAt;

  const SocialNotification({
    required this.id,
    required this.userId,
    required this.actorId,
    this.actorDisplayName,
    this.actorPhotoUrl,
    required this.type,
    this.postId,
    this.commentId,
    this.previewText,
    this.isRead = false,
    required this.createdAt,
  });

  factory SocialNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SocialNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      actorId: data['actorId'] ?? '',
      actorDisplayName: data['actorDisplayName'],
      actorPhotoUrl: data['actorPhotoUrl'],
      type: NotificationType.fromString(data['type']) ?? NotificationType.like,
      postId: data['postId'],
      commentId: data['commentId'],
      previewText: data['previewText'],
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'actorId': actorId,
      'actorDisplayName': actorDisplayName,
      'actorPhotoUrl': actorPhotoUrl,
      'type': type.name,
      if (postId != null) 'postId': postId,
      if (commentId != null) 'commentId': commentId,
      if (previewText != null) 'previewText': previewText,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  SocialNotification copyWith({
    String? id,
    String? userId,
    String? actorId,
    String? actorDisplayName,
    String? actorPhotoUrl,
    NotificationType? type,
    String? postId,
    String? commentId,
    String? previewText,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return SocialNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      actorId: actorId ?? this.actorId,
      actorDisplayName: actorDisplayName ?? this.actorDisplayName,
      actorPhotoUrl: actorPhotoUrl ?? this.actorPhotoUrl,
      type: type ?? this.type,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      previewText: previewText ?? this.previewText,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get notification message
  String get message {
    switch (type) {
      case NotificationType.like:
        return '${actorDisplayName ?? 'ユーザー'}があなたの投稿にいいねしました';
      case NotificationType.comment:
        return '${actorDisplayName ?? 'ユーザー'}があなたの投稿にコメントしました';
      case NotificationType.follow:
        return '${actorDisplayName ?? 'ユーザー'}があなたをフォローしました';
      case NotificationType.mention:
        return '${actorDisplayName ?? 'ユーザー'}があなたをメンションしました';
      case NotificationType.reply:
        return '${actorDisplayName ?? 'ユーザー'}があなたのコメントに返信しました';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocialNotification &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SocialNotification(${type.name})';
}
