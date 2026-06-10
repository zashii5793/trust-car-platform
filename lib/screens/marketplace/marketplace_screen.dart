import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import 'shop_list_screen.dart';
import 'part_list_screen.dart';
import 'my_listings_screen.dart';

/// マーケットプレイス トップ画面
///
/// 工場一覧 / パーツ一覧 / マイ出品の3タブ構成。
/// HomeScreen の BottomNavigationBar 経由でアクセスする。
class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // 選択車両コンテキストバナー
          const _VehicleContextBanner(),
          // タブバー（Scaffold の appBar には入らないため Column で管理）
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.store_outlined), text: '工場・業者'),
                Tab(icon: Icon(Icons.build_outlined), text: 'パーツ'),
                Tab(icon: Icon(Icons.sell_outlined), text: 'マイ出品'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                ShopListScreen(),
                PartListScreen(),
                MyListingsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 選択中の車両を表示するコンテキストバナー
// ---------------------------------------------------------------------------

class _VehicleContextBanner extends StatelessWidget {
  const _VehicleContextBanner();

  @override
  Widget build(BuildContext context) {
    final vehicle = context.watch<VehicleProvider>().selectedVehicle;
    if (vehicle == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? AppColors.darkCard
          : AppColors.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_car,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            AppSpacing.horizontalSm,
            Expanded(
              child: Text(
                '${vehicle.maker} ${vehicle.model} (${vehicle.year}年) の情報を表示中',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      isDark ? AppColors.darkTextSecondary : AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
