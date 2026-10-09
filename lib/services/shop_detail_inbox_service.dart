import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/inquiry.dart';
import 'inquiry_maintenance_importer.dart';

/// A maintenance detail a shop sent to the user, not yet added to records.
class ReceivedShopDetail {
  final Inquiry inquiry;
  final InquiryMessage message;
  final InquiryMaintenancePayload payload;

  const ReceivedShopDetail({
    required this.inquiry,
    required this.message,
    required this.payload,
  });

  /// The sender, by the shop's name (never just "工場").
  String get shopName {
    final fromInquiry = inquiry.shopName?.trim() ?? '';
    if (fromInquiry.isNotEmpty) return fromInquiry;
    final fromPayload = payload.shopName?.trim() ?? '';
    return fromPayload.isNotEmpty ? fromPayload : '整備工場';
  }
}

/// Outcome of adding a shop detail to the user's records.
class DetailImportResult {
  final String recordId;

  /// True when the detail had already been added (nothing new was written).
  final bool alreadyImported;

  const DetailImportResult({
    required this.recordId,
    required this.alreadyImported,
  });
}

/// The user's side of shop-sent maintenance details (usability test
/// 2026-10-09).
///
/// - [importDetail] adds a detail to the records **once**. The record is
///   written under a deterministic ID and carries `sourceMessageId`; the
///   message gets `importedAt` / `importedRecordId` so the thread (and the
///   shop) can tell it was added after the screen is reopened
/// - [pendingDetails] lists details not yet added, for the home card and
///   the notification list
/// - Details added before `sourceMessageId` existed are recognised by the
///   same day, amount and title in the same thread (no data migration)
class ShopDetailInboxService {
  final FirebaseFirestore _firestore;
  final DateTime Function() _now;

  ShopDetailInboxService({
    required FirebaseFirestore firestore,
    DateTime Function()? now,
  })  : _firestore = firestore,
        _now = now ?? DateTime.now;

  /// How many of the user's latest threads to look through for details.
  static const int threadLimit = 30;

  /// How many messages per thread to look through.
  static const int messageLimit = 200;

  CollectionReference<Map<String, dynamic>> get _inquiries =>
      _firestore.collection(FirestoreCollections.inquiries);

  CollectionReference<Map<String, dynamic>> get _records =>
      _firestore.collection(FirestoreCollections.maintenanceRecords);

  CollectionReference<Map<String, dynamic>> _messages(String inquiryId) =>
      _inquiries.doc(inquiryId).collection(FirestoreCollections.messages);

  /// Deterministic record ID: one record per shop detail, even when two
  /// devices add it at the same time.
  static String recordIdFor(String inquiryId, String messageId) =>
      'shopdetail_${inquiryId}_$messageId';

