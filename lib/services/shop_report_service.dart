import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/inquiry.dart';
import '../models/shop_monthly_report.dart';

/// Service for BtoB shop reporting (ROI visibility).
///
/// Produces the minimal "monthly inquiry report" so a shop can answer the only
/// question that decides whether they keep paying: "how many inquiries did I
/// get, and is it growing?". Heavier CRM/pipeline tracking is intentionally out
/// of scope here.
class ShopReportService {
  final FirebaseFirestore? _firestoreOverride;

  ShopReportService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  /// Resolved lazily so tests can construct this service without
  /// calling Firebase.initializeApp().
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _inquiries =>
      _firestore.collection('inquiries');

  /// Returns the inquiry report for the calendar month containing [asOf]
  /// (defaults to now), including the previous month for comparison.
  Future<Result<ShopMonthlyReport, AppError>> getMonthlyReport(
    String shopId, {
    DateTime? asOf,
  }) async {
    if (shopId.isEmpty) {
      return const Result.failure(
        AppError.validation('shopId must not be empty', field: 'shopId'),
      );
    }

    try {
      final now = asOf ?? DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      // DateTime normalizes month underflow/overflow (month 0 -> prev Dec).
      final previousMonthStart = DateTime(now.year, now.month - 1, 1);
      final nextMonthStart = DateTime(now.year, now.month + 1, 1);
      final fromTs = Timestamp.fromDate(previousMonthStart);
      final toTs = Timestamp.fromDate(nextMonthStart);

      // Single range over createdAt bounded to [prevMonth, nextMonth),
      // then bucket in memory to avoid a second round trip.
      final snapshot = await _inquiries
          .where('shopId', isEqualTo: shopId)
          .where('createdAt', isGreaterThanOrEqualTo: fromTs)
          .where('createdAt', isLessThan: toTs)
          .get();

      var total = 0;
      var previousTotal = 0;
      final byStatus = <InquiryStatus, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null) continue;

        if (createdAt.isBefore(monthStart)) {
          previousTotal++;
        } else {
          total++;
          final parsed = InquiryStatus.fromString(data['status']);
          final status = parsed ?? InquiryStatus.pending;
          byStatus[status] = (byStatus[status] ?? 0) + 1;
        }
      }

      // Maintenance proposals the shop itself sent this month. Sourced from the
      // shop's own messages (senderId == shopId), so this stays within what the
      // shop is allowed to read — no cross-user maintenance_records access.
      final messages = await _firestore
          .collectionGroup('messages')
          .where('senderId', isEqualTo: shopId)
          .get();

      var proposalCount = 0;
      var proposalValue = 0;
      for (final doc in messages.docs) {
        final data = doc.data();
        if (data['maintenancePayload'] is! Map) continue;
        final sentAt = (data['sentAt'] as Timestamp?)?.toDate();
        if (sentAt == null) continue;
        if (sentAt.isBefore(monthStart) || !sentAt.isBefore(nextMonthStart)) {
          continue;
        }
        proposalCount++;
        final payload = data['maintenancePayload'] as Map;
        final cost = payload['cost'];
        if (cost is num) proposalValue += cost.toInt();
      }

      return Result.success(ShopMonthlyReport(
        month: monthStart,
        total: total,
        previousTotal: previousTotal,
        byStatus: byStatus,
        maintenanceProposalCount: proposalCount,
        maintenanceProposalValue: proposalValue,
      ));
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}
