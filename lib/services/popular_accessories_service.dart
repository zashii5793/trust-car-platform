import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/accessory_showcase.dart';

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
