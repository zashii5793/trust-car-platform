import 'package:cloud_firestore/cloud_firestore.dart';
import 'drive_log.dart';

/// Spot category
enum SpotCategory {
  scenicView,      // 景勝地
  restaurant,      // レストラン
  cafe,            // カフェ
  gasStation,      // ガソリンスタンド
  parkingArea,     // 駐車場・PA
  serviceArea,     // サービスエリア
  shrine,          // 神社
  temple,          // 寺院
  hotSpring,       // 温泉
  campsite,        // キャンプ場
  beach,           // ビーチ
  mountain,        // 山
  lake,            // 湖
  waterfall,       // 滝
  historicSite,    // 史跡
  museum,          // 博物館
  park,            // 公園
  shopping,        // ショッピング
  carWash,         // 洗車場
  other,           // その他
  ;

  String get displayName {
    switch (this) {
      case SpotCategory.scenicView:
        return '景勝地';
      case SpotCategory.restaurant:
        return 'レストラン';
      case SpotCategory.cafe:
        return 'カフェ';
      case SpotCategory.gasStation:
        return 'ガソリンスタンド';
      case SpotCategory.parkingArea:
        return '駐車場・PA';
      case SpotCategory.serviceArea:
        return 'サービスエリア';
      case SpotCategory.shrine:
        return '神社';
      case SpotCategory.temple:
        return '寺院';
      case SpotCategory.hotSpring:
        return '温泉';
      case SpotCategory.campsite:
        return 'キャンプ場';
      case SpotCategory.beach:
        return 'ビーチ';
      case SpotCategory.mountain:
        return '山';
      case SpotCategory.lake:
        return '湖';
      case SpotCategory.waterfall:
        return '滝';
      case SpotCategory.historicSite:
        return '史跡';
      case SpotCategory.museum:
        return '博物館';
      case SpotCategory.park:
        return '公園';
      case SpotCategory.shopping:
        return 'ショッピング';
      case SpotCategory.carWash:
        return '洗車場';
      case SpotCategory.other:
        return 'その他';
    }
  }

  String get emoji {
    switch (this) {
      case SpotCategory.scenicView:
        return '🏞️';
      case SpotCategory.restaurant:
        return '🍽️';
      case SpotCategory.cafe:
        return '☕';
      case SpotCategory.gasStation:
        return '⛽';
      case SpotCategory.parkingArea:
        return '🅿️';
      case SpotCategory.serviceArea:
        return '🛣️';
      case SpotCategory.shrine:
        return '⛩️';
      case SpotCategory.temple:
        return '🛕';
      case SpotCategory.hotSpring:
        return '♨️';
      case SpotCategory.campsite:
        return '🏕️';
      case SpotCategory.beach:
        return '🏖️';
      case SpotCategory.mountain:
        return '⛰️';
      case SpotCategory.lake:
        return '🏞️';
      case SpotCategory.waterfall:
        return '💧';
      case SpotCategory.historicSite:
        return '🏯';
      case SpotCategory.museum:
        return '🏛️';
      case SpotCategory.park:
        return '🌳';
      case SpotCategory.shopping:
        return '🛍️';
      case SpotCategory.carWash:
        return '🚿';
      case SpotCategory.other:
        return '📍';
    }
  }

  static SpotCategory? fromString(String? value) {
    if (value == null) return null;
    return SpotCategory.values.where((e) => e.name == value).firstOrNull;
  }
}

/// Spot image
class SpotImage {
  final String url;
  final String? thumbnailUrl;
  final int order;
  final String? caption;

  const SpotImage({
    required this.url,
    this.thumbnailUrl,
    this.order = 0,
    this.caption,
  });

  factory SpotImage.fromMap(Map<String, dynamic> map) {
    return SpotImage(
      url: map['url'] as String,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      order: (map['order'] as num?)?.toInt() ?? 0,
      caption: map['caption'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'order': order,
      if (caption != null) 'caption': caption,
    };
  }
}

/// Business hours for a spot
class SpotBusinessHours {
  final int dayOfWeek;     // 0 = Sunday, 6 = Saturday
  final String? openTime;  // "09:00"
  final String? closeTime; // "18:00"
  final bool isClosed;

  const SpotBusinessHours({
    required this.dayOfWeek,
    this.openTime,
    this.closeTime,
    this.isClosed = false,
  });

