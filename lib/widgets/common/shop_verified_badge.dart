import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';

/// Compact "認証済み" (platform-verified) badge for shops.
///
/// Renders nothing unless [isVerified] is true, so callers can drop it inline
/// without guarding. Conveys trust on user-facing surfaces (shop list/detail).
class ShopVerifiedBadge extends StatelessWidget {
  final bool isVerified;

  /// When true, shows only the icon (for dense rows). Defaults to icon + label.
  final bool compact;

  const ShopVerifiedBadge({
    super.key,
    required this.isVerified,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    final icon = Icon(
      Icons.verified,
      size: compact ? 16 : AppSpacing.iconSm,
      color: AppColors.success,
    );

    if (compact) {
      return Semantics(label: '認証済みの店舗', child: icon);
    }

    return Semantics(
      label: '認証済みの店舗',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: AppSpacing.borderRadiusXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 2),
            const Text(
              '認証済み',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
