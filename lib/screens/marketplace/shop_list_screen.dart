import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/shop.dart';
import '../../providers/shop_provider.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/loading_indicator.dart';
import 'shop_detail_screen.dart';

/// BtoBマーケットプレイス 工場一覧画面
///
/// 設計思想:
/// - ユーザーが工場を探す（工場からの売り込みは排除）
/// - FABなし・業者起点のアクションなし
/// - isFeatured は「広告」ラベルで明示（ソート優先度を隠さない）
class ShopListScreen extends StatefulWidget {
  const ShopListScreen({super.key});

  @override
  State<ShopListScreen> createState() => _ShopListScreenState();
}

class _ShopListScreenState extends State<ShopListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShopProvider>().loadShops();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<ShopProvider>().searchShops(query);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('マーケットプレイス'),
            actions: [
              if (!provider.isLoading)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '再読み込み',
                  onPressed: () {
                    _searchController.clear();
                    provider.loadShops();
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              _SearchBar(
                controller: _searchController,
                onChanged: _onSearchChanged,
              ),
              _FilterBar(provider: provider),
              Expanded(child: _buildBody(provider)),
            ],
          ),
          // FABなし: 業者への能動的なアクションは「問い合わせる」のみ
        );
      },
    );
  }

  Widget _buildBody(ShopProvider provider) {
    if (provider.isLoading) {
      return const AppLoadingCenter(message: '工場を検索中...');
    }

    if (provider.error != null) {
      return AppErrorState(
        message: provider.error!.userMessage,
        onRetry: provider.loadShops,
      );
    }

    if (provider.shops.isEmpty) {
      return AppEmptyState(
        icon: Icons.store_mall_directory_outlined,
        title: '工場が見つかりません',
        description: 'フィルタや検索条件を変えてお試しください',
        buttonLabel: 'フィルタをリセット',
        onButtonPressed: provider.clearFilters,
      );
    }

    return ListView.builder(
      padding: AppSpacing.paddingScreen,
      itemCount: provider.shops.length,
      itemBuilder: (context, index) {
        final shop = provider.shops[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _ShopCard(
            shop: shop,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopDetailScreen(shopId: shop.id),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 検索バー
// ---------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: '工場名で検索',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: AppSpacing.borderRadiusMd,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// フィルタバー
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  final ShopProvider provider;

  const _FilterBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        children: [
          // 全てリセット
          if (provider.selectedType != null ||
              provider.selectedService != null ||
              provider.selectedPrefecture != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ActionChip(
                label: const Text('リセット'),
                avatar: const Icon(Icons.clear, size: 16),
                onPressed: provider.clearFilters,
              ),
            ),

          // 業種フィルタ
          ...ShopType.values.map((type) {
            final isSelected = provider.selectedType == type;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: FilterChip(
                label: Text(type.displayName),
                selected: isSelected,
                onSelected: (_) => provider.selectType(isSelected ? null : type),
              ),
            );
          }),

          const SizedBox(width: AppSpacing.sm),

          // サービスフィルタ（主要なもののみ）
          ...const [
            ServiceCategory.inspection,
            ServiceCategory.maintenance,
            ServiceCategory.repair,
            ServiceCategory.tire,
          ].map((service) {
            final isSelected = provider.selectedService == service;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: FilterChip(
                label: Text(service.displayName),
                selected: isSelected,
                onSelected: (_) =>
                    provider.selectService(isSelected ? null : service),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 工場カード
// ---------------------------------------------------------------------------

class _ShopCard extends StatelessWidget {
  final Shop shop;
  final VoidCallback onTap;

  const _ShopCard({required this.shop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: Padding(
          padding: AppSpacing.paddingCard,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ロゴ/アバター
              CircleAvatar(
                radius: 28,
                backgroundImage: shop.logoUrl != null
                    ? NetworkImage(shop.logoUrl!)
                    : null,
                child: shop.logoUrl == null
                    ? const Icon(Icons.store, size: 28)
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              // 情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            shop.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 認証バッジ
                        if (shop.isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: AppSpacing.xs),
                            child: Icon(
                              Icons.verified,
                              size: 18,
                              color: Colors.blue,
                            ),
                          ),
                        // 広告ラベル（isFeaturedの場合）
                        if (shop.isFeatured && !shop.isVerified)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.xs),
                            child: Chip(
                              label: const Text('広告'),
                              labelStyle: const TextStyle(fontSize: 10),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // 業種
                    Text(
                      shop.type.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    // サービス
                    if (shop.services.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        shop.services.take(2).map((s) => s.displayName).join(' · '),
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        // 評価
                        if (shop.rating != null) ...[
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            shop.rating!.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        // 営業中バッジ
                        if (shop.isOpenNow)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '営業中',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
