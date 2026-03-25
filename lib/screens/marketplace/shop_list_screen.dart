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
                    provider.clearFilters();
                    provider.loadShops();
                  },
                ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchBar(
                controller: _searchController,
                onChanged: _onSearchChanged,
              ),
              _FilterRow(provider: provider),
              if (!provider.isLoading && provider.shops.isNotEmpty)
                _ResultCount(count: provider.shops.length),
              Expanded(child: _buildBody(provider)),
            ],
          ),
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
          hintText: '工場名・サービスで検索',
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
          filled: true,
          border: OutlineInputBorder(
            borderRadius: AppSpacing.borderRadiusMd,
            borderSide: BorderSide.none,
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
// フィルタ行（3つのDropdownChip）
// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  final ShopProvider provider;

  const _FilterRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasFilter = provider.selectedType != null ||
        provider.selectedService != null ||
        provider.selectedPrefecture != null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          _FilterDropdownChip<ShopType>(
            label: '業種',
            selected: provider.selectedType,
            displayName: (t) => t.displayName,
            options: ShopType.values,
            onSelected: provider.selectType,
          ),
          const SizedBox(width: AppSpacing.xs),
          _FilterDropdownChip<ServiceCategory>(
            label: 'サービス',
            selected: provider.selectedService,
            displayName: (s) => s.displayName,
            options: ServiceCategory.values,
            onSelected: provider.selectService,
          ),
          const SizedBox(width: AppSpacing.xs),
          _FilterDropdownChip<String>(
            label: '地域',
            selected: provider.selectedPrefecture,
            displayName: (p) => p,
            options: _prefectures,
            onSelected: provider.selectPrefecture,
          ),
          if (hasFilter) ...[
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.clear, size: 14),
              label: const Text('リセット', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              ),
              onPressed: provider.clearFilters,
            ),
          ],
        ],
      ),
    );
  }
}

/// DropdownChip: タップするとボトムシートでオプションを選択できる
class _FilterDropdownChip<T> extends StatelessWidget {
  final String label;
  final T? selected;
  final String Function(T) displayName;
  final List<T> options;
  final void Function(T?) onSelected;

  const _FilterDropdownChip({
    required this.label,
    required this.selected,
    required this.displayName,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = selected != null;

    return GestureDetector(
      onTap: () => _showBottomSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive ? displayName(selected as T) : label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isActive
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.bold : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: isActive
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.lg)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text(
                '$labelを選択',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            if (selected != null)
              ListTile(
                leading: const Icon(Icons.clear),
                title: Text('$labelフィルタをクリア'),
                onTap: () {
                  onSelected(null);
                  Navigator.pop(ctx);
                },
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options.map((option) {
                  final isCurrent = option == selected;
                  return ListTile(
                    leading: isCurrent
                        ? Icon(
                            Icons.check,
                            color: Theme.of(ctx).colorScheme.primary,
                          )
                        : const SizedBox(width: 24),
                    title: Text(displayName(option)),
                    onTap: () {
                      onSelected(option);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + AppSpacing.sm),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 件数表示
// ---------------------------------------------------------------------------

class _ResultCount extends StatelessWidget {
  final int count;

  const _ResultCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        '$count件の工場',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 都道府県リスト
// ---------------------------------------------------------------------------

const _prefectures = [
  '北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県',
  '茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県',
  '新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県',
  '岐阜県', '静岡県', '愛知県', '三重県',
  '滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県',
  '鳥取県', '島根県', '岡山県', '広島県', '山口県',
  '徳島県', '香川県', '愛媛県', '高知県',
  '福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県',
];

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
    final todayHours = shop.getTodayHours();

    return Card(
      elevation: 1,
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
                    // 店名 + バッジ
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
                        if (shop.isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: AppSpacing.xs),
                            child: Icon(
                              Icons.verified,
                              size: 16,
                              color: Colors.blue,
                            ),
                          ),
                        if (shop.isFeatured && !shop.isVerified)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.xs),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '広告',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // 業種 + 都道府県
                    Text(
                      [
                        shop.type.displayName,
                        if (shop.prefecture != null) shop.prefecture!,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    // サービス
                    if (shop.services.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        shop.services
                            .take(3)
                            .map((s) => s.displayName)
                            .join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    // 評価 + 営業状況
                    Row(
                      children: [
                        if (shop.rating != null) ...[
                          const Icon(Icons.star_rounded,
                              size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            shop.rating!.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (shop.reviewCount > 0) ...[
                            const SizedBox(width: 2),
                            Text(
                              '(${shop.reviewCount}件)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        // 今日の営業時間
                        if (todayHours != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: shop.isOpenNow
                                  ? Colors.green.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              shop.isOpenNow
                                  ? '営業中 〜${todayHours.closeTime ?? ''}'
                                  : (todayHours.isClosed
                                      ? '本日定休'
                                      : '本日${todayHours.openTime ?? ''}〜'),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: shop.isOpenNow
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

