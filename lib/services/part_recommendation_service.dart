import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/part_listing.dart';
import '../models/vehicle.dart';

/// Service for part recommendations based on vehicle compatibility
class PartRecommendationService {
  final FirebaseFirestore _firestore;

  PartRecommendationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get recommended parts for a vehicle
  Future<Result<List<PartRecommendation>, AppError>> getRecommendationsForVehicle(
    Vehicle vehicle, {
    PartCategory? category,
    int limit = 10,
  }) async {
    try {
      Query query = _firestore
          .collection('part_listings')
          .where('isActive', isEqualTo: true);

      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }

      // Get featured parts first, then by rating
      query = query
          .orderBy('isFeatured', descending: true)
          .orderBy('rating', descending: true)
          .limit(limit * 2);  // Get more to filter by compatibility

      final snapshot = await query.get();

      final recommendations = <PartRecommendation>[];

      for (final doc in snapshot.docs) {
        final part = PartListing.fromFirestore(doc);

        // Calculate compatibility
        final compatibility = part.getCompatibilityFor(
          makerId: _getMakerId(vehicle.maker),
          modelId: _getModelId(vehicle.maker, vehicle.model),
          year: vehicle.year,
          grade: vehicle.grade,
        );

        // Skip incompatible parts unless specifically requested
        if (compatibility == CompatibilityLevel.incompatible) {
          continue;
        }

        // Calculate relevance score
        final relevance = _calculateRelevanceScore(part, vehicle, compatibility);

        recommendations.add(PartRecommendation(
          part: part,
          compatibility: compatibility,
          compatibilityNote: _getCompatibilityNote(compatibility, vehicle),
          relevanceScore: relevance,
        ));
      }

      // Sort by relevance and compatibility
      recommendations.sort(PartRecommendation.compare);

      // Return limited results
      return Result.success(recommendations.take(limit).toList());
    } catch (e) {
      return Result.failure(AppError.server('パーツ情報の取得に失敗しました: $e'));
    }
  }

  /// Get parts by category
  Future<Result<List<PartListing>, AppError>> getPartsByCategory(
    PartCategory category, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('part_listings')
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: category.name)
          .orderBy('isFeatured', descending: true)
          .orderBy('rating', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      final parts = snapshot.docs
          .map((doc) => PartListing.fromFirestore(doc))
          .toList();

      return Result.success(parts);
    } catch (e) {
      return Result.failure(AppError.server('パーツ情報の取得に失敗しました: $e'));
    }
  }

  /// Search parts by keyword
  Future<Result<List<PartListing>, AppError>> searchParts(
    String keyword, {
    PartCategory? category,
    int limit = 20,
  }) async {
    try {
      // Simple tag-based search (Firestore doesn't support full-text search)
      Query query = _firestore
          .collection('part_listings')
          .where('isActive', isEqualTo: true)
          .where('tags', arrayContains: keyword.toLowerCase())
          .limit(limit);

      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }

      final snapshot = await query.get();

      final parts = snapshot.docs
          .map((doc) => PartListing.fromFirestore(doc))
          .toList();

      return Result.success(parts);
    } catch (e) {
      return Result.failure(AppError.server('検索に失敗しました: $e'));
    }
  }

  /// Get featured parts
  Future<Result<List<PartListing>, AppError>> getFeaturedParts({
    int limit = 5,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('part_listings')
          .where('isActive', isEqualTo: true)
          .where('isFeatured', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      final parts = snapshot.docs
          .map((doc) => PartListing.fromFirestore(doc))
          .toList();

      return Result.success(parts);
    } catch (e) {
      return Result.failure(AppError.server('おすすめパーツの取得に失敗しました: $e'));
    }
  }

  /// Get part detail
  Future<Result<PartListing, AppError>> getPartDetail(String partId) async {
    try {
      final doc = await _firestore
          .collection('part_listings')
          .doc(partId)
          .get();

      if (!doc.exists) {
        return Result.failure(AppError.notFound('パーツが見つかりません'));
      }

      return Result.success(PartListing.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.server('パーツ情報の取得に失敗しました: $e'));
    }
  }

  /// Generate AI pros and cons for a part (placeholder for future LLM integration)
  List<PartProCon> generateProsAndCons(PartListing part, Vehicle vehicle) {
    final prosAndCons = <PartProCon>[];

    // Category-based default pros/cons
    switch (part.category) {
      case PartCategory.aero:
        prosAndCons.add(const PartProCon(text: '見た目のカスタマイズ性が高い', isPro: true));
        prosAndCons.add(const PartProCon(text: '空力性能の向上が期待できる', isPro: true));
        prosAndCons.add(const PartProCon(text: '最低地上高が変わる可能性', isPro: false));
        break;

      case PartCategory.wheel:
        prosAndCons.add(const PartProCon(text: '足元の印象を大きく変えられる', isPro: true));
        prosAndCons.add(const PartProCon(text: '軽量化で燃費向上の可能性', isPro: true));
        prosAndCons.add(const PartProCon(text: 'タイヤサイズ変更が必要な場合あり', isPro: false));
        break;

      case PartCategory.suspension:
        prosAndCons.add(const PartProCon(text: '乗り心地やハンドリングの向上', isPro: true));
        prosAndCons.add(const PartProCon(text: '車高調整が可能', isPro: true));
        prosAndCons.add(const PartProCon(text: '乗り心地が硬くなる場合あり', isPro: false));
        break;

      case PartCategory.exhaust:
        prosAndCons.add(const PartProCon(text: 'サウンドのカスタマイズ', isPro: true));
        prosAndCons.add(const PartProCon(text: '排気効率の向上', isPro: true));
        prosAndCons.add(const PartProCon(text: '車検対応の確認が必要', isPro: false));
        break;

      case PartCategory.audio:
        prosAndCons.add(const PartProCon(text: '音質の大幅向上', isPro: true));
        prosAndCons.add(const PartProCon(text: 'Bluetooth等の最新機能追加', isPro: true));
        prosAndCons.add(const PartProCon(text: '取付工賃が別途必要', isPro: false));
        break;

      default:
        prosAndCons.add(const PartProCon(text: '車両のカスタマイズが可能', isPro: true));
    }

    // Price-based
    if (part.priceFrom != null && part.priceFrom! < 30000) {
      prosAndCons.add(const PartProCon(text: '比較的リーズナブルな価格', isPro: true));
    }
    if (part.priceFrom != null && part.priceFrom! > 100000) {
      prosAndCons.add(const PartProCon(text: '高価格帯の製品', isPro: false));
    }

    // Rating-based
    if (part.rating != null && part.rating! >= 4.5) {
      prosAndCons.add(const PartProCon(text: 'ユーザー評価が非常に高い', isPro: true));
    }

    // Brand-based
    if (part.brand != null) {
      prosAndCons.add(PartProCon(text: '${part.brand}ブランドの信頼性', isPro: true));
    }

    return prosAndCons;
  }

  // Helper: Convert maker name to ID (simplified)
  String _getMakerId(String makerName) {
    final makerMap = {
      'トヨタ': 'toyota',
      'ホンダ': 'honda',
      '日産': 'nissan',
      'マツダ': 'mazda',
      'スバル': 'subaru',
      'スズキ': 'suzuki',
      'ダイハツ': 'daihatsu',
      '三菱': 'mitsubishi',
      'レクサス': 'lexus',
    };
    return makerMap[makerName] ?? makerName.toLowerCase();
  }

  // Helper: Generate model ID
  String _getModelId(String makerName, String modelName) {
    final makerId = _getMakerId(makerName);
    final modelId = modelName.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    return '${makerId}_$modelId';
  }

  // Helper: Calculate relevance score
  double _calculateRelevanceScore(
    PartListing part,
    Vehicle vehicle,
    CompatibilityLevel compatibility,
  ) {
    double score = 0.5;

    // Compatibility boost
    switch (compatibility) {
      case CompatibilityLevel.perfect:
        score += 0.3;
        break;
      case CompatibilityLevel.compatible:
        score += 0.2;
        break;
      case CompatibilityLevel.conditional:
        score += 0.1;
        break;
      case CompatibilityLevel.incompatible:
        score -= 0.3;
        break;
    }

    // Rating boost
    if (part.rating != null) {
      score += (part.rating! - 3) * 0.05;  // 3 is neutral
    }

    // Featured boost
    if (part.isFeatured) {
      score += 0.1;
    }

    // Review count boost (more reviews = more reliable)
    if (part.reviewCount > 10) {
      score += 0.05;
    }
    if (part.reviewCount > 50) {
      score += 0.05;
    }

    return score.clamp(0.0, 1.0);
  }

  // Helper: Get compatibility note
  String _getCompatibilityNote(CompatibilityLevel level, Vehicle vehicle) {
    switch (level) {
      case CompatibilityLevel.perfect:
        return '${vehicle.displayName}に完全対応';
      case CompatibilityLevel.compatible:
        return '${vehicle.displayName}に対応';
      case CompatibilityLevel.conditional:
        return '追加パーツや加工が必要な場合があります';
      case CompatibilityLevel.incompatible:
        return '${vehicle.displayName}には非対応';
    }
  }
}
