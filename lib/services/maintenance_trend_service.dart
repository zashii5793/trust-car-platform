import '../core/utils/calendar_days.dart';
import '../models/maintenance_record.dart';

enum TrendConfidence { high, medium, low }

/// A single maintenance trend insight derived from vehicle history.
class MaintenanceTrendInsight {
  final MaintenanceType type;
  final double? averageIntervalKm;
  final double? averageIntervalDays;
  final DateTime? lastServiceDate;
  final int? lastServiceMileage;
  final DateTime? predictedNextDate;
  final int? predictedNextMileage;
  final double? averageCost;
  final int sampleCount;
  final TrendConfidence confidence;

  const MaintenanceTrendInsight({
    required this.type,
    this.averageIntervalKm,
    this.averageIntervalDays,
    this.lastServiceDate,
    this.lastServiceMileage,
    this.predictedNextDate,
    this.predictedNextMileage,
    this.averageCost,
    required this.sampleCount,
    required this.confidence,
  });
}

/// Analyzes a vehicle's maintenance history to surface trends and predictions.
/// Pure function service — no Firestore access.
class MaintenanceTrendService {
  const MaintenanceTrendService();

  /// Returns trend insights for each maintenance type found in [records].
  List<MaintenanceTrendInsight> analyzeHistory(
    List<MaintenanceRecord> records, {
    int? currentMileage,
    DateTime? currentDate,
  }) {
    if (records.isEmpty) {
      return [];
    }

    // Group records by type
    final byType = <MaintenanceType, List<MaintenanceRecord>>{};
    for (final r in records) {
      byType.putIfAbsent(r.type, () => []).add(r);
    }

    final insights = <MaintenanceTrendInsight>[];

    for (final entry in byType.entries) {
      final type = entry.key;
      final typeRecords = List<MaintenanceRecord>.from(entry.value)
        ..sort((a, b) => a.date.compareTo(b.date));

      final sampleCount = typeRecords.length;
      final confidence = _confidence(sampleCount);

      final lastRecord = typeRecords.last;
      final lastDate = lastRecord.date;
      final lastMileage = lastRecord.mileageAtService;

      double? avgIntervalKm;
      double? avgIntervalDays;

      if (sampleCount >= 2) {
        avgIntervalDays = _averageIntervalDays(typeRecords);

        final mileageRecords =
            typeRecords.where((r) => r.mileageAtService != null).toList();
        if (mileageRecords.length >= 2) {
          avgIntervalKm = _averageIntervalKm(mileageRecords);
        }
      }

      // Records without an amount say nothing about the price; leave them
      // out instead of averaging them in as ¥0.
      final costed = typeRecords.where((r) => r.hasCost).toList();
      final avgCost = costed.isEmpty
          ? null
          : costed.map((r) => r.cost).reduce((a, b) => a + b) / costed.length;

      DateTime? predictedNextDate;
      int? predictedNextMileage;

      if (avgIntervalDays != null) {
        predictedNextDate = lastDate.add(
          Duration(days: avgIntervalDays.round()),
        );
      }

      if (avgIntervalKm != null && lastMileage != null) {
        predictedNextMileage = lastMileage + avgIntervalKm.round();
      }

      insights.add(MaintenanceTrendInsight(
        type: type,
        averageIntervalKm: avgIntervalKm,
        averageIntervalDays: avgIntervalDays,
        lastServiceDate: lastDate,
        lastServiceMileage: lastMileage,
        predictedNextDate: predictedNextDate,
        predictedNextMileage: predictedNextMileage,
        averageCost: avgCost,
        sampleCount: sampleCount,
        confidence: confidence,
      ));
    }

    return insights;
  }

  /// Sorts insights by urgency (overdue first, then soonest upcoming).
  /// Replaces the interval guess for 車検 with the actual expiry date.
  ///
  /// The certificate's expiry is a fact; two past inspections a few months
  /// off the 2-year cycle made the guess say 「62日過ぎています」 on the same
  /// screen that showed 149 days left (usability test 2026-10-09).
  List<MaintenanceTrendInsight> withInspectionDeadline(
    List<MaintenanceTrendInsight> insights,
    DateTime? inspectionExpiryDate,
  ) {
    if (inspectionExpiryDate == null) return insights;
    return [
      for (final i in insights)
        if (i.type == MaintenanceType.carInspection)
          MaintenanceTrendInsight(
            type: i.type,
            averageIntervalKm: i.averageIntervalKm,
            averageIntervalDays: i.averageIntervalDays,
            lastServiceDate: i.lastServiceDate,
            lastServiceMileage: i.lastServiceMileage,
            predictedNextDate: inspectionExpiryDate,
            predictedNextMileage: null,
            averageCost: i.averageCost,
            sampleCount: i.sampleCount,
            confidence: TrendConfidence.high,
          )
        else
          i,
    ];
  }

  List<MaintenanceTrendInsight> sortByUrgency(
    List<MaintenanceTrendInsight> insights, {
    DateTime? currentDate,
  }) {
    final now = currentDate ?? DateTime.now();
    final sorted = List<MaintenanceTrendInsight>.from(insights);
    sorted.sort((a, b) {
      final daysA = _daysUntilNext(a, now);
      final daysB = _daysUntilNext(b, now);
      return daysA.compareTo(daysB);
    });
    return sorted;
  }

  static double _averageIntervalDays(List<MaintenanceRecord> sorted) {
    double total = 0;
    for (int i = 1; i < sorted.length; i++) {
      total += sorted[i].date.difference(sorted[i - 1].date).inDays;
    }
    return total / (sorted.length - 1);
  }

  static double _averageIntervalKm(List<MaintenanceRecord> sorted) {
    double total = 0;
    int count = 0;
    for (int i = 1; i < sorted.length; i++) {
      final km = (sorted[i].mileageAtService ?? 0) -
          (sorted[i - 1].mileageAtService ?? 0);
      if (km > 0) {
        total += km;
        count++;
      }
    }
    return count > 0 ? total / count : 0;
  }

  static TrendConfidence _confidence(int sampleCount) {
    if (sampleCount >= 3) {
      return TrendConfidence.high;
    }
    if (sampleCount == 2) {
      return TrendConfidence.medium;
    }
    return TrendConfidence.low;
  }

  static int _daysUntilNext(
    MaintenanceTrendInsight insight,
    DateTime now,
  ) {
    if (insight.predictedNextDate == null) {
      return 9999;
    }
    return calendarDaysUntil(insight.predictedNextDate!, now: now);
  }
}
