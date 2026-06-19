import 'package:cloud_firestore/cloud_firestore.dart';

/// Listing plan type for BtoB shop registration
enum ShopPlanType {
  free, // Free listing: 5 inquiries/month, 3 photos
  standard, // Standard: ¥3,980/month — unlimited inquiries, 20 photos
  premium, // Premium: ¥9,800/month — priority display, monthly report
  enterprise, // Enterprise: ¥14,800/month — up to 5 shops, API access

  ;

  static ShopPlanType fromString(String? value) {
    if (value == null) return ShopPlanType.free;
    try {
      return ShopPlanType.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return ShopPlanType.free;
    }
  }

  String get displayName => switch (this) {
        ShopPlanType.free => 'フリー',
        ShopPlanType.standard => 'スタンダード',
        ShopPlanType.premium => 'プレミアム',
        ShopPlanType.enterprise => 'エンタープライズ',
      };

  int? get monthlyPrice => switch (this) {
        ShopPlanType.free => null,
        ShopPlanType.standard => 3980,
        ShopPlanType.premium => 9800,
        ShopPlanType.enterprise => 14800,
      };
}

/// Subscription status for BtoB shops
enum ShopSubscriptionStatus {
  active, // Subscription active
  trialing, // Within trial period
  expired, // Past expiration date
  cancelled, // Cancelled (will expire at period end)
  free, // No paid subscription

  ;

  static ShopSubscriptionStatus fromString(String? value) {
    if (value == null) return ShopSubscriptionStatus.free;
    try {
      return ShopSubscriptionStatus.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return ShopSubscriptionStatus.free;
    }
  }
}

/// Shop type classification
enum ShopType {
  maintenanceShop('整備工場', 'Maintenance Shop'),
  dealer('ディーラー', 'Dealer'),
  partsShop('パーツショップ', 'Parts Shop'),
  customShop('カスタムショップ', 'Custom Shop'),
  usedCarDealer('中古車販売店', 'Used Car Dealer'),
  carWash('洗車・コーティング', 'Car Wash & Coating'),
  bodyShop('板金・塗装', 'Body Shop'),
  other('その他', 'Other');

  final String displayName;
  final String displayNameEn;
  const ShopType(this.displayName, this.displayNameEn);

