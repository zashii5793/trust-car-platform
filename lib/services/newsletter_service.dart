import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/newsletter.dart';
import '../core/result/result.dart';
import '../core/error/app_error.dart';

/// Manages newsletter creation, delivery, and subscription preferences.
///
/// Delivery flow (Firestore-trigger pattern):
/// 1. App calls sendNewsletter() → sets status to "scheduled" in Firestore
/// 2. Cloud Function `onNewsletterSend` watches newsletters/{id} for
///    status=="scheduled", then sends emails via SendGrid and marks "sent".
/// This avoids the cloud_functions package dependency.
class NewsletterService {
  final FirebaseFirestore? _firestore;

  NewsletterService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  static const String _newsletters = 'newsletters';
  static const String _subscriptions = 'newsletter_subscriptions';

  // ---------------------------------------------------------------------------
  // Newsletter CRUD
  // ---------------------------------------------------------------------------

  /// Creates a new draft newsletter. Returns the new document ID.
  Future<Result<String, AppError>> createNewsletter(
      Newsletter newsletter) async {
    try {
      final doc = await _db.collection(_newsletters).add(newsletter.toMap());
      return Result.success(doc.id);
    } catch (e) {
      return Result.failure(ServerError('ニュースレターの作成に失敗しました: $e'));
    }
  }

  /// Updates an existing draft newsletter.
  Future<Result<void, AppError>> updateNewsletter(Newsletter newsletter) async {
    try {
      if (newsletter.status == NewsletterStatus.sent) {
        return const Result.failure(
          ValidationError('送信済みのニュースレターは編集できません'),
        );
      }
      await _db
          .collection(_newsletters)
          .doc(newsletter.id)
          .update(newsletter.toMap());
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ServerError('ニュースレターの更新に失敗しました: $e'));
    }
  }

  /// Deletes a draft newsletter. Sent newsletters cannot be deleted.
  Future<Result<void, AppError>> deleteNewsletter(String id) async {
    try {
      final doc = await _db.collection(_newsletters).doc(id).get();
      if (!doc.exists) {
        return const Result.failure(NotFoundError('ニュースレターが見つかりません'));
      }
      final status = NewsletterStatus.values.firstWhere(
        (s) => s.name == (doc.data() as Map<String, dynamic>)['status'],
        orElse: () => NewsletterStatus.draft,
      );
      if (status == NewsletterStatus.sent) {
        return const Result.failure(
          ValidationError('送信済みのニュースレターは削除できません'),
        );
      }
      await _db.collection(_newsletters).doc(id).delete();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ServerError('ニュースレターの削除に失敗しました: $e'));
    }
  }

  /// Fetches all newsletters authored by [authorId], newest first.
  Future<Result<List<Newsletter>, AppError>> getMyNewsletters(
      String authorId) async {
    try {
      final snap = await _db
          .collection(_newsletters)
          .where('authorId', isEqualTo: authorId)
          .orderBy('createdAt', descending: true)
          .get();
      final list = snap.docs.map(Newsletter.fromFirestore).toList();
      return Result.success(list);
    } catch (e) {
      return Result.failure(ServerError('ニュースレターの取得に失敗しました: $e'));
    }
  }

  /// Queues the newsletter for delivery.
  ///
  /// Sets status to "scheduled" in Firestore. The Cloud Function
  /// `onNewsletterSend` watches for this state change and handles
  /// actual email delivery, then updates the doc to "sent".
  Future<Result<void, AppError>> sendNewsletter(String newsletterId) async {
    try {
      await _db.collection(_newsletters).doc(newsletterId).update({
        'status': NewsletterStatus.scheduled.name,
        'scheduledAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ServerError('配信キューへの登録に失敗しました: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Subscription management
  // ---------------------------------------------------------------------------

  /// Fetches the newsletter subscription preferences for [userId].
  /// Returns null if not yet configured (first-time user).
  Future<Result<NewsletterSubscription?, AppError>> getSubscription(
      String userId) async {
    try {
      final doc = await _db.collection(_subscriptions).doc(userId).get();
      if (!doc.exists) {
        return const Result.success(null);
      }
      return Result.success(NewsletterSubscription.fromFirestore(doc));
    } catch (e) {
      return Result.failure(ServerError('購読設定の取得に失敗しました: $e'));
    }
  }

  /// Saves or updates the subscription preferences for [sub.userId].
  Future<Result<void, AppError>> updateSubscription(
      NewsletterSubscription sub) async {
    try {
      await _db
          .collection(_subscriptions)
          .doc(sub.userId)
          .set(sub.toMap(), SetOptions(merge: true));
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ServerError('購読設定の更新に失敗しました: $e'));
    }
  }

  /// Unsubscribes a user by their secure token (for email unsubscribe links).
  Future<Result<void, AppError>> unsubscribeByToken(String token) async {
    try {
      final snap = await _db
          .collection(_subscriptions)
          .where('unsubscribeToken', isEqualTo: token)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        return const Result.failure(
          NotFoundError('無効な配信停止リンクです'),
        );
      }
      await snap.docs.first.reference.update({
        'isSubscribed': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ServerError('配信停止処理に失敗しました: $e'));
    }
  }
}
