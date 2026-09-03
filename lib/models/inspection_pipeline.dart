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

  /// 満了日を過ぎ、猶予も過ぎた台数。入庫したかどうかは問わない。
  ///
  /// 入庫が分かる場合（[isCompletionKnown] が true）は [missedCount] と同じ。
  /// 分からない場合は「取りこぼしかもしれない、確かめる先」の台数になる。
  final int overdueCount;

  /// 入庫したかどうかが分かるか。
  ///
  /// 店から顧客の整備記録は読めない（`firestore.rules`）。**読めるようにする
  /// ほうが問題**なので、そこは開けない。店側の集計ではこれが false になり、
  /// [completedCount] と [missedCount] は 0 のまま置く。
  /// **分からないものを「取りこぼし0台」と出さないため。**
  final bool isCompletionKnown;

  const InspectionPipeline({
    required this.dueCount,
    required this.completedCount,
    required this.pendingCount,
    required this.missedCount,
    required this.unknownExpiryCount,
    this.overdueCount = 0,
    this.isCompletionKnown = true,
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
      overdueCount: missed,
    );
  }

  /// 店側の集計。**顧客が同意して渡した車検満了日だけ**から数える。
  ///
  /// `docs/BUSINESS_MODEL_RETHINK_2026-08-27.md` §6-2 の案A。
  ///
  /// 店は顧客の `vehicles` を読めない（読めるようにするほうが問題）。そこで
  /// **顧客のアプリが、自分の `shop_customers` 文書に満了日だけを置く。**
  /// 車種も走行距離も整備履歴も渡らない。
  ///
  /// 入庫したかどうかはここでは分からない。だから
  /// [isCompletionKnown] は false で返し、[missedCount] は 0 のまま置く。
  /// **「満了を迎える台数」と「猶予が切れた台数」までしか言わない。**
  /// そこから先は、店の伝票と突き合わせる仕事になる。
  static InspectionPipeline fromSharedExpiries({
    required List<CustomerExpirySummary> customers,
    required DateTime from,
    required DateTime to,
    required DateTime today,
  }) {
    final start = from.isAfter(to) ? to : from;
    final end = from.isAfter(to) ? from : to;

    var due = 0;
    var pending = 0;
    var overdue = 0;
    var unknown = 0;

    for (final c in customers) {
      // 共有していない人は、台数まるごと「分からない」に入れる。
      // 0台として扱うと、分母が小さく見えてしまう。
      if (!c.isSharing) {
        unknown += c.vehicleCount;
        continue;
      }

      final missing = c.vehicleCount - c.expiries.length;
      if (missing > 0) unknown += missing;

      for (final expiry in c.expiries) {
        if (expiry.isBefore(start) || expiry.isAfter(end)) continue;
        due++;

        if (today.difference(expiry).inDays > graceDays) {
          overdue++;
        } else {
          pending++;
        }
      }
    }

    return InspectionPipeline(
      dueCount: due,
      completedCount: 0,
      pendingCount: pending + overdue,
      missedCount: 0,
      unknownExpiryCount: unknown,
      overdueCount: overdue,
      isCompletionKnown: false,
    );
  }
}

/// 顧客ひとりが店に渡している、車検の満了日だけの写し。
///
/// **ここに車両IDも車種も入れない。** 入れた瞬間、店が顧客の車を特定できる
/// ようになり、案Aの前提（車の中身は見せない）が崩れる。
class CustomerExpirySummary {
  /// 顧客が共有している車検満了日。台数分ある。
  final List<DateTime> expiries;

  /// その顧客の保有台数。[expiries] との差が「満了日が未入力の台数」。
  final int vehicleCount;

  /// 共有に同意しているか。**切っている人を0台と数えない。**
  final bool isSharing;

  const CustomerExpirySummary({
    required this.expiries,
    required this.vehicleCount,
    required this.isSharing,
  });
}
