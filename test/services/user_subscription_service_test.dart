import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/user_plan.dart';
import 'package:trust_car_platform/services/user_subscription_service.dart';

void main() {
  group('UserSubscriptionService', () {
    group('isPremium', () {
      test('free plan returns false', () {
        expect(
          UserSubscriptionService.isPremium(UserPlanType.free, null),
          isFalse,
        );
      });

      test('premium plan with future expiry returns true', () {
        final future = DateTime.now().add(const Duration(days: 30));
        expect(
          UserSubscriptionService.isPremium(UserPlanType.premium, future),
          isTrue,
        );
      });

      test('premium plan with past expiry returns false', () {
        final past = DateTime.now().subtract(const Duration(days: 1));
        expect(
          UserSubscriptionService.isPremium(UserPlanType.premium, past),
          isFalse,
        );
      });

      test('premium plan with null expiry returns true (lifetime/manual grant)', () {
        expect(
          UserSubscriptionService.isPremium(UserPlanType.premium, null),
          isTrue,
        );
      });

      group('Edge Cases', () {
        test('expiry exactly now is treated as expired', () {
          final now = DateTime.now();
          expect(
            UserSubscriptionService.isPremium(UserPlanType.premium, now),
            isFalse,
          );
        });
      });
    });

    group('UserPlanLimits', () {
      test('free plan has drive log limit', () {
        final limits = UserPlanLimits.forPlan(UserPlanType.free);
        expect(limits.driveLogRetentionDays, lessThan(9999));
      });

      test('premium plan has unlimited drive logs', () {
        final limits = UserPlanLimits.forPlan(UserPlanType.premium);
        expect(limits.driveLogRetentionDays, equals(UserPlanLimits.unlimited));
      });

      test('free plan cannot export PDF', () {
        final limits = UserPlanLimits.forPlan(UserPlanType.free);
        expect(limits.canExportPdf, isFalse);
      });

      test('premium plan can export PDF', () {
        final limits = UserPlanLimits.forPlan(UserPlanType.premium);
        expect(limits.canExportPdf, isTrue);
      });

      test('free plan has monthly inquiry limit', () {
        final limits = UserPlanLimits.forPlan(UserPlanType.free);
        expect(limits.maxMonthlyInquiries, lessThan(9999));
      });

      test('premium plan has unlimited inquiries', () {
        final limits = UserPlanLimits.forPlan(UserPlanType.premium);
        expect(limits.maxMonthlyInquiries, equals(UserPlanLimits.unlimited));
      });

      group('Edge Cases', () {
        test('unlimited sentinel is a large positive number', () {
          expect(UserPlanLimits.unlimited, greaterThan(100));
        });
      });
    });
  });
}
