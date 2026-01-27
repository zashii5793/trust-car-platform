import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/vehicle_provider.dart';
import '../providers/maintenance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../models/vehicle.dart';
import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/loading_indicator.dart';
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
      Provider.of<VehicleProvider>(context, listen: false).listenToVehicles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マイカー'),
        actions: [
          // プロフィールアイコン
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
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
      ),
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
        return _buildNotificationPlaceholder();
      case 2:
        return _buildProfilePlaceholder();
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
            message: vehicleProvider.error!,
            onRetry: () {
              vehicleProvider.listenToVehicles();
            },
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
          itemCount: vehicleProvider.vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicleProvider.vehicles[index];
            return _VehicleCard(vehicle: vehicle);
          },
        );
      },
    );
  }

  Widget _buildNotificationPlaceholder() {
    return const NotificationListScreen();
  }

  Widget _buildProfilePlaceholder() {
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
          AppSpacing.verticalXxl,
          // ログアウトボタン
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await authProvider.signOut();
              },
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
      child: Row(
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
                      errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
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
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
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
