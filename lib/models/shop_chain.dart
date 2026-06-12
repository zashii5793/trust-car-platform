import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a corporate chain operating multiple shop locations
/// (e.g., コバック, ジェームス, イエローハット).
class ShopChain {
  final String id;
  final String name;
  final String? logoUrl;
  final String? website;
  final String? nationalPhone; // Central customer service line
  final String? description;
  final int shopCount; // Denormalized count for display
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShopChain({
    required this.id,
    required this.name,
    this.logoUrl,
    this.website,
    this.nationalPhone,
    this.description,
    this.shopCount = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShopChain.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShopChain(
      id: doc.id,
      name: data['name'] ?? '',
      logoUrl: data['logoUrl'],
      website: data['website'],
      nationalPhone: data['nationalPhone'],
      description: data['description'],
      shopCount: data['shopCount'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'logoUrl': logoUrl,
      'website': website,
      'nationalPhone': nationalPhone,
      'description': description,
      'shopCount': shopCount,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ShopChain copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? website,
    String? nationalPhone,
    String? description,
    int? shopCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopChain(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      website: website ?? this.website,
      nationalPhone: nationalPhone ?? this.nationalPhone,
      description: description ?? this.description,
      shopCount: shopCount ?? this.shopCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ShopChain && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ShopChain($name, $shopCount shops)';
}
