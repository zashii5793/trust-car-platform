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

  /// Returns the feature limits actually in force.
  ///
  /// [accountCreatedAt] lets the opening period apply: a new account runs
  /// with everything open for the first [UserPlanLimits.graceDays] days,
  /// because nothing this app offers is worth much until records have piled
  /// up. Pass null when the sign-up date is unknown — the plan's own limits
  /// then apply.
  UserPlanLimits limitsFor(
    UserPlanType planType, {
    DateTime? accountCreatedAt,
  }) =>
      UserPlanLimits.effective(planType, accountCreatedAt: accountCreatedAt);
}