  factory SpotBusinessHours.fromMap(Map<String, dynamic> map) {
    return SpotBusinessHours(
      dayOfWeek: (map['dayOfWeek'] as num).toInt(),
      openTime: map['openTime'] as String?,
      closeTime: map['closeTime'] as String?,
      isClosed: map['isClosed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dayOfWeek': dayOfWeek,
      if (openTime != null) 'openTime': openTime,
      if (closeTime != null) 'closeTime': closeTime,
      'isClosed': isClosed,
    };
  }

  String get dayName {
    const days = ['日', '月', '火', '水', '木', '金', '土'];
    return days[dayOfWeek];
  }

  String get displayHours {
    if (isClosed) return '定休日';
    if (openTime == null || closeTime == null) return '時間不明';
    return '$openTime - $closeTime';
  }
}

/// Drive spot / point of interest
class DriveSpot {
  final String id;
  final String userId;           // Creator
  final String? driveLogId;      // Associated drive log (if discovered during drive)

  // Basic info
  final String name;
  final String? description;
  final SpotCategory category;
  final List<String> tags;

  // Location
  final GeoPoint2D location;
  final String? address;
  final String? prefecture;
  final String? city;

  // Details
  final String? phoneNumber;
  final String? website;
  final List<SpotBusinessHours> businessHours;
  final bool isParkingAvailable;
  final int? parkingCapacity;

  // Media
  final List<SpotImage> images;
  final String? thumbnailUrl;

  // Ratings
  final double averageRating;    // 1.0 - 5.0
  final int ratingCount;
  final int visitCount;

