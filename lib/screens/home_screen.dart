import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/vehicle_provider.dart';
import '../providers/maintenance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/user_subscription_provider.dart';
import '../models/vehicle.dart';
import '../models/app_notification.dart';
import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/offline_banner.dart';
import 'vehicle_registration_screen.dart';
import 'vehicle_detail_screen.dart';
import 'profile/profile_screen.dart';
import 'profile/settings_screen.dart';
import 'settings/privacy_policy_screen.dart';
import 'settings/terms_of_service_screen.dart';
import 'notifications/notification_list_screen.dart';
import '../core/di/service_locator.dart';
import '../services/mileage_notification_service.dart';
import 'marketplace/marketplace_screen.dart';
import 'marketplace/shop_list_screen.dart';
import 'marketplace/shop_owner_screen.dart';
import 'sns/sns_feed_screen.dart';
import 'drive/drive_log_screen.dart';
import 'add_maintenance_screen.dart';
import 'ai_chat/ai_chat_screen.dart';
import '../widgets/vehicle/mileage_reminder_banner.dart';
import '../widgets/vehicle/mileage_update_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  VehicleProvider? _vehicleProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() {
    final vehicleProvider =
        Provider.of<VehicleProvider>(context, listen: false);
    _vehicleProvider = vehicleProvider;
    vehicleProvider.listenToVehicles();
    vehicleProvider.addListener(_onVehiclesChanged);
  }

  void _onVehiclesChanged() {
    if (!mounted) return;
    final vehicleProvider =
        Provider.of<VehicleProvider>(context, listen: false);
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);

    if (vehicleProvider.vehicles.isNotEmpty) {
      notificationProvider
          .generateNotificationsForVehicles(vehicleProvider.vehicles);
    }
  }

  @override
  void dispose() {
    _vehicleProvider?.removeListener(_onVehiclesChanged);
    super.dispose();
  }

  // ---- AppBar タイトル（タブ連動） ----
  String get _appBarTitle {
    switch (_currentIndex) {
      case 0:
        return 'マイカー';
      case 1:
        return 'マーケットプレイス';
      case 2:
        return 'みんなの投稿';
      case 3:
        return '通知';
      case 4:
        return 'プロフィール';
      default:
        return 'マイカー';
    }
  }

  // ---- AppBar アクション（タブ連動） ----
  List<Widget> _buildAppBarActions() {
    final actions = <Widget>[];

    // オフラインアイコンは常に表示
    actions.add(
      Consumer<ConnectivityProvider>(
        builder: (context, connectivity, child) {
          if (connectivity.isOffline) {
            return const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.cloud_off,
                color: AppColors.warning,
                size: 20,
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );

    // AIチャットボタン（全タブ共通）
    actions.add(
      IconButton(
        icon: const Icon(Icons.smart_toy_outlined),
        tooltip: 'AIに聞く',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiChatScreen()),
          );
        },
      ),
    );

    // マーケットプレイスタブにオーナー掲載ボタンを表示
    if (_currentIndex == 1) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.storefront_outlined),
          tooltip: '店舗を掲載する',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShopOwnerScreen()),
            );
          },
        ),
      );
    }

    // 通知タブのみ「すべて既読」ボタンを表示
    if (_currentIndex == 3) {
      actions.add(
        Consumer<NotificationProvider>(
          builder: (context, provider, child) {
            if (provider.unreadCount > 0) {
              return TextButton(
                onPressed: () => provider.markAllAsRead(),
                child: const Text('すべて既読'),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      );
    }

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: _buildAppBarActions(),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
      // FABは車両タブのみ表示（SNSタブのFABはSnsFeedScreen内で管理）
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VehicleRegistrationScreen(),
                  ),
                );
              },
              tooltip: '車両を登録',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          final unread = notificationProvider.unreadCount;
          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.directions_car_outlined),
                selectedIcon: Icon(Icons.directions_car),
                label: 'マイカー',
              ),
              const NavigationDestination(
                icon: Icon(Icons.store_outlined),
                selectedIcon: Icon(Icons.store),
                label: 'マーケット',
              ),
              const NavigationDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum),
                label: 'みんなの投稿',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.notifications_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.notifications),
                ),
                label: '通知',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'プロフィール',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _VehicleTab(onNavigateToMarketplace: () {
          setState(() {
            _currentIndex = 1;
          });
        });
      case 1:
        return const MarketplaceScreen();
      case 2:
        return const SnsFeedScreen();
      case 3:
        return const NotificationListScreen();
      case 4:
        return const _ProfileTab();
      default:
        return _VehicleTab(onNavigateToMarketplace: () {
          setState(() {
            _currentIndex = 1;
          });
        });
    }
  }
}

