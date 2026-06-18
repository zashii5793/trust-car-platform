import 'package:cloud_firestore/cloud_firestore.dart';

/// A lightweight comment on an [AccessoryShowcase] post.
///
/// Intentionally minimal: users share a good part/accessory via a showcase and
/// can discuss it with comments. No likes, replies, or moderation — that scope
/// is deliberately out (the C2C marketplace was frozen in favour of this).
class ShowcaseComment {
  final String id;
  final String showcaseId;
  final String userId;
  final String? userDisplayName;
  final String? userPhotoUrl;
  final String content;
  final DateTime createdAt;

  const ShowcaseComment({
    required this.id,
    required this.showcaseId,
    required this.userId,
    this.userDisplayName,
    this.userPhotoUrl,
    required this.content,
    required this.createdAt,
  });

  factory ShowcaseComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ShowcaseComment(
      id: doc.id,
      showcaseId: data['showcaseId'] ?? '',
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'],
      userPhotoUrl: data['userPhotoUrl'],
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'showcaseId': showcaseId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userPhotoUrl': userPhotoUrl,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ShowcaseComment copyWith({String? id}) {
    return ShowcaseComment(
      id: id ?? this.id,
      showcaseId: showcaseId,
      userId: userId,
      userDisplayName: userDisplayName,
      userPhotoUrl: userPhotoUrl,
      content: content,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShowcaseComment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