  static ShopType? fromString(String? value) {
    if (value == null) return null;
    try {
      return ShopType.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// Reservation/contact methods offered by the shop
enum ReservationMethod {
  phone('電話予約'),
  line('LINE予約'),
  web('Web予約'),
  walkIn('当日飛び込み可'),
  email('メール予約');

  final String displayName;
  const ReservationMethod(this.displayName);

  static ReservationMethod? fromString(String? value) {
    if (value == null) return null;
    try {
      return ReservationMethod.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// Service categories offered by shops
enum ServiceCategory {
  inspection('車検', 'Vehicle Inspection'),
  maintenance('整備・点検', 'Maintenance'),
  repair('修理', 'Repair'),
  customization('カスタム', 'Customization'),
  partsInstall('パーツ取付', 'Parts Installation'),
  coating('コーティング', 'Coating'),
  bodyWork('板金・塗装', 'Body Work'),
  tire('タイヤ交換', 'Tire Service'),
  purchase('車両購入', 'Vehicle Purchase'),
  sale('車両売却', 'Vehicle Sale'),
  rental('レンタカー', 'Rental'),
  insurance('保険', 'Insurance');

  final String displayName;
  final String displayNameEn;
  const ServiceCategory(this.displayName, this.displayNameEn);

  static ServiceCategory? fromString(String? value) {
    if (value == null) return null;
    try {
      return ServiceCategory.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }

  /// Maps an AI maintenance recommendation keyword (the Japanese rule name,
  /// e.g. "タイヤローテーション") to the [ServiceCategory] best suited to handle
  /// it.
  ///
  /// AI suggestion cards pass their rule name as a free-text keyword. Matching
  /// it against shop names returns nothing because rule names never appear in
  /// names. Instead we resolve the keyword to a capability category so the
  /// marketplace can filter shops by [Shop.services].
  ///
  /// Returns null when no category confidently applies; callers should then
  /// fall back to showing all shops rather than an empty result.
  static ServiceCategory? fromMaintenanceKeyword(String? keyword) {
    if (keyword == null) return null;
    final k = keyword.trim();
    if (k.isEmpty) return null;

    // Tire-related work (rotation, replacement).
    if (k.contains('タイヤ')) return tire;
    // Statutory inspections / 車検. Checked before the generic 点検 rule below
    // because "12ヶ月点検"/"24ヶ月点検" also contain "点検".
    if (k.contains('車検') ||
        k.contains('法定点検') ||
        k.contains('12ヶ月点検') ||
        k.contains('24ヶ月点検')) {
      return inspection;
    }
    // Body work / paint.
    if (k.contains('板金') || k.contains('塗装')) return bodyWork;
    // Coating.
    if (k.contains('コーティング')) return coating;
    // Generic periodic maintenance: oil/filter/fluid/battery/brake checks and
    // swaps all fall under 整備・点検.
    if (k.contains('交換') || k.contains('点検')) return maintenance;

    return null;
  }
}

/// Business hours for a day
class BusinessHours {
  final String? openTime; // "09:00"
  final String? closeTime; // "18:00"
  final bool isClosed;

  const BusinessHours({
    this.openTime,
    this.closeTime,
    this.isClosed = false,
  });

  factory BusinessHours.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BusinessHours(isClosed: true);
    return BusinessHours(
      openTime: map['openTime'],
      closeTime: map['closeTime'],
      isClosed: map['isClosed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'openTime': openTime,
      'closeTime': closeTime,
      'isClosed': isClosed,
    };
  }

  String get displayText {
    if (isClosed) return '定休日';
    if (openTime == null || closeTime == null) return '-';
    return '$openTime〜$closeTime';
  }
}

/// Shop/Business partner model
class Shop {
  final String id;
  final String name;
  final ShopType type;
  final String? description;
  final String? logoUrl;
  final List<String> imageUrls;

  // Contact info
  final String? phone;
  final String? email;
  final String? website;
  final String? lineUrl; // LINE official account URL
  final String?
      bookingUrl; // Online booking URL (e.g., Google Reserve, HotPepper)
  final List<ReservationMethod> reservationMethods;
  final List<String> appealPoints; // e.g. ["24時間対応", "女性スタッフ在籍"]

  // Location
  final String? address;
  final String? prefecture; // 都道府県
  final String? city; // 市区町村
  final GeoPoint? location; // For map display

  // Services
  final List<ServiceCategory> services;
  final List<String> supportedMakerIds; // Supported vehicle makers

  // Business hours (indexed by weekday: 0=Sun, 1=Mon, ... 6=Sat)
  final Map<int, BusinessHours> businessHours;
  final String? businessHoursNote; // Additional notes like "祝日休み"

  // Rating & Reviews
  final double? rating; // Average rating (1-5)
  final int reviewCount;

  // Verification
  final bool isVerified; // Platform verified
  final bool isFeatured; // Featured/promoted
  final DateTime? verifiedAt;

  // Chain affiliation (e.g., コバック, ジェームス)
  final String? chainId; // Parent ShopChain document ID
  final String? chainName; // Denormalized chain name for display

  // Plan & Subscription
  final ShopPlanType planType; // Listing plan (default: free)
  final DateTime? planExpiresAt; // Plan expiration date
  final ShopSubscriptionStatus subscriptionStatus; // Current subscription state
  final String? revenueCatUserId; // RevenueCat customer ID
  final DateTime? trialStartedAt; // 30-day trial start
  final String? ownerId; // Owner's UID

  // Status
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Shop({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.logoUrl,
    this.imageUrls = const [],
    this.phone,
    this.email,
    this.website,
    this.lineUrl,
    this.bookingUrl,
    this.reservationMethods = const [],
    this.appealPoints = const [],
    this.chainId,
    this.chainName,
    this.address,
    this.prefecture,
    this.city,
    this.location,
    this.services = const [],
    this.supportedMakerIds = const [],
    this.businessHours = const {},
    this.businessHoursNote,
    this.rating,
    this.reviewCount = 0,
    this.isVerified = false,
    this.isFeatured = false,
    this.verifiedAt,
    this.planType = ShopPlanType.free,
    this.planExpiresAt,
    this.subscriptionStatus = ShopSubscriptionStatus.free,
    this.revenueCatUserId,
    this.trialStartedAt,
    this.ownerId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get display address
  String get displayAddress {
    final parts = <String>[];
    if (prefecture != null) parts.add(prefecture!);
    if (city != null) parts.add(city!);
    if (address != null) parts.add(address!);
    return parts.join(' ');
  }

  /// Check if shop supports a specific maker
  bool supportsMaker(String makerId) {
    if (supportedMakerIds.isEmpty) return true; // Supports all if not specified
    return supportedMakerIds.contains(makerId);
  }

  /// Check if shop offers a specific service
  bool offersService(ServiceCategory category) {
    return services.contains(category);
  }

  /// Get today's business hours
  BusinessHours? getTodayHours() {
    final weekday = DateTime.now().weekday % 7; // Convert to 0=Sun format
    return businessHours[weekday];
  }

  /// Check if shop is currently open (simplified)
  bool get isOpenNow {
    final hours = getTodayHours();
    if (hours == null || hours.isClosed) return false;
    if (hours.openTime == null || hours.closeTime == null) return false;

    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return currentTime.compareTo(hours.openTime!) >= 0 &&
        currentTime.compareTo(hours.closeTime!) <= 0;
  }

  factory Shop.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Shop(
      id: doc.id,
      name: data['name'] ?? '',
      type: ShopType.fromString(data['type']) ?? ShopType.other,
      description: data['description'],
      logoUrl: data['logoUrl'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      phone: data['phone'],
      email: data['email'],
      website: data['website'],
      lineUrl: data['lineUrl'],
      bookingUrl: data['bookingUrl'],
      reservationMethods: (data['reservationMethods'] as List<dynamic>?)
              ?.map((e) => ReservationMethod.fromString(e as String?))
              .whereType<ReservationMethod>()
              .toList() ??
          [],
      appealPoints: List<String>.from(data['appealPoints'] ?? []),
      chainId: data['chainId'],
      chainName: data['chainName'],
      address: data['address'],
      prefecture: data['prefecture'],
      city: data['city'],
      location: data['location'] as GeoPoint?,
      services: (data['services'] as List<dynamic>?)
              ?.map((e) => ServiceCategory.fromString(e))
              .whereType<ServiceCategory>()
              .toList() ??
          [],
      supportedMakerIds: List<String>.from(data['supportedMakerIds'] ?? []),
      businessHours: (data['businessHours'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(
                    int.tryParse(key) ?? 0,
                    BusinessHours.fromMap(value as Map<String, dynamic>?),
                  )) ??
          {},
      businessHoursNote: data['businessHoursNote'],
      rating: data['rating']?.toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      isVerified: data['isVerified'] ?? false,
      isFeatured: data['isFeatured'] ?? false,
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      planType: ShopPlanType.fromString(data['planType']),
      planExpiresAt: (data['planExpiresAt'] as Timestamp?)?.toDate(),
      subscriptionStatus:
          ShopSubscriptionStatus.fromString(data['subscriptionStatus']),
      revenueCatUserId: data['revenueCatUserId'],
      trialStartedAt: (data['trialStartedAt'] as Timestamp?)?.toDate(),
      ownerId: data['ownerId'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name,
      'description': description,
      'logoUrl': logoUrl,
      'imageUrls': imageUrls,
      'phone': phone,
      'email': email,
      'website': website,
      'lineUrl': lineUrl,
      'bookingUrl': bookingUrl,
      'reservationMethods': reservationMethods.map((e) => e.name).toList(),
      'appealPoints': appealPoints,
      'chainId': chainId,
      'chainName': chainName,
      'address': address,
      'prefecture': prefecture,
      'city': city,
      'location': location,
      'services': services.map((e) => e.name).toList(),
      'supportedMakerIds': supportedMakerIds,
      'businessHours': businessHours.map(
        (key, value) => MapEntry(key.toString(), value.toMap()),
      ),
      'businessHoursNote': businessHoursNote,
      'rating': rating,
      'reviewCount': reviewCount,
      'isVerified': isVerified,
      'isFeatured': isFeatured,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'planType': planType.name,
      'planExpiresAt':
          planExpiresAt != null ? Timestamp.fromDate(planExpiresAt!) : null,
      'subscriptionStatus': subscriptionStatus.name,
      'revenueCatUserId': revenueCatUserId,
      'trialStartedAt':
          trialStartedAt != null ? Timestamp.fromDate(trialStartedAt!) : null,
      'ownerId': ownerId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Shop copyWith({
    String? id,
    String? name,
    ShopType? type,
    String? description,
    String? logoUrl,
    List<String>? imageUrls,
    String? phone,
    String? email,
    String? website,
    String? lineUrl,
    String? bookingUrl,
    List<ReservationMethod>? reservationMethods,
    List<String>? appealPoints,
    String? chainId,
    String? chainName,
    String? address,
    String? prefecture,
    String? city,
    GeoPoint? location,
    List<ServiceCategory>? services,
    List<String>? supportedMakerIds,
    Map<int, BusinessHours>? businessHours,
    String? businessHoursNote,
    double? rating,
    int? reviewCount,
    bool? isVerified,
    bool? isFeatured,
    DateTime? verifiedAt,
    ShopPlanType? planType,
    DateTime? planExpiresAt,
    ShopSubscriptionStatus? subscriptionStatus,
    String? revenueCatUserId,
    DateTime? trialStartedAt,
    String? ownerId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      lineUrl: lineUrl ?? this.lineUrl,
      bookingUrl: bookingUrl ?? this.bookingUrl,
      reservationMethods: reservationMethods ?? this.reservationMethods,
      appealPoints: appealPoints ?? this.appealPoints,
      chainId: chainId ?? this.chainId,
      chainName: chainName ?? this.chainName,
      address: address ?? this.address,
      prefecture: prefecture ?? this.prefecture,
      city: city ?? this.city,
      location: location ?? this.location,
      services: services ?? this.services,
      supportedMakerIds: supportedMakerIds ?? this.supportedMakerIds,
      businessHours: businessHours ?? this.businessHours,
      businessHoursNote: businessHoursNote ?? this.businessHoursNote,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isVerified: isVerified ?? this.isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      planType: planType ?? this.planType,
      planExpiresAt: planExpiresAt ?? this.planExpiresAt,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      revenueCatUserId: revenueCatUserId ?? this.revenueCatUserId,
      trialStartedAt: trialStartedAt ?? this.trialStartedAt,
      ownerId: ownerId ?? this.ownerId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Shop($name, ${type.displayName})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Shop && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
