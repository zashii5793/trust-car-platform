import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../models/vehicle.dart';

/// Banner shown when mileage hasn't been updated in 30+ days.
/// Returns [SizedBox.shrink] when the update is recent enough.
class MileageReminderBanner extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onTapUpdate;

  const MileageReminderBanner({
    super.key,
    required this.vehicle,
    required this.onTapUpdate,
  });

  /// Whether the banner should be displayed.
  /// True when mileageUpdatedAt is null or >= 30 days ago.
  bool get _shouldShow {
    if (vehicle.mileageUpdatedAt == null) {
      return true;
    }
    return DateTime.now().difference(vehicle.mileageUpdatedAt!).inDays >= 30;
  }

  /// Human-readable last-update label.
  String _lastUpdatedLabel() {
    if (vehicle.mileageUpdatedAt == null) {
      return '未設定';
    }
    final days = DateTime.now().difference(vehicle.mileageUpdatedAt!).inDays;
    return '$days日前';
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.warningBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.speed_outlined,
              color: AppColors.warning,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '走行距離を更新してください',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '最終更新: ${_lastUpdatedLabel()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onTapUpdate,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warning,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('今すぐ更新'),
            ),
          ],
        ),
      ),
    );
  }
}
