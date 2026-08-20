import 'package:flutter/material.dart';

import '../core/constants/colors.dart';

/// Plan badge shown on the profile header.
///
/// The header sits on a dark blue gradient. Leaving the chip's colors to the
/// theme rendered a near-white background with a near-white label — the badge
/// was invisible on the real app. Background, label and icon colors are always
/// set explicitly here so the badge stays readable wherever it is placed.
class PlanBadge extends StatelessWidget {
  const PlanBadge({
    super.key,
    required this.isPremium,
    this.onTap,
  });

  final bool isPremium;

  /// Tapping opens the plan screen. Kept optional so the badge can be used as
  /// a plain indicator.
  final VoidCallback? onTap;

  /// Amber reads as "premium" and stands out against the blue header, unlike
  /// the primary blue that used to blend into it.
  static const Color _premiumBackground = AppColors.warning;
  static const Color _freeBackground = AppColors.backgroundWhite;
  static const Color _foreground = AppColors.textPrimary;

  Color get backgroundColor =>
      isPremium ? _premiumBackground : _freeBackground;

  Color get foregroundColor => _foreground;

  String get label => isPremium ? 'プレミアム' : 'フリープラン';

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      key: const Key('profile_plan_chip'),
      avatar: Icon(
        isPremium ? Icons.star : Icons.star_border,
        size: 16,
        color: foregroundColor,
      ),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _foreground,
        ),
      ),
      backgroundColor: backgroundColor,
      side: const BorderSide(color: AppColors.border),
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }
}
