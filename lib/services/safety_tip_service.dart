import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../data/default_safety_tips.dart';
import '../core/result/result.dart';
import '../models/safety_tip.dart';

/// Provides official safety tips from Japanese government sources
/// (JAF, NPA, MLIT, etc.).
///
/// Security/legal constraints enforced here:
/// - sourceUrl MUST use HTTPS (rejects http:// links)
/// - sourceUrl MUST NOT be empty (official source link is mandatory)
/// - User-generated content is NOT accepted — only admin-inserted tips
///
/// Every tip returned carries [SafetyTip.disclaimer] which UI MUST display.
class SafetyTipService {
  static const _collection = 'safety_tips';

  final FirebaseFirestore _firestore;

  SafetyTipService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Adds a new safety tip (platform admin operation).
  Future<Result<String, AppError>> addTip({
    required String title,
    required String body,
    required SafetyTipCategory category,
    required SafetyTipSource source,
    required String sourceUrl,
  }) async {
    if (title.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('title must not be empty'));
    }
    if (body.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('body must not be empty'));
    }
    if (sourceUrl.trim().isEmpty) {
      return const Result.failure(
          AppError.validation('sourceUrl is mandatory for official tips'));
    }
    if (!sourceUrl.startsWith('https://')) {
      return const Result.failure(
          AppError.validation('sourceUrl must use HTTPS'));
    }

    try {
      final tip = SafetyTip(
        id: '',
        title: title.trim(),
        body: body.trim(),
        category: category,
        source: source,
        sourceUrl: sourceUrl,
        publishedAt: DateTime.now(),
      );
      final doc = await _firestore.collection(_collection).add(tip.toMap());
      return Result.success(doc.id);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Returns active safety tips, optionally filtered by [category] and/or [source].
  Future<Result<List<SafetyTip>, AppError>> getTips({
    SafetyTipCategory? category,
    SafetyTipSource? source,
  }) async {
    try {
      Query query =
          _firestore.collection(_collection).where('isActive', isEqualTo: true);

      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }
      if (source != null) {
        query = query.where('source', isEqualTo: source.name);
      }

      final snap = await query.orderBy('publishedAt', descending: true).get();
      if (snap.docs.isNotEmpty) {
        return Result.success(snap.docs.map(SafetyTip.fromFirestore).toList());
      }
      // Firestore が空なら同梱コンテンツへフォールバックする。
      //
      // 安全運転情報はシードスクリプトを実行しないと1件も入らず、
      // その運用作業が済むまで全ユーザーに空画面が見えていた。
      // 編集コンテンツはアプリに同梱できるので、空画面を構造的に
      // なくす。該当データが1件でもあれば従来どおりそちらを使う
      // （フィルタ単位で判定するので、どのカテゴリのタブも空にならない）。
      return Result.success(_defaultTips(category: category, source: source));
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// 同梱コンテンツをフィルタして返す。
  List<SafetyTip> _defaultTips({
    SafetyTipCategory? category,
    SafetyTipSource? source,
  }) {
    return kDefaultSafetyTips
        .where((t) => category == null || t.category == category)
        .where((t) => source == null || t.source == source)
        .toList();
  }

  /// Returns a single tip by [id].
  Future<Result<SafetyTip, AppError>> getById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (!doc.exists) {
        // 一覧が同梱コンテンツへフォールバックした場合、詳細もそこから
        // 引けないと「一覧には出るのに開けない」になる。
        for (final tip in kDefaultSafetyTips) {
          if (tip.id == id) return Result.success(tip);
        }
        return Result.failure(AppError.notFound('SafetyTip not found: $id'));
      }
      return Result.success(SafetyTip.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }
}
