import 'vehicle_listing.dart';

/// Sort options for vehicle search
enum VehicleSortOption {
  newest,       // 新着順
  priceAsc,     // 価格安い順
  priceDesc,    // 価格高い順
  mileageAsc,   // 走行距離少ない順
  yearDesc,     // 年式新しい順
  popular,      // 人気順
  ;

  String get displayName {
    switch (this) {
      case VehicleSortOption.newest:
        return '新着順';
      case VehicleSortOption.priceAsc:
        return '価格が安い順';
      case VehicleSortOption.priceDesc:
        return '価格が高い順';
      case VehicleSortOption.mileageAsc:
        return '走行距離が少ない順';
      case VehicleSortOption.yearDesc:
        return '年式が新しい順';
      case VehicleSortOption.popular:
        return '人気順';
    }
  }
}

/// Search criteria for vehicle listings
class VehicleSearchCriteria {
  // 基本条件
  final String? makerId;
  final String? modelId;
  final List<String>? bodyTypes;

  // 年式
  final int? yearMin;
  final int? yearMax;

  // 走行距離
  final int? mileageMin;
  final int? mileageMax;

  // 価格
  final int? priceMin;
  final int? priceMax;

  // スペック
  final List<TransmissionType>? transmissionTypes;
  final List<FuelType>? fuelTypes;
  final List<DriveType>? driveTypes;
  final int? seatingCapacityMin;

  // 状態
  final List<ConditionGrade>? conditionGrades;
  final bool? hasInspection;        // 車検あり
  final bool? noAccidentHistory;    // 修復歴なし
  final bool? noSmokingHistory;     // 禁煙車
  final bool? oneOwnerOnly;         // ワンオーナーのみ

  // 地域
  final List<String>? prefectures;

  // 出品者タイプ
  final bool? shopListingOnly;      // 販売店のみ

  // 並び順
  final VehicleSortOption sortBy;

  // キーワード
  final String? keyword;

  const VehicleSearchCriteria({
    this.makerId,
    this.modelId,
    this.bodyTypes,
    this.yearMin,
    this.yearMax,
    this.mileageMin,
    this.mileageMax,
    this.priceMin,
    this.priceMax,
    this.transmissionTypes,
    this.fuelTypes,
    this.driveTypes,
    this.seatingCapacityMin,
    this.conditionGrades,
    this.hasInspection,
    this.noAccidentHistory,
    this.noSmokingHistory,
    this.oneOwnerOnly,
    this.prefectures,
    this.shopListingOnly,
    this.sortBy = VehicleSortOption.newest,
    this.keyword,
  });

  VehicleSearchCriteria copyWith({
    String? makerId,
    String? modelId,
    List<String>? bodyTypes,
    int? yearMin,
    int? yearMax,
    int? mileageMin,
    int? mileageMax,
    int? priceMin,
    int? priceMax,
    List<TransmissionType>? transmissionTypes,
    List<FuelType>? fuelTypes,
    List<DriveType>? driveTypes,
    int? seatingCapacityMin,
    List<ConditionGrade>? conditionGrades,
    bool? hasInspection,
    bool? noAccidentHistory,
    bool? noSmokingHistory,
    bool? oneOwnerOnly,
    List<String>? prefectures,
    bool? shopListingOnly,
    VehicleSortOption? sortBy,
    String? keyword,
  }) {
    return VehicleSearchCriteria(
      makerId: makerId ?? this.makerId,
      modelId: modelId ?? this.modelId,
      bodyTypes: bodyTypes ?? this.bodyTypes,
      yearMin: yearMin ?? this.yearMin,
      yearMax: yearMax ?? this.yearMax,
      mileageMin: mileageMin ?? this.mileageMin,
      mileageMax: mileageMax ?? this.mileageMax,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      transmissionTypes: transmissionTypes ?? this.transmissionTypes,
      fuelTypes: fuelTypes ?? this.fuelTypes,
      driveTypes: driveTypes ?? this.driveTypes,
      seatingCapacityMin: seatingCapacityMin ?? this.seatingCapacityMin,
      conditionGrades: conditionGrades ?? this.conditionGrades,
      hasInspection: hasInspection ?? this.hasInspection,
      noAccidentHistory: noAccidentHistory ?? this.noAccidentHistory,
      noSmokingHistory: noSmokingHistory ?? this.noSmokingHistory,
      oneOwnerOnly: oneOwnerOnly ?? this.oneOwnerOnly,
      prefectures: prefectures ?? this.prefectures,
      shopListingOnly: shopListingOnly ?? this.shopListingOnly,
      sortBy: sortBy ?? this.sortBy,
      keyword: keyword ?? this.keyword,
    );
  }

