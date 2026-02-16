import 'package:cloud_firestore/cloud_firestore.dart';

/// Part category for classification
enum PartCategory {
  aero('エアロパーツ', 'Aero Parts'),
  wheel('ホイール', 'Wheels'),
  tire('タイヤ', 'Tires'),
  suspension('サスペンション', 'Suspension'),
  exhaust('マフラー・排気系', 'Exhaust'),
  intake('吸気系', 'Intake'),
  brake('ブレーキ', 'Brakes'),
  interior('内装', 'Interior'),
  exterior('外装', 'Exterior'),
  lighting('ライト・照明', 'Lighting'),
  audio('オーディオ', 'Audio'),
  navigation('ナビ・電装', 'Navigation & Electronics'),
  safety('安全装備', 'Safety'),
  performance('パフォーマンス', 'Performance'),
  maintenance('メンテナンス用品', 'Maintenance'),
  accessory('アクセサリー', 'Accessories'),
  other('その他', 'Other');

  final String displayName;
  final String displayNameEn;
  const PartCategory(this.displayName, this.displayNameEn);

  static PartCategory? fromString(String? value) {
    if (value == null) return null;
    try {
      return PartCategory.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// Compatibility level for parts
enum CompatibilityLevel {
  perfect('完全対応', 'ボルトオンで取付可能'),
  compatible('対応', '軽微な加工で取付可能'),
  conditional('条件付き', '追加パーツや加工が必要'),
  incompatible('非対応', '取付不可');

  final String displayName;
  final String description;
  const CompatibilityLevel(this.displayName, this.description);

  static CompatibilityLevel? fromString(String? value) {
    if (value == null) return null;
    try {
      return CompatibilityLevel.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// Vehicle specification for compatibility matching
class VehicleSpec {
  final String? makerId;
  final String? modelId;
  final int? yearFrom;
  final int? yearTo;
  final String? gradePattern;  // Regex pattern for grade matching
  final String? bodyType;

  const VehicleSpec({
    this.makerId,
    this.modelId,
    this.yearFrom,
    this.yearTo,
    this.gradePattern,
    this.bodyType,
  });

  factory VehicleSpec.fromMap(Map<String, dynamic> map) {
    return VehicleSpec(
      makerId: map['makerId'],
      modelId: map['modelId'],
      yearFrom: map['yearFrom'],
      yearTo: map['yearTo'],
      gradePattern: map['gradePattern'],
      bodyType: map['bodyType'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'makerId': makerId,
      'modelId': modelId,
      'yearFrom': yearFrom,
      'yearTo': yearTo,
      'gradePattern': gradePattern,
      'bodyType': bodyType,
    };
  }

  /// Check if this spec matches a vehicle
  bool matchesVehicle({
    required String makerId,
    required String modelId,
    required int year,
    String? grade,
    String? bodyType,
  }) {
    // Check maker
    if (this.makerId != null && this.makerId != makerId) {
      return false;
    }

    // Check model
    if (this.modelId != null && this.modelId != modelId) {
      return false;
    }

    // Check year range
    if (yearFrom != null && year < yearFrom!) {
      return false;
    }
    if (yearTo != null && year > yearTo!) {
      return false;
    }

    // Check grade pattern (simple contains check for now)
    if (gradePattern != null && grade != null) {
      if (!grade.toLowerCase().contains(gradePattern!.toLowerCase())) {
        return false;
      }
    }

    // Check body type
    if (this.bodyType != null && bodyType != null) {
      if (this.bodyType != bodyType) {
        return false;
      }
    }

    return true;
  }
}

/// Pro/Con for part recommendation
class PartProCon {
  final String text;
  final bool isPro;  // true = pro (メリット), false = con (デメリット)

  const PartProCon({
    required this.text,
    required this.isPro,
  });

  factory PartProCon.fromMap(Map<String, dynamic> map) {
    return PartProCon(
      text: map['text'] ?? '',
      isPro: map['isPro'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isPro': isPro,
    };
  }
}

/// Part listing model for marketplace
class PartListing {
  final String id;
  final String shopId;          // Shop that offers this part
  final String name;
  final String? nameEn;
  final String description;
  final PartCategory category;
  final List<String> imageUrls;

  // Pricing
  final int? priceFrom;         // Starting price (null = 要問合せ)
  final int? priceTo;           // Max price for range display
  final bool isPriceNegotiable;

  // Compatibility
  final List<VehicleSpec> compatibleVehicles;
  final CompatibilityLevel defaultCompatibility;

  // Pros and Cons (AI generated or manual)
  final List<PartProCon> prosAndCons;

  // Metadata
  final String? brand;          // Part brand/manufacturer
  final String? partNumber;     // Manufacturer part number
  final List<String> tags;      // Search tags
  final double? rating;         // Average user rating (1-5)
  final int reviewCount;

  // Status
  final bool isActive;
  final bool isFeatured;        // Featured/promoted listing
  final DateTime createdAt;
  final DateTime updatedAt;

  const PartListing({
    required this.id,
    required this.shopId,
    required this.name,
    this.nameEn,
    required this.description,
    required this.category,
    this.imageUrls = const [],
    this.priceFrom,
    this.priceTo,
    this.isPriceNegotiable = false,
    this.compatibleVehicles = const [],
    this.defaultCompatibility = CompatibilityLevel.compatible,
    this.prosAndCons = const [],
    this.brand,
    this.partNumber,
    this.tags = const [],
    this.rating,
    this.reviewCount = 0,
    this.isActive = true,
    this.isFeatured = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get display price string
  String get priceDisplay {
    if (priceFrom == null) return '要問合せ';
    if (priceTo == null || priceFrom == priceTo) {
      return '¥${_formatPrice(priceFrom!)}';
    }
    return '¥${_formatPrice(priceFrom!)}〜¥${_formatPrice(priceTo!)}';
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// Get pros only
  List<PartProCon> get pros => prosAndCons.where((p) => p.isPro).toList();

  /// Get cons only
  List<PartProCon> get cons => prosAndCons.where((p) => !p.isPro).toList();

  /// Check compatibility with a vehicle
  CompatibilityLevel getCompatibilityFor({
    required String makerId,
    required String modelId,
    required int year,
    String? grade,
    String? bodyType,
  }) {
    for (final spec in compatibleVehicles) {
      if (spec.matchesVehicle(
        makerId: makerId,
        modelId: modelId,
        year: year,
        grade: grade,
        bodyType: bodyType,
      )) {
        return CompatibilityLevel.perfect;
      }
    }

    // Check if at least maker matches
    for (final spec in compatibleVehicles) {
      if (spec.makerId == makerId) {
        return CompatibilityLevel.conditional;
      }
    }

    return defaultCompatibility;
  }

  factory PartListing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PartListing(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      name: data['name'] ?? '',
      nameEn: data['nameEn'],
      description: data['description'] ?? '',
      category: PartCategory.fromString(data['category']) ?? PartCategory.other,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      priceFrom: data['priceFrom'],
      priceTo: data['priceTo'],
      isPriceNegotiable: data['isPriceNegotiable'] ?? false,
      compatibleVehicles: (data['compatibleVehicles'] as List<dynamic>?)
          ?.map((e) => VehicleSpec.fromMap(e))
          .toList() ?? [],
      defaultCompatibility: CompatibilityLevel.fromString(data['defaultCompatibility'])
          ?? CompatibilityLevel.compatible,
      prosAndCons: (data['prosAndCons'] as List<dynamic>?)
          ?.map((e) => PartProCon.fromMap(e))
          .toList() ?? [],
      brand: data['brand'],
      partNumber: data['partNumber'],
      tags: List<String>.from(data['tags'] ?? []),
      rating: data['rating']?.toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      isActive: data['isActive'] ?? true,
      isFeatured: data['isFeatured'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'name': name,
      'nameEn': nameEn,
      'description': description,
      'category': category.name,
      'imageUrls': imageUrls,
      'priceFrom': priceFrom,
      'priceTo': priceTo,
      'isPriceNegotiable': isPriceNegotiable,
      'compatibleVehicles': compatibleVehicles.map((e) => e.toMap()).toList(),
      'defaultCompatibility': defaultCompatibility.name,
      'prosAndCons': prosAndCons.map((e) => e.toMap()).toList(),
      'brand': brand,
      'partNumber': partNumber,
      'tags': tags,
      'rating': rating,
      'reviewCount': reviewCount,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PartListing copyWith({
    String? id,
    String? shopId,
    String? name,
    String? nameEn,
    String? description,
    PartCategory? category,
    List<String>? imageUrls,
    int? priceFrom,
    int? priceTo,
    bool? isPriceNegotiable,
    List<VehicleSpec>? compatibleVehicles,
    CompatibilityLevel? defaultCompatibility,
    List<PartProCon>? prosAndCons,
    String? brand,
    String? partNumber,
    List<String>? tags,
    double? rating,
    int? reviewCount,
    bool? isActive,
    bool? isFeatured,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PartListing(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrls: imageUrls ?? this.imageUrls,
      priceFrom: priceFrom ?? this.priceFrom,
      priceTo: priceTo ?? this.priceTo,
      isPriceNegotiable: isPriceNegotiable ?? this.isPriceNegotiable,
      compatibleVehicles: compatibleVehicles ?? this.compatibleVehicles,
      defaultCompatibility: defaultCompatibility ?? this.defaultCompatibility,
      prosAndCons: prosAndCons ?? this.prosAndCons,
      brand: brand ?? this.brand,
      partNumber: partNumber ?? this.partNumber,
      tags: tags ?? this.tags,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'PartListing($name, ${category.displayName})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PartListing && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Part recommendation result with compatibility info
class PartRecommendation {
  final PartListing part;
  final CompatibilityLevel compatibility;
  final String? compatibilityNote;
  final double relevanceScore;  // 0.0 - 1.0, how relevant to user's vehicle/preferences

  const PartRecommendation({
    required this.part,
    required this.compatibility,
    this.compatibilityNote,
    this.relevanceScore = 0.5,
  });

  /// Sort by relevance and compatibility
  static int compare(PartRecommendation a, PartRecommendation b) {
    // First by compatibility level
    final compDiff = a.compatibility.index - b.compatibility.index;
    if (compDiff != 0) return compDiff;

    // Then by relevance score (higher is better)
    return (b.relevanceScore - a.relevanceScore).sign.toInt();
  }
}
