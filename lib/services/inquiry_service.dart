import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/inquiry.dart';
import '../models/vehicle.dart';

/// Service for inquiry (user-to-shop communication) operations
class InquiryService {
  final FirebaseFirestore _firestore;

  InquiryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _inquiriesCollection =>
      _firestore.collection('inquiries');

  /// Create a new inquiry
  Future<Result<Inquiry, AppError>> createInquiry({
    required String userId,
    required String shopId,
    required InquiryType type,
    required String subject,
    required String message,
    String? vehicleId,
    String? partListingId,
    Vehicle? vehicle,
    List<String> attachmentUrls = const [],
  }) async {
    try {
      final now = DateTime.now();
      final inquiryData = {
        'userId': userId,
        'shopId': shopId,
        'vehicleId': vehicleId,
        'partListingId': partListingId,
        'type': type.name,
        'status': InquiryStatus.pending.name,
        'subject': subject,
        'initialMessage': message,
        'attachmentUrls': attachmentUrls,
        'vehicleMaker': vehicle?.maker,
        'vehicleModel': vehicle?.model,
        'vehicleYear': vehicle?.year,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'repliedAt': null,
        'closedAt': null,
        'messageCount': 1,
        'unreadCountUser': 0,
        'unreadCountShop': 1,
      };

      final docRef = await _inquiriesCollection.add(inquiryData);
      final doc = await docRef.get();

      return Result.success(Inquiry.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.server('問い合わせの送信に失敗しました: $e'));
    }
  }

  /// Get inquiry by ID
  Future<Result<Inquiry, AppError>> getInquiry(String inquiryId) async {
    try {
      final doc = await _inquiriesCollection.doc(inquiryId).get();

      if (!doc.exists) {
        return Result.failure(AppError.notFound('問い合わせが見つかりません'));
      }

      return Result.success(Inquiry.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.server('問い合わせの取得に失敗しました: $e'));
    }
  }

  /// Get inquiries for a user
  Future<Result<List<Inquiry>, AppError>> getUserInquiries(
    String userId, {
    InquiryStatus? status,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _inquiriesCollection
          .where('userId', isEqualTo: userId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      query = query
          .orderBy('updatedAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      final inquiries = snapshot.docs
          .map((doc) => Inquiry.fromFirestore(doc))
          .toList();

      return Result.success(inquiries);
    } catch (e) {
      return Result.failure(AppError.server('問い合わせ一覧の取得に失敗しました: $e'));
    }
  }

  /// Get inquiries for a shop
  Future<Result<List<Inquiry>, AppError>> getShopInquiries(
    String shopId, {
    InquiryStatus? status,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _inquiriesCollection
          .where('shopId', isEqualTo: shopId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      query = query
          .orderBy('updatedAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      final inquiries = snapshot.docs
          .map((doc) => Inquiry.fromFirestore(doc))
          .toList();

      return Result.success(inquiries);
    } catch (e) {
      return Result.failure(AppError.server('問い合わせ一覧の取得に失敗しました: $e'));
    }
  }

  /// Send a message in an inquiry thread
  Future<Result<InquiryMessage, AppError>> sendMessage({
    required String inquiryId,
    required String senderId,
    required bool isFromShop,
    required String content,
    List<String> attachmentUrls = const [],
  }) async {
    try {
      final now = DateTime.now();
      final messageData = {
        'senderId': senderId,
        'isFromShop': isFromShop,
        'content': content,
        'attachmentUrls': attachmentUrls,
        'sentAt': Timestamp.fromDate(now),
        'isRead': false,
      };

      // Add message to subcollection
      final messageRef = await _inquiriesCollection
          .doc(inquiryId)
          .collection('messages')
          .add(messageData);

      // Update inquiry
      final updateData = {
        'updatedAt': Timestamp.fromDate(now),
        'messageCount': FieldValue.increment(1),
      };

      if (isFromShop) {
        // First reply from shop
        final inquiry = await getInquiry(inquiryId);
        if (inquiry.isSuccess && inquiry.valueOrNull?.repliedAt == null) {
          updateData['repliedAt'] = Timestamp.fromDate(now);
          updateData['status'] = InquiryStatus.replied.name;
        }
        updateData['unreadCountUser'] = FieldValue.increment(1);
      } else {
        updateData['unreadCountShop'] = FieldValue.increment(1);
        // If user replies after shop, set status back to inProgress
        updateData['status'] = InquiryStatus.inProgress.name;
      }

      await _inquiriesCollection.doc(inquiryId).update(updateData);

      final messageDoc = await messageRef.get();
      return Result.success(InquiryMessage.fromMap(
        messageDoc.data() ?? {},
        messageDoc.id,
      ));
    } catch (e) {
      return Result.failure(AppError.server('メッセージの送信に失敗しました: $e'));
    }
  }

  /// Get messages for an inquiry
  Future<Result<List<InquiryMessage>, AppError>> getMessages(
    String inquiryId, {
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _inquiriesCollection
          .doc(inquiryId)
          .collection('messages')
          .orderBy('sentAt', descending: false)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      final messages = snapshot.docs
          .map((doc) => InquiryMessage.fromMap(doc.data(), doc.id))
          .toList();

      return Result.success(messages);
    } catch (e) {
      return Result.failure(AppError.server('メッセージの取得に失敗しました: $e'));
    }
  }

  /// Mark messages as read
  Future<Result<void, AppError>> markAsRead({
    required String inquiryId,
    required bool isUser,
  }) async {
    try {
      // Reset unread count
      final updateData = isUser
          ? {'unreadCountUser': 0}
          : {'unreadCountShop': 0};

      await _inquiriesCollection.doc(inquiryId).update(updateData);

      // Mark individual messages as read
      final messages = await _inquiriesCollection
          .doc(inquiryId)
          .collection('messages')
          .where('isFromShop', isEqualTo: isUser)  // Messages from the other party
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.server('既読処理に失敗しました: $e'));
    }
  }

  /// Update inquiry status
  Future<Result<Inquiry, AppError>> updateStatus(
    String inquiryId,
    InquiryStatus status,
  ) async {
    try {
      final now = DateTime.now();
      final updateData = {
        'status': status.name,
        'updatedAt': Timestamp.fromDate(now),
      };

      if (status == InquiryStatus.closed || status == InquiryStatus.cancelled) {
        updateData['closedAt'] = Timestamp.fromDate(now);
      }

      await _inquiriesCollection.doc(inquiryId).update(updateData);

      return getInquiry(inquiryId);
    } catch (e) {
      return Result.failure(AppError.server('ステータスの更新に失敗しました: $e'));
    }
  }

  /// Get unread inquiry count for user
  Future<Result<int, AppError>> getUnreadCountForUser(String userId) async {
    try {
      final snapshot = await _inquiriesCollection
          .where('userId', isEqualTo: userId)
          .where('unreadCountUser', isGreaterThan: 0)
          .get();

      return Result.success(snapshot.docs.length);
    } catch (e) {
      return Result.failure(AppError.server('未読数の取得に失敗しました: $e'));
    }
  }

  /// Stream inquiries for real-time updates
  Stream<List<Inquiry>> streamUserInquiries(String userId) {
    return _inquiriesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Inquiry.fromFirestore(doc))
            .toList());
  }

  /// Stream messages for real-time chat
  Stream<List<InquiryMessage>> streamMessages(String inquiryId) {
    return _inquiriesCollection
        .doc(inquiryId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InquiryMessage.fromMap(doc.data(), doc.id))
            .toList());
  }
}
