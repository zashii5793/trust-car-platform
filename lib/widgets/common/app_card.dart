import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';

/// アプリケーション全体で使用するカードウィジェット
/// DESIGN_SYSTEM.md に準拠
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      elevation: elevation ?? 2,
      color: backgroundColor ?? Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? AppSpacing.borderRadiusMd,
      ),
      margin: margin ?? EdgeInsets.zero,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: borderRadius ?? AppSpacing.borderRadiusMd,
              child: Padding(
                padding: padding ?? AppSpacing.paddingCard,
                child: child,
              ),
            )
          : Padding(
              padding: padding ?? AppSpacing.paddingCard,
              child: child,
            ),
    );

    return card;
  }
}

/// リスト項目用のカード
class AppListCard extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  const AppListCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      margin: margin ?? AppSpacing.marginListItem,
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        contentPadding: AppSpacing.paddingCard,
      ),
    );
  }
}

/// 画像付きカード（車両表示用）
class AppImageCard extends StatelessWidget {
  final String? imageUrl;
  final Widget? placeholder;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final double imageHeight;

  const AppImageCard({
    super.key,
    this.imageUrl,
    this.placeholder,
    required this.child,
    this.onTap,
    this.margin,
    this.imageHeight = 160,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      margin: margin ?? AppSpacing.marginListItem,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image section
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusMd),
            ),
            child: SizedBox(
              height: imageHeight,
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceholder(context),
                    )
                  : _buildPlaceholder(context),
            ),
          ),
          // Content section
          Padding(
            padding: AppSpacing.paddingCard,
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (placeholder != null) return placeholder!;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.darkCard : AppColors.backgroundLight,
      child: Center(
        child: Icon(
          Icons.directions_car,
          size: AppSpacing.iconXl,
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
        ),
      ),
    );
  }
}

/// 情報表示用のカード（統計、サマリーなど）
class AppInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? iconColor;
  final VoidCallback? onTap;

  const AppInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: AppSpacing.iconMd,
                color: iconColor ?? theme.colorScheme.primary,
              ),
              AppSpacing.horizontalXs,
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          AppSpacing.verticalSm,
          Text(
            value,
            style: theme.textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}
