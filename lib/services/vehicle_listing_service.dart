import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/vehicle_listing.dart';
import '../models/vehicle_search.dart';

/// Service for managing vehicle listings and recommendations
class VehicleListingService {
  final FirebaseFirestore _firestore;

  VehicleListingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _listingsRef =>
      _firestore.collection('vehicle_listings');

  CollectionReference<Map<String, dynamic>> get _favoritesRef =>
      _firestore.collection('listing_favorites');

  CollectionReference<Map<String, dynamic>> get _preferencesRef =>
      _firestore.collection('vehicle_preferences');

  // ==================== Listings ====================

  /// Get a listing by ID
  Future<Result<VehicleListing, AppError>> getListing(String listingId) async {
    try {
      final doc = await _listingsRef.doc(listingId).get();
      if (!doc.exists) {
        return Result.failure(const AppError.notFound(
          '車両情報が見つかりません',
          resourceType: 'VehicleListing',
        ));
      }
      return Result.success(VehicleListing.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.unknown(
        '車両情報の取得に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Search listings with criteria
  Future<Result<List<VehicleListing>, AppError>> searchListings({
    required VehicleSearchCriteria criteria,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _listingsRef
          .where('status', isEqualTo: ListingStatus.active.name);

      // Apply filters
      if (criteria.makerId != null) {
        query = query.where('makerId', isEqualTo: criteria.makerId);
      }
      if (criteria.modelId != null) {
        query = query.where('modelId', isEqualTo: criteria.modelId);
      }
      if (criteria.priceMin != null) {
        query = query.where('price', isGreaterThanOrEqualTo: criteria.priceMin);
      }
      if (criteria.priceMax != null) {
        query = query.where('price', isLessThanOrEqualTo: criteria.priceMax);
      }
      if (criteria.shopListingOnly == true) {
        query = query.where('shopId', isNull: false);
      }

      // Apply sorting
      switch (criteria.sortBy) {
        case VehicleSortOption.newest:
          query = query.orderBy('createdAt', descending: true);
          break;
        case VehicleSortOption.priceAsc:
          query = query.orderBy('price', descending: false);
          break;
        case VehicleSortOption.priceDesc:
          query = query.orderBy('price', descending: true);
          break;
        case VehicleSortOption.mileageAsc:
          query = query.orderBy('mileage', descending: false);
          break;
        case VehicleSortOption.yearDesc:
          query = query.orderBy('modelYear', descending: true);
          break;
        case VehicleSortOption.popular:
          query = query.orderBy('viewCount', descending: true);
          break;
      }

      query = query.limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      var listings = snapshot.docs
          .map((doc) => VehicleListing.fromFirestore(doc))
          .toList();

      // Apply client-side filters (Firestore query limitations)
      listings = _applyClientSideFilters(listings, criteria);

      return Result.success(listings);
    } catch (e) {
      return Result.failure(AppError.unknown(
        '検索に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Apply filters that can't be done in Firestore query
  List<VehicleListing> _applyClientSideFilters(
    List<VehicleListing> listings,
    VehicleSearchCriteria criteria,
  ) {
    return listings.where((listing) {
      // Body type filter
      if (criteria.bodyTypes?.isNotEmpty == true) {
        if (listing.bodyType == null ||
            !criteria.bodyTypes!.contains(listing.bodyType)) {
          return false;
        }
      }

      // Year range
      if (criteria.yearMin != null && listing.modelYear < criteria.yearMin!) {
        return false;
      }
      if (criteria.yearMax != null && listing.modelYear > criteria.yearMax!) {
        return false;
      }

      // Mileage range
      if (criteria.mileageMin != null && listing.mileage < criteria.mileageMin!) {
        return false;
      }
      if (criteria.mileageMax != null && listing.mileage > criteria.mileageMax!) {
        return false;
      }

      // Transmission
      if (criteria.transmissionTypes?.isNotEmpty == true) {
        if (listing.specs.transmission == null ||
            !criteria.transmissionTypes!.contains(listing.specs.transmission)) {
          return false;
        }
      }

      // Fuel type
      if (criteria.fuelTypes?.isNotEmpty == true) {
        if (listing.specs.fuelType == null ||
            !criteria.fuelTypes!.contains(listing.specs.fuelType)) {
          return false;
        }
      }

      // Drive type
      if (criteria.driveTypes?.isNotEmpty == true) {
        if (listing.specs.driveType == null ||
            !criteria.driveTypes!.contains(listing.specs.driveType)) {
          return false;
        }
      }

      // Seating capacity
      if (criteria.seatingCapacityMin != null) {
        if (listing.specs.seatingCapacity == null ||
            listing.specs.seatingCapacity! < criteria.seatingCapacityMin!) {
          return false;
        }
      }

      // Condition grade
      if (criteria.conditionGrades?.isNotEmpty == true) {
        if (!criteria.conditionGrades!.contains(listing.conditionGrade)) {
          return false;
        }
      }

      // No accident history
      if (criteria.noAccidentHistory == true && listing.hasAccidentHistory) {
        return false;
      }

      // No smoking history
      if (criteria.noSmokingHistory == true && listing.hasSmokingHistory) {
        return false;
      }

      // One owner
      if (criteria.oneOwnerOnly == true && !listing.isOneOwner) {
        return false;
      }

      // Prefecture
      if (criteria.prefectures?.isNotEmpty == true) {
        if (!criteria.prefectures!.contains(listing.prefecture)) {
          return false;
        }
      }

      // Keyword search
      if (criteria.keyword?.isNotEmpty == true) {
        final keyword = criteria.keyword!.toLowerCase();
        final searchableText = '${listing.makerName} ${listing.modelName} '
            '${listing.gradeName ?? ''} ${listing.description ?? ''}'
            .toLowerCase();
        if (!searchableText.contains(keyword)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Get recommendations based on user preference
  Future<Result<List<VehicleRecommendation>, AppError>> getRecommendations({
    required String userId,
    int limit = 10,
  }) async {
    try {
      // Get user preference
      final prefDoc = await _preferencesRef.doc(userId).get();
      VehiclePreference preference;

      if (prefDoc.exists) {
        final data = prefDoc.data()!;
        preference = VehiclePreference(
          userId: userId,
          preferredMakerIds: List<String>.from(data['preferredMakerIds'] ?? []),
          preferredBodyTypes: List<String>.from(data['preferredBodyTypes'] ?? []),
          budgetMin: data['budgetMin'],
          budgetMax: data['budgetMax'],
          maxMileage: data['maxMileage'],
          minYear: data['minYear'],
          preferredFuelTypes: (data['preferredFuelTypes'] as List<dynamic>?)
              ?.map((e) => FuelType.fromString(e))
              .whereType<FuelType>()
              .toList(),
          preferredTransmissions: (data['preferredTransmissions'] as List<dynamic>?)
              ?.map((e) => TransmissionType.fromString(e))
              .whereType<TransmissionType>()
              .toList(),
          requiresNoAccidentHistory: data['requiresNoAccidentHistory'] ?? false,
          requiresInspection: data['requiresInspection'] ?? false,
          minSeatingCapacity: data['minSeatingCapacity'],
          preferredPrefectures: List<String>.from(data['preferredPrefectures'] ?? []),
          viewedListingIds: List<String>.from(data['viewedListingIds'] ?? []),
          favoriteListingIds: List<String>.from(data['favoriteListingIds'] ?? []),
        );
      } else {
        preference = VehiclePreference(userId: userId);
      }

      // Get active listings
      final snapshot = await _listingsRef
          .where('status', isEqualTo: ListingStatus.active.name)
          .orderBy('createdAt', descending: true)
          .limit(100) // Get more for scoring
          .get();

      final listings = snapshot.docs
          .map((doc) => VehicleListing.fromFirestore(doc))
          .toList();

      // Score and rank listings
      final recommendations = _scoreListings(listings, preference);

      // Sort by relevance and take top results
      recommendations.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      return Result.success(recommendations.take(limit).toList());
    } catch (e) {
      return Result.failure(AppError.unknown(
        'おすすめの取得に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Score listings based on preference
  List<VehicleRecommendation> _scoreListings(
    List<VehicleListing> listings,
    VehiclePreference preference,
  ) {
    return listings.map((listing) {
      var score = 0.0;
      final reasons = <String>[];

      // Skip already viewed
      if (preference.viewedListingIds.contains(listing.id)) {
        return VehicleRecommendation(
          listing: listing,
          relevanceScore: 0,
        );
      }

      // Maker preference (weight: 0.2)
      if (preference.preferredMakerIds.contains(listing.makerId)) {
        score += 0.2;
        reasons.add('希望メーカー');
      }

      // Body type preference (weight: 0.15)
      if (preference.preferredBodyTypes.contains(listing.bodyType)) {
        score += 0.15;
        reasons.add('希望ボディタイプ');
      }

      // Budget match (weight: 0.25)
      final budgetScore = _calculateBudgetScore(listing, preference);
      score += budgetScore * 0.25;
      if (budgetScore > 0.8) {
        reasons.add('予算内');
      }

      // Mileage score (weight: 0.1)
      final mileageScore = _calculateMileageScore(listing, preference);
      score += mileageScore * 0.1;
      if (mileageScore > 0.8) {
        reasons.add('走行距離が少ない');
      }

      // Year score (weight: 0.1)
      final yearScore = _calculateYearScore(listing, preference);
      score += yearScore * 0.1;
      if (yearScore > 0.8) {
        reasons.add('高年式');
      }

      // Fuel type preference (weight: 0.05)
      if (preference.preferredFuelTypes?.contains(listing.specs.fuelType) == true) {
        score += 0.05;
        reasons.add('希望燃料タイプ');
      }

      // Transmission preference (weight: 0.05)
      if (preference.preferredTransmissions?.contains(listing.specs.transmission) == true) {
        score += 0.05;
      }

      // Condition requirements
      if (preference.requiresNoAccidentHistory && !listing.hasAccidentHistory) {
        score += 0.05;
        reasons.add('修復歴なし');
      } else if (preference.requiresNoAccidentHistory && listing.hasAccidentHistory) {
        score -= 0.3; // Penalty
      }

      // Prefecture preference (weight: 0.05)
      if (preference.preferredPrefectures.contains(listing.prefecture)) {
        score += 0.05;
        reasons.add('希望地域');
      }

      // Similar to favorites bonus
      if (_isSimilarToFavorites(listing, preference)) {
        score += 0.1;
        reasons.add('お気に入りに類似');
      }

      // Normalize score to 0-1
      score = score.clamp(0.0, 1.0);

      return VehicleRecommendation(
        listing: listing,
        relevanceScore: score,
        matchReasons: reasons,
      );
    }).where((r) => r.relevanceScore > 0).toList();
  }

  double _calculateBudgetScore(VehicleListing listing, VehiclePreference pref) {
    if (pref.budgetMax == null) return 0.5;

    if (listing.price <= pref.budgetMax!) {
      if (pref.budgetMin != null && listing.price < pref.budgetMin!) {
        return 0.3; // Under budget
      }
      // Within budget - higher score for lower price
      return 1.0 - (listing.price / pref.budgetMax!) * 0.5;
    }

    // Over budget - penalty based on how much
    final overRatio = (listing.price - pref.budgetMax!) / pref.budgetMax!;
    return (1.0 - overRatio).clamp(0.0, 0.5);
  }

  double _calculateMileageScore(VehicleListing listing, VehiclePreference pref) {
    if (pref.maxMileage == null) return 0.5;

    if (listing.mileage <= pref.maxMileage!) {
      return 1.0 - (listing.mileage / pref.maxMileage!) * 0.5;
    }

    final overRatio = (listing.mileage - pref.maxMileage!) / pref.maxMileage!;
    return (1.0 - overRatio).clamp(0.0, 0.3);
  }

  double _calculateYearScore(VehicleListing listing, VehiclePreference pref) {
    final currentYear = DateTime.now().year;
    final age = currentYear - listing.modelYear;

    if (pref.minYear != null) {
      if (listing.modelYear >= pref.minYear!) {
        return 1.0;
      }
      final underYears = pref.minYear! - listing.modelYear;
      return (1.0 - underYears * 0.1).clamp(0.0, 0.5);
    }

    // Default: newer is better
    return (1.0 - age * 0.05).clamp(0.3, 1.0);
  }

  bool _isSimilarToFavorites(VehicleListing listing, VehiclePreference pref) {
    // Simple similarity check - same maker or body type as favorited
    // In production, this would be more sophisticated
    return pref.favoriteListingIds.isNotEmpty;
  }

  // ==================== Favorites ====================

  /// Add listing to favorites
  Future<Result<void, AppError>> addToFavorites({
    required String listingId,
    required String userId,
  }) async {
    try {
      final favoriteId = '${listingId}_$userId';
      final existingFav = await _favoritesRef.doc(favoriteId).get();

      if (existingFav.exists) {
        return Result.success(null);
      }

      final batch = _firestore.batch();

      batch.set(_favoritesRef.doc(favoriteId), {
        'listingId': listingId,
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(_listingsRef.doc(listingId), {
        'favoriteCount': FieldValue.increment(1),
      });

      // Update user preferences
      batch.set(
        _preferencesRef.doc(userId),
        {
          'favoriteListingIds': FieldValue.arrayUnion([listingId]),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'お気に入りの追加に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Remove listing from favorites
  Future<Result<void, AppError>> removeFromFavorites({
    required String listingId,
    required String userId,
  }) async {
    try {
      final favoriteId = '${listingId}_$userId';
      final existingFav = await _favoritesRef.doc(favoriteId).get();

      if (!existingFav.exists) {
        return Result.success(null);
      }

      final batch = _firestore.batch();

      batch.delete(_favoritesRef.doc(favoriteId));

      batch.update(_listingsRef.doc(listingId), {
        'favoriteCount': FieldValue.increment(-1),
      });

      batch.set(
        _preferencesRef.doc(userId),
        {
          'favoriteListingIds': FieldValue.arrayRemove([listingId]),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'お気に入りの削除に失敗しました',
        originalError: e,
      ));
    }
  }

  /// Check if listing is favorited
  Future<bool> isFavorited({
    required String listingId,
    required String userId,
  }) async {
    try {
      final favoriteId = '${listingId}_$userId';
      final doc = await _favoritesRef.doc(favoriteId).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Get user's favorite listings
  Future<Result<List<VehicleListing>, AppError>> getFavorites({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final favSnapshot = await _favoritesRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      if (favSnapshot.docs.isEmpty) {
        return Result.success([]);
      }

      final listingIds = favSnapshot.docs
          .map((doc) => doc.data()['listingId'] as String)
          .toList();

      // Fetch listings in batches
      final listings = <VehicleListing>[];
      for (var i = 0; i < listingIds.length; i += 10) {
        final batchIds = listingIds.sublist(
          i,
          i + 10 > listingIds.length ? listingIds.length : i + 10,
        );
        final listingSnapshot = await _listingsRef
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();
        listings.addAll(
          listingSnapshot.docs.map((doc) => VehicleListing.fromFirestore(doc)),
        );
      }

      return Result.success(listings);
    } catch (e) {
      return Result.failure(AppError.unknown(
        'お気に入りの取得に失敗しました',
        originalError: e,
      ));
    }
  }

  // ==================== View Tracking ====================

  /// Record listing view
  Future<void> recordView({
    required String listingId,
    required String userId,
  }) async {
    try {
      final batch = _firestore.batch();

      batch.update(_listingsRef.doc(listingId), {
        'viewCount': FieldValue.increment(1),
      });

      batch.set(
        _preferencesRef.doc(userId),
        {
          'viewedListingIds': FieldValue.arrayUnion([listingId]),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (_) {
      // Silently fail
    }
  }

  // ==================== User Preferences ====================

  /// Update user preference
  Future<Result<void, AppError>> updatePreference({
    required String userId,
    List<String>? preferredMakerIds,
    List<String>? preferredBodyTypes,
    int? budgetMin,
    int? budgetMax,
    int? maxMileage,
    int? minYear,
    List<FuelType>? preferredFuelTypes,
    List<TransmissionType>? preferredTransmissions,
    bool? requiresNoAccidentHistory,
    bool? requiresInspection,
    int? minSeatingCapacity,
    List<String>? preferredPrefectures,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (preferredMakerIds != null) {
        updates['preferredMakerIds'] = preferredMakerIds;
      }
      if (preferredBodyTypes != null) {
        updates['preferredBodyTypes'] = preferredBodyTypes;
      }
      if (budgetMin != null) updates['budgetMin'] = budgetMin;
      if (budgetMax != null) updates['budgetMax'] = budgetMax;
      if (maxMileage != null) updates['maxMileage'] = maxMileage;
      if (minYear != null) updates['minYear'] = minYear;
      if (preferredFuelTypes != null) {
        updates['preferredFuelTypes'] = preferredFuelTypes.map((e) => e.name).toList();
      }
      if (preferredTransmissions != null) {
        updates['preferredTransmissions'] = preferredTransmissions.map((e) => e.name).toList();
      }
      if (requiresNoAccidentHistory != null) {
        updates['requiresNoAccidentHistory'] = requiresNoAccidentHistory;
      }
      if (requiresInspection != null) {
        updates['requiresInspection'] = requiresInspection;
      }
      if (minSeatingCapacity != null) {
        updates['minSeatingCapacity'] = minSeatingCapacity;
      }
      if (preferredPrefectures != null) {
        updates['preferredPrefectures'] = preferredPrefectures;
      }

      if (updates.isEmpty) {
        return Result.success(null);
      }

      await _preferencesRef.doc(userId).set(updates, SetOptions(merge: true));
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(
        '設定の更新に失敗しました',
        originalError: e,
      ));
    }
  }
}
