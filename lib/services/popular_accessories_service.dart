import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/accessory_showcase.dart';
import '../models/showcase_comment.dart';
import '../models/comment_report.dart';

/// Aggregates community accessory showcase posts to surface trending car
/// accessories (dash cams, seat covers, etc.) per category.
///
/// Data is read from `accessory_showcases` and aggregated in-memory rather than
/// via pre-computed documents, keeping the implementation simple while the
/// community is small. At scale (>10K MAU), move aggregation to Cloud Functions.
class PopularAccessoriesService {
  static const _collection = 'accessory_showcases';

  final FirebaseFirestore _firestore;

  PopularAccessoriesService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Submits a new accessory showcase post.
  Future<Result<String, AppError>> submitShowcase({
    required String userId,
    required AccessoryCategory category,
    required String itemName,
    String? brand,
    int rating = 5,
    int? priceApprox,
    String? review,
    String? vehicleId,
    List<String> imageUrls = const [],
  }) async {
    if (userId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('userId must not be empty'));
    }
    if (itemName.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('itemName must not be empty'));
    }
    if (rating < 1 || rating > 5) {
      return const Result.failure(
          AppError.validation('rating must be between 1 and 5'));
    }

    try {
      final showcase = AccessoryShowcase(
        id: '',
        userId: userId,
        vehicleId: vehicleId,
        category: category,
        itemName: itemName.trim(),
        brand: brand?.trim(),
        rating: rating,
        priceApprox: priceApprox,
        review: review,
        imageUrls: imageUrls,
        createdAt: DateTime.now(),
      );
      final doc =
          await _firestore.collection(_collection).add(showcase.toMap());
      return Result.success(doc.id);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Returns all showcase posts for [category], newest first.
  Future<Result<List<AccessoryShowcase>, AppError>> getShowcasesByCategory(
      AccessoryCategory category) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category.name)
          .orderBy('createdAt', descending: true)
          .get();
      final list = snap.docs.map(AccessoryShowcase.fromFirestore).toList();
      return Result.success(list);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Returns popularity-ranked accessory trends for [category].
  ///
  /// Items are grouped by (itemName, brand) and ranked by showcase count.
  Future<Result<List<AccessoryTrend>, AppError>> getPopularTrends({
    required AccessoryCategory category,
    int limit = 20,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category.name)
          .get();

      final trends =
          _aggregate(snap.docs.map(AccessoryShowcase.fromFirestore).toList());

      final sorted = trends
        ..sort((a, b) => b.showcaseCount.compareTo(a.showcaseCount));

      return Result.success(sorted.take(limit).toList());
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Returns cross-category popularity-ranked accessory trends.
  Future<Result<List<AccessoryTrend>, AppError>> getTopAccessories(
      {int limit = 10}) async {
    try {
      final snap = await _firestore.collection(_collection).get();
      final trends =
          _aggregate(snap.docs.map(AccessoryShowcase.fromFirestore).toList());

      final sorted = trends
        ..sort((a, b) => b.showcaseCount.compareTo(a.showcaseCount));

      return Result.success(sorted.take(limit).toList());
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  CollectionReference<Map<String, dynamic>> _commentsRef(String showcaseId) =>
      _firestore.collection(_collection).doc(showcaseId).collection('comments');

  /// Adds a comment to the showcase [showcaseId].
  ///
  /// Comments let users discuss a shared part/accessory. This is the lightweight
  /// replacement for the frozen C2C parts marketplace — share + comment only.
  Future<Result<ShowcaseComment, AppError>> addComment({
    required String showcaseId,
    required String userId,
    required String content,
    String? userDisplayName,
    String? userPhotoUrl,
  }) async {
    if (showcaseId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('showcaseId must not be empty'));
    }
    if (userId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('userId must not be empty'));
    }
    if (content.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('content must not be empty'));
    }

    try {
      final comment = ShowcaseComment(
        id: '',
        showcaseId: showcaseId,
        userId: userId,
        userDisplayName: userDisplayName,
        userPhotoUrl: userPhotoUrl,
        content: content.trim(),
        createdAt: DateTime.now(),
      );
      final doc = await _commentsRef(showcaseId).add(comment.toMap());
      return Result.success(comment.copyWith(id: doc.id));
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Returns comments for [showcaseId], oldest first (conversation order).
  Future<Result<List<ShowcaseComment>, AppError>> getComments(
      String showcaseId) async {
    if (showcaseId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('showcaseId must not be empty'));
    }
    try {
      final snap = await _commentsRef(showcaseId)
          .orderBy('createdAt', descending: false)
          .get();
      final list = snap.docs.map(ShowcaseComment.fromFirestore).toList();
      return Result.success(list);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Deletes a comment. Only the comment author may delete it.
  Future<Result<void, AppError>> deleteComment({
    required String showcaseId,
    required String commentId,
    required String userId,
  }) async {
    if (showcaseId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('showcaseId must not be empty'));
    }
    if (commentId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('commentId must not be empty'));
    }

    try {
      final ref = _commentsRef(showcaseId).doc(commentId);
      final snap = await ref.get();
      if (!snap.exists) {
        return const Result.failure(
            AppError.notFound('comment not found', resourceType: 'コメント'));
      }
      final ownerId = snap.data()?['userId'] as String? ?? '';
      if (ownerId != userId) {
        return const Result.failure(
            AppError.permission('only the author can delete this comment'));
      }
      await ref.delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Updates a comment's content. Only the comment author may edit it.
  ///
  /// Marks the comment as edited and records [DateTime.now] as `updatedAt`.
  Future<Result<ShowcaseComment, AppError>> updateComment({
    required String showcaseId,
    required String commentId,
    required String userId,
    required String content,
  }) async {
    if (showcaseId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('showcaseId must not be empty'));
    }
    if (commentId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('commentId must not be empty'));
    }
    if (content.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('content must not be empty'));
    }

    try {
      final ref = _commentsRef(showcaseId).doc(commentId);
      final snap = await ref.get();
      if (!snap.exists) {
        return const Result.failure(
            AppError.notFound('comment not found', resourceType: 'コメント'));
      }
      final ownerId = snap.data()?['userId'] as String? ?? '';
      if (ownerId != userId) {
        return const Result.failure(
            AppError.permission('only the author can edit this comment'));
      }
      await ref.update({
        'content': content.trim(),
        'isEdited': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      final updated = ShowcaseComment.fromFirestore(await ref.get());
      return Result.success(updated);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  DocumentReference<Map<String, dynamic>> _likeRef(
          String showcaseId, String commentId, String userId) =>
      _commentsRef(showcaseId).doc(commentId).collection('likes').doc(userId);

  /// Likes a comment for [userId]. Idempotent: liking again is a no-op.
  ///
  /// Maintains the denormalized `likeCount` on the comment and a
  /// `likes/{userId}` marker doc (enforces 1 like per user) in one transaction.
  Future<Result<void, AppError>> likeComment({
    required String showcaseId,
    required String commentId,
    required String userId,
  }) async {
    if (showcaseId.trim().isEmpty ||
        commentId.trim().isEmpty ||
        userId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('showcaseId, commentId, userId are required'));
    }
    try {
      final commentRef = _commentsRef(showcaseId).doc(commentId);
      final likeRef = _likeRef(showcaseId, commentId, userId);
      await _firestore.runTransaction((tx) async {
        final commentSnap = await tx.get(commentRef);
        if (!commentSnap.exists) {
          throw _NotFound();
        }
        final likeSnap = await tx.get(likeRef);
        if (likeSnap.exists) return; // already liked — no-op
        final current = (commentSnap.data()?['likeCount'] as int?) ?? 0;
        tx.set(likeRef, {
          'userId': userId,
          'showcaseId': showcaseId,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
        tx.update(commentRef, {'likeCount': current + 1});
      });
      return const Result.success(null);
    } on _NotFound {
      return const Result.failure(
          AppError.notFound('comment not found', resourceType: 'コメント'));
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Removes [userId]'s like from a comment. Idempotent: unliking when not
  /// liked is a no-op. `likeCount` never goes below zero.
  Future<Result<void, AppError>> unlikeComment({
    required String showcaseId,
    required String commentId,
    required String userId,
  }) async {
    if (showcaseId.trim().isEmpty ||
        commentId.trim().isEmpty ||
        userId.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('showcaseId, commentId, userId are required'));
    }
    try {
      final commentRef = _commentsRef(showcaseId).doc(commentId);
      final likeRef = _likeRef(showcaseId, commentId, userId);
      await _firestore.runTransaction((tx) async {
        final likeSnap = await tx.get(likeRef);
        if (!likeSnap.exists) return; // not liked — no-op
        final commentSnap = await tx.get(commentRef);
        final current = (commentSnap.data()?['likeCount'] as int?) ?? 0;
        tx.delete(likeRef);
        tx.update(commentRef, {'likeCount': current > 0 ? current - 1 : 0});
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Returns the subset of [commentIds] (within [showcaseId]) that [userId] has
  /// liked, so the UI can render each comment's like state in one pass.
  Future<Result<Set<String>, AppError>> getMyLikedCommentIds({
    required String showcaseId,
    required List<String> commentIds,
    required String userId,
  }) async {
    if (userId.trim().isEmpty || commentIds.isEmpty) {
      return const Result.success(<String>{});
    }
    try {
      final snaps = await Future.wait(
        commentIds.map((cid) => _likeRef(showcaseId, cid, userId).get()),
      );
      final liked = <String>{};
      for (var i = 0; i < commentIds.length; i++) {
        if (snaps[i].exists) liked.add(commentIds[i]);
      }
      return Result.success(liked);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  static const _reportsCollection = 'comment_reports';

  /// Reports a comment for manual moderation. One report per user per comment
  /// (idempotent: re-reporting overwrites the existing report rather than
  /// creating duplicates). Reports are write-only for clients; no automatic
  /// hiding is applied (see Issue #37).
  Future<Result<void, AppError>> reportComment({
    required String showcaseId,
    required String commentId,
    required String reporterId,
    required ReportReason reason,
  }) async {
    if (showcaseId.trim().isEmpty ||
        commentId.trim().isEmpty ||
        reporterId.trim().isEmpty) {
      return const Result.failure(AppError.validation(
          'showcaseId, commentId, reporterId are required'));
    }
    try {
      // Deterministic id => one report per (comment, reporter).
      final reportId = '${commentId}_$reporterId';
      final report = CommentReport(
        id: reportId,
        showcaseId: showcaseId,
        commentId: commentId,
        reporterId: reporterId,
        reason: reason,
        createdAt: DateTime.now(),
      );
      await _firestore
          .collection(_reportsCollection)
          .doc(reportId)
          .set(report.toMap());
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  List<AccessoryTrend> _aggregate(List<AccessoryShowcase> showcases) {
    // Key: "itemName||brand||category"
    final counts = <String, int>{};
    final ratingsSums = <String, int>{};
    final priceSums = <String, int>{};
    final priceCount = <String, int>{};
    final meta = <String, (String, String?, AccessoryCategory)>{};

    for (final s in showcases) {
      final key = '${s.itemName}||${s.brand ?? ''}||${s.category.name}';
      counts[key] = (counts[key] ?? 0) + 1;
      ratingsSums[key] = (ratingsSums[key] ?? 0) + s.rating;
      if (s.priceApprox != null) {
        priceSums[key] = (priceSums[key] ?? 0) + s.priceApprox!;
        priceCount[key] = (priceCount[key] ?? 0) + 1;
      }
      meta[key] = (s.itemName, s.brand, s.category);
    }

    return counts.entries.map((entry) {
      final k = entry.key;
      final (name, brand, cat) = meta[k]!;
      final count = entry.value;
      final avgRating = ratingsSums[k]! / count;
      final avgPrice = priceCount.containsKey(k)
          ? (priceSums[k]! / priceCount[k]!).round()
          : null;

      return AccessoryTrend(
        itemName: name,
        brand: brand,
        category: cat,
        showcaseCount: count,
        averageRating: avgRating,
        averagePriceApprox: avgPrice,
      );
    }).toList();
  }
}

/// Internal sentinel used to surface "comment not found" out of a Firestore
/// transaction as a typed [AppError.notFound].
class _NotFound implements Exception {}
