import 'package:cloud_firestore/cloud_firestore.dart';
import 'shop.dart';

/// A before/after work example posted by a shop owner.
class ShopCaseStudy {
  final String id;
  final String shopId;
  final String title;
  final String? description;
  final String? beforeImageUrl;
  final String? afterImageUrl;
  final ServiceCategory? category;
  final DateTime createdAt;

  const ShopCaseStudy({
    required this.id,
    required this.shopId,
    required this.title,
    this.description,
    this.beforeImageUrl,
    this.afterImageUrl,
    this.category,
    required this.createdAt,
  });

  factory ShopCaseStudy.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ShopCaseStudy(
      id: doc.id,
      shopId: data['shopId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      beforeImageUrl: data['beforeImageUrl'] as String?,
      afterImageUrl: data['afterImageUrl'] as String?,
      category: ServiceCategory.values.cast<ServiceCategory?>().firstWhere(
            (e) => e?.name == data['category'],
            orElse: () => null,
          ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'shopId': shopId,
        'title': title,
        'description': description,
        'beforeImageUrl': beforeImageUrl,
        'afterImageUrl': afterImageUrl,
        'category': category?.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
