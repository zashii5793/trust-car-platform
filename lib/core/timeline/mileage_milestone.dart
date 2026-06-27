import '../../models/maintenance_record.dart';

/// 走行距離のマイルストーン（例:「50,000km突破」）。
///
/// 愛車カルテのタイムライン上で、整備記録の合間に「節目」として表示するための
/// 値オブジェクト。OEMコネクテッドアプリ（スズキコネクト等）が持てない
/// 「所有の歴史」を可視化する強み①の一部。
class MileageMilestone {
  /// 到達したオドメーター値 (km)。例: 50000。
  final int mileage;

  /// 到達日（その節目に最初に到達／超過した整備記録の日付）。
  final DateTime reachedOn;

  const MileageMilestone({required this.mileage, required this.reachedOn});

  @override
  bool operator ==(Object other) =>
      other is MileageMilestone &&
      other.mileage == mileage &&
      other.reachedOn == reachedOn;

  @override
  int get hashCode => Object.hash(mileage, reachedOn);

  @override
  String toString() =>
      'MileageMilestone(mileage: $mileage, reachedOn: $reachedOn)';
}

/// 整備記録の `mileageAtService` から走行距離マイルストーンを検出する純粋ロジック。
///
/// Firebase I/O を持たない純粋関数のため、`core/` 配下に置く（Service層ではない）。
class MileageMilestoneDetector {
  const MileageMilestoneDetector._();

  /// [records] を走査し、[interval] km ごと（既定 10,000km）の節目を検出する。
  ///
  /// - `mileageAtService` が null / 0以下の記録は「計測値なし」として無視する。
  /// - 記録は日付の昇順で評価し、各節目は最初に到達／超過した記録の日付に紐づく。
  /// - 同じ節目は一度だけ報告する。
  /// - [interval] が 0 以下の場合は空リストを返す。
  static List<MileageMilestone> detect(
    List<MaintenanceRecord> records, {
    int interval = 10000,
  }) {
    if (interval <= 0) return const [];

    final withMileage =
        records.where((r) => (r.mileageAtService ?? 0) > 0).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final milestones = <MileageMilestone>[];
    var next = interval;
    for (final record in withMileage) {
      final mileage = record.mileageAtService!;
      while (mileage >= next) {
        milestones.add(MileageMilestone(mileage: next, reachedOn: record.date));
        next += interval;
      }
    }
    return milestones;
  }
}
