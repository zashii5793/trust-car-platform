import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/loading_indicator.dart';
import 'settings_screen.dart';

/// プロフィール画面
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.firebaseUser;
          final appUser = authProvider.appUser;

          if (authProvider.isLoading) {
            return const AppLoadingCenter();
          }

          return SingleChildScrollView(
            padding: AppSpacing.paddingScreen,
            child: Column(
              children: [
                AppSpacing.verticalLg,

                // プロフィールヘッダー
                _ProfileHeader(
                  photoUrl: user?.photoURL,
                  displayName: appUser?.displayName ?? user?.displayName ?? 'ユーザー',
                  email: user?.email ?? '',
                ),

                AppSpacing.verticalXxl,

                // メニュー項目
                _MenuSection(
                  title: 'アカウント',
                  items: [
                    _MenuItem(
                      icon: Icons.person_outline,
                      label: 'プロフィールを編集',
                      onTap: () {
                        // TODO: プロフィール編集画面
                        showSuccessSnackBar(context, '実装予定の機能です');
                      },
                    ),
                    _MenuItem(
                      icon: Icons.notifications_outlined,
                      label: '通知設定',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                AppSpacing.verticalMd,

                _MenuSection(
                  title: 'データ',
                  items: [
                    _MenuItem(
                      icon: Icons.download_outlined,
                      label: 'データをエクスポート',
                      onTap: () {
                        // TODO: PDF エクスポート
                        showSuccessSnackBar(context, '実装予定の機能です');
                      },
                    ),
                  ],
                ),

                AppSpacing.verticalMd,

                _MenuSection(
                  title: 'サポート',
                  items: [
                    _MenuItem(
                      icon: Icons.help_outline,
                      label: 'ヘルプ',
                      onTap: () {
                        showSuccessSnackBar(context, '実装予定の機能です');
                      },
                    ),
                    _MenuItem(
                      icon: Icons.info_outline,
                      label: 'このアプリについて',
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'クルマ統合管理',
                          applicationVersion: '1.0.0',
                          applicationLegalese: '© 2026 Trust Car Platform',
                        );
                      },
                    ),
                  ],
                ),

                AppSpacing.verticalXxl,

                // ログアウトボタン
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await _showLogoutConfirmation(context);
                      if (confirmed && context.mounted) {
                        await authProvider.signOut();
                        if (context.mounted) {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        }
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('ログアウト'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    ),
                  ),
                ),

                AppSpacing.verticalLg,
              ],
            ),
          );
        },
      ),
    );
  }

  Future<bool> _showLogoutConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ログアウト'),
            content: const Text('ログアウトしてもよろしいですか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'ログアウト',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _ProfileHeader extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final String email;

  const _ProfileHeader({
    this.photoUrl,
    required this.displayName,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // プロフィール画像
        CircleAvatar(
          radius: 50,
          backgroundColor: theme.colorScheme.primary,
          child: photoUrl != null && photoUrl!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    photoUrl!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                )
              : const Icon(
                  Icons.person,
                  size: 50,
                  color: Colors.white,
                ),
        ),
        AppSpacing.verticalMd,

        // 表示名
        Text(
          displayName,
          style: theme.textTheme.headlineMedium,
        ),
        AppSpacing.verticalXxs,

        // メールアドレス
        Text(
          email,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _MenuSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xxs,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            title,
            style: theme.textTheme.labelMedium,
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: item.onTap,
                  ),
                  if (index < items.length - 1) const Divider(height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
