import 'inspection_pipeline.dart';

/// How many inspections are due per month, for the months ahead.
///
/// A shop already sees "N due in this window" ([InspectionPipeline]). That
/// number does not say *when* the work lands, and an independent garage has
/// a fixed number of lifts and hands. Knowing that five inspections fall in
/// November is what lets them staff for it.
///
/// **No individuals.** What the shop holds is a list of expiry dates with no
/// vehicle and no owner attached (see `ShopCustomerLink`). This keeps to that
/// line: counts per month, nothing else. Reaching out to a specific customer
/// is not possible from here, and deliberately so.
class InspectionForecast {
  const InspectionForecast({required this.months, required this.byMonth});

  /// The months covered, oldest first. Each is normalised to the 1st.
  final List<DateTime> months;

  /// Month (normalised to the 1st) → number of inspections falling in it.
  final Map<DateTime, int> byMonth;

  /// Total across the covered months.
  int get total => byMonth.values.fold(0, (a, b) => a + b);

  /// The month with the most inspections, or null when there are none.
  DateTime? get busiestMonth {
    DateTime? best;
    var bestCount = 0;
    for (final m in months) {
      final c = byMonth[m] ?? 0;
      if (c > bestCount) {
        best = m;
        bestCount = c;
      }
    }
    return best;
  }

  int countFor(DateTime month) =>
      byMonth[DateTime(month.year, month.month)] ?? 0;

  /// Builds the forecast from what customers have chosen to share.
  ///
  /// The current month counts from its 1st, not from [today] — an expiry
  /// earlier this month is still this month's workload, and dropping it
  /// would make the near term look emptier than it is.
  static InspectionForecast build({
    required List<CustomerExpirySummary> customers,
    required DateTime today,
    int months = 6,
  }) {
    if (months <= 0) {
      return const InspectionForecast(months: [], byMonth: {});
    }

    final start = DateTime(today.year, today.month);
    final buckets = <DateTime, int>{};
    final ordered = <DateTime>[];
    for (var i = 0; i < months; i++) {
      final m = DateTime(start.year, start.month + i);
      ordered.add(m);
      buckets[m] = 0;
    }
    final end = DateTime(start.year, start.month + months);

    for (final c in customers) {
      // Someone who has not shared tells us nothing; counting them as zero
      // would be the same as counting them as having no inspections due.
      if (!c.isSharing) continue;

      for (final expiry in c.expiries) {
        if (expiry.isBefore(start) || !expiry.isBefore(end)) continue;
        final key = DateTime(expiry.year, expiry.month);
        buckets[key] = (buckets[key] ?? 0) + 1;
      }
    }

    return InspectionForecast(months: ordered, byMonth: buckets);
  }
}
