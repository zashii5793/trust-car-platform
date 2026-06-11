import '../models/user_plan.dart';

/// Business logic for B2C user subscription plans.
///
/// Plan state lives in the user Firestore document and is updated
/// exclusively by Cloud Functions (RevenueCat webhook). Clients read-only.
class UserSubscriptionService {
  const UserSubscriptionService();

  /// Returns true if the user currently has an active premium subscription.
  ///
  /// [planType] is the user's current plan.
  /// [planExpiresAt] is null for lifetime/manual grants (treated as active).
  static bool isPremium(UserPlanType planType, DateTime? planExpiresAt) {
    if (planType != UserPlanType.premium) return false;
    if (planExpiresAt == null) return true;
    return planExpiresAt.isAfter(DateTime.now());
  }

  /// Returns the feature limits for the given plan.
  UserPlanLimits limitsFor(UserPlanType planType) =>
      UserPlanLimits.forPlan(planType);
}
