import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/post.dart';
import '../models/comment.dart';

/// Service for managing posts and comments
class PostService {
  final FirebaseFirestore _firestore;

  PostService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _firestore.collection('posts');

  CollectionReference<Map<String, dynamic>> get _commentsRef =>
      _firestore.collection('comments');

  CollectionReference<Map<String, dynamic>> get _postLikesRef =>
      _firestore.collection('post_likes');

  CollectionReference<Map<String, dynamic>> get _commentLikesRef =>
      _firestore.collection('comment_likes');

  // ==================== Posts ====================

  /// Create a new post
  Future<Result<Post, AppError>> createPost({
    required String userId,
    String? userDisplayName,
    String? userPhotoUrl,
    required PostCategory category,
    PostVisibility visibility = PostVisibility.public,
    required String content,
    List<PostMedia> media = const [],
    PostVehicleTag? vehicleTag,
  }) async {
    try {
      final now = DateTime.now();
      final hashtags = Post.extractHashtags(content);
      final mentions = Post.extractMentions(content);

      final post = Post(
        id: '',
        userId: userId,
        userDisplayName: userDisplayName,
        userPhotoUrl: userPhotoUrl,
        category: category,
        visibility: visibility,
        content: content,
        media: media,
        vehicleTag: vehicleTag,
        hashtags: hashtags,
        mentionedUserIds: mentions,
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await _postsRef.add(post.toMap());
      return Result.success(post.copyWith(id: docRef.id));
    } catch (e) {
      return Result.failure(AppError.unknown(
        '投稿の作成に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Get a post by ID
  Future<Result<Post, AppError>> getPost(String postId) async {
    try {
      final doc = await _postsRef.doc(postId).get();
      if (!doc.exists) {
        return Result.failure(const AppError.notFound(
          '投稿が見つかりません',
          resourceType: 'Post',
        ));
      }
      return Result.success(Post.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.unknown(
        '投稿の取得に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Update a post
  Future<Result<void, AppError>> updatePost({
    required String postId,
    required String userId,
    String? content,
    PostCategory? category,
    PostVisibility? visibility,
  }) async {
    try {
      final doc = await _postsRef.doc(postId).get();
      if (!doc.exists) {
        return Result.failure(const AppError.notFound(
          '投稿が見つかりません',
          resourceType: 'Post',
        ));
      }

      final post = Post.fromFirestore(doc);
      if (post.userId != userId) {
        return Result.failure(const AppError.permission(
          '投稿を編集する権限がありません',
        ));
      }

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'isEdited': true,
      };

      if (content != null) {
        updates['content'] = content;
        updates['hashtags'] = Post.extractHashtags(content);
        updates['mentionedUserIds'] = Post.extractMentions(content);
      }
      if (category != null) updates['category'] = category.name;
      if (visibility != null) updates['visibility'] = visibility.storageName;

      await _postsRef.doc(postId).update(updates);
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        '投稿の更新に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Delete a post
  Future<Result<void, AppError>> deletePost({
    required String postId,
    required String userId,
  }) async {
    try {
      final doc = await _postsRef.doc(postId).get();
      if (!doc.exists) {
        return Result.failure(const AppError.notFound(
          '投稿が見つかりません',
          resourceType: 'Post',
        ));
      }

      final post = Post.fromFirestore(doc);
      if (post.userId != userId) {
        return Result.failure(const AppError.permission(
          '投稿を削除する権限がありません',
        ));
      }

      await _postsRef.doc(postId).delete();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        '投稿の削除に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Get posts feed (public posts, paginated)
  Future<Result<List<Post>, AppError>> getFeed({
    int limit = 20,
    DocumentSnapshot? startAfter,
    PostCategory? category,
    String? makerId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _postsRef
          .where('visibility', isEqualTo: PostVisibility.public.storageName)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }

      if (makerId != null) {
        query = query.where('vehicleTag.makerId', isEqualTo: makerId);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
      return Result.success(posts);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'フィードの取得に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Get posts by user
  Future<Result<List<Post>, AppError>> getUserPosts({
    required String userId,
    required String viewerId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _postsRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      var posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

      // Filter by visibility if not own posts
      if (userId != viewerId) {
        posts = posts.where((p) => p.visibility == PostVisibility.public).toList();
      }

      return Result.success(posts);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'ユーザーの投稿の取得に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Search posts by hashtag
  Future<Result<List<Post>, AppError>> searchByHashtag({
    required String hashtag,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _postsRef
          .where('hashtags', arrayContains: hashtag)
          .where('visibility', isEqualTo: PostVisibility.public.storageName)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
      return Result.success(posts);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'ハッシュタグ検索に失敗しました',
        originalError: e,
      ));
    }
  }

  // ==================== Likes ====================

  /// Like a post
  Future<Result<void, AppError>> likePost({
    required String postId,
    required String userId,
  }) async {
    try {
      final likeId = '${postId}_$userId';
      final likeDoc = await _postLikesRef.doc(likeId).get();

      if (likeDoc.exists) {
        return Result.success(null); // Already liked
      }

      final batch = _firestore.batch();

      batch.set(_postLikesRef.doc(likeId), {
        'postId': postId,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(_postsRef.doc(postId), {
        'likeCount': FieldValue.increment(1),
      });

      await batch.commit();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'いいねに失敗しました',
        originalError: e,
      ));
    }
  }

  /// Unlike a post
  Future<Result<void, AppError>> unlikePost({
    required String postId,
    required String userId,
  }) async {
    try {
      final likeId = '${postId}_$userId';
      final likeDoc = await _postLikesRef.doc(likeId).get();

      if (!likeDoc.exists) {
        return Result.success(null); // Not liked
      }

      final batch = _firestore.batch();

      batch.delete(_postLikesRef.doc(likeId));

      batch.update(_postsRef.doc(postId), {
        'likeCount': FieldValue.increment(-1),
      });

      await batch.commit();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'いいね解除に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Check if user liked a post
  Future<bool> isPostLiked({
    required String postId,
    required String userId,
  }) async {
    try {
      final likeId = '${postId}_$userId';
      final doc = await _postLikesRef.doc(likeId).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // ==================== Comments ====================

  /// Add a comment to a post
  Future<Result<Comment, AppError>> addComment({
    required String postId,
    required String userId,
    String? userDisplayName,
    String? userPhotoUrl,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final now = DateTime.now();

      final comment = Comment(
        id: '',
        postId: postId,
        userId: userId,
        userDisplayName: userDisplayName,
        userPhotoUrl: userPhotoUrl,
        content: content,
        parentCommentId: parentCommentId,
        createdAt: now,
        updatedAt: now,
      );

      final batch = _firestore.batch();

      final commentRef = _commentsRef.doc();
      batch.set(commentRef, comment.toMap());

      batch.update(_postsRef.doc(postId), {
        'commentCount': FieldValue.increment(1),
      });

      if (parentCommentId != null) {
        batch.update(_commentsRef.doc(parentCommentId), {
          'replyCount': FieldValue.increment(1),
        });
      }

      await batch.commit();
      return Result.success(comment.copyWith(id: commentRef.id));
    } catch (e) {
      return Result.failure(AppError.unknown(
        'コメントの追加に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Get comments for a post
  Future<Result<List<Comment>, AppError>> getComments({
    required String postId,
    int limit = 50,
    DocumentSnapshot? startAfter,
    bool topLevelOnly = true,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _commentsRef
          .where('postId', isEqualTo: postId)
          .orderBy('createdAt', descending: false)
          .limit(limit);

      if (topLevelOnly) {
        query = query.where('parentCommentId', isNull: true);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final comments =
          snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList();
      return Result.success(comments);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'コメントの取得に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Get replies to a comment
  Future<Result<List<Comment>, AppError>> getReplies({
    required String commentId,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _commentsRef
          .where('parentCommentId', isEqualTo: commentId)
          .orderBy('createdAt', descending: false)
          .limit(limit)
          .get();

      final replies =
          snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList();
      return Result.success(replies);
    } catch (e) {
      return Result.failure(AppError.unknown(
        '返信の取得に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Delete a comment
  Future<Result<void, AppError>> deleteComment({
    required String commentId,
    required String userId,
  }) async {
    try {
      final doc = await _commentsRef.doc(commentId).get();
      if (!doc.exists) {
        return Result.failure(const AppError.notFound(
          'コメントが見つかりません',
          resourceType: 'Comment',
        ));
      }

      final comment = Comment.fromFirestore(doc);
      if (comment.userId != userId) {
        return Result.failure(const AppError.permission(
          'コメントを削除する権限がありません',
        ));
      }

      final batch = _firestore.batch();

      batch.delete(_commentsRef.doc(commentId));

      batch.update(_postsRef.doc(comment.postId), {
        'commentCount': FieldValue.increment(-1),
      });

      if (comment.parentCommentId != null) {
        batch.update(_commentsRef.doc(comment.parentCommentId), {
          'replyCount': FieldValue.increment(-1),
        });
      }

      await batch.commit();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'コメントの削除に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Like a comment
  Future<Result<void, AppError>> likeComment({
    required String commentId,
    required String userId,
  }) async {
    try {
      final likeId = '${commentId}_$userId';
      final likeDoc = await _commentLikesRef.doc(likeId).get();

      if (likeDoc.exists) {
        return Result.success(null);
      }

      final batch = _firestore.batch();

      batch.set(_commentLikesRef.doc(likeId), {
        'commentId': commentId,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(_commentsRef.doc(commentId), {
        'likeCount': FieldValue.increment(1),
      });

      await batch.commit();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'いいねに失敗しました',
        originalError: e,
      ));
    }
  }

  /// Increment view count
  Future<void> incrementViewCount(String postId) async {
    try {
      await _postsRef.doc(postId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (_) {
      // Silently fail
    }
  }

  /// Stream of posts for real-time updates
  Stream<List<Post>> watchFeed({
    int limit = 20,
    PostCategory? category,
  }) {
    Query<Map<String, dynamic>> query = _postsRef
        .where('visibility', isEqualTo: PostVisibility.public.storageName)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList());
  }
}
