import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
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

  /// Optional HTTP client for dependency injection (used in tests).
  final http.Client? _httpClient;

  /// Cloud Functions base URL override (tests). Defaults to
  /// FIREBASE_FUNCTIONS_URL in .env, same as AiChatService.
  final String? _functionsBaseUrl;

  NewsletterService({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
    String? functionsBaseUrl,
  })  : _firestore = firestore,
        _httpClient = httpClient,
        _functionsBaseUrl = functionsBaseUrl;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  String get _baseUrl =>
      _functionsBaseUrl ??
      (dotenv.isInitialized ? dotenv.env['FIREBASE_FUNCTIONS_URL'] : null) ??
      '';

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
  ///
  /// Cloud Function `unsubscribeNewsletter` に POST する（Issue #192）。
  /// リンクから来る人はログインしていないので、クライアントから
  /// newsletter_subscriptions をトークンで引くとルールで必ず拒否される。
  /// トークンの照合と書き込みはサーバー（Admin SDK）で行う。
  Future<Result<void, AppError>> unsubscribeByToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      return const Result.failure(ValidationError('無効な配信停止リンクです'));
    }
    if (_baseUrl.isEmpty) {
      return const Result.failure(
        ServerError('FIREBASE_FUNCTIONS_URLが設定されていません。'),
      );
    }
    try {
      final client = _httpClient ?? http.Client();
      final response = await client
          .post(
            Uri.parse('$_baseUrl/unsubscribeNewsletter'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': trimmed}),
          )
          .timeout(const Duration(seconds: 20));

      switch (response.statusCode) {
        case 200:
          return const Result.success(null);
        case 400:
        case 404:
          return const Result.failure(NotFoundError('無効な配信停止リンクです'));
        default:
          return Result.failure(ServerError(
            '配信停止処理に失敗しました (${response.statusCode})',
            statusCode: response.statusCode,
          ));
      }
    } on http.ClientException catch (e) {
      return Result.failure(NetworkError('ネットワークエラー: ${e.message}'));
    } on TimeoutException {
      return const Result.failure(NetworkError('配信停止処理がタイムアウトしました'));
    } catch (e) {
      return Result.failure(ServerError('配信停止処理に失敗しました: $e'));
    }
  }
}
