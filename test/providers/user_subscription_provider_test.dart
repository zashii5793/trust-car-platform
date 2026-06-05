// UserSubscriptionProvider Unit Tests
//
// Tests cover:
//   1.  Initial state (free, no expiry, limits match free plan)
//   2.  loadFromUser — updates planType + planExpiresAt + notifies
//   3.  loadFromUser called twice — last value wins
//   4.  clear() — resets to free + notifies
//   5.  isPremium — false for free plan
//   6.  isPremium — true for premium with no expiry
//   7.  isPremium — true for premium with future expiry
//   8.  isPremium — false for premium with past expiry (expired)
//   9.  limits — correct values for free plan
//   10. limits — correct values for premium plan
//   11. canExportPdf — false for free, true for premium
//   12. maxMonthlyInquiries — 3 for free, unlimited for premium
//   13. driveLogRetentionDays — 30 for free, unlimited for premium
//   14. Edge: loadFromUser(free, null) after premium reverts isPremium
//   15. Edge: clear() after premium → isPremium returns false

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/user_plan.dart';
import 'package:trust_car_platform/providers/user_subscription_provider.dart';
import 'package:trust_car_platform/services/user_subscription_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Initial state
  // ---------------------------------------------------------------------------
  group('Initial state', () {
    test('starts with free plan, no expiry, and free limits', () {
      final sut = UserSubscriptionProvider();

      expect(sut.planType, UserPlanType.free);
      expect(sut.planExpiresAt, isNull);
      expect(sut.isPremium, isFalse);
      expect(sut.canExportPdf, isFalse);
      expect(sut.maxMonthlyInquiries, 3);
      expect(sut.driveLogRetentionDays, 30);
    });
  });

  // ---------------------------------------------------------------------------
  // loadFromUser
  // ---------------------------------------------------------------------------
  group('loadFromUser', () {
    test('updates planType, planExpiresAt and notifies listeners', () {
      final sut = UserSubscriptionProvider();
      final expiresAt = DateTime.now().add(const Duration(days: 30));

      bool notified = false;
      sut.addListener(() => notified = true);

      sut.loadFromUser(UserPlanType.premium, expiresAt);

      expect(sut.planType, UserPlanType.premium);
      expect(sut.planExpiresAt, expiresAt);
      expect(notified, isTrue);
    });

    test('loadFromUser called twice — last value wins', () {
      final sut = UserSubscriptionProvider();
      final firstExpiry = DateTime.now().add(const Duration(days: 10));
      final secondExpiry = DateTime.now().add(const Duration(days: 60));

      sut.loadFromUser(UserPlanType.premium, firstExpiry);
      sut.loadFromUser(UserPlanType.free, secondExpiry);

      expect(sut.planType, UserPlanType.free);
      expect(sut.planExpiresAt, secondExpiry);
    });
  });

  // ---------------------------------------------------------------------------
  // clear
  // ---------------------------------------------------------------------------
  group('clear', () {
    test('resets planType to free, clears expiry, and notifies listeners', () {
      final sut = UserSubscriptionProvider();
      final expiresAt = DateTime.now().add(const Duration(days: 30));
      sut.loadFromUser(UserPlanType.premium, expiresAt);

      bool notified = false;
      sut.addListener(() => notified = true);

      sut.clear();

      expect(sut.planType, UserPlanType.free);
      expect(sut.planExpiresAt, isNull);
      expect(notified, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // isPremium
  // ---------------------------------------------------------------------------
  group('isPremium', () {
    test('returns false for free plan', () {
      final sut = UserSubscriptionProvider();
      sut.loadFromUser(UserPlanType.free, null);

      expect(sut.isPremium, isFalse);
    });

    test('returns true for premium with no expiry date', () {
      final sut = UserSubscriptionProvider();
      sut.loadFromUser(UserPlanType.premium, null);

      expect(sut.isPremium, isTrue);
    });

    test('returns true for premium with a future expiry date', () {
      final sut = UserSubscriptionProvider();
      final futureExpiry = DateTime.now().add(const Duration(days: 1));
      sut.loadFromUser(UserPlanType.premium, futureExpiry);

      expect(sut.isPremium, isTrue);
    });

    test('returns false for premium with a past expiry date (expired)', () {
      final sut = UserSubscriptionProvider();
      final pastExpiry = DateTime.now().subtract(const Duration(seconds: 1));
      sut.loadFromUser(UserPlanType.premium, pastExpiry);

      expect(sut.isPremium, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // limits
  // ---------------------------------------------------------------------------
  group('limits', () {
    test('returns correct limits for free plan', () {
      final sut = UserSubscriptionProvider();
      sut.loadFromUser(UserPlanType.free, null);

      final limits = sut.limits;
      expect(limits.driveLogRetentionDays, 30);
      expect(limits.maxMonthlyInquiries, 3);
      expect(limits.canExportPdf, isFalse);
    });

    test('returns correct limits for premium plan', () {
      final sut = UserSubscriptionProvider();
      sut.loadFromUser(UserPlanType.premium, null);

      final limits = sut.limits;
      expect(limits.driveLogRetentionDays, UserPlanLimits.unlimited);
      expect(limits.maxMonthlyInquiries, UserPlanLimits.unlimited);
      expect(limits.canExportPdf, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // canExportPdf
  // ---------------------------------------------------------------------------
  group('canExportPdf', () {
    test('is false for free plan', () {
      final sut = UserSubscriptionProvider();
      sut.loadFromUser(UserPlanType.free, null);

      expect(sut.canExportPdf, isFalse);
    });

    test('is true for premium plan', () {
      final sut = UserSubscriptionProvider();
      sut.loadFromUser(UserPlanType.premium, null);

      expect(sut.canExportPdf, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // maxMonthlyInquiries
  // ---------------------------------------------------------------------------
  group('maxMonthlyInquiries', () {
    test('is 3 for free plan', () {
      final sut = UserSubscriptionProvider();
      sut.loadFromUser(UserPlanType.free, null);

      expect(sut.maxMonthlyInquiries, 3);
    });

    test('is unlimited for premium plan', () {
      final sut = UserSubscriptionProvider();
      sut.loadFromUser(UserPlanType.premium, null);

      expect(sut.maxMonthlyInquiries, UserPlanLimits.unlimited);
    });
  });

  // ---------------------------------------------------------------------------
  // driveLogRetentionDays
  // ---------------------------------------------------------------------------
  group('driveLogRetentionDays', () {
    test('is 30 for free plan', () {
      final sut = UserSubscriptionProvider();
      sut.loadFromUser(UserPlanType.free, null);

      expect(sut.driveLogRetentionDays, 30);
    });

    test('is unlimited for premium plan', () {
      final sut = UserSubscriptionProvider();
      sut.loadFromUser(UserPlanType.premium, null);

      expect(sut.driveLogRetentionDays, UserPlanLimits.unlimited);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------
  group('Edge cases', () {
    test('loadFromUser(free, null) after premium reverts isPremium to false',
        () {
      final sut = UserSubscriptionProvider();
      sut.loadFromUser(UserPlanType.premium, null);
      expect(sut.isPremium, isTrue);

      sut.loadFromUser(UserPlanType.free, null);
      expect(sut.isPremium, isFalse);
      expect(sut.planType, UserPlanType.free);
      expect(sut.planExpiresAt, isNull);
    });

    test('clear() after premium → isPremium returns false', () {
      final sut = UserSubscriptionProvider();
      sut.loadFromUser(UserPlanType.premium, null);
      expect(sut.isPremium, isTrue);

      sut.clear();
      expect(sut.isPremium, isFalse);
    });
  });
}
