import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/loading_indicator.dart';

/// 設定画面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late NotificationSettings _notificationSettings;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _notificationSettings =
        authProvider.appUser?.notificationSettings ?? NotificationSettings();
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success =
        await authProvider.updateNotificationSettings(_notificationSettings);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        showSuccessSnackBar(context, '設定を保存しました');
      } else {
        showErrorSnackBar(context, '設定の保存に失敗しました');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSettings,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingScreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 通知設定セクション
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xxs,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                '通知設定',
                style: theme.textTheme.labelMedium,
              ),
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('プッシュ通知'),
                    subtitle: const Text('お知らせを受け取る'),
                    value: _notificationSettings.pushEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationSettings = _notificationSettings.copyWith(
                          pushEnabled: value,
                        );
                      });
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('点検リマインダー'),
                    subtitle: const Text('定期点検の時期をお知らせ'),
                    value: _notificationSettings.inspectionReminder,
                    onChanged: _notificationSettings.pushEnabled
                        ? (value) {
                            setState(() {
                              _notificationSettings =
                                  _notificationSettings.copyWith(
                                inspectionReminder: value,
                              );
                            });
                          }
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('オイル交換リマインダー'),
                    subtitle: const Text('オイル交換の時期をお知らせ'),
                    value: _notificationSettings.oilChangeReminder,
                    onChanged: _notificationSettings.pushEnabled
                        ? (value) {
                            setState(() {
                              _notificationSettings =
                                  _notificationSettings.copyWith(
                                oilChangeReminder: value,
                              );
                            });
                          }
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('タイヤ交換リマインダー'),
                    subtitle: const Text('タイヤ交換の時期をお知らせ'),
                    value: _notificationSettings.tireChangeReminder,
                    onChanged: _notificationSettings.pushEnabled
                        ? (value) {
                            setState(() {
                              _notificationSettings =
                                  _notificationSettings.copyWith(
                                tireChangeReminder: value,
                              );
                            });
                          }
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('車検リマインダー'),
                    subtitle: const Text('車検の時期をお知らせ'),
                    value: _notificationSettings.carInspectionReminder,
                    onChanged: _notificationSettings.pushEnabled
                        ? (value) {
                            setState(() {
                              _notificationSettings =
                                  _notificationSettings.copyWith(
                                carInspectionReminder: value,
                              );
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ),

            AppSpacing.verticalXxl,

            // アプリ情報セクション
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xxs,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                'アプリ情報',
                style: theme.textTheme.labelMedium,
              ),
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('バージョン'),
                    trailing: Text(
                      '1.0.0',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('利用規約'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showSuccessSnackBar(context, '実装予定の機能です');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('プライバシーポリシー'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showSuccessSnackBar(context, '実装予定の機能です');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
