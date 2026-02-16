import 'package:cloud_firestore/cloud_firestore.dart';

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
}

/// Business hours for a day
class BusinessHours {
  final String? openTime;   // "09:00"
  final String? closeTime;  // "18:00"
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

  // Location
  final String? address;
  final String? prefecture;  // 都道府県
  final String? city;        // 市区町村
  final GeoPoint? location;  // For map display

  // Services
  final List<ServiceCategory> services;
  final List<String> supportedMakerIds;  // Supported vehicle makers

  // Business hours (indexed by weekday: 0=Sun, 1=Mon, ... 6=Sat)
  final Map<int, BusinessHours> businessHours;
  final String? businessHoursNote;  // Additional notes like "祝日休み"

  // Rating & Reviews
  final double? rating;       // Average rating (1-5)
  final int reviewCount;

  // Verification
  final bool isVerified;      // Platform verified
  final bool isFeatured;      // Featured/promoted
  final DateTime? verifiedAt;

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
    if (supportedMakerIds.isEmpty) return true;  // Supports all if not specified
    return supportedMakerIds.contains(makerId);
  }

  /// Check if shop offers a specific service
  bool offersService(ServiceCategory category) {
    return services.contains(category);
  }

  /// Get today's business hours
  BusinessHours? getTodayHours() {
    final weekday = DateTime.now().weekday % 7;  // Convert to 0=Sun format
    return businessHours[weekday];
  }

  /// Check if shop is currently open (simplified)
  bool get isOpenNow {
    final hours = getTodayHours();
    if (hours == null || hours.isClosed) return false;
    if (hours.openTime == null || hours.closeTime == null) return false;

    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

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
      address: data['address'],
      prefecture: data['prefecture'],
      city: data['city'],
      location: data['location'] as GeoPoint?,
      services: (data['services'] as List<dynamic>?)
          ?.map((e) => ServiceCategory.fromString(e))
          .whereType<ServiceCategory>()
          .toList() ?? [],
      supportedMakerIds: List<String>.from(data['supportedMakerIds'] ?? []),
      businessHours: (data['businessHours'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(
              int.tryParse(key) ?? 0,
              BusinessHours.fromMap(value as Map<String, dynamic>?),
          )) ?? {},
      businessHoursNote: data['businessHoursNote'],
      rating: data['rating']?.toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      isVerified: data['isVerified'] ?? false,
      isFeatured: data['isFeatured'] ?? false,
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
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
