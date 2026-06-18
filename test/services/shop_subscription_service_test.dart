// ShopSubscriptionService Unit Tests
//
// Tests cover:
//   1. getPlanLimits - correct limits per tier
//   2. canReceiveInquiry - free plan limit enforcement
//   3. canAddPhoto - photo count limit per plan
//   4. updatePlan - Firestore update
//   5. getMonthlyInquiryCount - query by shopId + current month
//   6. Edge cases

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/services/shop_subscription_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _seedShop(
  FakeFirebaseFirestore fakeFs,
  String shopId, {
  ShopPlanType planType = ShopPlanType.free,
  ShopSubscriptionStatus subscriptionStatus = ShopSubscriptionStatus.free,
  DateTime? planExpiresAt,
}) async {
  await fakeFs.collection('shops').doc(shopId).set({
    'planType': planType.name,
    'subscriptionStatus': subscriptionStatus.name,
    'planExpiresAt':
        planExpiresAt != null ? Timestamp.fromDate(planExpiresAt) : null,
    'ownerId': 'owner1',
    'isActive': true,
    'name': 'Test Shop',
    'type': 'maintenanceShop',
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  });
}

Future<void> _seedInquiry(
  FakeFirebaseFirestore fakeFs,
  String shopId, {
  DateTime? createdAt,
  String status = 'pending',
  DateTime? repliedAt,
}) async {
  await fakeFs.collection('inquiries').add({
    'shopId': shopId,
    'userId': 'user1',
    'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    'status': status,
    'repliedAt': repliedAt != null ? Timestamp.fromDate(repliedAt) : null,
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore fakeFs;
  late ShopSubscriptionService sut;

  setUp(() {
    fakeFs = FakeFirebaseFirestore();
    sut = ShopSubscriptionService(firestore: fakeFs);
  });

  // -------------------------------------------------------------------------
  // getPlanLimits
  // -------------------------------------------------------------------------
  group('getPlanLimits', () {
    test('free plan: 5 inquiries, 3 photos, no priority', () {
      final limits = sut.getPlanLimits(ShopPlanType.free);
      expect(limits.maxMonthlyInquiries, 5);
      expect(limits.maxPhotos, 3);
      expect(limits.hasPriorityDisplay, isFalse);
      expect(limits.hasMonthlyReport, isFalse);
      expect(limits.maxShops, 1);
    });

    test('standard plan: unlimited inquiries, 20 photos', () {
      final limits = sut.getPlanLimits(ShopPlanType.standard);
      expect(limits.maxMonthlyInquiries, isNegative); // -1 = unlimited
      expect(limits.maxPhotos, 20);
      expect(limits.hasPriorityDisplay, isFalse);
      expect(limits.hasMonthlyReport, isFalse);
      expect(limits.maxShops, 1);
    });

    test('premium plan: unlimited inquiries, unlimited photos, priority', () {
      final limits = sut.getPlanLimits(ShopPlanType.premium);
      expect(limits.maxMonthlyInquiries, isNegative);
      expect(limits.maxPhotos, isNegative);
      expect(limits.hasPriorityDisplay, isTrue);
      expect(limits.hasMonthlyReport, isTrue);
      expect(limits.maxShops, 1);
    });

    test('enterprise plan: unlimited everything, 5 shops', () {
      final limits = sut.getPlanLimits(ShopPlanType.enterprise);
      expect(limits.maxMonthlyInquiries, isNegative);
      expect(limits.maxPhotos, isNegative);
      expect(limits.hasPriorityDisplay, isTrue);
      expect(limits.hasMonthlyReport, isTrue);
      expect(limits.maxShops, 5);
    });
  });

  // -------------------------------------------------------------------------
  // canReceiveInquiry
  // -------------------------------------------------------------------------
  group('canReceiveInquiry', () {
    test('free plan with 0 inquiries this month -> can receive', () async {
      await _seedShop(fakeFs, 'shop1');

      final result = await sut.canReceiveInquiry('shop1');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isTrue);
    });

    test('free plan with 4 inquiries this month -> can receive', () async {
      await _seedShop(fakeFs, 'shop1');
      for (var i = 0; i < 4; i++) {
        await _seedInquiry(fakeFs, 'shop1');
      }

      final result = await sut.canReceiveInquiry('shop1');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isTrue);
    });

    test('free plan with 5 inquiries this month -> cannot receive', () async {
      await _seedShop(fakeFs, 'shop1');
      for (var i = 0; i < 5; i++) {
        await _seedInquiry(fakeFs, 'shop1');
      }

      final result = await sut.canReceiveInquiry('shop1');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isFalse);
    });

    test('standard plan with 100 inquiries -> can receive (unlimited)',
        () async {
      await _seedShop(fakeFs, 'shop1',
          planType: ShopPlanType.standard,
          subscriptionStatus: ShopSubscriptionStatus.active);
      for (var i = 0; i < 100; i++) {
        await _seedInquiry(fakeFs, 'shop1');
      }

      final result = await sut.canReceiveInquiry('shop1');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isTrue);
    });

    test('inquiries from last month not counted for free plan limit', () async {
      await _seedShop(fakeFs, 'shop1');
      final lastMonth = DateTime.now().subtract(const Duration(days: 35));
      for (var i = 0; i < 5; i++) {
        await _seedInquiry(fakeFs, 'shop1', createdAt: lastMonth);
      }

      final result = await sut.canReceiveInquiry('shop1');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isTrue); // last month's don't count
    });

    test('shop not found -> failure', () async {
      final result = await sut.canReceiveInquiry('nonexistent_shop');

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<NotFoundError>());
    });

    test('empty shopId -> failure', () async {
      final result = await sut.canReceiveInquiry('');

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationError>());
    });
  });

  // -------------------------------------------------------------------------
  // canAddPhoto
  // -------------------------------------------------------------------------
  group('canAddPhoto', () {
    test('free plan: 2 photos -> can add', () async {
      await _seedShop(fakeFs, 'shop1');
      final result = await sut.canAddPhoto('shop1', currentCount: 2);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isTrue);
    });

    test('free plan: 3 photos -> cannot add', () async {
      await _seedShop(fakeFs, 'shop1');
      final result = await sut.canAddPhoto('shop1', currentCount: 3);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isFalse);
    });

    test('standard plan: 19 photos -> can add', () async {
      await _seedShop(fakeFs, 'shop1',
          planType: ShopPlanType.standard,
          subscriptionStatus: ShopSubscriptionStatus.active);
      final result = await sut.canAddPhoto('shop1', currentCount: 19);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isTrue);
    });

    test('standard plan: 20 photos -> cannot add', () async {
      await _seedShop(fakeFs, 'shop1', planType: ShopPlanType.standard);
      final result = await sut.canAddPhoto('shop1', currentCount: 20);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isFalse);
    });

    test('premium plan: 999 photos -> can add (unlimited)', () async {
      await _seedShop(fakeFs, 'shop1',
          planType: ShopPlanType.premium,
          subscriptionStatus: ShopSubscriptionStatus.active);
      final result = await sut.canAddPhoto('shop1', currentCount: 999);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isTrue);
    });

    test('empty shopId -> failure', () async {
      final result = await sut.canAddPhoto('', currentCount: 1);
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationError>());
    });

    test('negative currentCount -> failure', () async {
      await _seedShop(fakeFs, 'shop1');
      final result = await sut.canAddPhoto('shop1', currentCount: -1);
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationError>());
    });
  });

  // -------------------------------------------------------------------------
  // updatePlan
  // -------------------------------------------------------------------------
  group('updatePlan', () {
    test('updates planType and subscriptionStatus in Firestore', () async {
      await _seedShop(fakeFs, 'shop1');
      final expiresAt = DateTime.now().add(const Duration(days: 30));

      final result = await sut.updatePlan(
        'shop1',
        newPlan: ShopPlanType.standard,
        subscriptionStatus: ShopSubscriptionStatus.active,
        expiresAt: expiresAt,
        revenueCatUserId: 'rc_customer_123',
      );

      expect(result.isSuccess, isTrue);

      final doc = await fakeFs.collection('shops').doc('shop1').get();
      expect(doc.data()?['planType'], 'standard');
      expect(doc.data()?['subscriptionStatus'], 'active');
      expect(doc.data()?['revenueCatUserId'], 'rc_customer_123');
    });

    test('downgrade to free plan clears expiry', () async {
      await _seedShop(
        fakeFs,
        'shop1',
        planType: ShopPlanType.premium,
        subscriptionStatus: ShopSubscriptionStatus.active,
        planExpiresAt: DateTime.now().add(const Duration(days: 10)),
      );

      final result = await sut.updatePlan(
        'shop1',
        newPlan: ShopPlanType.free,
        subscriptionStatus: ShopSubscriptionStatus.free,
      );

      expect(result.isSuccess, isTrue);
      final doc = await fakeFs.collection('shops').doc('shop1').get();
      expect(doc.data()?['planType'], 'free');
      expect(doc.data()?['planExpiresAt'], isNull);
    });

    test('empty shopId -> failure', () async {
      final result = await sut.updatePlan(
        '',
        newPlan: ShopPlanType.standard,
        subscriptionStatus: ShopSubscriptionStatus.active,
      );
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationError>());
    });
  });

  // -------------------------------------------------------------------------
  // getMonthlyInquiryCount
  // -------------------------------------------------------------------------
  group('getMonthlyInquiryCount', () {
    test('returns count of inquiries for this month', () async {
      await _seedShop(fakeFs, 'shop1');
      await _seedInquiry(fakeFs, 'shop1');
      await _seedInquiry(fakeFs, 'shop1');
      final lastMonth = DateTime.now().subtract(const Duration(days: 35));
      await _seedInquiry(fakeFs, 'shop1', createdAt: lastMonth);

      final result = await sut.getMonthlyInquiryCount('shop1');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 2); // only this month
    });

    test('returns 0 when no inquiries this month', () async {
      await _seedShop(fakeFs, 'shop1');

      final result = await sut.getMonthlyInquiryCount('shop1');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 0);
    });

    test('empty shopId -> failure', () async {
      final result = await sut.getMonthlyInquiryCount('');
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationError>());
    });
  });

  // -------------------------------------------------------------------------
  // Edge Cases
  // -------------------------------------------------------------------------
  group('Edge Cases', () {
    test('expired paid plan treated as free for limit checks', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await _seedShop(
        fakeFs,
        'shop1',
        planType: ShopPlanType.standard,
        subscriptionStatus: ShopSubscriptionStatus.expired,
        planExpiresAt: yesterday,
      );
      for (var i = 0; i < 5; i++) {
        await _seedInquiry(fakeFs, 'shop1');
      }

      final result = await sut.canReceiveInquiry('shop1');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isFalse); // treated as free
    });

    test('trialing plan has full standard limits', () async {
      final futureDate = DateTime.now().add(const Duration(days: 25));
      await _seedShop(
        fakeFs,
        'shop1',
        planType: ShopPlanType.standard,
        subscriptionStatus: ShopSubscriptionStatus.trialing,
        planExpiresAt: futureDate,
      );
      for (var i = 0; i < 100; i++) {
        await _seedInquiry(fakeFs, 'shop1');
      }

      final result = await sut.canReceiveInquiry('shop1');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isTrue); // trial = full access
    });
  });

  // -------------------------------------------------------------------------
  // getMonthlyReport (BtoB ROI visibility)
  // -------------------------------------------------------------------------
  group('getMonthlyReport', () {
    test('aggregates received / replied / closed for current month', () async {
      // 3 received this month: 1 pending, 1 replied, 1 closed (replied + closed)
      await _seedInquiry(fakeFs, 'shop1'); // pending, no reply
      await _seedInquiry(
        fakeFs,
        'shop1',
        status: 'replied',
        repliedAt: DateTime.now(),
      );
      await _seedInquiry(
        fakeFs,
        'shop1',
        status: 'closed',
        repliedAt: DateTime.now(),
      );

      final result = await sut.getMonthlyReport('shop1');

      expect(result.isSuccess, isTrue);
      final report = result.valueOrNull!;
      expect(report.totalInquiries, 3);
      expect(report.repliedInquiries, 2);
      expect(report.closedInquiries, 1);
      expect(report.responseRate, closeTo(2 / 3, 0.0001));
      expect(report.conversionRate, closeTo(1 / 3, 0.0001));
    });

    test('excludes inquiries from previous months', () async {
      final lastMonth =
          DateTime(DateTime.now().year, DateTime.now().month - 1, 15);
      await _seedInquiry(fakeFs, 'shop1'); // this month
      await _seedInquiry(fakeFs, 'shop1', createdAt: lastMonth);

      final result = await sut.getMonthlyReport('shop1');

      expect(result.valueOrNull!.totalInquiries, 1);
    });

    test('only counts the target shop', () async {
      await _seedInquiry(fakeFs, 'shop1');
      await _seedInquiry(fakeFs, 'shop2');

      final result = await sut.getMonthlyReport('shop1');

      expect(result.valueOrNull!.totalInquiries, 1);
    });

    group('Edge Cases', () {
      test('no inquiries yields zeroed rates without dividing by zero',
          () async {
        final result = await sut.getMonthlyReport('shop1');

        expect(result.isSuccess, isTrue);
        final report = result.valueOrNull!;
        expect(report.totalInquiries, 0);
        expect(report.repliedInquiries, 0);
        expect(report.closedInquiries, 0);
        expect(report.responseRate, 0.0);
        expect(report.conversionRate, 0.0);
      });

      test('empty shopId returns validation failure', () async {
        final result = await sut.getMonthlyReport('');

        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<AppError>());
      });
    });
  });
}
