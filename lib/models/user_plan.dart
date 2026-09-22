/// Subscription plan tier for B2C users.
enum UserPlanType {
  free,
  premium,
}

/// Feature limits per user plan.
class UserPlanLimits {
  /// Sentinel value meaning "no limit enforced".
  static const int unlimited = 999999;

  final int driveLogRetentionDays;
  final int maxMonthlyInquiries;
  final bool canExportPdf;

  // History sharing: user grants shop access to maintenance records
  final int maxHistorySharingGrants;

  // Community trends: access to aggregated same-model statistics
  final bool canAccessCommunityTrends;

  // Vehicle limit
  final int maxVehicles;

  // FAQ: can the user allow shop responses on their questions
  final bool canAllowShopFaqResponse;

  // AI features: maintenance trend analysis
  final bool canAccessMaintenanceTrends;

  const UserPlanLimits({
    required this.driveLogRetentionDays,
    required this.maxMonthlyInquiries,
    required this.canExportPdf,
    this.maxHistorySharingGrants = 0,
    this.canAccessCommunityTrends = false,
    this.maxVehicles = 3,
    this.canAllowShopFaqResponse = false,
    this.canAccessMaintenanceTrends = false,
  });

  /// How long a new account runs with everything open.
  ///
  /// The value of this app comes from records piling up — fuel economy,
  /// service intervals, next-service predictions all say nothing until there
  /// is history. The free plan keeps drive logs for 30 days, which throws the
  /// history away before it becomes worth anything. That is the wrong shape
  /// for a product whose whole pitch is accumulation.
  ///
  /// So the first six months are open, and the conversation about paying
  /// happens once there is something to lose.
  static const int graceDays = 180;

  /// Limits actually in force for [plan], allowing for the opening period.
  ///
  /// Derived from [accountCreatedAt] alone, so no Cloud Function is needed —
  /// `planType` and `planExpiresAt` can only be written by Functions under
  /// the security rules, and those are not deployed yet.
  static UserPlanLimits effective(
    UserPlanType plan, {
    required DateTime? accountCreatedAt,
    DateTime? now,
  }) {
    if (plan == UserPlanType.premium) return UserPlanLimits.forPlan(plan);
    if (accountCreatedAt == null) return UserPlanLimits.forPlan(plan);

    final elapsed = (now ?? DateTime.now()).difference(accountCreatedAt).inDays;
    // A negative value means the clock disagrees with the server; treat it as
    // a brand new account rather than locking someone out.
    if (elapsed <= graceDays) {
      return UserPlanLimits.forPlan(UserPlanType.premium);
    }
    return UserPlanLimits.forPlan(plan);
  }

  /// Days left in the opening period. 0 once it is over, or unknown.
  static int graceRemaining({
    required DateTime? accountCreatedAt,
    DateTime? now,
  }) {
    if (accountCreatedAt == null) return 0;
    final elapsed = (now ?? DateTime.now()).difference(accountCreatedAt).inDays;
    final left = graceDays - elapsed;
    return left > 0 ? left : 0;
  }

  factory UserPlanLimits.forPlan(UserPlanType plan) {
    switch (plan) {
      case UserPlanType.free:
        return const UserPlanLimits(
          driveLogRetentionDays: 30,
          maxMonthlyInquiries: 3,
          canExportPdf: false,
          maxHistorySharingGrants: 0,
          canAccessCommunityTrends: false,
          maxVehicles: 3,
          canAllowShopFaqResponse: false,
          canAccessMaintenanceTrends: false,
        );
      case UserPlanType.premium:
        return const UserPlanLimits(
          driveLogRetentionDays: unlimited,
          maxMonthlyInquiries: unlimited,
          canExportPdf: true,
          maxHistorySharingGrants: unlimited,
          canAccessCommunityTrends: true,
          maxVehicles: unlimited,
          canAllowShopFaqResponse: true,
          canAccessMaintenanceTrends: true,
        );
    }
  }
}
