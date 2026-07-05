import '../core/config/maintenance_knowledge.dart';
import '../models/maintenance_record.dart';
import '../models/vehicle.dart';
import 'maintenance_comment_service.dart';
import 'maintenance_schedule_service.dart';

/// What a maintenance record means at a glance. Drives UI colour/emphasis.
enum InsightMeaning {
  /// Performed within (or close to) the recommended timing.
  onTime,

  /// Noticeably later than the recommended timing.
  overdue,

  /// First record of this type — sets the baseline for future comparisons.
  baseline,

  /// Legal/cosmetic/custom item — informational, no timing judgement.
  informational,
}

/// How much the insight relies on the vehicle's own history.
enum InsightConfidence { high, medium, low }

/// A rich, explained view of a single maintenance record: not just "when" but
/// "what it means", "what's next", and "why it is worth recording".
///
/// Pure value object — computed on the fly, never persisted.
class MaintenanceInsight {
  final InsightMeaning meaning;

  /// One-line evaluation, e.g. "このオイル交換は適切なタイミングで行われました。"
  final String headline;

  /// Supporting facts (timing detail, general meaning, risk if late).
  /// Never empty for a returned insight.
  final List<String> reasons;

  /// Next-service guidance, e.g. "次回の目安：2026年8月ごろ または 3.5万km 走行後".
  final String? nextStep;

  /// Why keeping this record matters (asset/provenance framing).
  final String? assetNote;

  final InsightConfidence confidence;

  /// The underlying general knowledge (why/risk/how-to-tell), if any.
  final MaintenanceKnowledge? knowledge;

  const MaintenanceInsight({
    required this.meaning,
    required this.headline,
    required this.reasons,
    this.nextStep,
    this.assetNote,
    required this.confidence,
    this.knowledge,
  });
}

/// Explains the *meaning* of a maintenance record to the owner.
///
/// Pure logic — no I/O, no Firebase. Composes existing engines rather than
/// duplicating interval rules:
///   - [MaintenanceCommentService] for timing tone + next-service estimate,
///   - [MaintenanceScheduleService] for the fuel-type-aware baseline used when
///     there is no prior history (so the very first record still returns
///     meaning),
///   - [MaintenanceKnowledge] for the general "why / risk / how to tell" text.
///
/// Wording never asserts or diagnoses: it explains and offers context, leaving
/// the decision to the owner (and safety-critical judgement to a workshop).
class MaintenanceInsightService {
  final MaintenanceCommentService _commentService;
  final MaintenanceScheduleService _scheduleService;

  MaintenanceInsightService({
    MaintenanceCommentService? commentService,
    MaintenanceScheduleService? scheduleService,
  })  : _commentService = commentService ?? MaintenanceCommentService(),
        _scheduleService =
            scheduleService ?? const MaintenanceScheduleService();

  /// Returns an explained view of [record], or null when there is nothing
  /// meaningful to say (e.g. a cosmetic/custom entry with no known meaning).
  MaintenanceInsight? explain({
    required MaintenanceRecord record,
    required Vehicle vehicle,
    required List<MaintenanceRecord> allRecords,
    required int currentMileage,
  }) {
    final knowledge = MaintenanceKnowledge.forType(record.type);
    final typeName = record.typeDisplayName;

    // Legal inspections / 車検 are informational — never judged as "late".
    if (record.type.isLegalInspection) {
      return MaintenanceInsight(
        meaning: InsightMeaning.informational,
        headline: 'この$typeNameは、法律で定められた点検・車検の記録です。',
        reasons: [
          if (knowledge != null) knowledge.whyNeeded,
        ],
        nextStep: _legalNextStep(vehicle, record.type),
        assetNote: '点検・車検の記録が揃っていることは、売却や譲渡のときの安心材料になります。',
        confidence: InsightConfidence.high,
        knowledge: knowledge,
      );
    }

    final comment = _commentService.generateComment(
      record: record,
      allRecords: allRecords,
      currentMileage: currentMileage,
    );

    // No timing rule for this type (cosmetic/custom). Only explain if we have
    // general knowledge to share; otherwise there is nothing meaningful.
    if (comment == null) {
      if (knowledge == null) return null;
      return MaintenanceInsight(
        meaning: InsightMeaning.informational,
        headline: 'この$typeNameを記録しました。',
        reasons: [knowledge.whyNeeded],
        assetNote: _assetNote(record.type),
        confidence: InsightConfidence.low,
        knowledge: knowledge,
      );
    }

    final meaning = switch (comment.tone) {
      CommentTone.good => InsightMeaning.onTime,
      CommentTone.acceptable => InsightMeaning.onTime,
      CommentTone.overdue => InsightMeaning.overdue,
      CommentTone.noHistory => InsightMeaning.baseline,
    };

    final reasons = <String>[];
    if (comment.timingDetail != null) reasons.add(comment.timingDetail!);
    if (meaning == InsightMeaning.baseline) {
      // First record: use the fuel-type-aware schedule as the baseline meaning.
      final desc = _scheduleDescription(vehicle, record.type);
      if (desc != null) reasons.add('一般的な目安：$desc');
    }
    if (knowledge != null) {
      reasons.add(knowledge.whyNeeded);
      if (meaning == InsightMeaning.overdue) {
        reasons.add(knowledge.riskIfSkipped);
      }
    }

    return MaintenanceInsight(
      meaning: meaning,
      headline: comment.timingEvaluation,
      reasons: reasons,
      nextStep: comment.nextSchedule,
      assetNote: _assetNote(record.type),
      confidence: meaning == InsightMeaning.baseline
          ? InsightConfidence.medium
          : InsightConfidence.high,
      knowledge: knowledge,
    );
  }

  /// Description of [type] from the vehicle's fuel-type-aware schedule.
  String? _scheduleDescription(Vehicle vehicle, MaintenanceType type) {
    for (final s in _scheduleService.generateSchedule(vehicle)) {
      if (s.type == type) return s.description;
    }
    return null;
  }

  String? _legalNextStep(Vehicle vehicle, MaintenanceType type) {
    final desc = _scheduleDescription(vehicle, type);
    return desc == null ? null : '次回の目安：$desc';
  }

  /// Provenance/asset framing — factual, never a numeric promise.
  String _assetNote(MaintenanceType type) {
    const highValue = {
      MaintenanceType.tireChange,
      MaintenanceType.batteryChange,
      MaintenanceType.brakePadChange,
      MaintenanceType.transmissionFluidChange,
    };
    if (highValue.contains(type)) {
      return '近年の交換記録は、次のオーナーへの安心材料になります。';
    }
    return '整備の記録が積み上がるほど、売却や下取りのときの説明材料になります。';
  }
}
