import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/firestore_collections.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/inquiry.dart';
import '../models/vehicle.dart';
import 'shop_subscription_service.dart';

/// Service for inquiry (user-to-shop communication) operations
class InquiryService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth? _authOverride;
  final ShopSubscriptionService _subscriptionService;

  InquiryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ShopSubscriptionService? subscriptionService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authOverride = auth,
        _subscriptionService = subscriptionService ?? ShopSubscriptionService();

  /// Resolved lazily so tests can construct this service with a fake
  /// Firestore only, without calling Firebase.initializeApp().
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _inquiriesCollection =>
      _firestore.collection(FirestoreCollections.inquiries);

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
    String? shopName,
    List<String> attachmentUrls = const [],
  }) async {
    // Enforce monthly inquiry limit for the shop's subscription plan.
    // NOTE: There is a known TOCTOU race condition between this check and the
    // document write below. Two simultaneous requests could both pass the check
    // and exceed the limit by 1. Atomic enforcement requires a Cloud Function
    // with a Firestore transaction; the Firestore security rule provides a
    // server-side backstop for egregious over-use.
    final canReceiveResult =
        await _subscriptionService.canReceiveInquiry(shopId);
    if (canReceiveResult.isFailure) {
      return Result.failure(canReceiveResult.errorOrNull!);
    }
    if (canReceiveResult.valueOrNull == false) {
      return const Result.failure(
        AppError.planLimit(
          'This shop has reached its monthly inquiry limit',
          planName: 'フリー',
        ),
      );
    }

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
        'shopName': shopName,
        'vehicleMaker': vehicle?.maker,
        'vehicleModel': vehicle?.model,
        'vehicleYear': vehicle?.year,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'repliedAt': null,
        'closedAt': null,
        'visitedAt': null,
        'convertedAt': null,
        'dealAmount': null,
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
      Query<Map<String, dynamic>> query =
          _inquiriesCollection.where('userId', isEqualTo: userId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      query = query.orderBy('updatedAt', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      final inquiries =
          snapshot.docs.map((doc) => Inquiry.fromFirestore(doc)).toList();

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
      Query<Map<String, dynamic>> query =
          _inquiriesCollection.where('shopId', isEqualTo: shopId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      query = query.orderBy('updatedAt', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      final inquiries =
          snapshot.docs.map((doc) => Inquiry.fromFirestore(doc)).toList();

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
    Map<String, dynamic>? maintenancePayload,
  }) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      return const Result.failure(
        AppError.auth('認証が必要です', type: AuthErrorType.unknown),
      );
    }
    if (currentUid != senderId) {
      return const Result.failure(
        AppError.auth('操作が許可されていません', type: AuthErrorType.unknown),
      );
    }
    try {
      final now = DateTime.now();
      final messageData = {
        'senderId': senderId,
        'isFromShop': isFromShop,
        'content': content,
        'attachmentUrls': attachmentUrls,
        'sentAt': Timestamp.fromDate(now),
        'isRead': false,
        if (maintenancePayload != null)
          'maintenancePayload': maintenancePayload,
      };

      // Add message to subcollection
      final messageRef = await _inquiriesCollection
          .doc(inquiryId)
          .collection(FirestoreCollections.messages)
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
          .collection(FirestoreCollections.messages)
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
      final updateData =
          isUser ? {'unreadCountUser': 0} : {'unreadCountShop': 0};

      await _inquiriesCollection.doc(inquiryId).update(updateData);

      // Mark individual messages as read
      final messages = await _inquiriesCollection
          .doc(inquiryId)
          .collection(FirestoreCollections.messages)
          .where('isFromShop',
              isEqualTo: isUser) // Messages from the other party
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

  /// Mark that the customer has visited the shop (lead → visit).
  ///
  /// Part of the B2B ROI funnel: lets a shop record real-world conversion so the
  /// platform can prove send-through value when selling to other shops.
  Future<Result<Inquiry, AppError>> markVisited(String inquiryId) async {
    try {
      final doc = await _inquiriesCollection.doc(inquiryId).get();
      if (!doc.exists) {
        return Result.failure(AppError.notFound('問い合わせが見つかりません'));
      }

      final now = DateTime.now();
      await _inquiriesCollection.doc(inquiryId).update({
        'visitedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      return getInquiry(inquiryId);
    } catch (e) {
      return Result.failure(AppError.server('来店記録の更新に失敗しました: $e'));
    }
  }

  /// Mark that the inquiry resulted in a closed deal (visit → conversion).
  ///
  /// A conversion implies a visit, so [visitedAt] is back-filled when it has not
  /// been recorded yet. [dealAmount] is the closed amount in JPY (optional);
  /// negative values are rejected.
  Future<Result<Inquiry, AppError>> markConverted(
    String inquiryId, {
    int? dealAmount,
  }) async {
    if (dealAmount != null && dealAmount < 0) {
      return const Result.failure(
        AppError.validation('成約金額に負の値は指定できません', field: 'dealAmount'),
      );
    }
    try {
      final doc = await _inquiriesCollection.doc(inquiryId).get();
      if (!doc.exists) {
        return Result.failure(AppError.notFound('問い合わせが見つかりません'));
      }

      final now = DateTime.now();
      final existing = Inquiry.fromFirestore(doc);
      final updateData = <String, dynamic>{
        'convertedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        if (dealAmount != null) 'dealAmount': dealAmount,
        // A closed deal means the customer came in — back-fill the visit.
        if (existing.visitedAt == null) 'visitedAt': Timestamp.fromDate(now),
      };

      await _inquiriesCollection.doc(inquiryId).update(updateData);

      return getInquiry(inquiryId);
    } catch (e) {
      return Result.failure(AppError.server('成約記録の更新に失敗しました: $e'));
    }
  }

  /// Aggregate the lead-conversion funnel for a shop over an optional period.
  ///
  /// Returns inquiry → reply → visit → conversion counts plus the total closed
  /// deal amount. This is the raw material for the monthly B2B ROI report.
  Future<Result<ShopConversionStats, AppError>> getShopConversionStats(
    String shopId, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _inquiriesCollection.where('shopId', isEqualTo: shopId);

      if (from != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from));
      }
      if (to != null) {
        query = query.where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(to));
      }

      final snapshot = await query.get();
      final inquiries =
          snapshot.docs.map((doc) => Inquiry.fromFirestore(doc)).toList();

      var replied = 0;
      var visited = 0;
      var converted = 0;
      var totalDeal = 0;
      for (final inq in inquiries) {
        if (inq.hasReply) replied++;
        if (inq.hasVisited) visited++;
        if (inq.isConverted) {
          converted++;
          totalDeal += inq.dealAmount ?? 0;
        }
      }

      return Result.success(ShopConversionStats(
        inquiryCount: inquiries.length,
        repliedCount: replied,
        visitedCount: visited,
        convertedCount: converted,
        totalDealAmount: totalDeal,
      ));
    } catch (e) {
      return Result.failure(AppError.server('送客集計の取得に失敗しました: $e'));
    }
  }

  /// Count inquiries the user has sent this calendar month.
  ///
  /// Used to enforce the B2C free-plan monthly inquiry limit on the client
  /// before submission (server-side rule remains the backstop).
  Future<Result<int, AppError>> countUserInquiriesThisMonth(
      String userId) async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final snapshot = await _inquiriesCollection
          .where('userId', isEqualTo: userId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .get();

      return Result.success(snapshot.docs.length);
    } catch (e) {
      return Result.failure(AppError.server('問い合わせ数の取得に失敗しました: $e'));
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
        .map((snapshot) =>
            snapshot.docs.map((doc) => Inquiry.fromFirestore(doc)).toList());
  }

  /// Stream messages for real-time chat
  Stream<List<InquiryMessage>> streamMessages(String inquiryId) {
    return _inquiriesCollection
        .doc(inquiryId)
        .collection(FirestoreCollections.messages)
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InquiryMessage.fromMap(doc.data(), doc.id))
            .toList());
  }
}

/// Aggregated lead-conversion funnel for a single shop.
///
/// Drives the B2B ROI story: "we sent you N leads, you replied to R, V came in,
/// and C closed for ¥total". Rates are guarded against division by zero.
class ShopConversionStats {
  final int inquiryCount;
  final int repliedCount;
  final int visitedCount;
  final int convertedCount;
  final int totalDealAmount; // JPY

  const ShopConversionStats({
    this.inquiryCount = 0,
    this.repliedCount = 0,
    this.visitedCount = 0,
    this.convertedCount = 0,
    this.totalDealAmount = 0,
  });

  /// Share of inquiries the shop replied to (0.0–1.0).
  double get replyRate =>
      inquiryCount == 0 ? 0 : repliedCount / inquiryCount;

  /// Share of inquiries that turned into a real visit (0.0–1.0).
  double get visitRate =>
      inquiryCount == 0 ? 0 : visitedCount / inquiryCount;

  /// Share of inquiries that closed into a deal (0.0–1.0).
  double get conversionRate =>
      inquiryCount == 0 ? 0 : convertedCount / inquiryCount;
}
