import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/faq.dart';

/// Service for structured community FAQ with shop permission-based responses.
/// Shops can only respond to questions where [Faq.allowShopResponse] is true.
class FaqService {
  final FirebaseFirestore _firestore;

  static const _faqCollection = 'faqs';
  static const _answerCollection = 'faq_answers';
  static const _helpfulCollection = 'faq_helpful_votes';

  FaqService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Result<String, AppError>> createFaq({
    required String question,
    required FaqCategory category,
    required String authorId,
    required bool allowShopResponse,
    String? detail,
    String? vehicleMaker,
    String? vehicleModel,
    List<String> tags = const [],
  }) async {
    if (question.trim().isEmpty) {
      return const Result.failure(
        AppError.validation('question must not be empty'),
      );
    }
    if (authorId.isEmpty) {
      return const Result.failure(
        AppError.validation('authorId must not be empty'),
      );
    }

    try {
      final now = DateTime.now();
      final faq = Faq(
        id: '',
        question: question.trim(),
        detail: detail,
        category: category,
        authorId: authorId,
        createdAt: now,
        allowShopResponse: allowShopResponse,
        vehicleMaker: vehicleMaker,
        vehicleModel: vehicleModel,
        tags: tags,
      );

      final ref = await _firestore.collection(_faqCollection).add(faq.toMap());
      return Result.success(ref.id);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  Future<Result<Faq, AppError>> getFaq(String faqId) async {
    try {
      final doc =
          await _firestore.collection(_faqCollection).doc(faqId).get();
      if (!doc.exists) {
        return const Result.failure(AppError.notFound('FAQ not found'));
      }
      return Result.success(Faq.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  Future<Result<List<Faq>, AppError>> getFaqs({
    FaqCategory? category,
    String? keyword,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection(_faqCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }

      final snapshot = await query.get();
      var faqs = snapshot.docs.map(Faq.fromFirestore).toList();

      if (keyword != null && keyword.isNotEmpty) {
        final lower = keyword.toLowerCase();
        faqs = faqs
            .where((f) => f.question.toLowerCase().contains(lower))
            .toList();
      }

      return Result.success(faqs);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  Future<Result<String, AppError>> addAnswer({
    required String faqId,
    required String content,
    required String authorId,
    required bool isShopResponse,
    String? shopId,
    String? authorName,
  }) async {
    if (content.trim().isEmpty) {
      return const Result.failure(
        AppError.validation('answer content must not be empty'),
      );
    }

    try {
      // Check FAQ exists and shop permission
      final faqDoc =
          await _firestore.collection(_faqCollection).doc(faqId).get();
      if (!faqDoc.exists) {
        return const Result.failure(AppError.notFound('FAQ not found'));
      }

      final faq = Faq.fromFirestore(faqDoc);
      if (isShopResponse && !faq.allowShopResponse) {
        return const Result.failure(
          AppError.permission(
            'permission denied: shop response not allowed for this FAQ',
          ),
        );
      }

      final now = DateTime.now();
      final answer = FaqAnswer(
        id: '',
        faqId: faqId,
        content: content.trim(),
        authorId: authorId,
        authorName: authorName,
        isShopResponse: isShopResponse,
        shopId: isShopResponse ? shopId : null,
        createdAt: now,
      );

      final ref = await _firestore
          .collection(_answerCollection)
          .add(answer.toMap());

      // Increment answer count
      await _firestore.collection(_faqCollection).doc(faqId).update({
        'answerCount': FieldValue.increment(1),
      });

      return Result.success(ref.id);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  Future<Result<List<FaqAnswer>, AppError>> getAnswers(String faqId) async {
    try {
      final snapshot = await _firestore
          .collection(_answerCollection)
          .where('faqId', isEqualTo: faqId)
          .orderBy('createdAt')
          .get();

      return Result.success(
        snapshot.docs.map(FaqAnswer.fromFirestore).toList(),
      );
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  Future<Result<void, AppError>> markHelpful({
    required String faqId,
    required String answerId,
    required String userId,
  }) async {
    try {
      final voteId = '${answerId}_$userId';
      final voteRef =
          _firestore.collection(_helpfulCollection).doc(voteId);
      final existing = await voteRef.get();

      if (existing.exists) {
        // Already voted — idempotent, return success
        return const Result.success(null);
      }

      await _firestore.runTransaction((tx) async {
        tx.set(voteRef, {
          'answerId': answerId,
          'userId': userId,
          'faqId': faqId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(
          _firestore.collection(_answerCollection).doc(answerId),
          {'helpfulCount': FieldValue.increment(1)},
        );
      });

      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  Future<Result<void, AppError>> markBestAnswer({
    required String faqId,
    required String answerId,
    required String requesterId,
  }) async {
    try {
      final faqDoc =
          await _firestore.collection(_faqCollection).doc(faqId).get();
      if (!faqDoc.exists) {
        return const Result.failure(AppError.notFound('FAQ not found'));
      }

      final faq = Faq.fromFirestore(faqDoc);
      if (faq.authorId != requesterId) {
        return const Result.failure(
          AppError.permission(
            'only the question author can mark a best answer',
          ),
        );
      }

      await _firestore
          .collection(_answerCollection)
          .doc(answerId)
          .update({'isBestAnswer': true});

      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  Future<Result<void, AppError>> incrementViewCount(String faqId) async {
    try {
      await _firestore.collection(_faqCollection).doc(faqId).update({
        'viewCount': FieldValue.increment(1),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }
}
