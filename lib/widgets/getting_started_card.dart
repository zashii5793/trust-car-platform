import 'package:flutter/material.dart';

import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';

/// Three steps that turn an empty account into a useful one.
///
/// After logging in, the only guidance was "register your car" — and after
/// that, nothing. The app only starts paying off once a vehicle has an
/// inspection date (so reminders can fire) and at least one maintenance record
/// (so the history has something to show).
///
/// Completion is derived from real data, never from a "you have seen this"
/// flag: a step that is genuinely done disappears, and one that was skipped
/// stays. The whole card removes itself when all three are done.
class GettingStartedCard extends StatelessWidget {
  const GettingStartedCard({
    super.key,
    required this.hasVehicle,
    required this.hasInspectionDate,
    required this.hasMaintenanceRecord,
    required this.onRegisterVehicle,
    required this.onSetInspectionDate,
    required this.onAddMaintenance,
    required this.onDismiss,
  });

  final bool hasVehicle;
  final bool hasInspectionDate;
  final bool hasMaintenanceRecord;

  final VoidCallback onRegisterVehicle;
  final VoidCallback onSetInspectionDate;
  final VoidCallback onAddMaintenance;

  /// Lets people who do not want to be nudged put the card away.
  final VoidCallback onDismiss;

  int get _doneCount =>
      (hasVehicle ? 1 : 0) +
      (hasInspectionDate ? 1 : 0) +
      (hasMaintenanceRecord ? 1 : 0);

  bool get _isComplete => _doneCount == 3;

  @override
  Widget build(BuildContext context) {
    if (_isComplete) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Card(
      key: const Key('getting_started_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined,
                    size: 20, color: theme.colorScheme.primary),
                AppSpacing.horizontalXs,
                Expanded(
                  child: Text(
                    'はじめの3ステップ',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '$_doneCount / 3',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  key: const Key('getting_started_dismiss'),
                  tooltip: '閉じる',
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: _doneCount / 3,
              minHeight: 4,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 12),
            _Step(
              stepKey: const Key('getting_started_step_vehicle'),
              done: hasVehicle,
              title: '愛車を登録する',
              description: '車検証をカメラで読み取れば、入力はほとんど要りません',
              onTap: onRegisterVehicle,
            ),
            _Step(
              stepKey: const Key('getting_started_step_inspection'),
              done: hasInspectionDate,
              title: '車検の満了日を入れる',
              description: '期限が近づいたらお知らせします',
              onTap: onSetInspectionDate,
            ),
            _Step(
              stepKey: const Key('getting_started_step_maintenance'),
              done: hasMaintenanceRecord,
              title: '整備の記録を1件つける',
              description: '直近のオイル交換でも構いません。次の時期をAIが見積もります',
              onTap: onAddMaintenance,
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.stepKey,
    required this.done,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final Key stepKey;
  final bool done;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return InkWell(
      key: stepKey,
      // 終わったステップは押しても行き先が無いので、タップ自体を止める。
      onTap: done ? null : onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: done ? AppColors.success : muted,
            ),
            AppSpacing.horizontalSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: done ? FontWeight.normal : FontWeight.w600,
                      color: done ? muted : null,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (!done) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
            if (!done) Icon(Icons.chevron_right, size: 20, color: muted),
          ],
        ),
      ),
    );
  }
}
