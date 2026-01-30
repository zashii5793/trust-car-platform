import 'package:flutter/material.dart';
import '../error/app_error.dart';

/// アプリ全体で統一されたSnackBar表示
class AppSnackBar {
  AppSnackBar._();

  /// 成功メッセージを表示
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      type: _SnackBarType.success,
      duration: duration,
      action: action,
    );
  }

  /// エラーメッセージを表示
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onRetry,
  }) {
    _show(
      context,
      message: message,
      type: _SnackBarType.error,
      duration: duration,
      action: onRetry != null
          ? SnackBarAction(
              label: '再試行',
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
    );
  }

  /// AppErrorを表示
  static void showAppError(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) {
    _show(
      context,
      message: error.userMessage,
      type: _SnackBarType.error,
      duration: const Duration(seconds: 4),
      action: error.isRetryable && onRetry != null
          ? SnackBarAction(
              label: '再試行',
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
    );
  }

  /// 警告メッセージを表示
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      type: _SnackBarType.warning,
      duration: duration,
      action: action,
    );
  }

  /// 情報メッセージを表示
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      type: _SnackBarType.info,
      duration: duration,
      action: action,
    );
  }

  /// 内部実装
  static void _show(
    BuildContext context, {
    required String message,
    required _SnackBarType type,
    required Duration duration,
    SnackBarAction? action,
  }) {
    // 既存のSnackBarを閉じる
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            type.icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: type.backgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(16),
      action: action,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// 現在のSnackBarを閉じる
  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }
}

/// SnackBarの種類
enum _SnackBarType {
  success,
  error,
  warning,
  info,
}

extension on _SnackBarType {
  Color get backgroundColor {
    switch (this) {
      case _SnackBarType.success:
        return const Color(0xFF4CAF50);
      case _SnackBarType.error:
        return const Color(0xFFE53935);
      case _SnackBarType.warning:
        return const Color(0xFFFFA726);
      case _SnackBarType.info:
        return const Color(0xFF2196F3);
    }
  }

  IconData get icon {
    switch (this) {
      case _SnackBarType.success:
        return Icons.check_circle;
      case _SnackBarType.error:
        return Icons.error;
      case _SnackBarType.warning:
        return Icons.warning;
      case _SnackBarType.info:
        return Icons.info;
    }
  }
}
