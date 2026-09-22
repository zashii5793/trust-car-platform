import 'inquiry.dart';
import 'shop_inquiry_demand.dart';

/// What kinds of enquiries a non-partner shop is turning away, and when.
///
/// `shop_inquiry_demands` has held this since the freemium gate shipped, and
/// `ShopDemandService.getDemandsForShop` reads it — but **no screen ever
/// called that method**. The shop only saw a bare count.
///
/// A count does not tell a garage whether registering is worth it. "Four
/// estimate requests and two repair enquiries in the last month" does.
///
/// **The wording stays out.** Subjects and message bodies belong to the
/// people who wrote them, and they are also the reason to register — giving
/// them away for free removes the reason.
class ShopDemandSummary {
  const ShopDemandSummary({
    required this.total,
    required this.byType,
    this.newestAt,
    this.oldestAt,
  });

  final int total;

  /// Enquiry type → how many. Types with none are left out.
  final Map<InquiryType, int> byType;

  final DateTime? newestAt;
  final DateTime? oldestAt;

  bool get isEmpty => total == 0;

  /// Types present, most frequent first. Ties keep enum order so the list
  /// does not reshuffle between builds.
  List<InquiryType> get typesByCount {
    final types = byType.keys.toList();
    types.sort((a, b) {
      final diff = (byType[b] ?? 0).compareTo(byType[a] ?? 0);
      return diff != 0 ? diff : a.index.compareTo(b.index);
    });
    return types;
  }

  /// How many arrived within [days] of [now].
  int recentCount(
    List<ShopInquiryDemand> demands, {
    required DateTime now,
    int days = 30,
  }) {
    final cutoff = now.subtract(Duration(days: days));
    return demands.where((d) => d.createdAt.isAfter(cutoff)).length;
  }

  static ShopDemandSummary from(List<ShopInquiryDemand> demands) {
    if (demands.isEmpty) {
      return const ShopDemandSummary(total: 0, byType: {});
    }

    final counts = <InquiryType, int>{};
    DateTime? newest;
    DateTime? oldest;

    for (final d in demands) {
      counts[d.type] = (counts[d.type] ?? 0) + 1;
      if (newest == null || d.createdAt.isAfter(newest)) newest = d.createdAt;
      if (oldest == null || d.createdAt.isBefore(oldest)) oldest = d.createdAt;
    }

    return ShopDemandSummary(
      total: demands.length,
      byType: counts,
      newestAt: newest,
      oldestAt: oldest,
    );
  }
}
