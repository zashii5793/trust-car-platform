// ShopReportService Unit Tests
//
// Covers the BtoB "monthly inquiry report" (ROI visibility) feature.
//   1. getMonthlyReport - total / previousTotal / month-over-month change
//   2. getMonthlyReport - status breakdown for the current month
//   3. Month + year boundary handling
//   4. Edge cases (empty shopId, zero inquiries, other shop isolation)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/services/shop_report_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _seedInquiry(
  FakeFirebaseFirestore fakeFs,
  String shopId, {
  required DateTime createdAt,
  InquiryStatus status = InquiryStatus.pending,
}) async {
  await fakeFs.collection('inquiries').add({
    'shopId': shopId,
    'userId': 'user1',
    'createdAt': Timestamp.fromDate(createdAt),
    'status': status.name,
  });
}

/// Creates an inquiry doc and returns its id so messages can be attached.
Future<String> _seedInquiryDoc(
  FakeFirebaseFirestore fakeFs,
  String shopId, {
  required DateTime createdAt,
}) async {
  final ref = await fakeFs.collection('inquiries').add({
    'shopId': shopId,
    'userId': 'user1',
    'createdAt': Timestamp.fromDate(createdAt),
    'status': InquiryStatus.replied.name,
  });
  return ref.id;
}

/// Seeds a message in an inquiry thread. When [withPayload] is true the message
/// carries a `maintenancePayload` (a shop's maintenance proposal).
Future<void> _seedMessage(
  FakeFirebaseFirestore fakeFs,
  String inquiryId, {
  required String senderId,
  required DateTime sentAt,
  int? cost,
  bool withPayload = true,
}) async {
  await fakeFs
      .collection('inquiries')
      .doc(inquiryId)
      .collection('messages')
      .add({
    'senderId': senderId,
    'isFromShop': senderId != 'user1',
    'content': 'msg',
    'sentAt': Timestamp.fromDate(sentAt),
    if (withPayload)
      'maintenancePayload': <String, dynamic>{
        'typeKey': 'oilChange',
        'title': 'オイル交換',
        'date': sentAt.toIso8601String(),
        if (cost != null) 'cost': cost,
      },
  });
}

