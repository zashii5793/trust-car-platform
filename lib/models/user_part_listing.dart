import 'package:cloud_firestore/cloud_firestore.dart';

import 'part_listing.dart';
import '../services/part_listing_service.dart';

/// Status of a user-submitted part listing
enum PartListingStatus {
  active('出品中'),
  soldOut('売り切れ'),
  cancelled('取り下げ');

  final String displayName;
  const PartListingStatus(this.displayName);

  static PartListingStatus fromString(String? value) {
    if (value == null) return PartListingStatus.active;
    try {
      return PartListingStatus.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return PartListingStatus.active;
    }
  }
}

/// User-submitted part listing (stored in user_part_listings collection)
class UserPartListing {
  final String id;
  final String sellerId;
  final String title;
  final PartCategory category;
  final PartCondition condition;
  final int price;
  final int payout;
  final String description;
  final String? compatibleVehicle;
  final List<String> imageUrls;
  final ShippingMethod shippingMethod;
  final PartListingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserPartListing({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.category,
    required this.condition,
    required this.price,
    required this.payout,
    required this.description,
    this.compatibleVehicle,
    this.imageUrls = const [],
    required this.shippingMethod,
    this.status = PartListingStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Formatted price string
  String get priceDisplay =>
      '¥${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  factory UserPartListing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserPartListing(
      id: doc.id,
      sellerId: data['sellerId'] ?? '',
      title: data['title'] ?? '',
      category: PartCategory.fromString(data['category']) ?? PartCategory.other,
      condition: PartCondition.fromString(data['condition']) ??
          PartCondition.goodCondition,
      price: data['price'] ?? 0,
      payout: data['payout'] ?? 0,
      description: data['description'] ?? '',
      compatibleVehicle: data['compatibleVehicle'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      shippingMethod: ShippingMethod.fromString(data['shippingMethod']) ??
          ShippingMethod.includedInPrice,
      status: PartListingStatus.fromString(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sellerId': sellerId,
      'title': title,
      'category': category.name,
      'condition': condition.name,
      'price': price,
      'payout': payout,
      'description': description,
      'compatibleVehicle': compatibleVehicle,
      'imageUrls': imageUrls,
      'shippingMethod': shippingMethod.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserPartListing copyWith({
    String? id,
    String? sellerId,
    String? title,
    PartCategory? category,
    PartCondition? condition,
    int? price,
    int? payout,
    String? description,
    String? compatibleVehicle,
    List<String>? imageUrls,
    ShippingMethod? shippingMethod,
    PartListingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPartListing(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      title: title ?? this.title,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      price: price ?? this.price,
      payout: payout ?? this.payout,
      description: description ?? this.description,
      compatibleVehicle: compatibleVehicle ?? this.compatibleVehicle,
      imageUrls: imageUrls ?? this.imageUrls,
      shippingMethod: shippingMethod ?? this.shippingMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserPartListing && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
