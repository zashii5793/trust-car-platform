import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../models/newsletter.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../services/push_notification_service.dart';
import '../../services/newsletter_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../settings/privacy_policy_screen.dart';
import '../settings/terms_of_service_screen.dart';
import '../about/whats_new_screen.dart';

/// 設定画面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late NotificationSettings _notificationSettings;
  NewsletterSubscription? _newsletterSubscription;
  bool _isLoading = false;
  bool _isNewsletterLoading = false;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _notificationSettings =
        authProvider.appUser?.notificationSettings ?? NotificationSettings();
    _loadNewsletterSubscription();
  }

  Future<void> _loadNewsletterSubscription() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;
    final result = await sl.get<NewsletterService>().getSubscription(uid);
    if (!mounted) return;
    result.when(
      success: (sub) => setState(() {
        _newsletterSubscription = sub ??
            NewsletterSubscription(
              userId: uid,
              email: context.read<AuthProvider>().appUser?.email ?? '',
              updatedAt: DateTime.now(),
            );
      }),
      failure: (_) => setState(() {
        _newsletterSubscription = NewsletterSubscription(
          userId: uid,
          email: context.read<AuthProvider>().appUser?.email ?? '',
          updatedAt: DateTime.now(),
        );
      }),
    );
  }

  Future<void> _saveNewsletterSubscription() async {
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    final sub = _newsletterSubscription;
    if (uid == null || sub == null) return;
    setState(() => _isNewsletterLoading = true);
    final result = await sl.get<NewsletterService>().updateSubscription(sub);
    if (!mounted) return;
    setState(() => _isNewsletterLoading = false);
    if (result.isFailure) {
      showErrorSnackBar(context, 'ニュースレター設定の保存に失敗しました');
    }
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

  /// 法人アカウント登録・編集ダイアログ
  Future<void> _showBusinessAccountDialog() async {
    final authProvider = context.read<AuthProvider>();
    final controller = TextEditingController(
      text: authProvider.appUser?.companyName ?? '',
    );

    final companyName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('法人アカウント登録'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '社用車・リース車両の複数台管理に対応します。\n'
              '5台以上の管理は法人向けプラン対象ですが、現在は無料開放中です'
              '（正式リリース後 月額¥4,980〜を予定）。',
              style: TextStyle(fontSize: 13),
            ),
            AppSpacing.verticalMd,
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '会社名',
                hintText: '例: 株式会社○○商事',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('登録'),
          ),
        ],
      ),
    );

    if (companyName == null || companyName.isEmpty || !mounted) {
      controller.dispose();
      return;
    }

    final success = await authProvider.updateBusinessProfile(
      accountType: AccountType.business,
      companyName: companyName,
    );
    controller.dispose();

    if (mounted) {
      if (success) {
        showSuccessSnackBar(context, '法人アカウントとして登録しました');
      } else {
        showErrorSnackBar(context, '登録に失敗しました。再度お試しください。');
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
                    onChanged: (value) async {
                      if (value) {
                        // Request notification permission when enabling
                        final pushService = sl.get<PushNotificationService>();
                        final result = await pushService.requestPermission();
                        final granted = result.getOrElse(false);
                        if (!granted && mounted) {
                          // ignore: use_build_context_synchronously
                          showErrorSnackBar(context, '通知の許可が必要です');
                          return;
                        }
                      }
                      if (!mounted) return;
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

            // ニュースレター設定セクション
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xxs,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                'メールニュースレター',
                style: theme.textTheme.labelMedium,
              ),
            ),
            _newsletterSubscription == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('ニュースレターを受け取る'),
                          subtitle: const Text('整備のコツやお得な情報をお届け'),
                          value: _newsletterSubscription!.isSubscribed,
                          onChanged: _isNewsletterLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    _newsletterSubscription =
                                        _newsletterSubscription!
                                            .copyWith(isSubscribed: value);
                                  });
                                  _saveNewsletterSubscription();
                                },
                        ),
                        if (_newsletterSubscription!.isSubscribed) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.sm,
                              AppSpacing.md,
                              AppSpacing.xs,
                            ),
                            child: Text(
                              '受け取るカテゴリ',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          ...NewsletterCategory.values.map((cat) {
                            final sub = _newsletterSubscription!;
                            final selected =
                                sub.subscribedCategories.contains(cat);
                            return CheckboxListTile(
                              title: Text(cat.displayName),
                              value: selected,
                              dense: true,
                              onChanged: _isNewsletterLoading
                                  ? null
                                  : (checked) {
                                      final updated =
                                          List<NewsletterCategory>.from(
                                              sub.subscribedCategories);
                                      if (checked == true) {
                                        if (!updated.contains(cat)) {
                                          updated.add(cat);
                                        }
                                      } else {
                                        updated.remove(cat);
                                      }
                                      setState(() {
                                        _newsletterSubscription = sub.copyWith(
                                          subscribedCategories: updated,
                                        );
                                      });
                                      _saveNewsletterSubscription();
                                    },
                            );
                          }),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                      ],
                    ),
                  ),

            AppSpacing.verticalXxl,

            // 法人アカウントセクション
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xxs,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                '法人利用',
                style: theme.textTheme.labelMedium,
              ),
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Builder(builder: (context) {
                final appUser = context.watch<AuthProvider>().appUser;
                final isBusiness = appUser?.isBusiness ?? false;
                return ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(isBusiness ? '法人アカウント設定' : '法人アカウント登録'),
                  subtitle: Text(
                    isBusiness
                        ? (appUser?.companyName ?? '会社名未設定')
                        : '社用車・リース車両をまとめて管理（現在無料開放中）',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showBusinessAccountDialog,
                );
              }),
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
                    subtitle: const Text('アップデート情報を見る'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '1.0.0',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WhatsNewScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('利用規約'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TermsOfServiceScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('プライバシーポリシー'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
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
