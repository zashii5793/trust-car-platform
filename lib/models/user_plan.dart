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

  const UserPlanLimits({
    required this.driveLogRetentionDays,
    required this.maxMonthlyInquiries,
    required this.canExportPdf,
  });

  factory UserPlanLimits.forPlan(UserPlanType plan) {
    switch (plan) {
      case UserPlanType.free:
        return const UserPlanLimits(
          driveLogRetentionDays: 30,
          maxMonthlyInquiries: 3,
          canExportPdf: false,
        );
      case UserPlanType.premium:
        return const UserPlanLimits(
          driveLogRetentionDays: unlimited,
          maxMonthlyInquiries: unlimited,
          canExportPdf: true,
        );
    }
  }
}
