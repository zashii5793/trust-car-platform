import 'package:cloud_firestore/cloud_firestore.dart';

/// Comment model for posts
class Comment {
  final String id;
  final String postId;
  final String userId;
  final String? userDisplayName;
  final String? userPhotoUrl;
  final String content;
  final String? parentCommentId; // For nested replies
  final int likeCount;
  final int replyCount;
  final bool isEdited;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    this.userDisplayName,
    this.userPhotoUrl,
    required this.content,
    this.parentCommentId,
    this.likeCount = 0,
    this.replyCount = 0,
    this.isEdited = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Comment(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'],
      userPhotoUrl: data['userPhotoUrl'],
      content: data['content'] ?? '',
      parentCommentId: data['parentCommentId'],
      likeCount: data['likeCount'] ?? 0,
      replyCount: data['replyCount'] ?? 0,
      isEdited: data['isEdited'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userPhotoUrl': userPhotoUrl,
      'content': content,
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
      'likeCount': likeCount,
      'replyCount': replyCount,
      'isEdited': isEdited,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userDisplayName,
    String? userPhotoUrl,
    String? content,
    String? parentCommentId,
    int? likeCount,
    int? replyCount,
    bool? isEdited,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      content: content ?? this.content,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if this is a reply to another comment
  bool get isReply => parentCommentId != null;

  /// Check if this is a top-level comment
  bool get isTopLevel => parentCommentId == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Comment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Comment(${content.length > 30 ? '${content.substring(0, 30)}...' : content})';
}

/// Like record for comments
class CommentLike {
  final String id;
  final String commentId;
  final String userId;
  final DateTime createdAt;

  const CommentLike({
    required this.id,
    required this.commentId,
    required this.userId,
    required this.createdAt,
  });

  factory CommentLike.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CommentLike(
      id: doc.id,
      commentId: data['commentId'] ?? '',
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