  /// Check if any filter is applied
  bool get hasFilters {
    return makerId != null ||
        modelId != null ||
        (bodyTypes?.isNotEmpty ?? false) ||
        yearMin != null ||
        yearMax != null ||
        mileageMin != null ||
        mileageMax != null ||
        priceMin != null ||
        priceMax != null ||
        (transmissionTypes?.isNotEmpty ?? false) ||
        (fuelTypes?.isNotEmpty ?? false) ||
        (driveTypes?.isNotEmpty ?? false) ||
        seatingCapacityMin != null ||
        (conditionGrades?.isNotEmpty ?? false) ||
        hasInspection == true ||
        noAccidentHistory == true ||
        noSmokingHistory == true ||
        oneOwnerOnly == true ||
        (prefectures?.isNotEmpty ?? false) ||
        shopListingOnly == true ||
        (keyword?.isNotEmpty ?? false);
  }

  /// Get filter count
  int get filterCount {
    var count = 0;
    if (makerId != null) count++;
    if (modelId != null) count++;
    if (bodyTypes?.isNotEmpty ?? false) count++;
    if (yearMin != null || yearMax != null) count++;
    if (mileageMin != null || mileageMax != null) count++;
    if (priceMin != null || priceMax != null) count++;
    if (transmissionTypes?.isNotEmpty ?? false) count++;
    if (fuelTypes?.isNotEmpty ?? false) count++;
    if (driveTypes?.isNotEmpty ?? false) count++;
    if (seatingCapacityMin != null) count++;
    if (conditionGrades?.isNotEmpty ?? false) count++;
    if (hasInspection == true) count++;
    if (noAccidentHistory == true) count++;
    if (noSmokingHistory == true) count++;
    if (oneOwnerOnly == true) count++;
    if (prefectures?.isNotEmpty ?? false) count++;
    if (shopListingOnly == true) count++;
    return count;
  }

  /// Reset all filters
  VehicleSearchCriteria reset() {
    return const VehicleSearchCriteria();
  }

  /// Convert to map for analytics/logging
  Map<String, dynamic> toMap() {
    return {
      if (makerId != null) 'makerId': makerId,
      if (modelId != null) 'modelId': modelId,
      if (bodyTypes != null) 'bodyTypes': bodyTypes,
      if (yearMin != null) 'yearMin': yearMin,
      if (yearMax != null) 'yearMax': yearMax,
      if (mileageMin != null) 'mileageMin': mileageMin,
      if (mileageMax != null) 'mileageMax': mileageMax,
      if (priceMin != null) 'priceMin': priceMin,
      if (priceMax != null) 'priceMax': priceMax,
      if (transmissionTypes != null)
        'transmissionTypes': transmissionTypes!.map((e) => e.name).toList(),
      if (fuelTypes != null)
        'fuelTypes': fuelTypes!.map((e) => e.name).toList(),
      if (driveTypes != null)
        'driveTypes': driveTypes!.map((e) => e.storageName).toList(),
      if (seatingCapacityMin != null) 'seatingCapacityMin': seatingCapacityMin,
      if (conditionGrades != null)
        'conditionGrades': conditionGrades!.map((e) => e.name).toList(),
      if (hasInspection != null) 'hasInspection': hasInspection,
      if (noAccidentHistory != null) 'noAccidentHistory': noAccidentHistory,
      if (noSmokingHistory != null) 'noSmokingHistory': noSmokingHistory,
      if (oneOwnerOnly != null) 'oneOwnerOnly': oneOwnerOnly,
      if (prefectures != null) 'prefectures': prefectures,
      if (shopListingOnly != null) 'shopListingOnly': shopListingOnly,
      'sortBy': sortBy.name,
      if (keyword != null) 'keyword': keyword,
    };
  }
}

