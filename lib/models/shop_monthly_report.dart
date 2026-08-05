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

  const ShopMonthlyReport({
    required this.month,
    required this.total,
    required this.previousTotal,
    required this.byStatus,
  });

  /// Month-over-month change in inquiry volume (positive = growth).
  int get momChange => total - previousTotal;

  /// Count of current-month inquiries with [status] (0 when absent).
  int countFor(InquiryStatus status) => byStatus[status] ?? 0;
}
