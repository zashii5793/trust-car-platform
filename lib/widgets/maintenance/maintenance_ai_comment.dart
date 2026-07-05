import 'package:flutter/material.dart';
import '../../core/constants/spacing.dart';
import '../../models/maintenance_record.dart';
import '../../models/vehicle.dart';
import '../../services/maintenance_comment_service.dart';
import '../../services/maintenance_insight_service.dart';

/// Displays an AI-generated explanation for a single maintenance record.
///
/// When [vehicle] is provided, renders the richer *insight* — what the record
/// means, whether the timing was good, what's next, and why keeping the record
/// matters — from the very first record. When [vehicle] is null, falls back to
/// the timing-only comment.
///
/// Based only on rule-based logic — no LLM required, no network call.
/// Returns [SizedBox.shrink] when nothing meaningful can be generated.
class MaintenanceAiComment extends StatelessWidget {
  final MaintenanceRecord record;
  final List<MaintenanceRecord> allRecords;
  final int currentMileage;

  /// Optional — when supplied, the widget shows the full explanation
  /// (meaning + reasons + next step + asset note) instead of timing only.
  final Vehicle? vehicle;

  const MaintenanceAiComment({
    super.key,
    required this.record,
    required this.allRecords,
    required this.currentMileage,
    this.vehicle,
  });

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    if (v != null) return _buildInsight(context, v);
    return _buildComment(context);
  }

  // Insight view (with vehicle) — "what this record means".
  Widget _buildInsight(BuildContext context, Vehicle vehicle) {
    final insight = MaintenanceInsightService().explain(
      record: record,
      vehicle: vehicle,
      allRecords: allRecords,
      currentMileage: currentMileage,
    );

    if (insight == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final (color, icon) = _meaningStyle(context, insight.meaning);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.smart_toy_outlined, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                'AI解説',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Headline (timing evaluation)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  insight.headline,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // Meaning — why this maintenance matters
          if (insight.reasons.isNotEmpty) ...[
            const SizedBox(height: 4),
            _iconLine(
              context,
              icon: Icons.subject,
              iconColor: theme.colorScheme.outline,
              text: insight.reasons.join('\n'),
            ),
          ],

          // Next step
          if (insight.nextStep != null) ...[
            const SizedBox(height: 4),
            _iconLine(
              context,
              icon: Icons.calendar_today_outlined,
              iconColor: theme.colorScheme.outline,
              text: insight.nextStep!,
            ),
          ],

          // Asset / provenance note
          if (insight.assetNote != null) ...[
            const SizedBox(height: 4),
            _iconLine(
              context,
              icon: Icons.trending_up,
              iconColor: Colors.green.shade600,
              text: insight.assetNote!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconLine(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  (Color, IconData) _meaningStyle(
    BuildContext context,
    InsightMeaning meaning,
  ) {
    final cs = Theme.of(context).colorScheme;
    return switch (meaning) {
      InsightMeaning.onTime => (
          Colors.green.shade600,
          Icons.check_circle_outline
        ),
      InsightMeaning.overdue => (cs.error, Icons.error_outline),
      InsightMeaning.baseline => (cs.primary, Icons.flag_outlined),
      InsightMeaning.informational => (cs.primary, Icons.info_outline),
    };
  }

  // Comment view (no vehicle) — timing only, backward compatible.
  Widget _buildComment(BuildContext context) {
    final service = MaintenanceCommentService();
    final comment = service.generateComment(
      record: record,
      allRecords: allRecords,
      currentMileage: currentMileage,
    );

    if (comment == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final (color, icon) = _toneStyle(context, comment.tone);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.smart_toy_outlined, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                'AIコメント',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Timing evaluation
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  comment.timingEvaluation +
                      (comment.timingDetail != null
                          ? ' ${comment.timingDetail}'
                          : ''),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),

          // Next schedule
          if (comment.nextSchedule != null) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 13, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    comment.nextSchedule!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  (Color, IconData) _toneStyle(BuildContext context, CommentTone tone) {
    final cs = Theme.of(context).colorScheme;
    return switch (tone) {
      CommentTone.good => (Colors.green.shade600, Icons.check_circle_outline),
      CommentTone.acceptable => (
          Colors.amber.shade700,
          Icons.warning_amber_outlined
        ),
      CommentTone.overdue => (cs.error, Icons.error_outline),
      CommentTone.noHistory => (cs.primary, Icons.info_outline),
    };
  }
}