// ---------------------------------------------------------------------------
// 車両タブ（マイカー一覧・ダッシュボード・AI提案）
// ---------------------------------------------------------------------------

class _VehicleTab extends StatelessWidget {
  final VoidCallback onNavigateToMarketplace;

  const _VehicleTab({required this.onNavigateToMarketplace});

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();

    if (vehicleProvider.isLoading) {
      return const AppLoadingCenter(message: '車両を読み込み中...');
    }

    if (vehicleProvider.error != null) {
      return AppErrorState(
        message: vehicleProvider.errorMessage ?? 'データを読み込めませんでした',
        onRetry: vehicleProvider.isRetryable
            ? () {
                vehicleProvider.clearError();
                vehicleProvider.listenToVehicles();
              }
            : null,
      );
    }

    if (vehicleProvider.vehicles.isEmpty) {
      return _VehicleEmptyOnboarding(
        onRegister: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VehicleRegistrationScreen(),
            ),
          );
        },
      );
    }

    final primaryVehicle = vehicleProvider.vehicles.first;

    return Column(
      children: [
        MileageReminderBanner(
          vehicle: primaryVehicle,
          onTapUpdate: () => MileageUpdateDialog.show(
            context,
            primaryVehicle,
            (newMileage) async {
              final updated = primaryVehicle.copyWith(
                mileage: newMileage,
                mileageUpdatedAt: DateTime.now(),
              );
              await context
                  .read<VehicleProvider>()
                  .updateVehicle(primaryVehicle.id, updated);
              // Schedule a 30-day reminder to update mileage again
              sl
                  .get<MileageNotificationService>()
                  .scheduleMonthlyReminder()
                  .catchError((_) {}); // fire-and-forget
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: AppSpacing.paddingScreen,
            itemCount: vehicleProvider.vehicles.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _DashboardSummaryCard(
                  vehicles: vehicleProvider.vehicles,
                );
              }
              if (index == 1) {
                return _AiSuggestionSection(onSeeAll: onNavigateToMarketplace);
              }
              final vehicle = vehicleProvider.vehicles[index - 2];
              return _VehicleCard(vehicle: vehicle);
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// プロフィールタブ
// ---------------------------------------------------------------------------

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().firebaseUser;
    final isPremium = context.watch<UserSubscriptionProvider>().isPremium;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ---- プロフィールヘッダー ----
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xl,
              horizontal: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [AppColors.darkCard, AppColors.darkSurface]
                    : [AppColors.primary, AppColors.primaryHover],
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: user?.photoURL != null
                      ? ClipOval(
                          child: Image.network(
                            user!.photoURL!,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 44,
                          color: Colors.white,
                        ),
                ),
                AppSpacing.verticalSm,
                Text(
                  user?.displayName ?? 'ユーザー',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSpacing.verticalXxs,
                Text(
                  user?.email ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                AppSpacing.verticalSm,
                // プランバッジ
                Chip(
                  avatar: Icon(
                    isPremium ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    isPremium ? 'プレミアム' : 'フリープラン',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          AppSpacing.verticalSm,

          // ---- アカウントセクション ----
          _buildMenuSection(
            context,
            title: 'アカウント',
            items: [
              _MenuItemData(
                icon: Icons.manage_accounts_outlined,
                label: 'プロフィールを編集',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
              _MenuItemData(
                icon: Icons.directions_car_outlined,
                label: 'ドライブログ',
                color: AppColors.accentDrive,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriveLogScreen()),
                ),
              ),
              _MenuItemData(
                icon: Icons.settings_outlined,
                label: '設定',
                color: AppColors.textSecondary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),

          AppSpacing.verticalSm,

          // ---- データセクション ----
          _buildMenuSection(
            context,
            title: 'データ',
            items: [
              _MenuItemData(
                icon: Icons.download_outlined,
                label: isPremium ? 'データをエクスポート' : 'データをエクスポート（プレミアム）',
                color: AppColors.primary,
                onTap: isPremium
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen()),
                        )
                    : () => _showUpgradeDialog(context),
              ),
            ],
          ),

          AppSpacing.verticalSm,

          // ---- サポートセクション ----
          _buildMenuSection(
            context,
            title: 'サポート・法的情報',
            items: [
              _MenuItemData(
                icon: Icons.privacy_tip_outlined,
                label: 'プライバシーポリシー',
                color: AppColors.info,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen()),
                ),
              ),
              _MenuItemData(
                icon: Icons.article_outlined,
                label: '利用規約',
                color: AppColors.info,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TermsOfServiceScreen()),
                ),
              ),
            ],
          ),

          AppSpacing.verticalSm,

          // ---- ログアウト ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: AppSpacing.borderRadiusSm,
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: AppColors.error,
                    size: AppSpacing.iconMd,
                  ),
                ),
                title: const Text(
                  'ログアウト',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () => _confirmSignOut(context),
              ),
            ),
          ),

          AppSpacing.verticalXxl,
        ],
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context, {
    required String title,
    required List<_MenuItemData> items,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.1),
                          borderRadius: AppSpacing.borderRadiusSm,
                        ),
                        child: Icon(
                          item.icon,
                          color: item.color,
                          size: AppSpacing.iconMd,
                        ),
                      ),
                      title: Text(
                        item.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        size: AppSpacing.iconMd,
                      ),
                      onTap: item.onTap,
                    ),
                    if (i < items.length - 1)
                      const Divider(height: 1, indent: 56),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('プレミアムプランが必要です'),
        content: const Text(
          'データのエクスポートはプレミアムプランの機能です。\n'
          'プレミアムプランにアップグレードしてご利用ください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final vehicleProvider = context.read<VehicleProvider>();
      final maintenanceProvider = context.read<MaintenanceProvider>();
      final notificationProvider = context.read<NotificationProvider>();
      final authProvider = context.read<AuthProvider>();

      vehicleProvider.clear();
      maintenanceProvider.clear();
      notificationProvider.clear();
      await authProvider.signOut();
      if (!context.mounted) return;
    }
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;

  const _VehicleCard({required this.vehicle});

  String _formatMileage(int mileage) {
    final formatter = NumberFormat('#,###');
    return formatter.format(mileage);
  }

  Color _statusAccentColor() {
    if (vehicle.isInspectionExpired ||
        (vehicle.daysUntilInsuranceExpiry != null &&
            vehicle.daysUntilInsuranceExpiry! < 0)) {
      return AppColors.error;
    }
    if (vehicle.isInspectionDueSoon || vehicle.isInsuranceDueSoon) {
      return AppColors.warning;
    }
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasInspectionWarning =
        vehicle.isInspectionExpired || vehicle.isInspectionDueSoon;
    final hasInsuranceWarning = vehicle.isInsuranceDueSoon ||
        (vehicle.daysUntilInsuranceExpiry != null &&
            vehicle.daysUntilInsuranceExpiry! < 0);

    final suggestionCount = context
        .watch<NotificationProvider>()
        .getNotificationsForVehicle(vehicle.id)
        .where((n) =>
            n.type != NotificationType.system &&
            (n.priority == NotificationPriority.high ||
                n.priority == NotificationPriority.medium))
        .length;

    final accentColor = _statusAccentColor();

    return Card(
      margin: AppSpacing.marginListItem,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Provider.of<VehicleProvider>(context, listen: false)
              .selectVehicle(vehicle);
          Provider.of<MaintenanceProvider>(context, listen: false)
              .listenToMaintenanceRecords(vehicle.id);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VehicleDetailScreen(vehicle: vehicle),
            ),
          );
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left status accent bar (green=ok / orange=warning / red=expired)
              Container(width: 4, color: accentColor),
              Expanded(
                child: Padding(
                  padding: AppSpacing.paddingCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 車両画像
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : AppColors.backgroundLight,
                              borderRadius: AppSpacing.borderRadiusSm,
                            ),
                            child: vehicle.imageUrl != null &&
                                    vehicle.imageUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: AppSpacing.borderRadiusSm,
                                    child: Image.network(
                                      vehicle.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _buildPlaceholder(isDark),
                                    ),
                                  )
                                : _buildPlaceholder(isDark),
                          ),
                          AppSpacing.horizontalMd,
                          // 車両情報
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${vehicle.maker} ${vehicle.model}',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                AppSpacing.verticalXxs,
                                Text(
                                  '${vehicle.year}年式 ${vehicle.grade}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                AppSpacing.verticalXxs,
                                // 走行距離 + 燃料タイプ
                                Row(
                                  children: [
                                    Icon(
                                      Icons.speed,
                                      size: AppSpacing.iconSm,
                                      color: isDark
                                          ? AppColors.darkTextTertiary
                                          : AppColors.textTertiary,
                                    ),
                                    AppSpacing.horizontalXs,
                                    Text(
                                      '${_formatMileage(vehicle.mileage)} km',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (vehicle.fuelType != null) ...[
                                      AppSpacing.horizontalSm,
                                      _InfoChip(
                                        label: vehicle.fuelType!.displayName,
                                        color: AppColors.secondary,
                                        isDark: isDark,
                                      ),
                                    ],
                                  ],
                                ),
                                AppSpacing.verticalXxs,
                                // ナンバープレート + 車検残日数
                                Row(
                                  children: [
                                    if (vehicle.licensePlate != null &&
                                        vehicle.licensePlate!.isNotEmpty) ...[
                                      Icon(
                                        Icons.credit_card_outlined,
                                        size: 13,
                                        color: isDark
                                            ? AppColors.darkTextTertiary
                                            : AppColors.textTertiary,
                                      ),
                                      AppSpacing.horizontalXs,
                                      Flexible(
                                        child: Text(
                                          vehicle.licensePlate!,
                                          style: theme.textTheme.bodySmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      AppSpacing.horizontalSm,
                                    ],
                                    if (vehicle.daysUntilInspection != null &&
                                        !vehicle.isInspectionExpired) ...[
                                      Icon(
                                        Icons.verified_outlined,
                                        size: 13,
                                        color: vehicle.isInspectionDueSoon
                                            ? AppColors.warning
                                            : (isDark
                                                ? AppColors.darkTextTertiary
                                                : AppColors.textTertiary),
                                      ),
                                      AppSpacing.horizontalXs,
                                      Text(
                                        '車検 残${vehicle.daysUntilInspection}日',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: vehicle.isInspectionDueSoon
                                              ? AppColors.warning
                                              : null,
                                          fontWeight:
                                              vehicle.isInspectionDueSoon
                                                  ? FontWeight.w600
                                                  : null,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // 提案バッジ + シェブロン
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.chevron_right,
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.textTertiary,
                              ),
                              if (suggestionCount > 0) ...[
                                AppSpacing.verticalXxs,
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.12),
                                    borderRadius: AppSpacing.borderRadiusXs,
                                    border: Border.all(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    '提案 $suggestionCount件',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      // 車検・保険警告バナー
                      if (hasInspectionWarning || hasInsuranceWarning) ...[
                        AppSpacing.verticalSm,
                        _buildWarningBanner(context, theme),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningBanner(BuildContext context, ThemeData theme) {
    final warnings = <Widget>[];

    if (vehicle.isInspectionExpired) {
      warnings.add(_buildWarningChip(
        context,
        icon: Icons.error,
        label: '車検切れ',
        color: AppColors.error,
      ));
    } else if (vehicle.isInspectionDueSoon) {
      final days = vehicle.daysUntilInspection!;
      warnings.add(_buildWarningChip(
        context,
        icon: Icons.warning_amber,
        label: '車検 残り$days日',
        color: days <= 7 ? AppColors.error : AppColors.warning,
      ));
    }

    final insuranceDays = vehicle.daysUntilInsuranceExpiry;
    if (insuranceDays != null && insuranceDays < 0) {
      warnings.add(_buildWarningChip(
        context,
        icon: Icons.error,
        label: '自賠責切れ',
        color: AppColors.error,
      ));
    } else if (vehicle.isInsuranceDueSoon) {
      warnings.add(_buildWarningChip(
        context,
        icon: Icons.shield,
        label: '保険 残り$insuranceDays日',
        color: insuranceDays! <= 7 ? AppColors.error : AppColors.warning,
      ));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: warnings,
    );
  }

  Widget _buildWarningChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusXs,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          AppSpacing.horizontalXxs,
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Center(
      child: Icon(
        Icons.directions_car,
        size: AppSpacing.iconLg,
        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 車両未登録時オンボーディングガイド
// ---------------------------------------------------------------------------

class _VehicleEmptyOnboarding extends StatelessWidget {
  final VoidCallback onRegister;

  const _VehicleEmptyOnboarding({required this.onRegister});

  static const _features = [
    (
      icon: Icons.history,
      title: '整備履歴を正確に記録',
      description: '修理・点検・消耗品交換を時系列で管理できます',
      color: AppColors.primary,
    ),
    (
      icon: Icons.notifications_active,
      title: 'AIが次の点検をお知らせ',
      description: '走行距離と履歴から最適なタイミングを自動分析',
      color: AppColors.info,
    ),
    (
      icon: Icons.handshake,
      title: '信頼できる整備工場と繋がる',
      description: 'AI提案から評価の高い工場へ簡単にアクセス',
      color: AppColors.success,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.paddingScreen,
      child: Column(
        children: [
          AppSpacing.verticalXl,
          // Hero icon — decorative, excluded from semantics tree
          ExcludeSemantics(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_car,
                size: 52,
                color: AppColors.primary,
              ),
            ),
          ),
          AppSpacing.verticalMd,
          Semantics(
            header: true,
            child: Text(
              'まず愛車を登録しよう',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color:
                    isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          AppSpacing.verticalSm,
          Text(
            '登録するだけで、AIがあなたの愛車に\n合ったお役立ち情報をお知らせします',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.verticalXl,
          // Feature list
          ...(_features.map((f) => _FeatureRow(
                icon: f.icon,
                title: f.title,
                description: f.description,
                accentColor: f.color,
              ))),
          AppSpacing.verticalXl,
          // CTA button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRegister,
              icon: const Icon(Icons.add),
              label: const Text('車両を登録する'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          AppSpacing.verticalLg,
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Feature icon — decorative; text title/description carry the meaning
          ExcludeSemantics(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: AppSpacing.borderRadiusMd,
              ),
              child: Icon(icon, size: 22, color: accentColor),
            ),
          ),
          AppSpacing.horizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AIからの提案セクション（ホーム画面トップ）
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// ダッシュボードサマリーカード（マイカータブ最上部）
// ---------------------------------------------------------------------------

class _DashboardSummaryCard extends StatelessWidget {
  final List<Vehicle> vehicles;

  const _DashboardSummaryCard({required this.vehicles});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 警告のある車両を集計
    final expiredCount = vehicles
        .where((v) =>
            v.isInspectionExpired ||
            (v.daysUntilInsuranceExpiry != null &&
                v.daysUntilInsuranceExpiry! < 0))
        .length;
    final warnCount = vehicles
        .where((v) =>
            (v.isInspectionDueSoon && !v.isInspectionExpired) ||
            (v.isInsuranceDueSoon &&
                v.daysUntilInsuranceExpiry != null &&
                v.daysUntilInsuranceExpiry! >= 0))
        .length;

    // 最も近い車検日を持つ車両
    Vehicle? nextInspectionVehicle;
    int? minDays;
    for (final v in vehicles) {
      if (v.daysUntilInspection != null && v.daysUntilInspection! > 0) {
        if (minDays == null || v.daysUntilInspection! < minDays) {
          minDays = v.daysUntilInspection;
          nextInspectionVehicle = v;
        }
      }
    }

    return Container(
      margin: AppSpacing.marginListItem,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.darkCard, AppColors.darkSurface]
              : [AppColors.primary, AppColors.primaryHover],
        ),
        borderRadius: AppSpacing.borderRadiusMd,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- タイトル ----
          Row(
            children: [
              const Icon(Icons.dashboard_outlined,
                  size: AppSpacing.iconSm, color: Colors.white70),
              AppSpacing.horizontalXs,
              Text(
                'ダッシュボード',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          AppSpacing.verticalSm,

          // ---- 統計行 ----
          Row(
            children: [
              _buildStatItem(
                context,
                icon: Icons.directions_car,
                value: '${vehicles.length}',
                label: '登録車両',
                iconColor: Colors.white,
              ),
              _buildDivider(),
              _buildStatItem(
                context,
                icon: Icons.error_outline,
                value: '$expiredCount',
                label: '要対応',
                iconColor: expiredCount > 0
                    ? AppColors.error.withValues(alpha: 0.9)
                    : Colors.white54,
              ),
              _buildDivider(),
              _buildStatItem(
                context,
                icon: Icons.warning_amber_outlined,
                value: '$warnCount',
                label: '注意',
                iconColor: warnCount > 0 ? AppColors.warning : Colors.white54,
              ),
            ],
          ),

          // ---- 次回車検 ----
          if (nextInspectionVehicle != null) ...[
            AppSpacing.verticalSm,
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: AppSpacing.borderRadiusSm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_outlined,
                      size: 14, color: Colors.white70),
                  AppSpacing.horizontalXs,
                  Text(
                    '次の車検: '
                    '${nextInspectionVehicle.maker} '
                    '${nextInspectionVehicle.model} '
                    '— あと$minDays日',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          AppSpacing.verticalXxs,
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 48,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }
}

// ---------------------------------------------------------------------------

class _AiSuggestionSection extends StatelessWidget {
  final VoidCallback onSeeAll;

  const _AiSuggestionSection({required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final suggestions = notificationProvider.topSuggestions;

        // 提案がなければセクション自体を非表示
        if (suggestions.isEmpty) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- ヘッダー ----
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: theme.colorScheme.primary,
                        ),
                        AppSpacing.horizontalXs,
                        Text(
                          'AIからの提案',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onSeeAll,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'すべて見る',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ---- 横スクロールカード ----
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => AppSpacing.horizontalSm,
                itemBuilder: (context, index) {
                  final n = suggestions[index];
                  return _SuggestionCard(
                    notification: n,
                    isDark: isDark,
                    onTap: n.vehicleId != null
                        ? () {
                            final vehicles =
                                context.read<VehicleProvider>().vehicles;
                            final vehicle =
                                vehicles.cast<Vehicle?>().firstWhere(
                                      (v) => v?.id == n.vehicleId,
                                      orElse: () => null,
                                    );
                            if (vehicle == null || !context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddMaintenanceScreen(
                                  vehicleId: vehicle.id,
                                  currentVehicleMileage: vehicle.mileage,
                                ),
                              ),
                            );
                          }
                        : null,
                  );
                },
              ),
            ),

            AppSpacing.verticalMd,
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 個別の提案カード
// ---------------------------------------------------------------------------

class _SuggestionCard extends StatefulWidget {
  final AppNotification notification;
  final bool isDark;
  final VoidCallback? onTap;

  const _SuggestionCard({
    required this.notification,
    required this.isDark,
    this.onTap,
  });

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  Color get _priorityColor {
    switch (widget.notification.priority) {
      case NotificationPriority.high:
        return AppColors.error;
      case NotificationPriority.medium:
        return AppColors.warning;
      case NotificationPriority.low:
        return AppColors.info;
    }
  }

  IconData get _typeIcon {
    switch (widget.notification.type) {
      case NotificationType.inspectionReminder:
        return Icons.verified_outlined;
      case NotificationType.partsReplacement:
        return Icons.build_outlined;
      case NotificationType.maintenanceRecommendation:
        return Icons.directions_car_outlined;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  void _openDetailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SuggestionDetailSheet(
        notification: widget.notification,
        isDark: widget.isDark,
        onAddRecord: widget.onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _priorityColor;
    final n = widget.notification;

    return GestureDetector(
      onTap: () => _openDetailSheet(context),
      child: SizedBox(
        width: 210,
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMd,
            side: BorderSide(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colored top accent strip
              Container(height: 3, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---- アイコン + 優先度バッジ ----
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Icon(_typeIcon, size: 15, color: color),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              n.priority == NotificationPriority.high
                                  ? '要対応'
                                  : '推奨',
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.verticalXs,
                      // ---- タイトル ----
                      Text(
                        n.title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AppSpacing.verticalXxs,
                      // ---- メッセージ ----
                      Expanded(
                        child: Text(
                          n.message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: widget.isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.textTertiary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // ---- 「理由を見る」ヒント ----
                      AppSpacing.verticalXxs,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'タップで詳細',
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 13, color: color),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 提案詳細ボトムシート（理由全文 + アクション選択）
// ---------------------------------------------------------------------------

class _SuggestionDetailSheet extends StatelessWidget {
  final AppNotification notification;
  final bool isDark;
  final VoidCallback? onAddRecord;

  const _SuggestionDetailSheet({
    required this.notification,
    required this.isDark,
    this.onAddRecord,
  });

  Color _priorityColor(BuildContext context) {
    switch (notification.priority) {
      case NotificationPriority.high:
        return AppColors.error;
      case NotificationPriority.medium:
        return AppColors.warning;
      case NotificationPriority.low:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _priorityColor(context);
    final n = notification;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: ListView(
          controller: scrollController,
          children: [
            // ---- ドラッグハンドル ----
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ---- 優先度バッジ + タイトル ----
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    n.priority == NotificationPriority.high ? '要対応' : '推奨',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              n.title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ---- 理由セクション ----
            if (n.reason != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 15, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'なぜ今なのか',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      n.reason!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.7,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ] else ...[
              Text(
                n.message,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // ---- 注意文 ----
            Text(
              'あなたが決めるための情報を整理しました。最終的な判断はあなた自身でお決めください。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ---- アクション: 整備記録を追加 ----
            if (onAddRecord != null)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onAddRecord!();
                },
                icon: const Icon(Icons.add),
                label: const Text('整備記録を追加する'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),

            const SizedBox(height: AppSpacing.sm),

            // ---- アクション: 整備工場を探す ----
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShopListScreen(
                      maintenanceContext:
                          n.metadata?['ruleName'] as String? ?? n.title,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.store_outlined),
              label: const Text('近くの整備工場を探す'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// プロフィールメニュー項目データクラス
// ---------------------------------------------------------------------------

class _MenuItemData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuItemData({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// ---------------------------------------------------------------------------
// 小型インフォチップ（車両カード内）
// ---------------------------------------------------------------------------

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _InfoChip({
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
