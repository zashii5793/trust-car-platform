import 'package:cloud_firestore/cloud_firestore.dart';

/// Purchase condition specified by the user for custom-order / used car inquiry.
class CarPurchaseCondition {
  final String? maker;
  final String? model;
  final int? minYear;
  final int? maxYear;
  final int? minPrice; // JPY
  final int? maxPrice; // JPY
  final int? maxMileage; // km
  final String? freeText; // Additional requirements

  const CarPurchaseCondition({
    this.maker,
    this.model,
    this.minYear,
    this.maxYear,
    this.minPrice,
    this.maxPrice,
    this.maxMileage,
    this.freeText,
  });

  Map<String, dynamic> toMap() => {
        'maker': maker,
        'model': model,
        'minYear': minYear,
        'maxYear': maxYear,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'maxMileage': maxMileage,
        'freeText': freeText,
      };
}

/// Status of a car purchase inquiry
enum InquiryStatus {
  open,
  inProgress,
  closed;

  static InquiryStatus fromString(String? value) {
    if (value == null) return InquiryStatus.open;
    try {
      return InquiryStatus.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return InquiryStatus.open;
    }
  }
}

/// User's inquiry to a custom-order car company.
class CarPurchaseInquiry {
  final String id;
  final String userId;
  final String? shopId; // Custom-order shop (if directed at a specific shop)
  final CarPurchaseCondition condition;
  final String message;
  final InquiryStatus status;
  final DateTime createdAt;

  const CarPurchaseInquiry({
    required this.id,
    required this.userId,
    this.shopId,
    required this.condition,
    required this.message,
    this.status = InquiryStatus.open,
    required this.createdAt,
  });

  factory CarPurchaseInquiry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final condData = data['condition'] as Map<String, dynamic>? ?? {};
    return CarPurchaseInquiry(
      id: doc.id,
      userId: data['userId'] ?? '',
      shopId: data['shopId'],
      condition: CarPurchaseCondition(
        maker: condData['maker'],
        model: condData['model'],
        minYear: condData['minYear'],
        maxYear: condData['maxYear'],
        minPrice: condData['minPrice'],
        maxPrice: condData['maxPrice'],
        maxMileage: condData['maxMileage'],
        freeText: condData['freeText'],
      ),
      message: data['message'] ?? '',
      status: InquiryStatus.fromString(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'shopId': shopId,
        'condition': condition.toMap(),
        'message': message,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

/// External used-car search portal deep link
class UsedCarSearchLink {
  final String siteName;
  final String url;

  const UsedCarSearchLink({required this.siteName, required this.url});
}