/// User preference for vehicle recommendation
class VehiclePreference {
  final String userId;

  // 好みのメーカー・車種
  final List<String> preferredMakerIds;
  final List<String> preferredBodyTypes;

  // 予算
  final int? budgetMin;
  final int? budgetMax;

  // 走行距離許容範囲
  final int? maxMileage;

  // 年式許容範囲
  final int? minYear;

  // 好みのスペック
  final List<FuelType>? preferredFuelTypes;
  final List<TransmissionType>? preferredTransmissions;

  // 必須条件
  final bool requiresNoAccidentHistory;
  final bool requiresInspection;
  final int? minSeatingCapacity;

  // 優先地域
  final List<String> preferredPrefectures;

  // 閲覧履歴から学習したデータ
  final List<String> viewedListingIds;
  final List<String> favoriteListingIds;

  // 重み付けスコア（AI計算用）
  final Map<String, double> featureWeights;

  const VehiclePreference({
    required this.userId,
    this.preferredMakerIds = const [],
    this.preferredBodyTypes = const [],
    this.budgetMin,
    this.budgetMax,
    this.maxMileage,
    this.minYear,
    this.preferredFuelTypes,
    this.preferredTransmissions,
    this.requiresNoAccidentHistory = false,
    this.requiresInspection = false,
    this.minSeatingCapacity,
    this.preferredPrefectures = const [],
    this.viewedListingIds = const [],
    this.favoriteListingIds = const [],
    this.featureWeights = const {},
  });

  VehiclePreference copyWith({
    String? userId,
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
    List<String>? viewedListingIds,
    List<String>? favoriteListingIds,
    Map<String, double>? featureWeights,
  }) {
    return VehiclePreference(
      userId: userId ?? this.userId,
      preferredMakerIds: preferredMakerIds ?? this.preferredMakerIds,
      preferredBodyTypes: preferredBodyTypes ?? this.preferredBodyTypes,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      maxMileage: maxMileage ?? this.maxMileage,
      minYear: minYear ?? this.minYear,
      preferredFuelTypes: preferredFuelTypes ?? this.preferredFuelTypes,
      preferredTransmissions: preferredTransmissions ?? this.preferredTransmissions,
      requiresNoAccidentHistory: requiresNoAccidentHistory ?? this.requiresNoAccidentHistory,
      requiresInspection: requiresInspection ?? this.requiresInspection,
      minSeatingCapacity: minSeatingCapacity ?? this.minSeatingCapacity,
      preferredPrefectures: preferredPrefectures ?? this.preferredPrefectures,
      viewedListingIds: viewedListingIds ?? this.viewedListingIds,
      favoriteListingIds: favoriteListingIds ?? this.favoriteListingIds,
      featureWeights: featureWeights ?? this.featureWeights,
    );
  }

  /// Convert to search criteria
  VehicleSearchCriteria toSearchCriteria() {
    return VehicleSearchCriteria(
      makerId: preferredMakerIds.isNotEmpty ? preferredMakerIds.first : null,
      bodyTypes: preferredBodyTypes.isNotEmpty ? preferredBodyTypes : null,
      priceMin: budgetMin,
      priceMax: budgetMax,
      mileageMax: maxMileage,
      yearMin: minYear,
      fuelTypes: preferredFuelTypes,
      transmissionTypes: preferredTransmissions,
      noAccidentHistory: requiresNoAccidentHistory ? true : null,
      hasInspection: requiresInspection ? true : null,
      seatingCapacityMin: minSeatingCapacity,
      prefectures: preferredPrefectures.isNotEmpty ? preferredPrefectures : null,
    );
  }
}

/// Recommendation result with score
class VehicleRecommendation {
  final VehicleListing listing;
  final double relevanceScore;  // 0.0 - 1.0
  final List<String> matchReasons;

  const VehicleRecommendation({
    required this.listing,
    required this.relevanceScore,
    this.matchReasons = const [],
  });

  /// Relevance as percentage
  int get relevancePercent => (relevanceScore * 100).round();
}
