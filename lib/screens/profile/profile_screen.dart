import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/maintenance_record.dart';
import '../../models/vehicle.dart';
import '../../providers/auth_provider.dart';
import '../../providers/maintenance_provider.dart';
import '../../providers/user_subscription_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../export/export_dialog.dart';
import '../marketplace/my_listings_screen.dart';
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
      body: Consumer2<AuthProvider, UserSubscriptionProvider>(
        builder: (context, authProvider, subProvider, child) {
          final user = authProvider.firebaseUser;
          final appUser = authProvider.appUser;
          final isPremium = subProvider.isPremium;

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
                  isPremium: isPremium,
                ),

                AppSpacing.verticalXxl,

                // メニュー項目
                _MenuSection(
                  title: 'アカウント',
                  items: [
                    _MenuItem(
                      icon: Icons.person_outline,
                      label: 'プロフィールを編集',
                      onTap: () => _showProfileEditSheet(
                        context,
                        authProvider,
                        appUser?.displayName ?? user?.displayName ?? 'ユーザー',
                        user?.photoURL,
                      ),
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
                  title: 'マーケットプレイス',
                  items: [
                    _MenuItem(
                      icon: Icons.sell_outlined,
                      label: 'マイ出品',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyListingsScreen(),
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
                      label: isPremium ? 'データをエクスポート' : 'データをエクスポート（プレミアム）',
                      onTap: isPremium
                          ? () => _showExportPicker(context)
                          : () => _showUpgradeDialog(context),
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
                      onTap: () async {
                        final uri = Uri.parse(
                          'https://zashii5793.github.io/trust-car-platform/',
                        );
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else if (context.mounted) {
                          showSuccessSnackBar(context, 'ブラウザを開けませんでした');
                        }
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

  void _showUpgradeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('プレミアムプランが必要です'),
        content: const Text(
          'データのエクスポートはプレミアムプランの機能です。\n'
          'アップグレードすると整備記録や走行ログのPDFエクスポート、無制限の問い合わせが利用できます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('閉じる'),
          ),
        ],
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

  void _showProfileEditSheet(
    BuildContext context,
    AuthProvider authProvider,
    String currentName,
    String? currentPhotoUrl,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ProfileEditSheet(
        authProvider: authProvider,
        currentName: currentName,
        currentPhotoUrl: currentPhotoUrl,
      ),
    );
  }

  Future<void> _showExportPicker(BuildContext context) async {
    final vehicleProvider = context.read<VehicleProvider>();
    final vehicles = vehicleProvider.vehicles;

    if (vehicles.isEmpty) {
      if (context.mounted) {
        showSuccessSnackBar(context, '車両が登録されていません');
      }
      return;
    }

    Vehicle? vehicle;
    if (vehicles.length == 1) {
      vehicle = vehicles.first;
    } else {
      vehicle = await showDialog<Vehicle>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('エクスポートする車両を選択'),
          children: vehicles
              .map(
                (v) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(v),
                  child: Text('${v.maker} ${v.model}'),
                ),
              )
              .toList(),
        ),
      );
    }

    if (vehicle == null || !context.mounted) return;

    final maintenanceProvider = context.read<MaintenanceProvider>();
    final List<MaintenanceRecord> records = maintenanceProvider.records;

    await showExportDialog(
      context: context,
      vehicle: vehicle,
      records: records,
    );
  }
}

class _ProfileEditSheet extends StatefulWidget {
  final AuthProvider authProvider;
  final String currentName;
  final String? currentPhotoUrl;

  const _ProfileEditSheet({
    required this.authProvider,
    required this.currentName,
    this.currentPhotoUrl,
  });

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSaving = false;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _pickedImageBytes = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    String? newPhotoUrl = widget.currentPhotoUrl;

    if (_pickedImageBytes != null) {
      final uid = widget.authProvider.firebaseUser?.uid;
      if (uid != null) {
        final firebaseService = sl.get<FirebaseService>();
        final uploadResult = await firebaseService.uploadImageBytes(
          _pickedImageBytes!,
          'profile_images/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        if (uploadResult.isSuccess) {
          newPhotoUrl = uploadResult.valueOrNull;
        }
      }
    }

    final success = await widget.authProvider.updateProfile(
      displayName: _nameController.text.trim(),
      photoUrl: newPhotoUrl,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop(); // close sheet first
      if (context.mounted) {
        showSuccessSnackBar(context, 'プロフィールを更新しました');
      }
    } else {
      showSuccessSnackBar(context, '更新に失敗しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('プロフィールを編集', style: theme.textTheme.titleLarge),
            AppSpacing.verticalLg,
            Center(
              child: GestureDetector(
                onTap: _isSaving ? null : _pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: theme.colorScheme.primary,
                      backgroundImage: _pickedImageBytes != null
                          ? MemoryImage(_pickedImageBytes!)
                          : (widget.currentPhotoUrl != null && widget.currentPhotoUrl!.isNotEmpty
                              ? NetworkImage(widget.currentPhotoUrl!) as ImageProvider
                              : null),
                      child: (_pickedImageBytes == null &&
                              (widget.currentPhotoUrl == null || widget.currentPhotoUrl!.isEmpty))
                          ? const Icon(Icons.person, size: 44, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.colorScheme.primary,
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.verticalLg,
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '表示名',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '表示名を入力してください' : null,
              textInputAction: TextInputAction.done,
            ),
            AppSpacing.verticalLg,
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final String email;
  final bool isPremium;

  const _ProfileHeader({
    this.photoUrl,
    required this.displayName,
    required this.email,
    required this.isPremium,
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
        AppSpacing.verticalSm,

        // プランバッジ
        Chip(
          avatar: Icon(
            isPremium ? Icons.star : Icons.star_border,
            size: 16,
            color: isPremium ? Colors.white : theme.colorScheme.onSurface,
          ),
          label: Text(
            isPremium ? 'プレミアム' : 'フリープラン',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isPremium ? Colors.white : null,
            ),
          ),
          backgroundColor: isPremium ? AppColors.primary : null,
          side: isPremium ? BorderSide.none : null,
          visualDensity: VisualDensity.compact,
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
