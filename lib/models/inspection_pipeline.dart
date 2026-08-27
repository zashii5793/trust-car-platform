import 'maintenance_record.dart';
import 'vehicle.dart';

/// How many inspections the shop is about to win — and how many it lost.
///
/// `docs/BUSINESS_MODEL_RETHINK_2026-08-27.md` §2-4。
///
/// オーナーへの聞き取りで、**年間の取りこぼし台数は「把握できていない」**
/// という回答だった。分母が無いので、何台逃しているのかも、手を打って効いたかも
/// 分からない。
///
/// **アプリの最大の価値は、実は「取りこぼしが数えられるようになること」
/// かもしれない。** 収益より前の、経営の可視化に近い。
///
/// ```
///  満了を迎える顧客     ← 車検満了日から出る
///  そのうち入庫した台数  ← 整備記録から出る
///  ─────────────────
///  差分 = 取りこぼし
/// ```
class InspectionPipeline {
  /// 期間内に車検満了を迎える台数。
  final int dueCount;

  /// そのうち、車検・法定点検で入庫した台数。
  final int completedCount;

  /// まだ満了日が来ていない、または猶予の中にある台数。
  final int pendingCount;

  /// 満了日を過ぎ、猶予も過ぎて、入庫が無い台数。**これが取りこぼし。**
  final int missedCount;

  /// 車検満了日が入っていない台数。**数えられない穴の大きさ。**
  final int unknownExpiryCount;

  const InspectionPipeline({
    required this.dueCount,
    required this.completedCount,
    required this.pendingCount,
    required this.missedCount,
    required this.unknownExpiryCount,
  });

  /// 満了日を過ぎてから、これだけは待つ。
  ///
  /// 継続検査は満了日の前後に受けることがあり、記録がアプリに入るまでにも
  /// 間がある。**満了の翌日に「逃した」と出すのは早すぎる。**
  static const int graceDays = 14;

  /// 車検の入庫とみなす整備の種別。
  ///
  /// オイル交換で来ただけでは、車検を取れたことにならない。
  static bool _isInspection(MaintenanceType type) {
    return type == MaintenanceType.legalInspection24 ||
        type == MaintenanceType.legalInspection12;
  }

  /// 満了日の前後これだけの範囲にある車検を「今回の入庫」とみなす。
  ///
  /// 広げすぎると2年前の車検を拾って取りこぼしが消える。狭めると、
  /// 早めに受けた人を逃したことにしてしまう。
  static const int matchWindowDays = 120;

  /// 数えられる状態か。
  ///
  /// **「取りこぼし0台」と「まだ分からない」はまったく違う。**
  /// 満了日が分かっている車が期間内に1台も無ければ、この集計は何も言って
  /// いない。**分母が無いのに「0台」と出すと、経営判断を誤らせる。**
  bool get canCount => dueCount > 0;

  static InspectionPipeline build({
    required List<Vehicle> vehicles,
    required List<MaintenanceRecord> records,
    required DateTime from,
    required DateTime to,
    required DateTime today,
  }) {
    final start = from.isAfter(to) ? to : from;
    final end = from.isAfter(to) ? from : to;

    // 車両ごとに、車検・法定点検の日付だけ集めておく。
    final inspectionsByVehicle = <String, List<DateTime>>{};
    for (final r in records) {
      if (!_isInspection(r.type)) continue;
      inspectionsByVehicle.putIfAbsent(r.vehicleId, () => []).add(r.date);
    }

    var due = 0;
    var completed = 0;
    var pending = 0;
    var missed = 0;
    var unknown = 0;

    for (final v in vehicles) {
      final expiry = v.inspectionExpiryDate;
      if (expiry == null) {
        unknown++;
        continue;
      }

      if (expiry.isBefore(start) || expiry.isAfter(end)) continue;
      due++;

      final done = (inspectionsByVehicle[v.id] ?? const <DateTime>[]).any((d) {
        final gap = d.difference(expiry).inDays.abs();
        return gap <= matchWindowDays;
      });

      if (done) {
        completed++;
        continue;
      }

      // まだ来ていない、または猶予の中。
      final overdueDays = today.difference(expiry).inDays;
      if (overdueDays <= graceDays) {
        pending++;
      } else {
        // 取りこぼしも「入庫していない」ことに変わりはないので、
        // pending と合わせて dueCount と釣り合わせる。
        pending++;
        missed++;
      }
    }

    return InspectionPipeline(
      dueCount: due,
      completedCount: completed,
      pendingCount: pending,
      missedCount: missed,
      unknownExpiryCount: unknown,
    );
  }
}
