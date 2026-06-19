// Inquiry conversion / lead-tracking tests (送客トラッキング)
//
// Covers the B2B ROI pipeline the business plan demands:
//   1. Inquiry.hasVisited / isConverted getters
//   2. InquiryService.markVisited()
//   3. InquiryService.markConverted()
//   4. InquiryService.getShopConversionStats() — funnel aggregation
//
// RED → GREEN → REFACTOR.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/services/shop_subscription_service.dart';

void main() {
  // ── Model getters ─────────────────────────────────────────────────────────

  group('Inquiry.hasVisited / isConverted', () {
    Inquiry make({DateTime? visitedAt, DateTime? convertedAt}) {
      final now = DateTime.now();
      return Inquiry(
        id: 'inq1',
        userId: 'user1',
        shopId: 'shop1',
        type: InquiryType.appointment,
        subject: 's',
        initialMessage: 'm',
        createdAt: now,
        updatedAt: now,
        visitedAt: visitedAt,
        convertedAt: convertedAt,
      );
    }

    test('visitedAt が null のとき hasVisited は false', () {
      expect(make().hasVisited, false);
    });

    test('visitedAt が設定済みのとき hasVisited は true', () {
      expect(make(visitedAt: DateTime.now()).hasVisited, true);
    });

    test('convertedAt が null のとき isConverted は false', () {
      expect(make().isConverted, false);
    });

    test('convertedAt が設定済みのとき isConverted は true', () {
      expect(make(convertedAt: DateTime.now()).isConverted, true);
    });

    test('toMap/fromFirestore で visitedAt/convertedAt/dealAmount が往復する',
        () async {
      final fakeFs = FakeFirebaseFirestore();
      final now = DateTime.now();
      final inq = Inquiry(
        id: 'x',
        userId: 'user1',
        shopId: 'shop1',
        type: InquiryType.appointment,
        subject: 's',
        initialMessage: 'm',
        createdAt: now,
        updatedAt: now,
        visitedAt: now,
        convertedAt: now,
        dealAmount: 120000,
      );
      final ref = await fakeFs.collection('inquiries').add(inq.toMap());
      final round = Inquiry.fromFirestore(await ref.get());
      expect(round.hasVisited, true);
      expect(round.isConverted, true);
      expect(round.dealAmount, 120000);
    });
  });

  // ── Service: markVisited / markConverted / stats ──────────────────────────

  group('InquiryService 送客トラッキング', () {
    late FakeFirebaseFirestore fakeFs;

    InquiryService makeService() => InquiryService(
          firestore: fakeFs,
          subscriptionService: ShopSubscriptionService(firestore: fakeFs),
        );

    Future<String> seedInquiry({
      String shopId = 'shop1',
      DateTime? createdAt,
      DateTime? repliedAt,
      DateTime? visitedAt,
      DateTime? convertedAt,
      int? dealAmount,
    }) async {
      final now = createdAt ?? DateTime.now();
      final ref = await fakeFs.collection('inquiries').add({
        'shopId': shopId,
        'userId': 'user1',
        'type': 'appointment',
        'status': 'pending',
        'subject': 'test',
        'initialMessage': 'msg',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        if (repliedAt != null) 'repliedAt': Timestamp.fromDate(repliedAt),
        if (visitedAt != null) 'visitedAt': Timestamp.fromDate(visitedAt),
        if (convertedAt != null) 'convertedAt': Timestamp.fromDate(convertedAt),
        if (dealAmount != null) 'dealAmount': dealAmount,
      });
      return ref.id;
    }

    setUp(() {
      fakeFs = FakeFirebaseFirestore();
    });

    test('markVisited は visitedAt を設定して更新後の Inquiry を返す', () async {
      final id = await seedInquiry();
      final result = await makeService().markVisited(id);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.hasVisited, isTrue);
    });

    test('markConverted は convertedAt と dealAmount を設定する', () async {
      final id = await seedInquiry();
      final result = await makeService().markConverted(id, dealAmount: 88000);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.isConverted, isTrue);
      expect(result.valueOrNull!.dealAmount, 88000);
    });

    test('markConverted は来店未記録なら visitedAt も自動補完する（成約=来店）', () async {
      final id = await seedInquiry();
      final result = await makeService().markConverted(id);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.isConverted, isTrue);
      expect(result.valueOrNull!.hasVisited, isTrue);
    });

    test('getShopConversionStats はファネル件数を集計する', () async {
      // 4 inquiries: 3 replied, 2 visited, 1 converted (¥150,000)
      await seedInquiry();
      await seedInquiry(repliedAt: DateTime.now());
      await seedInquiry(repliedAt: DateTime.now(), visitedAt: DateTime.now());
      await seedInquiry(
        repliedAt: DateTime.now(),
        visitedAt: DateTime.now(),
        convertedAt: DateTime.now(),
        dealAmount: 150000,
      );

      final result = await makeService().getShopConversionStats('shop1');

      expect(result.isSuccess, isTrue);
      final stats = result.valueOrNull!;
      expect(stats.inquiryCount, 4);
      expect(stats.repliedCount, 3);
      expect(stats.visitedCount, 2);
      expect(stats.convertedCount, 1);
      expect(stats.totalDealAmount, 150000);
      expect(stats.conversionRate, closeTo(0.25, 0.001));
    });

    test('getShopConversionStats は他ショップの問い合わせを除外する', () async {
      await seedInquiry(shopId: 'shop1');
      await seedInquiry(shopId: 'shop2', convertedAt: DateTime.now());

      final result = await makeService().getShopConversionStats('shop1');

      expect(result.valueOrNull!.inquiryCount, 1);
      expect(result.valueOrNull!.convertedCount, 0);
    });

    test('getShopConversionStats は期間(from/to)で絞り込む', () async {
      final old = DateTime(2020, 1, 1);
      final recent = DateTime.now();
      await seedInquiry(createdAt: old);
      await seedInquiry(createdAt: recent);

      final result = await makeService().getShopConversionStats(
        'shop1',
        from: DateTime.now().subtract(const Duration(days: 7)),
      );

      expect(result.valueOrNull!.inquiryCount, 1);
    });

    group('Edge Cases', () {
      test('markVisited: 存在しない inquiryId は failure', () async {
        final result = await makeService().markVisited('nonexistent');
        expect(result.isFailure, isTrue);
      });

      test('markConverted: 存在しない inquiryId は failure', () async {
        final result = await makeService().markConverted('nonexistent');
        expect(result.isFailure, isTrue);
      });

      test('markConverted: dealAmount=0 でも成約として記録される', () async {
        final id = await seedInquiry();
        final result = await makeService().markConverted(id, dealAmount: 0);
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.isConverted, isTrue);
        expect(result.valueOrNull!.dealAmount, 0);
      });

      test('markConverted: 負の dealAmount は ValidationError', () async {
        final id = await seedInquiry();
        final result = await makeService().markConverted(id, dealAmount: -1);
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<ValidationError>());
      });

      test('getShopConversionStats: 問い合わせ0件 → 全カウント0・rate 0（0除算なし）',
          () async {
        final result = await makeService().getShopConversionStats('empty-shop');
        expect(result.isSuccess, isTrue);
        final stats = result.valueOrNull!;
        expect(stats.inquiryCount, 0);
        expect(stats.convertedCount, 0);
        expect(stats.totalDealAmount, 0);
        expect(stats.conversionRate, 0);
        expect(stats.replyRate, 0);
        expect(stats.visitRate, 0);
      });

      test('getShopConversionStats: 空文字 shopId でもクラッシュしない', () async {
        final result = await makeService().getShopConversionStats('');
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.inquiryCount, 0);
      });
    });
  });
}
