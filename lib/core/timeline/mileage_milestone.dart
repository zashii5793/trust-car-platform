import '../../models/maintenance_record.dart';

class MileageMilestone {
  final int km;
  final DateTime date;

  const MileageMilestone({required this.km, required this.date});
}

class MileageMilestoneDetector {
  MileageMilestoneDetector._();

  static const List<int> _thresholds = [
    10000,
    20000,
    30000,
    40000,
    50000,
    75000,
    100000,
    150000,
    200000,
  ];

  /// Detect mileage milestones from a list of maintenance records.
  ///
  /// Records may be in any order. Returns milestones sorted newest-first.
  /// When multiple thresholds are crossed on the same calendar date, only
  /// the highest threshold is returned for that date.
  static List<MileageMilestone> detect(List<MaintenanceRecord> records) {
    final sorted = records
        .where((r) => r.mileageAtService != null)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (sorted.isEmpty) return [];

    // Track maximum mileage seen so far to handle odometer errors (backwards jumps).
    int maxSeen = 0;
    // Track which thresholds have been crossed to avoid duplicates.
    final crossed = <int>{};

    final raw = <MileageMilestone>[];
    for (final record in sorted) {
      final current = record.mileageAtService!;
      if (current <= maxSeen) continue; // odometer went back — skip

      for (final threshold in _thresholds) {
        if (!crossed.contains(threshold) &&
            maxSeen < threshold &&
            current >= threshold) {
          raw.add(MileageMilestone(km: threshold, date: record.date));
          crossed.add(threshold);
        }
      }

      maxSeen = current;
    }

    // Collapse same calendar-day milestones: keep only the highest km per day.
    final byDay = <String, MileageMilestone>{};
    for (final m in raw) {
      final key = '${m.date.year}-${m.date.month}-${m.date.day}';
      final prev = byDay[key];
      if (prev == null || m.km > prev.km) {
        byDay[key] = m;
      }
    }

    return byDay.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }
}
