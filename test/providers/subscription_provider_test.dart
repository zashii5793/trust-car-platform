// SubscriptionProvider Unit Tests
//
// Tests cover:
//   1. Initial state
//   2. loadFromShop - plan state loading
//   3. currentLimits / helpers (hasUnlimitedInquiries, hasPriorityDisplay, etc.)
//   4. _effectivePlan - expired plan treated as free
//   5. updatePlan - success / failure
//   6. canReceiveInquiry / canAddPhoto delegation
//   7. clearShop

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/providers/subscription_provider.dart';
import 'package:trust_car_platform/services/shop_subscription_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Shop _makeShop({
  String id = 'shop1',
  ShopPlanType planType = ShopPlanType.free,
  ShopSubscriptionStatus subscriptionStatus = ShopSubscriptionStatus.free,
  DateTime? planExpiresAt,
}) {
  final now = DateTime.now();
  return Shop(
    id: id,
    name: 'Test Shop',
    type: ShopType.maintenanceShop,
    planType: planType,
    subscriptionStatus: subscriptionStatus,
    planExpiresAt: planExpiresAt,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _seedShop(
  FakeFirebaseFirestore fakeFs,
  String shopId, {
  ShopPlanType planType = ShopPlanType.free,
  ShopSubscriptionStatus status = ShopSubscriptionStatus.free,
}) async {
  await fakeFs.collection('shops').doc(shopId).set({
    'planType': planType.name,
    'subscriptionStatus': status.name,
    'ownerId': 'owner1',
    'isActive': true,
    'name': 'Test Shop',
    'type': 'maintenanceShop',
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore fakeFs;
  late ShopSubscriptionService service;
  late SubscriptionProvider sut;

  setUp(() {
    fakeFs = FakeFirebaseFirestore();
    service = ShopSubscriptionService(firestore: fakeFs);
    sut = SubscriptionProvider(subscriptionService: service);
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------
  group('Initial state', () {
    test('starts with free plan and free status', () {
      expect(sut.planType, ShopPlanType.free);
      expect(sut.subscriptionStatus, ShopSubscriptionStatus.free);
      expect(sut.planExpiresAt, isNull);
      expect(sut.isLoading, isFalse);
      expect(sut.error, isNull);
      expect(sut.errorMessage, isNull);
    });

    test('currentLimits reflects free plan', () {
      expect(sut.currentLimits.maxMonthlyInquiries, 5);
      expect(sut.currentLimits.maxPhotos, 3);
      expect(sut.hasUnlimitedInquiries, isFalse);
      expect(sut.hasPriorityDisplay, isFalse);
      expect(sut.hasMonthlyReport, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // loadFromShop
  // -------------------------------------------------------------------------
  group('loadFromShop', () {
    test('loads plan state from shop model', () {
      final expiresAt = DateTime.now().add(const Duration(days: 30));
      final shop = _makeShop(
        id: 'shop1',
        planType: ShopPlanType.premium,
        subscriptionStatus: ShopSubscriptionStatus.active,
        planExpiresAt: expiresAt,
      );

      bool notified = false;
      sut.addListener(() => notified = true);
      sut.loadFromShop(shop);

      expect(sut.planType, ShopPlanType.premium);
      expect(sut.subscriptionStatus, ShopSubscriptionStatus.active);
      expect(sut.planExpiresAt, expiresAt);
      expect(notified, isTrue);
    });

    test('clears error on loadFromShop', () async {
      await sut.updatePlan(
        shopId: '',
        newPlan: ShopPlanType.standard,
        subscriptionStatus: ShopSubscriptionStatus.active,
      );
      expect(sut.error, isNotNull);

      sut.loadFromShop(_makeShop());
      expect(sut.error, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Effective plan and helpers
  // -------------------------------------------------------------------------
  group('Effective plan', () {
    test('active standard plan -> unlimited inquiries', () {
      sut.loadFromShop(_makeShop(
        planType: ShopPlanType.standard,
        subscriptionStatus: ShopSubscriptionStatus.active,
      ));
      expect(sut.hasUnlimitedInquiries, isTrue);
      expect(sut.currentLimits.maxPhotos, 20);
    });

    test('active premium plan -> priority display', () {
      sut.loadFromShop(_makeShop(
        planType: ShopPlanType.premium,
        subscriptionStatus: ShopSubscriptionStatus.active,
      ));
      expect(sut.hasPriorityDisplay, isTrue);
      expect(sut.hasMonthlyReport, isTrue);
    });

    test('trialing plan -> full access', () {
      sut.loadFromShop(_makeShop(
        planType: ShopPlanType.enterprise,
        subscriptionStatus: ShopSubscriptionStatus.trialing,
      ));
      expect(sut.hasUnlimitedInquiries, isTrue);
      expect(sut.currentLimits.maxShops, 5);
    });

    test('expired plan -> treated as free', () {
      sut.loadFromShop(_makeShop(
        planType: ShopPlanType.premium,
        subscriptionStatus: ShopSubscriptionStatus.expired,
      ));
      expect(sut.hasPriorityDisplay, isFalse);
      expect(sut.hasUnlimitedInquiries, isFalse);
      expect(sut.currentLimits.maxMonthlyInquiries, 5);
    });

    test('cancelled plan -> treated as free', () {
      sut.loadFromShop(_makeShop(
        planType: ShopPlanType.standard,
        subscriptionStatus: ShopSubscriptionStatus.cancelled,
      ));
      expect(sut.hasUnlimitedInquiries, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // updatePlan
  // -------------------------------------------------------------------------
  group('updatePlan', () {
    test('success -> updates local state and notifies', () async {
      await _seedShop(fakeFs, 'shop1');
      sut.loadFromShop(_makeShop());

      bool notified = false;
      sut.addListener(() => notified = true);

      final result = await sut.updatePlan(
        shopId: 'shop1',
        newPlan: ShopPlanType.standard,
        subscriptionStatus: ShopSubscriptionStatus.active,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      expect(result, isTrue);
      expect(sut.planType, ShopPlanType.standard);
      expect(sut.subscriptionStatus, ShopSubscriptionStatus.active);
      expect(sut.isLoading, isFalse);
      expect(sut.error, isNull);
      expect(notified, isTrue);
    });

    test('failure (empty shopId) -> sets error, returns false', () async {
      final result = await sut.updatePlan(
        shopId: '',
        newPlan: ShopPlanType.standard,
        subscriptionStatus: ShopSubscriptionStatus.active,
      );

      expect(result, isFalse);
      expect(sut.error, isA<ValidationError>());
      expect(sut.errorMessage, isNotNull);
      expect(sut.isLoading, isFalse);
    });

    test('isLoading is true during update', () async {
      await _seedShop(fakeFs, 'shop1');
      sut.loadFromShop(_makeShop());

      final loadingStates = <bool>[];
      sut.addListener(() => loadingStates.add(sut.isLoading));

      await sut.updatePlan(
        shopId: 'shop1',
        newPlan: ShopPlanType.standard,
        subscriptionStatus: ShopSubscriptionStatus.active,
      );

      // First notification: isLoading=true; last: isLoading=false
      expect(loadingStates.first, isTrue);
      expect(loadingStates.last, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // canReceiveInquiry / canAddPhoto (no shop loaded)
  // -------------------------------------------------------------------------
  group('No shop loaded', () {
    test('canReceiveInquiry returns false when no shop set', () async {
      final result = await sut.canReceiveInquiry();
      expect(result, isFalse);
    });

    test('canAddPhoto returns false when no shop set', () async {
      final result = await sut.canAddPhoto(0);
      expect(result, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // clearShop
  // -------------------------------------------------------------------------
  group('clearShop', () {
    test('resets to initial state', () {
      sut.loadFromShop(_makeShop(
        planType: ShopPlanType.premium,
        subscriptionStatus: ShopSubscriptionStatus.active,
      ));

      bool notified = false;
      sut.addListener(() => notified = true);
      sut.clearShop();

      expect(sut.planType, ShopPlanType.free);
      expect(sut.subscriptionStatus, ShopSubscriptionStatus.free);
      expect(sut.planExpiresAt, isNull);
      expect(sut.error, isNull);
      expect(notified, isTrue);
    });
  });
}