  /// Adds the detail in [messageId] to the user's records. Idempotent: when
  /// it was already added, returns the existing record.
  Future<Result<DetailImportResult, AppError>> importDetail({
    required String userId,
    required String inquiryId,
    required String messageId,
    required InquiryMaintenancePayload payload,
    required String vehicleId,
  }) async {
    if (userId.isEmpty || inquiryId.isEmpty || messageId.isEmpty) {
      return const Result.failure(AppError.validation('明細が特定できません'));
    }
    if (vehicleId.isEmpty) {
      return const Result.failure(
          AppError.validation('どの車の明細かを選んでください', field: 'vehicleId'));
    }
    try {
      final inquiry = await _inquiries.doc(inquiryId).get();
      if (!inquiry.exists) {
        return const Result.failure(
            AppError.notFound('この明細のやりとりが見つかりません', resourceType: 'inquiry'));
      }
      if (inquiry.data()?['userId'] != userId) {
        return const Result.failure(AppError.permission('この明細はあなた宛てではありません'));
      }

      final existing = await _findImported(
        userId: userId,
        inquiryId: inquiryId,
        messageId: messageId,
        payload: payload,
      );
      if (existing != null) {
        await _markMessage(inquiryId, messageId, existing);
        return Result.success(
            DetailImportResult(recordId: existing, alreadyImported: true));
      }

      final record = buildMaintenanceRecordFromPayload(
        payload: payload,
        vehicleId: vehicleId,
        userId: userId,
        inquiryId: inquiryId,
        sourceMessageId: messageId,
        now: _now(),
      );
      final id = recordIdFor(inquiryId, messageId);
      await _records.doc(id).set(record.toMap());
      await _markMessage(inquiryId, messageId, id);
      return Result.success(
          DetailImportResult(recordId: id, alreadyImported: false));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// IDs of the messages in [messages] whose detail is already in the
  /// user's records.
  Future<Result<Set<String>, AppError>> importedMessageIds({
    required String userId,
    required String inquiryId,
    required List<InquiryMessage> messages,
  }) async {
    if (userId.isEmpty || inquiryId.isEmpty) {
      return const Result.failure(AppError.validation('利用者が分かりません'));
    }
    final details = messages.where((m) => m.hasMaintenanceDetail).toList();
    if (details.isEmpty) return const Result.success(<String>{});
    try {
      final ids = <String>{
        for (final m in details)
          if (m.isDetailImported) m.id,
      };
      final records = await _recordsOf(userId, inquiryId);
      for (final m in details) {
        if (ids.contains(m.id)) continue;
        final payload =
            InquiryMaintenancePayload.fromMap(m.maintenancePayload!);
        if (_matchRecord(records, m.id, payload) != null) ids.add(m.id);
      }
      return Result.success(ids);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// Details the shop sent that the user has not added yet, newest first.
  Future<Result<List<ReceivedShopDetail>, AppError>> pendingDetails(
      String userId) async {
    if (userId.isEmpty) {
      return const Result.failure(AppError.validation('利用者が分かりません'));
    }
    try {
      final snap = await _inquiries
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .limit(threadLimit)
          .get();
      final out = <ReceivedShopDetail>[];
      for (final doc in snap.docs) {
        final inquiry = Inquiry.fromFirestore(doc);
        if (!inquiry.mayCarryDetails) continue;

        final msgs = (await _messages(inquiry.id)
                .orderBy('sentAt')
                .limit(messageLimit)
                .get())
            .docs
            .map((d) => InquiryMessage.fromMap(d.data(), d.id))
            .where((m) => m.hasMaintenanceDetail && !m.isDetailImported)
            .toList();
        if (msgs.isEmpty) continue;

        final records = await _recordsOf(userId, inquiry.id);
        for (final m in msgs) {
          final payload =
              InquiryMaintenancePayload.fromMap(m.maintenancePayload!);
          if (_matchRecord(records, m.id, payload) != null) continue;
          out.add(ReceivedShopDetail(
              inquiry: inquiry, message: m, payload: payload));
        }
      }
      out.sort((a, b) => b.message.sentAt.compareTo(a.message.sentAt));
      return Result.success(out);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// Marks the shop's unread detail messages as read, so the shop can tell
  /// the detail reached the user.
  Future<Result<void, AppError>> markSeen({
    required String inquiryId,
    required List<InquiryMessage> messages,
  }) async {
    final unread =
        messages.where((m) => m.hasMaintenanceDetail && !m.isRead).toList();
    if (inquiryId.isEmpty || unread.isEmpty) {
      return const Result.success(null);
    }
    try {
      final batch = _firestore.batch();
      for (final m in unread) {
        batch.update(_messages(inquiryId).doc(m.id), {
          'isRead': true,
          'readAt': Timestamp.fromDate(_now()),
        });
      }
      await batch.commit();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  Future<String?> _findImported({
    required String userId,
    required String inquiryId,
    required String messageId,
    required InquiryMaintenancePayload payload,
  }) async {
    final records = await _recordsOf(userId, inquiryId);
    return _matchRecord(records, messageId, payload);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _recordsOf(
      String userId, String inquiryId) async {
    final snap = await _records
        .where('userId', isEqualTo: userId)
        .where('inquiryId', isEqualTo: inquiryId)
        .get();
    return snap.docs;
  }

  /// The record made from [messageId], or — for records added before
  /// `sourceMessageId` existed — one with the same day, amount and title.
  static String? _matchRecord(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> records,
    String messageId,
    InquiryMaintenancePayload payload,
  ) {
    for (final r in records) {
      if (r.data()['sourceMessageId'] == messageId) return r.id;
    }
    final title = payload.title.isEmpty ? '整備記録' : payload.title;
    for (final r in records) {
      final d = r.data();
      if (d['sourceMessageId'] != null) continue;
      final date = (d['date'] as Timestamp?)?.toDate();
      if (date == null) continue;
      final sameDay = date.year == payload.date.year &&
          date.month == payload.date.month &&
          date.day == payload.date.day;
      if (sameDay &&
          (d['cost'] as num?)?.toInt() == payload.cost &&
          d['title'] == title) {
        return r.id;
      }
    }
    return null;
  }

  /// Best effort: the record is the source of truth; the mark on the message
  /// is for the shop and for showing the state without a query.
  Future<void> _markMessage(
      String inquiryId, String messageId, String recordId) async {
    try {
      await _messages(inquiryId).doc(messageId).update({
        'importedAt': Timestamp.fromDate(_now()),
        'importedRecordId': recordId,
      });
    } catch (_) {
      // Ignored: see above.
    }
  }
}
