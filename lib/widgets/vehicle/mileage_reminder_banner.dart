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

  /// 判定の基準時刻。
  ///
  /// mileageUpdatedAt が無い車両（この項目の導入前に登録されたもの）は
  /// 登録日を基準にする。以前は「未設定なら常に表示」だったため、
  /// たった今距離を入力して登録した直後に「更新してください」が出ていた。
  DateTime get _reference => vehicle.mileageUpdatedAt ?? vehicle.createdAt;

  /// Whether the banner should be displayed (30日以上未更新のときのみ).
  bool get _shouldShow => DateTime.now().difference(_reference).inDays >= 30;

  /// Human-readable last-update label.
  String _lastUpdatedLabel() {
    final days = DateTime.now().difference(_reference).inDays;
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
