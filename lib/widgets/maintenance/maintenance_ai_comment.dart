import 'package:flutter/material.dart';
import '../../core/constants/spacing.dart';
import '../../models/maintenance_record.dart';
import '../../services/maintenance_comment_service.dart';

/// Displays an AI-generated comment for a single maintenance record.
///
/// Shows timing evaluation (good/acceptable/overdue) and next-service schedule.
/// Based only on rule-based logic — no LLM required, no network call.
/// Returns [SizedBox.shrink] when no comment can be generated.
class MaintenanceAiComment extends StatelessWidget {
  final MaintenanceRecord record;
  final List<MaintenanceRecord> allRecords;
  final int currentMileage;

  const MaintenanceAiComment({
    super.key,
    required this.record,
    required this.allRecords,
    required this.currentMileage,
  });

  @override
  Widget build(BuildContext context) {
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
