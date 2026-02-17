import 'package:cloud_firestore/cloud_firestore.dart';

/// Post category types
enum PostCategory {
  general,      // 一般
  carLife,      // カーライフ
  maintenance,  // メンテナンス
  customization,// カスタム
  drive,        // ドライブ
  review,       // レビュー
  question,     // 質問
  event,        // イベント
  sale,         // 売買
  ;

  static PostCategory? fromString(String? value) {
    if (value == null) return null;
    return PostCategory.values.where((e) => e.name == value).firstOrNull;
  }

  String get displayName {
    switch (this) {
      case PostCategory.general:
        return '一般';
      case PostCategory.carLife:
        return 'カーライフ';
      case PostCategory.maintenance:
        return 'メンテナンス';
      case PostCategory.customization:
        return 'カスタム';
      case PostCategory.drive:
        return 'ドライブ';
      case PostCategory.review:
        return 'レビュー';
      case PostCategory.question:
        return '質問';
      case PostCategory.event:
        return 'イベント';
      case PostCategory.sale:
        return '売買';
    }
  }
}

/// Post visibility settings
enum PostVisibility {
  public,       // 全体公開
  followers,    // フォロワーのみ
  private_,     // 自分のみ
  ;

  static PostVisibility? fromString(String? value) {
    if (value == null) return null;
    if (value == 'private') return PostVisibility.private_;
    return PostVisibility.values.where((e) => e.name == value).firstOrNull;
  }

  String get displayName {
    switch (this) {
      case PostVisibility.public:
        return '全体公開';
      case PostVisibility.followers:
        return 'フォロワーのみ';
      case PostVisibility.private_:
        return '自分のみ';
    }
  }

  String get storageName {
    if (this == PostVisibility.private_) return 'private';
    return name;
  }
}

/// Media attachment for posts
class PostMedia {
  final String url;
  final String type; // 'image', 'video'
  final String? thumbnailUrl;
  final int? width;
  final int? height;

  const PostMedia({
    required this.url,
    required this.type,
    this.thumbnailUrl,
    this.width,
    this.height,
  });

  factory PostMedia.fromMap(Map<String, dynamic> map) {
    return PostMedia(
      url: map['url'] ?? '',
      type: map['type'] ?? 'image',
      thumbnailUrl: map['thumbnailUrl'],
      width: map['width'],
      height: map['height'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'type': type,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
    };
  }

  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';
}

/// Vehicle tag for posts (which vehicle this post is about)
class PostVehicleTag {
  final String? vehicleId;
  final String? makerId;
  final String? makerName;
  final String? modelId;
  final String? modelName;
  final int? year;

  const PostVehicleTag({
    this.vehicleId,
    this.makerId,
    this.makerName,
    this.modelId,
    this.modelName,
    this.year,
  });

  factory PostVehicleTag.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PostVehicleTag();
    return PostVehicleTag(
      vehicleId: map['vehicleId'],
      makerId: map['makerId'],
      makerName: map['makerName'],
      modelId: map['modelId'],
      modelName: map['modelName'],
      year: map['year'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (vehicleId != null) 'vehicleId': vehicleId,
      if (makerId != null) 'makerId': makerId,
      if (makerName != null) 'makerName': makerName,
      if (modelId != null) 'modelId': modelId,
      if (modelName != null) 'modelName': modelName,
      if (year != null) 'year': year,
    };
  }

  String? get displayName {
    if (makerName == null && modelName == null) return null;
    final parts = <String>[];
    if (makerName != null) parts.add(makerName!);
    if (modelName != null) parts.add(modelName!);
    if (year != null) parts.add('($year年式)');
    return parts.join(' ');
  }

  bool get isEmpty => vehicleId == null && makerId == null && modelId == null && makerName == null && modelName == null;
}

/// Social media post model
class Post {
  final String id;
  final String userId;
  final String? userDisplayName;
  final String? userPhotoUrl;
  final PostCategory category;
  final PostVisibility visibility;
  final String content;
  final List<PostMedia> media;
  final PostVehicleTag? vehicleTag;
  final List<String> hashtags;
  final List<String> mentionedUserIds;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int viewCount;
  final bool isEdited;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Post({
    required this.id,
    required this.userId,
    this.userDisplayName,
    this.userPhotoUrl,
    required this.category,
    this.visibility = PostVisibility.public,
    required this.content,
    this.media = const [],
    this.vehicleTag,
    this.hashtags = const [],
    this.mentionedUserIds = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.viewCount = 0,
    this.isEdited = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'],
      userPhotoUrl: data['userPhotoUrl'],
      category: PostCategory.fromString(data['category']) ?? PostCategory.general,
      visibility: PostVisibility.fromString(data['visibility']) ?? PostVisibility.public,
      content: data['content'] ?? '',
      media: (data['media'] as List<dynamic>?)
          ?.map((e) => PostMedia.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      vehicleTag: data['vehicleTag'] != null
          ? PostVehicleTag.fromMap(data['vehicleTag'] as Map<String, dynamic>)
          : null,
      hashtags: List<String>.from(data['hashtags'] ?? []),
      mentionedUserIds: List<String>.from(data['mentionedUserIds'] ?? []),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      isEdited: data['isEdited'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userPhotoUrl': userPhotoUrl,
      'category': category.name,
      'visibility': visibility.storageName,
      'content': content,
      'media': media.map((e) => e.toMap()).toList(),
      if (vehicleTag != null) 'vehicleTag': vehicleTag!.toMap(),
      'hashtags': hashtags,
      'mentionedUserIds': mentionedUserIds,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'viewCount': viewCount,
      'isEdited': isEdited,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Post copyWith({
    String? id,
    String? userId,
    String? userDisplayName,
    String? userPhotoUrl,
    PostCategory? category,
    PostVisibility? visibility,
    String? content,
    List<PostMedia>? media,
    PostVehicleTag? vehicleTag,
    List<String>? hashtags,
    List<String>? mentionedUserIds,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? viewCount,
    bool? isEdited,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      category: category ?? this.category,
      visibility: visibility ?? this.visibility,
      content: content ?? this.content,
      media: media ?? this.media,
      vehicleTag: vehicleTag ?? this.vehicleTag,
      hashtags: hashtags ?? this.hashtags,
      mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      viewCount: viewCount ?? this.viewCount,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if post has media
  bool get hasMedia => media.isNotEmpty;

  /// Check if post has vehicle tag
  bool get hasVehicleTag => vehicleTag != null && !vehicleTag!.isEmpty;

  /// Extract hashtags from content (supports Japanese characters)
  static List<String> extractHashtags(String content) {
    // Match # followed by word characters including Japanese
    final regex = RegExp(r'#([\w\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]+)');
    return regex.allMatches(content).map((m) => m.group(1)!).toList();
  }

  /// Extract mentioned user IDs from content
  static List<String> extractMentions(String content) {
    // Match @ followed by word characters (user IDs are typically alphanumeric)
    final regex = RegExp(r'@([\w]+)');
    return regex.allMatches(content).map((m) => m.group(1)!).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Post(${content.length > 30 ? '${content.substring(0, 30)}...' : content})';
}

/// Like record for posts
class PostLike {
  final String id;
  final String postId;
  final String userId;
  final DateTime createdAt;

  const PostLike({
    required this.id,
    required this.postId,
    required this.userId,
    required this.createdAt,
  });

  factory PostLike.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PostLike(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
