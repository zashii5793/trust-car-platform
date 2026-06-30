import 'inquiry.dart';

/// Monthly inquiry summary for a shop.
///
/// Minimal "ROI visibility" value object: how many inquiries a shop received
/// this month, how that compares to last month, and the status breakdown so
/// the shop can see what is still waiting on them.
class ShopMonthlyReport {
  /// First day of the reported (current) month.
  final DateTime month;

  /// Inquiries received during [month].
  final int total;

  /// Inquiries received during the month immediately before [month].
  final int previousTotal;

  /// Count of current-month inquiries per status.
  final Map<InquiryStatus, int> byStatus;

  /// Number of maintenance proposals the shop sent this month (inquiry messages
  /// carrying a `maintenancePayload`). The ROI signal a shop can act on: more
  /// proposals -> more maintenance history captured for its customers.
  final int maintenanceProposalCount;

  /// Total quoted value (yen) of this month's maintenance proposals.
  final int maintenanceProposalValue;

  const ShopMonthlyReport({
    required this.month,
    required this.total,
    required this.previousTotal,
    required this.byStatus,
    this.maintenanceProposalCount = 0,
    this.maintenanceProposalValue = 0,
  });

  /// Month-over-month change in inquiry volume (positive = growth).
  int get momChange => total - previousTotal;

  /// Count of current-month inquiries with [status] (0 when absent).
  int countFor(InquiryStatus status) => byStatus[status] ?? 0;
}
