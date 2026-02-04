import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/error/app_error.dart';

/// ローディングインジケーター
class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const AppLoadingIndicator({
    super.key,
    this.size = 40,
    this.color,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// 画面全体をカバーするローディングオーバーレイ
class AppLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? backgroundColor;

  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: backgroundColor ?? Colors.black.withValues(alpha: 0.3),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLoadingIndicator(
                    color: Colors.white,
                  ),
                  if (message != null) ...[
                    AppSpacing.verticalMd,
                    Text(
                      message!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 中央配置のローディング表示
class AppLoadingCenter extends StatelessWidget {
  final String? message;

  const AppLoadingCenter({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLoadingIndicator(),
          if (message != null) ...[
            AppSpacing.verticalMd,
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// 空状態の表示
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.buttonLabel,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: AppSpacing.paddingScreen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppSpacing.iconEmpty,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
            ),
            AppSpacing.verticalMd,
            Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              AppSpacing.verticalXs,
              Text(
                description!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (buttonLabel != null && onButtonPressed != null) ...[
              AppSpacing.verticalLg,
              ElevatedButton.icon(
                onPressed: onButtonPressed,
                icon: const Icon(Icons.add),
                label: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// エラー状態の表示
class AppErrorState extends StatelessWidget {
  final String message;
  final String? buttonLabel;
  final VoidCallback? onRetry;

  const AppErrorState({
    super.key,
    required this.message,
    this.buttonLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: AppSpacing.paddingScreen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: AppSpacing.paddingCard,
              decoration: BoxDecoration(
                color: AppColors.errorBackground,
                borderRadius: AppSpacing.borderRadiusSm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                  ),
                  AppSpacing.horizontalSm,
                  Expanded(
                    child: Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onRetry != null) ...[
              AppSpacing.verticalMd,
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(buttonLabel ?? '再試行'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 成功メッセージ表示用のスナックバーを表示
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          AppSpacing.horizontalSm,
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: AppColors.success,
    ),
  );
}

/// エラーメッセージ表示用のスナックバーを表示
void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          AppSpacing.horizontalSm,
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: AppColors.error,
    ),
  );
}

/// AppError対応のエラースナックバー（リトライ可能な場合はアクション付き）
void showAppErrorSnackBar(
  BuildContext context,
  AppError error, {
  VoidCallback? onRetry,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            _getErrorIcon(error),
            color: Colors.white,
          ),
          AppSpacing.horizontalSm,
          Expanded(child: Text(error.userMessage)),
        ],
      ),
      backgroundColor: AppColors.error,
      action: error.isRetryable && onRetry != null
          ? SnackBarAction(
              label: '再試行',
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
      duration: error.isRetryable
          ? const Duration(seconds: 5)
          : const Duration(seconds: 3),
    ),
  );
}

IconData _getErrorIcon(AppError error) {
  return switch (error) {
    NetworkError() => Icons.wifi_off,
    AuthError() => Icons.lock_outline,
    ValidationError() => Icons.warning_amber,
    NotFoundError() => Icons.search_off,
    PermissionError() => Icons.block,
    ServerError() => Icons.cloud_off,
    CacheError() => Icons.storage,
    UnknownError() => Icons.error_outline,
  };
}