void main() {
  late FakeFirebaseFirestore fakeFs;
  late ShopReportService sut;

  // Fixed reference point so month boundaries are deterministic.
  final asOf = DateTime(2026, 6, 15, 10);
  final thisMonth = DateTime(2026, 6, 10);
  final prevMonth = DateTime(2026, 5, 10);

  setUp(() {
    fakeFs = FakeFirebaseFirestore();
    sut = ShopReportService(firestore: fakeFs);
  });

  // -------------------------------------------------------------------------
  // getMonthlyReport - totals
  // -------------------------------------------------------------------------
  group('getMonthlyReport totals', () {
    test('counts inquiries received in the current month', () async {
      await _seedInquiry(fakeFs, 'shop1', createdAt: thisMonth);
      await _seedInquiry(fakeFs, 'shop1', createdAt: thisMonth);
      await _seedInquiry(fakeFs, 'shop1', createdAt: thisMonth);

      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      expect(result.isSuccess, isTrue);
      final report = result.valueOrNull!;
      expect(report.total, 3);
      expect(report.month, DateTime(2026, 6, 1));
    });

    test('previousTotal counts only the previous month', () async {
      await _seedInquiry(fakeFs, 'shop1', createdAt: thisMonth);
      await _seedInquiry(fakeFs, 'shop1', createdAt: prevMonth);
      await _seedInquiry(fakeFs, 'shop1', createdAt: prevMonth);

      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      final report = result.valueOrNull!;
      expect(report.total, 1);
      expect(report.previousTotal, 2);
    });

    test('momChange is current minus previous month', () async {
      await _seedInquiry(fakeFs, 'shop1', createdAt: thisMonth);
      await _seedInquiry(fakeFs, 'shop1', createdAt: thisMonth);
      await _seedInquiry(fakeFs, 'shop1', createdAt: thisMonth);
      await _seedInquiry(fakeFs, 'shop1', createdAt: prevMonth);

      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      final report = result.valueOrNull!;
      expect(report.momChange, 2); // 3 - 1
    });
  });

  // -------------------------------------------------------------------------
  // getMonthlyReport - status breakdown
  // -------------------------------------------------------------------------
  group('getMonthlyReport status breakdown', () {
    test('buckets current month inquiries by status', () async {
      await _seedInquiry(
        fakeFs,
        'shop1',
        createdAt: thisMonth,
        status: InquiryStatus.pending,
      );
      await _seedInquiry(
        fakeFs,
        'shop1',
        createdAt: thisMonth,
        status: InquiryStatus.pending,
      );
      await _seedInquiry(
        fakeFs,
        'shop1',
        createdAt: thisMonth,
        status: InquiryStatus.replied,
      );
      await _seedInquiry(
        fakeFs,
        'shop1',
        createdAt: thisMonth,
        status: InquiryStatus.closed,
      );

      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      final report = result.valueOrNull!;
      expect(report.countFor(InquiryStatus.pending), 2);
      expect(report.countFor(InquiryStatus.replied), 1);
      expect(report.countFor(InquiryStatus.closed), 1);
      expect(report.countFor(InquiryStatus.cancelled), 0);
    });

    test('status breakdown ignores previous month inquiries', () async {
      await _seedInquiry(
        fakeFs,
        'shop1',
        createdAt: thisMonth,
        status: InquiryStatus.pending,
      );
      await _seedInquiry(
        fakeFs,
        'shop1',
        createdAt: prevMonth,
        status: InquiryStatus.replied,
      );

      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      final report = result.valueOrNull!;
      expect(report.countFor(InquiryStatus.pending), 1);
      expect(report.countFor(InquiryStatus.replied), 0);
    });
  });

  // -------------------------------------------------------------------------
  // getMonthlyReport - maintenance proposals (ROI metric)
  // -------------------------------------------------------------------------
  group('getMonthlyReport maintenance proposals', () {
    test('counts proposals and sums their value for the current month',
        () async {
      final inq = await _seedInquiryDoc(fakeFs, 'shop1', createdAt: thisMonth);
      await _seedMessage(fakeFs, inq,
          senderId: 'shop1', sentAt: thisMonth, cost: 12000);
      await _seedMessage(fakeFs, inq,
          senderId: 'shop1', sentAt: thisMonth, cost: 8000);

      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      final report = result.valueOrNull!;
      expect(report.maintenanceProposalCount, 2);
      expect(report.maintenanceProposalValue, 20000);
    });

    test('ignores messages without a maintenance payload', () async {
      final inq = await _seedInquiryDoc(fakeFs, 'shop1', createdAt: thisMonth);
      await _seedMessage(fakeFs, inq,
          senderId: 'shop1', sentAt: thisMonth, cost: 5000);
      await _seedMessage(fakeFs, inq,
          senderId: 'shop1', sentAt: thisMonth, withPayload: false);

      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      final report = result.valueOrNull!;
      expect(report.maintenanceProposalCount, 1);
      expect(report.maintenanceProposalValue, 5000);
    });

    test('ignores proposals sent in the previous month', () async {
      final inq = await _seedInquiryDoc(fakeFs, 'shop1', createdAt: prevMonth);
      await _seedMessage(fakeFs, inq,
          senderId: 'shop1', sentAt: prevMonth, cost: 9000);

      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      final report = result.valueOrNull!;
      expect(report.maintenanceProposalCount, 0);
      expect(report.maintenanceProposalValue, 0);
    });

    test('does not count proposals sent by other shops', () async {
      final inq = await _seedInquiryDoc(fakeFs, 'shop1', createdAt: thisMonth);
      await _seedMessage(fakeFs, inq,
          senderId: 'shop1', sentAt: thisMonth, cost: 3000);
      // A message whose sender is a different shop must be excluded.
      await _seedMessage(fakeFs, inq,
          senderId: 'other_shop', sentAt: thisMonth, cost: 99999);

      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      final report = result.valueOrNull!;
      expect(report.maintenanceProposalCount, 1);
      expect(report.maintenanceProposalValue, 3000);
    });

    test('payload without cost counts but adds zero to value', () async {
      final inq = await _seedInquiryDoc(fakeFs, 'shop1', createdAt: thisMonth);
      await _seedMessage(fakeFs, inq, senderId: 'shop1', sentAt: thisMonth);

      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      final report = result.valueOrNull!;
      expect(report.maintenanceProposalCount, 1);
      expect(report.maintenanceProposalValue, 0);
    });

    test('no proposals -> zero count and value', () async {
      await _seedInquiry(fakeFs, 'shop1', createdAt: thisMonth);

      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      final report = result.valueOrNull!;
      expect(report.maintenanceProposalCount, 0);
      expect(report.maintenanceProposalValue, 0);
    });
  });

  // -------------------------------------------------------------------------
  // Boundaries
  // -------------------------------------------------------------------------
  group('Boundaries', () {
    test('excludes inquiries older than the previous month', () async {
      await _seedInquiry(fakeFs, 'shop1', createdAt: DateTime(2026, 3, 20));

      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      final report = result.valueOrNull!;
      expect(report.total, 0);
      expect(report.previousTotal, 0);
    });

    test('excludes inquiries created in a future month', () async {
      await _seedInquiry(fakeFs, 'shop1', createdAt: DateTime(2026, 7, 1));

      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      final report = result.valueOrNull!;
      expect(report.total, 0);
    });

    test('handles year boundary (January looks back to December)', () async {
      final jan = DateTime(2026, 1, 15, 9);
      await _seedInquiry(fakeFs, 'shop1', createdAt: DateTime(2026, 1, 5));
      await _seedInquiry(fakeFs, 'shop1', createdAt: DateTime(2025, 12, 20));
      await _seedInquiry(fakeFs, 'shop1', createdAt: DateTime(2025, 12, 2));

      final result = await sut.getMonthlyReport('shop1', asOf: jan);

      final report = result.valueOrNull!;
      expect(report.month, DateTime(2026, 1, 1));
      expect(report.total, 1);
      expect(report.previousTotal, 2);
    });
  });

  // -------------------------------------------------------------------------
  // Edge Cases
  // -------------------------------------------------------------------------
  group('Edge Cases', () {
    test('empty shopId -> failure', () async {
      final result = await sut.getMonthlyReport('', asOf: asOf);

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationError>());
    });

    test('zero inquiries -> all zero, empty breakdown', () async {
      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      final report = result.valueOrNull!;
      expect(report.total, 0);
      expect(report.previousTotal, 0);
      expect(report.momChange, 0);
      expect(report.countFor(InquiryStatus.pending), 0);
    });

    test('does not count other shops inquiries', () async {
      await _seedInquiry(fakeFs, 'shop1', createdAt: thisMonth);
      await _seedInquiry(fakeFs, 'other_shop', createdAt: thisMonth);
      await _seedInquiry(fakeFs, 'other_shop', createdAt: thisMonth);

      final result = await sut.getMonthlyReport('shop1', asOf: asOf);

      final report = result.valueOrNull!;
      expect(report.total, 1);
    });
  });
}
