import 'maintenance_record.dart';

/// One year of a car, summed up.
///
/// 1年でユーザーは整備記録を数十件入れる。**溜めることには協力してもらって
/// いるのに、溜まった価値を突き返していない。** 履歴の一覧はあるが、自分から
/// 開かないと見えないし、開いても記録が並んでいるだけ。
///
/// ここは集計だけを持つ（`docs/HABIT_DESIGN.md` 打ち手2）。画面にも Firebase にも
/// 依存させないので、**数え方が合っているかをテストで固定できる。**
class YearInReview {
  /// 集計した期間。`from` は生成側の名前なので、フィールドは別名にしてある。
  final DateTime periodFrom;
  final DateTime periodTo;

  final int totalCost;
  final int recordCount;

  /// 期間内に走った距離。出せないときは null（下の [_distanceOf] を参照）。
  final int? distanceKm;

  final Map<MaintenanceType, int> costByType;
  final Map<MaintenanceType, int> countByType;

  final MaintenanceRecord? mostExpensive;

  /// いちばん回数の多かった店。金額ではなく回数で見る。
  final String? mostVisitedShop;

  /// 同じ車種の人の年間費用の平均。無ければ null。
  final int? peerAverageCost;

  const YearInReview({
    required this.periodFrom,
    required this.periodTo,
    required this.totalCost,
    required this.recordCount,
    required this.distanceKm,
    required this.costByType,
    required this.countByType,
    required this.mostExpensive,
    required this.mostVisitedShop,
    required this.peerAverageCost,
  });

  /// 記録が1件だけの「振り返り」は、見せられた側が白ける。
  static const int minimumRecords = 2;

  /// 振り返りとして見せられるだけの中身があるか。
  bool get hasEnoughData => recordCount >= minimumRecords;

  /// 同車種の平均との差。安ければ負。比較相手がいなければ null。
  int? get costDiffFromPeers {
    final peers = peerAverageCost;
    if (peers == null) return null;
    return totalCost - peers;
  }

  /// 平均より安く済んだか。比較相手がいなければ false。
  bool get isCheaperThanPeers {
    final diff = costDiffFromPeers;
    return diff != null && diff < 0;
  }

  /// 1回あたりの平均費用。記録が無ければ 0。
  int get averageCostPerRecord =>
      recordCount == 0 ? 0 : totalCost ~/ recordCount;

  static YearInReview from({
    required List<MaintenanceRecord> records,
    required DateTime from,
    required DateTime to,
    int? peerAverageCost,
  }) {
    // 呼ぶ側が逆に渡しても、黙って0件にはしない。
    final start = from.isAfter(to) ? to : from;
    final end = from.isAfter(to) ? from : to;

    final inRange = records
        .where((r) => !r.date.isBefore(start) && !r.date.isAfter(end))
        .toList();

    final costByType = <MaintenanceType, int>{};
    final countByType = <MaintenanceType, int>{};
    final shopVisits = <String, int>{};
    var totalCost = 0;
    MaintenanceRecord? mostExpensive;

    for (final r in inRange) {
      totalCost += r.cost;
      costByType[r.type] = (costByType[r.type] ?? 0) + r.cost;
      countByType[r.type] = (countByType[r.type] ?? 0) + 1;

      final shop = (r.shopName ?? '').trim();
      if (shop.isNotEmpty) {
        shopVisits[shop] = (shopVisits[shop] ?? 0) + 1;
      }

      if (mostExpensive == null || r.cost > mostExpensive.cost) {
        mostExpensive = r;
      }
    }

    String? topShop;
    var topVisits = 0;
    shopVisits.forEach((shop, visits) {
      if (visits > topVisits) {
        topVisits = visits;
        topShop = shop;
      }
    });

    return YearInReview(
      periodFrom: start,
      periodTo: end,
      totalCost: totalCost,
      recordCount: inRange.length,
      distanceKm: _distanceOf(inRange),
      costByType: costByType,
      countByType: countByType,
      mostExpensive: mostExpensive,
      mostVisitedShop: topShop,
      peerAverageCost: peerAverageCost,
    );
  }

  /// 期間内の走行距離。
  ///
  /// 整備時の走行距離の最大 − 最小。**次の場合は出さない**:
  ///
  /// - 走行距離が入った記録が1件以下（差が取れない）
  /// - オドメーターが逆行している（桁の入力ミス。差がでたらめになる）
  ///
  /// 出せないものを 0 と書くと「1年で0km」と読まれる。null にして
  /// 画面側で出さない。
  static int? _distanceOf(List<MaintenanceRecord> records) {
    final byDate = records.where((r) => r.mileageAtService != null).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (byDate.length < 2) return null;

    final firstMileage = byDate.first.mileageAtService!;
    final lastMileage = byDate.last.mileageAtService!;

    for (var i = 1; i < byDate.length; i++) {
      if (byDate[i].mileageAtService! < byDate[i - 1].mileageAtService!) {
        return null;
      }
    }

    final distance = lastMileage - firstMileage;
    return distance <= 0 ? null : distance;
  }
}
