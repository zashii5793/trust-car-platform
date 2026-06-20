// RevenueCatService Unit Tests (TDD: RED phase)
//
// These tests cover the business-logic layer of RevenueCatService using fake
// executors — no native SDK required.
//
// Tested behaviours:
//   1. productIdFor  — planType → RevenueCat product ID mapping
//   2. initialize    — calls executor with the correct appUserId
//   3. purchasePlan  — success path, executor error, free plan guard
//   4. restorePurchases — success and failure
//   5. getActiveEntitlements — active / inactive / error
//   6. planTypeFromEntitlement — entitlement → ShopPlanType mapping
//   7. Edge cases: empty userId, unknown entitlementId

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/services/revenue_cat_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // productIdFor
  // ---------------------------------------------------------------------------
  group('productIdFor', () {
    test('returns correct product ID for each paid plan', () {
      expect(
        RevenueCatService.productIdFor(ShopPlanType.standard),
        'trustcar_btob_standard_monthly',
      );
      expect(
        RevenueCatService.productIdFor(ShopPlanType.premium),
        'trustcar_btob_premium_monthly',
      );
      expect(
        RevenueCatService.productIdFor(ShopPlanType.enterprise),
        'trustcar_btob_enterprise_monthly',
      );
    });

    test('returns null for free plan', () {
      expect(RevenueCatService.productIdFor(ShopPlanType.free), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // apiKeyForPlatform (platform routing for --dart-define keys)
  // ---------------------------------------------------------------------------
  group('apiKeyForPlatform', () {
    test('returns iOS key on iOS', () {
      expect(
        RevenueCatService.apiKeyForPlatform(
          TargetPlatform.iOS,
          iosKey: 'appl_ios',
          androidKey: 'goog_android',
        ),
        'appl_ios',
      );
    });

    test('returns Android key on Android', () {
      expect(
        RevenueCatService.apiKeyForPlatform(
          TargetPlatform.android,
          iosKey: 'appl_ios',
          androidKey: 'goog_android',
        ),
        'goog_android',
      );
    });

    test('non-iOS platforms fall back to the Android key', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          RevenueCatService.apiKeyForPlatform(
            platform,
            iosKey: 'appl_ios',
            androidKey: 'goog_android',
          ),
          'goog_android',
          reason: '$platform should use the Android key',
        );
      }
    });

    test('defaults to compile-time defines (empty when unset in tests)', () {
      // No --dart-define is passed under `flutter test`, so both keys resolve
      // to the empty string. This guarantees production fails fast rather than
      // configuring RevenueCat with a placeholder.
      expect(RevenueCatService.apiKeyForPlatform(TargetPlatform.iOS), '');
      expect(RevenueCatService.apiKeyForPlatform(TargetPlatform.android), '');
    });
  });

  // ---------------------------------------------------------------------------
  // planTypeFromEntitlement
  // ---------------------------------------------------------------------------
  group('planTypeFromEntitlement', () {
    test('maps known entitlement IDs to plan types', () {
      expect(
        RevenueCatService.planTypeFromEntitlement('btob_standard'),
        ShopPlanType.standard,
      );
      expect(
        RevenueCatService.planTypeFromEntitlement('btob_premium'),
        ShopPlanType.premium,
      );
      expect(
        RevenueCatService.planTypeFromEntitlement('btob_enterprise'),
        ShopPlanType.enterprise,
      );
    });

    test('returns free for unknown entitlement', () {
      expect(
        RevenueCatService.planTypeFromEntitlement('unknown'),
        ShopPlanType.free,
      );
      expect(
        RevenueCatService.planTypeFromEntitlement(''),
        ShopPlanType.free,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // initialize
  // ---------------------------------------------------------------------------
  group('initialize', () {
    test('calls executor with the correct userId', () async {
      String? capturedId;
      final svc = RevenueCatService(
        initializeExecutor: (userId) async {
          capturedId = userId;
        },
      );

      final result = await svc.initialize('user_abc');
      expect(result.isSuccess, isTrue);
      expect(capturedId, 'user_abc');
    });

    test('returns failure when executor throws', () async {
      final svc = RevenueCatService(
        initializeExecutor: (_) async => throw Exception('SDK not found'),
      );

      final result = await svc.initialize('user_abc');
      expect(result.isFailure, isTrue);
    });

    test('returns failure for empty userId', () async {
      final svc = RevenueCatService(
        initializeExecutor: (_) async {},
      );

      final result = await svc.initialize('');
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationError>());
    });
  });

  // ---------------------------------------------------------------------------
  // purchasePlan
  // ---------------------------------------------------------------------------
  group('purchasePlan', () {
    test('returns failure immediately for free plan', () async {
      final svc = RevenueCatService(
        purchaseExecutor: (_, __) async =>
            throw StateError('should not be called'),
      );

      final result = await svc.purchasePlan(ShopPlanType.free, userId: 'u1');
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationError>());
    });

    test('calls executor with correct productId for standard plan', () async {
      String? capturedProduct;
      final svc = RevenueCatService(
        purchaseExecutor: (productId, userId) async {
          capturedProduct = productId;
          return const PurchaseResult(
              isSuccess: true, productId: 'trustcar_btob_standard_monthly');
        },
      );

      final result =
          await svc.purchasePlan(ShopPlanType.standard, userId: 'u1');
      expect(result.isSuccess, isTrue);
      expect(capturedProduct, 'trustcar_btob_standard_monthly');
    });

    test('returns failure when executor throws', () async {
      final svc = RevenueCatService(
        purchaseExecutor: (_, __) async =>
            throw Exception('Purchase cancelled'),
      );

      final result = await svc.purchasePlan(ShopPlanType.premium, userId: 'u1');
      expect(result.isFailure, isTrue);
    });

    test('returns failure when purchase executor returns isSuccess=false',
        () async {
      final svc = RevenueCatService(
        purchaseExecutor: (_, __) async => const PurchaseResult(
            isSuccess: false, productId: 'trustcar_btob_premium_monthly'),
      );

      final result = await svc.purchasePlan(ShopPlanType.premium, userId: 'u1');
      expect(result.isFailure, isTrue);
    });

    test('returns failure for empty userId', () async {
      final svc = RevenueCatService(
        purchaseExecutor: (_, __) async =>
            const PurchaseResult(isSuccess: true, productId: 'x'),
      );

      final result = await svc.purchasePlan(ShopPlanType.standard, userId: '');
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationError>());
    });
  });

  // ---------------------------------------------------------------------------
  // restorePurchases
  // ---------------------------------------------------------------------------
  group('restorePurchases', () {
    test('returns success when executor succeeds', () async {
      final svc = RevenueCatService(
        restoreExecutor: (userId) async =>
            const RestoreResult(activeEntitlements: ['btob_standard']),
      );

      final result = await svc.restorePurchases(userId: 'u1');
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.activeEntitlements, ['btob_standard']);
    });

    test('returns failure when executor throws', () async {
      final svc = RevenueCatService(
        restoreExecutor: (_) async => throw Exception('network error'),
      );

      final result = await svc.restorePurchases(userId: 'u1');
      expect(result.isFailure, isTrue);
    });

    test('returns empty entitlements when no active subscription', () async {
      final svc = RevenueCatService(
        restoreExecutor: (_) async =>
            const RestoreResult(activeEntitlements: []),
      );

      final result = await svc.restorePurchases(userId: 'u1');
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.activeEntitlements, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // getActiveEntitlements
  // ---------------------------------------------------------------------------
  group('getActiveEntitlements', () {
    test('returns active entitlement list', () async {
      final svc = RevenueCatService(
        entitlementExecutor: (userId) async => ['btob_premium'],
      );

      final result = await svc.getActiveEntitlements(userId: 'u1');
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, ['btob_premium']);
    });

    test('returns empty list when no active entitlements', () async {
      final svc = RevenueCatService(
        entitlementExecutor: (_) async => [],
      );

      final result = await svc.getActiveEntitlements(userId: 'u1');
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });

    test('returns failure when executor throws', () async {
      final svc = RevenueCatService(
        entitlementExecutor: (_) async => throw Exception('SDK error'),
      );

      final result = await svc.getActiveEntitlements(userId: 'u1');
      expect(result.isFailure, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------
  group('Edge cases', () {
    test('getActiveEntitlements returns failure for empty userId', () async {
      final svc = RevenueCatService(
        entitlementExecutor: (_) async => [],
      );

      final result = await svc.getActiveEntitlements(userId: '');
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationError>());
    });

    test('restorePurchases returns failure for empty userId', () async {
      final svc = RevenueCatService(
        restoreExecutor: (_) async =>
            const RestoreResult(activeEntitlements: []),
      );

      final result = await svc.restorePurchases(userId: '');
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<ValidationError>());
    });
  });
}
