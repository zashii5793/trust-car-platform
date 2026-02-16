import 'package:cloud_firestore/cloud_firestore.dart';

/// Inquiry status
enum InquiryStatus {
  pending('未対応', 'Pending'),
  inProgress('対応中', 'In Progress'),
  replied('回答済み', 'Replied'),
  closed('クローズ', 'Closed'),
  cancelled('キャンセル', 'Cancelled');

  final String displayName;
  final String displayNameEn;
  const InquiryStatus(this.displayName, this.displayNameEn);

  static InquiryStatus? fromString(String? value) {
    if (value == null) return null;
    try {
      return InquiryStatus.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// Inquiry type
enum InquiryType {
  partInquiry('パーツについて', 'Part Inquiry'),
  serviceInquiry('サービスについて', 'Service Inquiry'),
  estimate('見積もり依頼', 'Estimate Request'),
  appointment('予約・来店', 'Appointment'),
  vehiclePurchase('車両購入', 'Vehicle Purchase'),
  vehicleSale('車両売却', 'Vehicle Sale'),
  general('その他', 'General');

  final String displayName;
  final String displayNameEn;
  const InquiryType(this.displayName, this.displayNameEn);

  static InquiryType? fromString(String? value) {
    if (value == null) return null;
    try {
      return InquiryType.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// Message in an inquiry thread
class InquiryMessage {
  final String id;
  final String senderId;      // User ID or Shop ID
  final bool isFromShop;      // true if sent by shop
  final String content;
  final List<String> attachmentUrls;
  final DateTime sentAt;
  final bool isRead;

  const InquiryMessage({
    required this.id,
    required this.senderId,
    required this.isFromShop,
    required this.content,
    this.attachmentUrls = const [],
    required this.sentAt,
    this.isRead = false,
  });

  factory InquiryMessage.fromMap(Map<String, dynamic> map, String id) {
    return InquiryMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      isFromShop: map['isFromShop'] ?? false,
      content: map['content'] ?? '',
      attachmentUrls: List<String>.from(map['attachmentUrls'] ?? []),
      sentAt: (map['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'isFromShop': isFromShop,
      'content': content,
      'attachmentUrls': attachmentUrls,
      'sentAt': Timestamp.fromDate(sentAt),
      'isRead': isRead,
    };
  }
}

/// User-to-Shop inquiry model
class Inquiry {
  final String id;
  final String userId;
  final String shopId;
  final String? vehicleId;      // Related vehicle (optional)
  final String? partListingId;  // Related part (optional)

  final InquiryType type;
  final InquiryStatus status;

  final String subject;
  final String initialMessage;  // First message content
  final List<String> attachmentUrls;

  // Vehicle info snapshot (for context)
  final String? vehicleMaker;
  final String? vehicleModel;
  final int? vehicleYear;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? repliedAt;    // First reply from shop
  final DateTime? closedAt;

  // Counts
  final int messageCount;
  final int unreadCountUser;    // Unread messages for user
  final int unreadCountShop;    // Unread messages for shop

  const Inquiry({
    required this.id,
    required this.userId,
    required this.shopId,
    this.vehicleId,
    this.partListingId,
    required this.type,
    this.status = InquiryStatus.pending,
    required this.subject,
    required this.initialMessage,
    this.attachmentUrls = const [],
    this.vehicleMaker,
    this.vehicleModel,
    this.vehicleYear,
    required this.createdAt,
    required this.updatedAt,
    this.repliedAt,
    this.closedAt,
    this.messageCount = 1,
    this.unreadCountUser = 0,
    this.unreadCountShop = 1,
  });

  /// Check if inquiry has been replied
  bool get hasReply => repliedAt != null;

  /// Check if inquiry is open
  bool get isOpen =>
      status != InquiryStatus.closed && status != InquiryStatus.cancelled;

  /// Get display status with context
  String get displayStatus {
    if (status == InquiryStatus.pending) {
      return '返信待ち';
    }
    return status.displayName;
  }

  /// Get vehicle display text
  String? get vehicleDisplay {
    if (vehicleMaker == null) return null;
    final parts = <String>[vehicleMaker!];
    if (vehicleModel != null) parts.add(vehicleModel!);
    if (vehicleYear != null) parts.add('(${vehicleYear}年式)');
    return parts.join(' ');
  }

  factory Inquiry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Inquiry(
      id: doc.id,
      userId: data['userId'] ?? '',
      shopId: data['shopId'] ?? '',
      vehicleId: data['vehicleId'],
      partListingId: data['partListingId'],
      type: InquiryType.fromString(data['type']) ?? InquiryType.general,
      status: InquiryStatus.fromString(data['status']) ?? InquiryStatus.pending,
      subject: data['subject'] ?? '',
      initialMessage: data['initialMessage'] ?? '',
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      vehicleMaker: data['vehicleMaker'],
      vehicleModel: data['vehicleModel'],
      vehicleYear: data['vehicleYear'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      repliedAt: (data['repliedAt'] as Timestamp?)?.toDate(),
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      messageCount: data['messageCount'] ?? 1,
      unreadCountUser: data['unreadCountUser'] ?? 0,
      unreadCountShop: data['unreadCountShop'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'shopId': shopId,
      'vehicleId': vehicleId,
      'partListingId': partListingId,
      'type': type.name,
      'status': status.name,
      'subject': subject,
      'initialMessage': initialMessage,
      'attachmentUrls': attachmentUrls,
      'vehicleMaker': vehicleMaker,
      'vehicleModel': vehicleModel,
      'vehicleYear': vehicleYear,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'repliedAt': repliedAt != null ? Timestamp.fromDate(repliedAt!) : null,
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
      'messageCount': messageCount,
      'unreadCountUser': unreadCountUser,
      'unreadCountShop': unreadCountShop,
    };
  }

  Inquiry copyWith({
    String? id,
    String? userId,
    String? shopId,
    String? vehicleId,
    String? partListingId,
    InquiryType? type,
    InquiryStatus? status,
    String? subject,
    String? initialMessage,
    List<String>? attachmentUrls,
    String? vehicleMaker,
    String? vehicleModel,
    int? vehicleYear,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? repliedAt,
    DateTime? closedAt,
    int? messageCount,
    int? unreadCountUser,
    int? unreadCountShop,
  }) {
    return Inquiry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      shopId: shopId ?? this.shopId,
      vehicleId: vehicleId ?? this.vehicleId,
      partListingId: partListingId ?? this.partListingId,
      type: type ?? this.type,
      status: status ?? this.status,
      subject: subject ?? this.subject,
      initialMessage: initialMessage ?? this.initialMessage,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      vehicleMaker: vehicleMaker ?? this.vehicleMaker,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      repliedAt: repliedAt ?? this.repliedAt,
      closedAt: closedAt ?? this.closedAt,
      messageCount: messageCount ?? this.messageCount,
      unreadCountUser: unreadCountUser ?? this.unreadCountUser,
      unreadCountShop: unreadCountShop ?? this.unreadCountShop,
    );
  }

  @override
  String toString() => 'Inquiry($subject, ${status.displayName})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Inquiry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
