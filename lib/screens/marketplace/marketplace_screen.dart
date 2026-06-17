import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import 'shop_list_screen.dart';
import 'part_list_screen.dart';
import 'my_inquiries_screen.dart';

/// マーケットプレイス トップ画面
///
/// 工場一覧 / パーツ一覧 / 問い合わせ の3タブ構成。
/// HomeScreen の BottomNavigationBar 経由でアクセスする。
///
/// 注: ユーザー同士の C2C「マイ出品」タブは廃止した。
/// コンセプト（「信頼を設計する」企画書）では、パーツは AI が提携 EC の
/// 商品を理由付きでレコメンドする B2C/アフィリエイトモデルであり、
/// 個人間売買はスコープ外。出品関連の画面・モデルは残置しているが
/// 導線からは外し、誤用を防ぐ。
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
                Tab(icon: Icon(Icons.inbox_outlined), text: '問い合わせ'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                ShopListScreen(),
                PartListScreen(),
                MyInquiriesScreen(),
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
