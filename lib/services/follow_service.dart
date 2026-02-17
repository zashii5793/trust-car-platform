import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/follow.dart';

/// Service for managing follow relationships and notifications
class FollowService {
  final FirebaseFirestore _firestore;

  FollowService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _followsRef =>
      _firestore.collection('follows');

  CollectionReference<Map<String, dynamic>> get _userProfilesRef =>
      _firestore.collection('user_profiles');

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('social_notifications');

  // ==================== Follow ====================

  /// Follow a user
  Future<Result<void, AppError>> followUser({
    required String followerId,
    required String followingId,
  }) async {
    if (followerId == followingId) {
      return Result.failure(const AppError.validation(
        '自分自身をフォローすることはできません',
        field: 'followingId',
      ));
    }

    try {
      final followId = '${followerId}_$followingId';
      final existingFollow = await _followsRef.doc(followId).get();

      if (existingFollow.exists) {
        return Result.success(null); // Already following
      }

      final batch = _firestore.batch();

      // Create follow relationship
      batch.set(_followsRef.doc(followId), {
        'followerId': followerId,
        'followingId': followingId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update follower's following count
      batch.set(
        _userProfilesRef.doc(followerId),
        {'followingCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      // Update following's follower count
      batch.set(
        _userProfilesRef.doc(followingId),
        {'followerCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      await batch.commit();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'フォローに失敗しました',
        originalError: e,
      ));
    }
  }

  /// Unfollow a user
  Future<Result<void, AppError>> unfollowUser({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final followId = '${followerId}_$followingId';
      final existingFollow = await _followsRef.doc(followId).get();

      if (!existingFollow.exists) {
        return Result.success(null); // Not following
      }

      final batch = _firestore.batch();

      // Delete follow relationship
      batch.delete(_followsRef.doc(followId));

      // Update follower's following count
      batch.set(
        _userProfilesRef.doc(followerId),
        {'followingCount': FieldValue.increment(-1)},
        SetOptions(merge: true),
      );

      // Update following's follower count
      batch.set(
        _userProfilesRef.doc(followingId),
        {'followerCount': FieldValue.increment(-1)},
        SetOptions(merge: true),
      );

      await batch.commit();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'フォロー解除に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Check if user A is following user B
  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final followId = '${followerId}_$followingId';
      final doc = await _followsRef.doc(followId).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Get followers of a user
  Future<Result<List<Follow>, AppError>> getFollowers({
    required String userId,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _followsRef
          .where('followingId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final follows =
          snapshot.docs.map((doc) => Follow.fromFirestore(doc)).toList();
      return Result.success(follows);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'フォロワーの取得に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Get users that a user is following
  Future<Result<List<Follow>, AppError>> getFollowing({
    required String userId,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _followsRef
          .where('followerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final follows =
          snapshot.docs.map((doc) => Follow.fromFirestore(doc)).toList();
      return Result.success(follows);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'フォロー中の取得に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Get follower IDs for timeline filtering
  Future<List<String>> getFollowingIds(String userId) async {
    try {
      final snapshot = await _followsRef
          .where('followerId', isEqualTo: userId)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['followingId'] as String)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ==================== User Profiles ====================

  /// Get user profile
  Future<Result<UserProfile, AppError>> getUserProfile(String userId) async {
    try {
      final doc = await _userProfilesRef.doc(userId).get();
      if (!doc.exists) {
        // Return empty profile if not exists
        return Result.success(UserProfile(userId: userId));
      }
      return Result.success(UserProfile.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.unknown(
        'プロフィールの取得に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Update user profile
  Future<Result<void, AppError>> updateUserProfile({
    required String userId,
    String? displayName,
    String? photoUrl,
    String? bio,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (displayName != null) updates['displayName'] = displayName;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      if (bio != null) updates['bio'] = bio;

      if (updates.isEmpty) {
        return Result.success(null);
      }

      await _userProfilesRef.doc(userId).set(updates, SetOptions(merge: true));
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'プロフィールの更新に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Get multiple user profiles
  Future<Result<List<UserProfile>, AppError>> getUserProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) {
      return Result.success([]);
    }

    try {
      // Firestore限制: whereIn最多10個
      final chunks = <List<String>>[];
      for (var i = 0; i < userIds.length; i += 10) {
        chunks.add(userIds.sublist(
          i,
          i + 10 > userIds.length ? userIds.length : i + 10,
        ));
      }

      final profiles = <UserProfile>[];
      for (final chunk in chunks) {
        final snapshot = await _userProfilesRef
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        profiles.addAll(
          snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)),
        );
      }

      return Result.success(profiles);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'プロフィールの取得に失敗しました',
        originalError: e,
      ));
    }
  }

  // ==================== Notifications ====================

  /// Create a notification
  Future<Result<void, AppError>> createNotification({
    required String userId,
    required String actorId,
    String? actorDisplayName,
    String? actorPhotoUrl,
    required NotificationType type,
    String? postId,
    String? commentId,
    String? previewText,
  }) async {
    // Don't notify yourself
    if (userId == actorId) {
      return Result.success(null);
    }

    try {
      await _notificationsRef.add({
        'userId': userId,
        'actorId': actorId,
        'actorDisplayName': actorDisplayName,
        'actorPhotoUrl': actorPhotoUrl,
        'type': type.name,
        if (postId != null) 'postId': postId,
        if (commentId != null) 'commentId': commentId,
        if (previewText != null) 'previewText': previewText,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        '通知の作成に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Get notifications for a user
  Future<Result<List<SocialNotification>, AppError>> getNotifications({
    required String userId,
    int limit = 50,
    DocumentSnapshot? startAfter,
    bool unreadOnly = false,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _notificationsRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (unreadOnly) {
        query = query.where('isRead', isEqualTo: false);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final notifications = snapshot.docs
          .map((doc) => SocialNotification.fromFirestore(doc))
          .toList();
      return Result.success(notifications);
    } catch (e) {
      return Result.failure(AppError.unknown(
        '通知の取得に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Mark notification as read
  Future<Result<void, AppError>> markNotificationAsRead(
    String notificationId,
  ) async {
    try {
      await _notificationsRef.doc(notificationId).update({'isRead': true});
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        '通知の更新に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Mark all notifications as read
  Future<Result<void, AppError>> markAllNotificationsAsRead(
    String userId,
  ) async {
    try {
      final snapshot = await _notificationsRef
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        '通知の更新に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final snapshot = await _notificationsRef
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Stream of unread notification count
  Stream<int> watchUnreadNotificationCount(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  /// Stream of notifications
  Stream<List<SocialNotification>> watchNotifications({
    required String userId,
    int limit = 50,
  }) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SocialNotification.fromFirestore(doc))
            .toList());
  }
}
