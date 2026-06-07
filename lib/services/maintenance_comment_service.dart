import '../models/maintenance_record.dart';

/// Tone of an AI-generated maintenance comment.
enum CommentTone {
  good,       // within recommended schedule
  acceptable, // slightly overdue (within 20%)
  overdue,    // significantly overdue
  noHistory,  // no previous record to compare against
}

/// Computed comment for a single maintenance record.
/// Not persisted — generated on the fly from vehicle history data.
class MaintenanceComment {
  /// e.g. "この交換は適切なタイミングでした。"
  final String timingEvaluation;

  /// e.g. "（前回から7ヶ月・6,800km走行後の交換）"
  final String? timingDetail;

  /// e.g. "次回の目安：2026年8月ごろ または 走行距離75,000kmごろ"
  final String? nextSchedule;

  final CommentTone tone;

  const MaintenanceComment({
    required this.timingEvaluation,
    this.timingDetail,
    this.nextSchedule,
    required this.tone,
  });
}

/// Rule parameters for each MaintenanceType.
class _Rule {
  final int intervalMonths;
  final int intervalKm;
  const _Rule(this.intervalMonths, this.intervalKm);
}

/// Generates contextual AI comments for maintenance records.
///
/// Pure logic — no I/O, no Firebase. Accepts record + historical records
/// and returns a [MaintenanceComment] so the user understands whether their
/// maintenance timing was good, and what to expect next.
class MaintenanceCommentService {
  // Mirrors the rules in RecommendationService (single source of truth if
  // this grows, but kept local to avoid coupling for now).
  static const _rules = <MaintenanceType, _Rule>{
    MaintenanceType.oilChange: _Rule(6, 5000),
    MaintenanceType.oilFilterChange: _Rule(12, 10000),
    MaintenanceType.airFilterChange: _Rule(24, 20000),
    MaintenanceType.brakePadChange: _Rule(12, 10000),
    MaintenanceType.tireRotation: _Rule(6, 5000),
    MaintenanceType.tireChange: _Rule(36, 40000),
    MaintenanceType.batteryChange: _Rule(36, 50000),
    MaintenanceType.coolantChange: _Rule(24, 40000),
    MaintenanceType.brakeFluidChange: _Rule(24, 40000),
    MaintenanceType.transmissionFluidChange: _Rule(48, 80000),
    MaintenanceType.cabinFilterChange: _Rule(12, 15000),
    MaintenanceType.wiperChange: _Rule(12, 0),
    MaintenanceType.legalInspection12: _Rule(12, 0),
    MaintenanceType.legalInspection24: _Rule(24, 0),
    MaintenanceType.carInspection: _Rule(24, 0),
  };

  /// Generate a comment for [record] based on previous records of the same type.
  ///
  /// Returns null if the maintenance type has no rules (e.g. custom entries)
  /// or if there is not enough data to produce a meaningful comment.
  MaintenanceComment? generateComment({
    required MaintenanceRecord record,
    required List<MaintenanceRecord> allRecords,
    required int currentMileage,
  }) {
    final rule = _rules[record.type];
    if (rule == null) return null;

    // Find the most recent previous record of the same type
    final previous = allRecords
        .where((r) =>
            r.id != record.id &&
            r.type == record.type &&
            r.date.isBefore(record.date))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final prev = previous.isEmpty ? null : previous.first;

    // Build timing detail string
    String? timingDetail;
    CommentTone tone;

    if (prev == null) {
      tone = CommentTone.noHistory;
    } else {
      final monthsGap = record.date.difference(prev.date).inDays / 30;
      final kmGap = (record.mileageAtService != null &&
              prev.mileageAtService != null)
          ? record.mileageAtService! - prev.mileageAtService!
          : null;

      final parts = <String>['前回から${monthsGap.round()}ヶ月'];
      if (kmGap != null) {
        parts.add('${_formatKm(kmGap)}走行後の交換');
      }
      timingDetail = '（${parts.join('・')}）';

      // Evaluate timing
      final timeRatio = rule.intervalMonths > 0
          ? monthsGap / rule.intervalMonths
          : 0.0;
      final kmRatio = (rule.intervalKm > 0 && kmGap != null)
          ? kmGap / rule.intervalKm
          : 0.0;
      final maxRatio =
          timeRatio > kmRatio ? timeRatio : kmRatio;

      if (maxRatio <= 1.0) {
        tone = CommentTone.good;
      } else if (maxRatio <= 1.2) {
        tone = CommentTone.acceptable;
      } else {
        tone = CommentTone.overdue;
      }
    }

    final typeName = record.typeDisplayName;

    final timingEvaluation = switch (tone) {
      CommentTone.good =>
        'この$typeName は適切なタイミングで行われました。',
      CommentTone.acceptable =>
        'この$typeName はほぼ推奨時期での対応でした。',
      CommentTone.overdue =>
        'この$typeName は推奨時期より遅れての対応でした。次回は少し早めに。',
      CommentTone.noHistory =>
        'この$typeName の記録が初めて登録されました。',
    };

    // Next schedule
    String? nextSchedule;
    final nextDate = record.date.add(Duration(days: rule.intervalMonths * 30));
    final nextDateStr = '${nextDate.year}年${nextDate.month}月ごろ';
    if (rule.intervalKm > 0 && record.mileageAtService != null) {
      final nextKm = record.mileageAtService! + rule.intervalKm;
      nextSchedule = '次回の目安：$nextDateStr または ${_formatKm(nextKm)} 走行後';
    } else if (rule.intervalMonths > 0) {
      nextSchedule = '次回の目安：$nextDateStr';
    }

    return MaintenanceComment(
      timingEvaluation: timingEvaluation,
      timingDetail: timingDetail,
      nextSchedule: nextSchedule,
      tone: tone,
    );
  }

  String _formatKm(int km) {
    if (km >= 10000) {
      return '${(km / 10000).toStringAsFixed(km % 10000 == 0 ? 0 : 1)}万km';
    }
    return '${km}km';
  }
}
