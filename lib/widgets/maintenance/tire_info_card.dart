import 'package:flutter/material.dart';
import '../../models/maintenance_record.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../common/app_card.dart';
import '../common/loading_indicator.dart';

/// Displays the latest tire change information for a vehicle.
/// Pass [latestTireChange] as null when no tire change has been recorded yet.
class TireInfoCard extends StatelessWidget {
  final MaintenanceRecord? latestTireChange;

  const TireInfoCard({
    super.key,
    required this.latestTireChange,
  });

  @override
  Widget build(BuildContext context) {
    if (latestTireChange == null) {
      return const AppEmptyState(
        icon: Icons.tire_repair,
        title: 'タイヤ情報が登録されていません',
        description: '整備記録からタイヤ交換を登録してください',
      );
    }

    final record = latestTireChange!;
    final theme = Theme.of(context);

    final String formattedDate =
        '${record.date.year}年${record.date.month}月${record.date.day}日';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                child: const Icon(
                  Icons.tire_repair,
                  color: AppColors.primary,
                  size: AppSpacing.iconMd,
                ),
              ),
              AppSpacing.horizontalMd,
              Expanded(
                child: Text(
                  'タイヤ情報',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.verticalMd,
          const Divider(),
          AppSpacing.verticalSm,

          // Info rows
          _InfoRow(
            icon: Icons.calendar_today,
            label: '交換日',
            value: formattedDate,
          ),
          AppSpacing.verticalSm,
          _InfoRow(
            icon: Icons.business,
            label: 'タイヤメーカー',
            value: record.partManufacturer ?? '不明',
          ),
          AppSpacing.verticalSm,
          _InfoRow(
            icon: Icons.tire_repair,
            label: 'タイヤサイズ',
            value: record.tireSize ?? '不明',
          ),
          AppSpacing.verticalSm,
          _InfoRow(
            icon: Icons.swap_vert,
            label: '交換位置',
            value: record.tirePosition ?? '全輪',
          ),
          if (record.mileageAtService != null) ...[
            AppSpacing.verticalSm,
            _InfoRow(
              icon: Icons.speed,
              label: '交換時走行距離',
              value: '${record.mileageAtService} km',
            ),
          ],
        ],
      ),
    );
  }
}

/// A single label/value row used inside [TireInfoCard].
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: AppSpacing.iconSm,
          color: AppColors.textTertiary,
        ),
        AppSpacing.horizontalSm,
        Text(
          '$label:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        AppSpacing.horizontalSm,
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
