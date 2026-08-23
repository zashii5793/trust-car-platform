import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/japan_prefectures.dart';
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
import '../../widgets/plan_badge.dart';
import '../export/export_dialog.dart';
import '../marketplace/my_listings_screen.dart';
import 'settings_screen.dart';
import '../../services/feedback_service.dart';
import '../settings/feedback_screen.dart';
import '../settings/help_screen.dart';
import '../settings/plan_screen.dart';

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
                  displayName:
                      appUser?.displayName ?? user?.displayName ?? 'ユーザー',
                  email: user?.email ?? '',
                  isPremium: isPremium,
                ),

                AppSpacing.verticalLg,

                // 統計セクション
                Consumer2<VehicleProvider, MaintenanceProvider>(
                  builder: (context, vehicleProvider, maintenanceProvider, _) {
                    return _StatsSection(
                      vehicleCount: vehicleProvider.vehicles.length,
                      maintenanceCount: maintenanceProvider.records.length,
                      totalMileage: vehicleProvider.vehicles
                          .fold(0, (sum, v) => sum + v.mileage),
                    );
                  },
                ),

                AppSpacing.verticalLg,

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
                        currentPrefecture: appUser?.prefecture,
                        currentCity: appUser?.city,
                      ),
                    ),
                    // `appUser?.x != null` では appUser 自体は昇格しないので、
                    // 変数そのものを null チェックする。
                    if (appUser != null && appUser.regionLabel != null)
                      _MenuItem(
                        icon: Icons.place_outlined,
                        label: 'お住まいの地域: ${appUser.regionLabel}',
                        onTap: () => _showProfileEditSheet(
                          context,
                          authProvider,
                          appUser.displayName ?? user?.displayName ?? 'ユーザー',
                          user?.photoURL,
                          currentPrefecture: appUser.prefecture,
                          currentCity: appUser.city,
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

                // C2Cパーツ売買は凍結中のため、フラグ有効時のみ表示する。
                if (isFeatureEnabled(FeatureFlag.c2cPartsMarketplace)) ...[
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
                ],

                _MenuSection(
                  title: 'プラン',
                  items: [
                    _MenuItem(
                      icon: Icons.workspace_premium_outlined,
                      label: isPremium ? 'プラン（プレミアム）' : 'プラン（フリー）',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const PlanScreen(),
                        ),
                      ),
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
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => HelpScreen(userId: user?.uid),
                        ),
                      ),
                    ),
                    _MenuItem(
                      icon: Icons.rate_review_outlined,
                      label: 'ご意見・不具合の報告',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => FeedbackScreen(
                            service:
                                ServiceLocator.instance.get<FeedbackService>(),
                            userId: user?.uid ?? '',
                            fromScreen: 'profile',
                          ),
                        ),
                      ),
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
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        }
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('ログアウト'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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

  /// Premium gate for PDF export.
  ///
  /// This dialog used to offer only 「閉じる」 while telling the user to
  /// upgrade — a dead end. The purchase flow already existed
  /// (UserSubscriptionProvider.purchasePremium); this dialog simply never
  /// called it, unlike the identical dialog on the home screen.
  void _showUpgradeDialog(BuildContext context) {
    final subscriptionProvider = context.read<UserSubscriptionProvider>();
    final uid = context.read<AuthProvider>().appUser?.id ?? '';

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
          FilledButton(
            key: const Key('profile_upgrade_purchase_button'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (uid.isEmpty) return;
              final result =
                  await subscriptionProvider.purchasePremium(userId: uid);
              if (!context.mounted) return;
              result.when(
                success: (_) => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('プレミアムプランへの登録が完了しました'),
                    backgroundColor: Colors.green,
                  ),
                ),
                failure: (err) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err.userMessage)),
                ),
              );
            },
            child: const Text('プレミアムに登録する'),
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
    String? currentPhotoUrl, {
    String? currentPrefecture,
    String? currentCity,
  }) {
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
        currentPrefecture: currentPrefecture,
        currentCity: currentCity,
      ),
    );
  }

  Future<void> _showExportPicker(BuildContext context) async {
    final vehicleProvider = context.read<VehicleProvider>();
    final vehicles = vehicleProvider.vehicles;

    if (vehicles.isEmpty) {
      if (context.mounted) {
        showErrorSnackBar(context, '車両が登録されていません');
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
  final String? currentPrefecture;
  final String? currentCity;

  const _ProfileEditSheet({
    required this.authProvider,
    required this.currentName,
    this.currentPhotoUrl,
    this.currentPrefecture,
    this.currentCity,
  });

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  String? _prefecture;
  bool _isSaving = false;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _cityController = TextEditingController(text: widget.currentCity ?? '');
    // 保存済みの値が一覧に無い場合（旧データなど）は未選択に倒す。
    // DropdownButtonFormField は一覧に無い値を渡すと例外になる。
    _prefecture = kJapanPrefectures.contains(widget.currentPrefecture)
        ? widget.currentPrefecture
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
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
        // Path includes the owner uid so Storage rules can enforce
        // write access per user.
        final uploadResult = await firebaseService.uploadImageBytes(
          _pickedImageBytes!,
          'profile_images/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        if (uploadResult.isSuccess) {
          newPhotoUrl = uploadResult.valueOrNull;
        }
      }
    }

    final success = await widget.authProvider.updateProfile(
      displayName: _nameController.text.trim(),
      photoUrl: newPhotoUrl,
      // 空文字を渡すとクリアされる。選択を外したら消せるようにする。
      prefecture: _prefecture ?? '',
      city: _cityController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop(); // close sheet first
      if (context.mounted) {
        showSuccessSnackBar(context, 'プロフィールを更新しました');
      }
    } else {
      showErrorSnackBar(context, '更新に失敗しました');
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
        // 居住地の欄を足して縦に伸びたため、小さい画面やキーボード表示時に
        // はみ出す。スクロールできるようにしておく。
        child: SingleChildScrollView(
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
                            : (widget.currentPhotoUrl != null &&
                                    widget.currentPhotoUrl!.isNotEmpty
                                ? NetworkImage(widget.currentPhotoUrl!)
                                    as ImageProvider
                                : null),
                        child: (_pickedImageBytes == null &&
                                (widget.currentPhotoUrl == null ||
                                    widget.currentPhotoUrl!.isEmpty))
                            ? const Icon(Icons.person,
                                size: 44, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.primary,
                          child: const Icon(Icons.camera_alt,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.verticalLg,
              TextFormField(
                key: const Key('profile_display_name_field'),
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

              // お住まいの地域。近くの整備工場を探すために使う。
              //
              // 都道府県は47件で確定しているので選択式。市区町村は約1,700件
              // あり網羅した一覧を保守できないので自由入力にする。
              Align(
                alignment: Alignment.centerLeft,
                child: Text('お住まいの地域（任意）', style: theme.textTheme.labelLarge),
              ),
              AppSpacing.verticalXxs,
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '近くの整備工場を探すときに使います',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
              AppSpacing.verticalSm,
              DropdownButtonFormField<String>(
                key: const Key('profile_prefecture_dropdown'),
                initialValue: _prefecture,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '都道府県',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('未設定'),
                  ),
                  for (final p in kJapanPrefectures)
                    DropdownMenuItem<String>(value: p, child: Text(p)),
                ],
                onChanged:
                    _isSaving ? null : (v) => setState(() => _prefecture = v),
              ),
              AppSpacing.verticalSm,
              TextFormField(
                key: const Key('profile_city_field'),
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: '市区町村',
                  hintText: '例: 世田谷区 / 横浜市青葉区',
                  border: OutlineInputBorder(),
                ),
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

        // プランバッジ。プラン内容を確認・変更できる場所がここしか無いので、
        // 表示だけで終わらせずタップでプラン画面へ入れるようにしている。
        // 配色は PlanBadge 側で固定している（青ヘッダーの上でテーマ既定色に
        // 任せると背景と文字がどちらも白になり読めなくなる）。
        PlanBadge(
          isPremium: isPremium,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const PlanScreen()),
          ),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  final int vehicleCount;
  final int maintenanceCount;
  final int totalMileage;

  const _StatsSection({
    required this.vehicleCount,
    required this.maintenanceCount,
    required this.totalMileage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatItem(
          icon: Icons.directions_car,
          value: vehicleCount.toString(),
          label: '登録車両',
          color: AppColors.primary,
        ),
        const _StatDivider(),
        _StatItem(
          icon: Icons.build_outlined,
          value: maintenanceCount.toString(),
          label: '整備記録',
          color: AppColors.maintenanceParts,
        ),
        const _StatDivider(),
        _StatItem(
          icon: Icons.speed,
          value: totalMileage == 0
              ? '0'
              : NumberFormat('#,###').format(totalMileage),
          label: '総走行距離(km)',
          color: AppColors.secondary,
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          AppSpacing.verticalXs,
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: AppColors.divider.withValues(alpha: 0.4),
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