  // Social
  final bool isPublic;
  final int favoriteCount;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  const DriveSpot({
    required this.id,
    required this.userId,
    this.driveLogId,
    required this.name,
    this.description,
    required this.category,
    this.tags = const [],
    required this.location,
    this.address,
    this.prefecture,
    this.city,
    this.phoneNumber,
    this.website,
    this.businessHours = const [],
    this.isParkingAvailable = false,
    this.parkingCapacity,
    this.images = const [],
    this.thumbnailUrl,
    this.averageRating = 0,
    this.ratingCount = 0,
    this.visitCount = 0,
    this.isPublic = true,
    this.favoriteCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriveSpot.fromMap(Map<String, dynamic> map, String id) {
    return DriveSpot(
      id: id,
      userId: map['userId'] as String,
      driveLogId: map['driveLogId'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      category: SpotCategory.fromString(map['category'] as String?) ?? SpotCategory.other,
      tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      location: GeoPoint2D.fromMap(map['location'] as Map<String, dynamic>?),
      address: map['address'] as String?,
      prefecture: map['prefecture'] as String?,
      city: map['city'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      website: map['website'] as String?,
      businessHours: (map['businessHours'] as List<dynamic>?)
              ?.map((e) => SpotBusinessHours.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      isParkingAvailable: map['isParkingAvailable'] as bool? ?? false,
      parkingCapacity: (map['parkingCapacity'] as num?)?.toInt(),
      images: (map['images'] as List<dynamic>?)
              ?.map((e) => SpotImage.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      thumbnailUrl: map['thumbnailUrl'] as String?,
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      visitCount: (map['visitCount'] as num?)?.toInt() ?? 0,
      isPublic: map['isPublic'] as bool? ?? true,
      favoriteCount: (map['favoriteCount'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      if (driveLogId != null) 'driveLogId': driveLogId,
      'name': name,
      if (description != null) 'description': description,
      'category': category.name,
      'tags': tags,
      'location': location.toMap(),
      if (address != null) 'address': address,
      if (prefecture != null) 'prefecture': prefecture,
      if (city != null) 'city': city,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (website != null) 'website': website,
      'businessHours': businessHours.map((e) => e.toMap()).toList(),
      'isParkingAvailable': isParkingAvailable,
      if (parkingCapacity != null) 'parkingCapacity': parkingCapacity,
      'images': images.map((e) => e.toMap()).toList(),
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'visitCount': visitCount,
      'isPublic': isPublic,
      'favoriteCount': favoriteCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  DriveSpot copyWith({
    String? id,
    String? userId,
    String? driveLogId,
    String? name,
    String? description,
    SpotCategory? category,
    List<String>? tags,
    GeoPoint2D? location,
    String? address,
    String? prefecture,
    String? city,
    String? phoneNumber,
    String? website,
    List<SpotBusinessHours>? businessHours,
    bool? isParkingAvailable,
    int? parkingCapacity,
    List<SpotImage>? images,
    String? thumbnailUrl,
    double? averageRating,
    int? ratingCount,
    int? visitCount,
    bool? isPublic,
    int? favoriteCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriveSpot(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      driveLogId: driveLogId ?? this.driveLogId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      location: location ?? this.location,
      address: address ?? this.address,
      prefecture: prefecture ?? this.prefecture,
      city: city ?? this.city,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
      businessHours: businessHours ?? this.businessHours,
      isParkingAvailable: isParkingAvailable ?? this.isParkingAvailable,
      parkingCapacity: parkingCapacity ?? this.parkingCapacity,
      images: images ?? this.images,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      visitCount: visitCount ?? this.visitCount,
      isPublic: isPublic ?? this.isPublic,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get primary image URL
  String? get primaryImageUrl {
    if (thumbnailUrl != null) return thumbnailUrl;
    if (images.isNotEmpty) return images.first.url;
    return null;
  }

  /// Check if spot has ratings
  bool get hasRatings => ratingCount > 0;

  /// Get formatted rating
  String get formattedRating {
    if (!hasRatings) return '評価なし';
    return '${averageRating.toStringAsFixed(1)} (${ratingCount}件)';
  }

  /// Get category with emoji
  String get categoryWithEmoji => '${category.emoji} ${category.displayName}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DriveSpot && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DriveSpot($name, ${category.displayName})';
}

/// Spot rating / review
class SpotRating {
  final String id;
  final String spotId;
  final String userId;
  final String? userName;
  final String? userAvatarUrl;
  final int rating;              // 1-5
  final String? comment;
  final List<String> photoUrls;
  final DateTime visitedAt;
  final DateTime createdAt;

  const SpotRating({
    required this.id,
    required this.spotId,
    required this.userId,
    this.userName,
    this.userAvatarUrl,
    required this.rating,
    this.comment,
    this.photoUrls = const [],
    required this.visitedAt,
    required this.createdAt,
  });

  factory SpotRating.fromMap(Map<String, dynamic> map, String id) {
    return SpotRating(
      id: id,
      spotId: map['spotId'] as String,
      userId: map['userId'] as String,
      userName: map['userName'] as String?,
      userAvatarUrl: map['userAvatarUrl'] as String?,
      rating: (map['rating'] as num).toInt(),
      comment: map['comment'] as String?,
      photoUrls: (map['photoUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      visitedAt: (map['visitedAt'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'spotId': spotId,
      'userId': userId,
      if (userName != null) 'userName': userName,
      if (userAvatarUrl != null) 'userAvatarUrl': userAvatarUrl,
      'rating': rating,
      if (comment != null) 'comment': comment,
      'photoUrls': photoUrls,
      'visitedAt': Timestamp.fromDate(visitedAt),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Get rating as stars
  String get ratingStars => '★' * rating + '☆' * (5 - rating);
}

/// Spot favorite
class SpotFavorite {
  final String id;
  final String spotId;
  final String userId;
  final String? note;
  final DateTime createdAt;

  const SpotFavorite({
    required this.id,
    required this.spotId,
    required this.userId,
    this.note,
    required this.createdAt,
  });

  factory SpotFavorite.fromMap(Map<String, dynamic> map, String id) {
    return SpotFavorite(
      id: id,
      spotId: map['spotId'] as String,
      userId: map['userId'] as String,
      note: map['note'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'spotId': spotId,
      'userId': userId,
      if (note != null) 'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Spot visit record
class SpotVisit {
  final String id;
  final String spotId;
  final String userId;
  final String? driveLogId;
  final DateTime visitedAt;
  final String? note;
  final List<String> photoUrls;

  const SpotVisit({
    required this.id,
    required this.spotId,
    required this.userId,
    this.driveLogId,
    required this.visitedAt,
    this.note,
    this.photoUrls = const [],
  });

  factory SpotVisit.fromMap(Map<String, dynamic> map, String id) {
    return SpotVisit(
      id: id,
      spotId: map['spotId'] as String,
      userId: map['userId'] as String,
      driveLogId: map['driveLogId'] as String?,
      visitedAt: (map['visitedAt'] as Timestamp).toDate(),
      note: map['note'] as String?,
      photoUrls: (map['photoUrls'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'spotId': spotId,
      'userId': userId,
      if (driveLogId != null) 'driveLogId': driveLogId,
      'visitedAt': Timestamp.fromDate(visitedAt),
      if (note != null) 'note': note,
      'photoUrls': photoUrls,
    };
  }
}
