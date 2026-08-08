import 'package:cloud_firestore/cloud_firestore.dart';
import 'inquiry.dart';

/// A captured demand from a user who tried to contact a non-partner shop.
///
/// When a user attempts to send an inquiry to a shop that is not a platform
/// partner, the inquiry is not delivered.  Instead, a [ShopInquiryDemand] is
/// recorded so the shop can later see "you had N potential customers" during
/// onboarding — the pull-type sales hook described in Issue #41 §7.3.
class ShopInquiryDemand {
  final String id;
  final String shopId;

  /// Denormalised owner UID so Firestore security rules can grant the shop
  /// owner read access without a cross-collection lookup.
  final String shopOwnerId;

  final String userId;
  final InquiryType type;
  final String subject;

  /// Optional verbatim question the user attempted to send.
  final String? message;

  final String? vehicleId;
  final DateTime createdAt;

  const ShopInquiryDemand({
    required this.id,
    required this.shopId,
    required this.shopOwnerId,
    required this.userId,
    required this.type,
    required this.subject,
    this.message,
    this.vehicleId,
    required this.createdAt,
  });

  factory ShopInquiryDemand.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShopInquiryDemand(
      id: doc.id,
      shopId: (data['shopId'] as String?) ?? '',
      shopOwnerId: (data['shopOwnerId'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      type: InquiryType.fromString(data['type'] as String?) ??
          InquiryType.general,
      subject: (data['subject'] as String?) ?? '',
      message: data['message'] as String?,
      vehicleId: data['vehicleId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'shopId': shopId,
        'shopOwnerId': shopOwnerId,
        'userId': userId,
        'type': type.name,
        'subject': subject,
        'message': message,
        'vehicleId': vehicleId,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
