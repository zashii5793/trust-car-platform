import 'package:cloud_firestore/cloud_firestore.dart';

/// Category of car accessory (for filtering / ranking)
enum AccessoryCategory {
  interior('インテリア'),
  exterior('エクステリア'),
  electronics('電装・ガジェット'),
  safety('安全装備'),
  maintenance('メンテナンス用品'),
  other('その他');

  final String displayName;
  const AccessoryCategory(this.displayName);

  static AccessoryCategory? fromString(String? value) {
    if (value == null) return null;
    try {
      return AccessoryCategory.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// A user's accessory showcase post — "I use this dash cam on my Prius".
class AccessoryShowcase {
  final String id;
  final String userId;
  final String? vehicleId;
  final AccessoryCategory category;
  final String itemName; // e.g. "Vantrue N2 Pro"
  final String? brand;
  final int? priceApprox; // Approx purchase price (JPY)
  final int rating; // 1–5
  final List<String> imageUrls;
  final String? review;
  final int helpfulCount;
  final DateTime createdAt;

  const AccessoryShowcase({
    required this.id,
    required this.userId,
    this.vehicleId,
    required this.category,
    required this.itemName,
    this.brand,
    this.priceApprox,
    this.rating = 5,
    this.imageUrls = const [],
    this.review,
    this.helpfulCount = 0,
    required this.createdAt,
  });

  factory AccessoryShowcase.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AccessoryShowcase(
      id: doc.id,
      userId: data['userId'] ?? '',
      vehicleId: data['vehicleId'],
      category: AccessoryCategory.fromString(data['category']) ??
          AccessoryCategory.other,
      itemName: data['itemName'] ?? '',
      brand: data['brand'],
      priceApprox: data['priceApprox'],
      rating: data['rating'] ?? 5,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      review: data['review'],
      helpfulCount: data['helpfulCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'vehicleId': vehicleId,
      'category': category.name,
      'itemName': itemName,
      'brand': brand,
      'priceApprox': priceApprox,
      'rating': rating,
      'imageUrls': imageUrls,
      'review': review,
      'helpfulCount': helpfulCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Aggregated popularity data for a single accessory item.
class AccessoryTrend {
  final String itemName;
  final String? brand;
  final AccessoryCategory category;
  final int showcaseCount; // How many users posted about this item
  final double averageRating;
  final int? averagePriceApprox;

  const AccessoryTrend({
    required this.itemName,
    this.brand,
    required this.category,
    required this.showcaseCount,
    required this.averageRating,
    this.averagePriceApprox,
  });
}
