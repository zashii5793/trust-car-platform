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
