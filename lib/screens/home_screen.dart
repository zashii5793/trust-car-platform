import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/vehicle_provider.dart';
import '../providers/maintenance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/connectivity_provider.dart';
import '../models/vehicle.dart';
import '../models/app_notification.dart';
import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/offline_banner.dart';
import 'vehicle_registration_screen.dart';
import 'vehicle_detail_screen.dart';
import 'profile/profile_screen.dart';
import 'profile/settings_screen.dart';
import 'settings/privacy_policy_screen.dart';
import 'settings/terms_of_service_screen.dart';
import 'notifications/notification_list_screen.dart';
import 'marketplace/marketplace_screen.dart';
import 'sns/sns_feed_screen.dart';
import 'drive/drive_log_screen.dart';

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
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    _vehicleProvider = vehicleProvider;
    vehicleProvider.listenToVehicles();
    vehicleProvider.addListener(_onVehiclesChanged);
  }

  void _onVehiclesChanged() {
    if (!mounted) return;
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
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
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.directions_car),
                label: 'マイカー',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.store_outlined),
                label: 'マーケット',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.forum_outlined),
                label: 'みんなの投稿',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: notificationProvider.unreadCount > 0,
                  label: Text(
                    notificationProvider.unreadCount > 99
                        ? '99+'
                        : notificationProvider.unreadCount.toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.notifications_outlined),
                ),
                label: '通知',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
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
        return _buildVehicleList();
      case 1:
        return const MarketplaceScreen();
      case 2:
        return const SnsFeedScreen();
      case 3:
        return const NotificationListScreen();
      case 4:
        return _buildProfileTab();
      default:
        return _buildVehicleList();
    }
  }

  Widget _buildVehicleList() {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, child) {
        if (vehicleProvider.isLoading) {
          return const AppLoadingCenter(message: '車両を読み込み中...');
        }

        if (vehicleProvider.error != null) {
          return AppErrorState(
            message: vehicleProvider.errorMessage ?? 'エラーが発生しました',
            onRetry: vehicleProvider.isRetryable
                ? () {
                    vehicleProvider.clearError();
                    vehicleProvider.listenToVehicles();
                  }
                : null,
          );
        }

        if (vehicleProvider.vehicles.isEmpty) {
          return AppEmptyState(
            icon: Icons.directions_car,
            title: '車両が登録されていません',
            description: '愛車を登録して、メンテナンス管理を始めましょう',
            buttonLabel: '車両を登録',
            onButtonPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VehicleRegistrationScreen(),
                ),
              );
            },
          );
        }

        return ListView.builder(
          padding: AppSpacing.paddingScreen,
          itemCount: vehicleProvider.vehicles.length + 2, // +2 for dashboard + suggestion
          itemBuilder: (context, index) {
            if (index == 0) {
              return _DashboardSummaryCard(
                vehicles: vehicleProvider.vehicles,
              );
            }
            if (index == 1) {
              return _AiSuggestionSection(
                onSeeAll: () => setState(() => _currentIndex = 1),
              );
            }
            final vehicle = vehicleProvider.vehicles[index - 2];
            return _VehicleCard(vehicle: vehicle);
          },
        );
      },
    );
  }

  Widget _buildProfileTab() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.firebaseUser;
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
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                ),
              ),
              _MenuItemData(
                icon: Icons.article_outlined,
                label: '利用規約',
                color: AppColors.info,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
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
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasInspectionWarning =
        vehicle.isInspectionExpired || vehicle.isInspectionDueSoon;
    final hasInsuranceWarning = vehicle.isInsuranceDueSoon ||
        (vehicle.daysUntilInsuranceExpiry != null &&
            vehicle.daysUntilInsuranceExpiry! < 0);

    return AppCard(
      margin: AppSpacing.marginListItem,
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
      child: Column(
        children: [
          Row(
            children: [
              // 車両画像
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.backgroundLight,
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                child: vehicle.imageUrl != null && vehicle.imageUrl!.isNotEmpty
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
                      style: theme.textTheme.headlineMedium,
                    ),
                    AppSpacing.verticalXxs,
                    Text(
                      '${vehicle.year}年式 ${vehicle.grade}',
                      style: theme.textTheme.bodyMedium,
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
                          style: theme.textTheme.bodyMedium,
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
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: vehicle.isInspectionDueSoon
                                  ? AppColors.warning
                                  : null,
                              fontWeight: vehicle.isInspectionDueSoon
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
              Icon(
                Icons.chevron_right,
                color:
                    isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
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
        .where((v) => v.isInspectionExpired ||
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
              : [AppColors.primary, const Color(0xFF2563B8)],
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
                    ? const Color(0xFFFF8A80)
                    : Colors.white54,
              ),
              _buildDivider(),
              _buildStatItem(
                context,
                icon: Icons.warning_amber_outlined,
                value: '$warnCount',
                label: '注意',
                iconColor: warnCount > 0
                    ? const Color(0xFFFFD740)
                    : Colors.white54,
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
                  Icon(
                    Icons.lightbulb_outline,
                    size: AppSpacing.iconSm,
                    color: theme.colorScheme.primary,
                  ),
                  AppSpacing.horizontalXs,
                  Text(
                    'メンテナンスの提案',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
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
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => AppSpacing.horizontalSm,
                itemBuilder: (context, index) {
                  return _SuggestionCard(
                    notification: suggestions[index],
                    isDark: isDark,
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

class _SuggestionCard extends StatelessWidget {
  final AppNotification notification;
  final bool isDark;

  const _SuggestionCard({
    required this.notification,
    required this.isDark,
  });

  Color get _priorityColor {
    switch (notification.priority) {
      case NotificationPriority.high:
        return AppColors.error;
      case NotificationPriority.medium:
        return AppColors.warning;
      case NotificationPriority.low:
        return AppColors.info;
    }
  }

  IconData get _typeIcon {
    switch (notification.type) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _priorityColor;

    return Container(
      width: 200,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(
          color: color.withValues(alpha: 0.4),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  notification.priority == NotificationPriority.high ? '要対応' : '推奨',
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
            notification.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          AppSpacing.verticalXxs,

          // ---- メッセージ（理由）----
          Expanded(
            child: Text(
              notification.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.textTertiary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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

