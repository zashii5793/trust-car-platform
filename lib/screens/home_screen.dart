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
import 'notifications/notification_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() {
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
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
    final vehicleProvider = Provider.of<VehicleProvider>(context, listen: false);
    vehicleProvider.removeListener(_onVehiclesChanged);
    super.dispose();
  }

  // ---- AppBar タイトル（タブ連動） ----
  String get _appBarTitle {
    switch (_currentIndex) {
      case 0:
        return 'マイカー';
      case 1:
        return '通知';
      case 2:
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
    if (_currentIndex == 1) {
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
      // FABは車両タブのみ表示
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
        return const NotificationListScreen();
      case 2:
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
          itemCount: vehicleProvider.vehicles.length + 1, // +1 for suggestion header
          itemBuilder: (context, index) {
            if (index == 0) {
              return _AiSuggestionSection(
                onSeeAll: () => setState(() => _currentIndex = 1),
              );
            }
            final vehicle = vehicleProvider.vehicles[index - 1];
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

    return SingleChildScrollView(
      padding: AppSpacing.paddingScreen,
      child: Column(
        children: [
          AppSpacing.verticalLg,
          // プロフィール画像
          CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.primary,
            child: user?.photoURL != null
                ? ClipOval(
                    child: Image.network(
                      user!.photoURL!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  ),
          ),
          AppSpacing.verticalMd,
          Text(
            user?.displayName ?? 'ユーザー',
            style: theme.textTheme.headlineMedium,
          ),
          AppSpacing.verticalXs,
          Text(
            user?.email ?? '',
            style: theme.textTheme.bodyMedium,
          ),
          AppSpacing.verticalLg,
          // プロフィール詳細ボタン
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('プロフィールを編集'),
            ),
          ),
          AppSpacing.verticalXxl,
          // ログアウトボタン
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout),
              label: const Text('ログアウト'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
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
                      '${vehicle.year}年 ${vehicle.grade}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    AppSpacing.verticalXxs,
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
