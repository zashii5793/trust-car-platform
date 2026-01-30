import 'package:flutter/material.dart';

/// アプリ全体で統一されたダイアログ
class AppDialog {
  AppDialog._();

  /// 確認ダイアログを表示
  static Future<bool> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '確認',
    String cancelText = 'キャンセル',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 削除確認ダイアログを表示
  static Future<bool> showDeleteConfirm(
    BuildContext context, {
    required String itemName,
    String? message,
  }) {
    return showConfirm(
      context,
      title: '$itemNameを削除',
      message: message ?? '$itemNameを削除してもよろしいですか？\nこの操作は取り消せません。',
      confirmText: '削除',
      cancelText: 'キャンセル',
      isDestructive: true,
    );
  }

  /// ログアウト確認ダイアログを表示
  static Future<bool> showLogoutConfirm(BuildContext context) {
    return showConfirm(
      context,
      title: 'ログアウト',
      message: 'ログアウトしてもよろしいですか？',
      confirmText: 'ログアウト',
      cancelText: 'キャンセル',
      isDestructive: true,
    );
  }

  /// 情報ダイアログを表示
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  /// エラーダイアログを表示
  static Future<void> showError(
    BuildContext context, {
    String title = 'エラー',
    required String message,
    String buttonText = 'OK',
    VoidCallback? onRetry,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('再試行'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  /// ローディングダイアログを表示
  static Future<void> showLoading(
    BuildContext context, {
    String message = '読み込み中...',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  /// ローディングダイアログを閉じる
  static void hideLoading(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// 選択ダイアログを表示
  static Future<T?> showSelection<T>(
    BuildContext context, {
    required String title,
    required List<SelectionOption<T>> options,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.only(top: 16, bottom: 8),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              return ListTile(
                leading: option.icon != null ? Icon(option.icon) : null,
                title: Text(option.label),
                subtitle: option.description != null
                    ? Text(option.description!)
                    : null,
                onTap: () => Navigator.of(context).pop(option.value),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }
}

/// 選択オプション
class SelectionOption<T> {
  final T value;
  final String label;
  final String? description;
  final IconData? icon;

  const SelectionOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
  });
}
