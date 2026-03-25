import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/part_listing.dart';
import '../../models/vehicle.dart';
import '../../providers/part_recommendation_provider.dart';
import 'part_detail_screen.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/loading_indicator.dart';

/// パーツ一覧画面（マーケットプレイス）
///
/// 設計思想:
/// - 車両指定なし: おすすめパーツ + カテゴリ絞り込み
/// - 車両指定あり: 互換性バッジを追加表示（「自分の車に合う」を視覚化）
/// - 価格・評価は常にフラットに表示（ランキングで誘導しない）
class PartListScreen extends StatefulWidget {
  /// 互換性表示に使う車両（省略可）
  final Vehicle? vehicle;

  const PartListScreen({super.key, this.vehicle});

  @override
  State<PartListScreen> createState() => _PartListScreenState();
}

class _PartListScreenState extends State<PartListScreen> {
  final _searchController = TextEditingController();
  PartCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  void _load({PartCategory? category, String? query}) {
    context.read<PartRecommendationProvider>().loadBrowseParts(
          category: category,
          query: query,
        );
  }

  void _onSearchChanged(String query) {
    _load(category: _selectedCategory, query: query.isEmpty ? null : query);
  }

  void _onCategoryChanged(PartCategory? category) {
    setState(() => _selectedCategory = category);
    _load(
      category: category,
      query: _searchController.text.isEmpty ? null : _searchController.text,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PartRecommendationProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('パーツを探す'),
            actions: [
              if (!provider.isLoading)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '再読み込み',
                  onPressed: () {
                    _searchController.clear();
                    _onCategoryChanged(null);
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              // 車両絞り込み中バナー（車両指定時のみ）
              if (widget.vehicle != null)
                _VehicleFilterBanner(vehicle: widget.vehicle!),

              // 検索バー
              _SearchBar(
                controller: _searchController,
                onChanged: _onSearchChanged,
              ),

              // カテゴリフィルタ
              _CategoryFilterRow(
                selected: _selectedCategory,
                onChanged: _onCategoryChanged,
              ),

              // 件数表示
              if (!provider.isLoading && provider.browseParts.isNotEmpty)
                _ResultCount(
                  count: provider.browseParts.length,
                  hasQuery: _searchController.text.isNotEmpty ||
                      _selectedCategory != null,
                ),

              Expanded(child: _buildBody(provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(PartRecommendationProvider provider) {
    if (provider.isLoading) {
      return const AppLoadingCenter(message: 'パーツを検索中...');
    }

    if (provider.error != null) {
      return AppErrorState(
        message: provider.error!.userMessage,
        onRetry: () => _load(category: _selectedCategory),
      );
    }

    if (provider.browseParts.isEmpty) {
      final hasFilter =
          _searchController.text.isNotEmpty || _selectedCategory != null;
      return AppEmptyState(
        icon: Icons.build_outlined,
        title: hasFilter ? 'パーツが見つかりません' : '現在パーツは掲載されていません',
        description: hasFilter
            ? 'フィルタや検索条件を変えてお試しください'
            : '登録されているパーツがまだありません',
        buttonLabel: hasFilter ? 'フィルタをリセット' : null,
        onButtonPressed: hasFilter ? () => _onCategoryChanged(null) : null,
      );
    }

    return ListView.builder(
      padding: AppSpacing.paddingScreen,
      itemCount: provider.browseParts.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _PartCard(
            part: provider.browseParts[index],
            vehicle: widget.vehicle,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 車両絞り込み中バナー
// ---------------------------------------------------------------------------

class _VehicleFilterBanner extends StatelessWidget {
  final Vehicle vehicle;

  const _VehicleFilterBanner({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Row(
        children: [
          Icon(
            Icons.directions_car,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '${vehicle.maker} ${vehicle.model} (${vehicle.year}年) の互換性を表示中',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 検索バー
// ---------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

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
          hintText: 'パーツ名・ブランド・タグで検索',
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
// カテゴリフィルタ（横スクロール ChoiceChip）
// ---------------------------------------------------------------------------

class _CategoryFilterRow extends StatelessWidget {
  final PartCategory? selected;
  final ValueChanged<PartCategory?> onChanged;

  // 一覧に表示するカテゴリ（全17種）
  static const _displayCategories = PartCategory.values;

  const _CategoryFilterRow({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: [
          // 「すべて」チップ
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 4, vertical: AppSpacing.xs),
            child: ChoiceChip(
              label: const Text('すべて'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
              visualDensity: VisualDensity.compact,
              labelStyle: const TextStyle(fontSize: 12),
            ),
          ),
          // 各カテゴリ
          ..._displayCategories.map((category) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(category.displayName),
                selected: category == selected,
                onSelected: (_) =>
                    onChanged(category == selected ? null : category),
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 12),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 件数表示
// ---------------------------------------------------------------------------

class _ResultCount extends StatelessWidget {
  final int count;
  final bool hasQuery;

  const _ResultCount({required this.count, required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Text(
        hasQuery ? '$count件のパーツが見つかりました' : '$count件のおすすめパーツ',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// パーツカード
// ---------------------------------------------------------------------------

class _PartCard extends StatelessWidget {
  final PartListing part;
  final Vehicle? vehicle;

  const _PartCard({required this.part, this.vehicle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 互換性の計算（車両指定時のみ）
    CompatibilityLevel? compatibility;
    if (vehicle != null) {
      compatibility = part.getCompatibilityFor(
        makerId: _getMakerId(vehicle!.maker),
        modelId: '${_getMakerId(vehicle!.maker)}_${vehicle!.model.toLowerCase()}',
        year: vehicle!.year,
        grade: vehicle!.grade,
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PartDetailScreen(part: part, vehicle: vehicle),
            ),
          );
        },
        child: Padding(
        padding: AppSpacing.paddingCard,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // パーツ画像
            ClipRRect(
              borderRadius: AppSpacing.borderRadiusSm,
              child: SizedBox(
                width: 80,
                height: 80,
                child: part.imageUrls.isNotEmpty
                    ? Image.network(
                        part.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildImagePlaceholder(theme),
                      )
                    : _buildImagePlaceholder(theme),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // 情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // カテゴリ + 広告ラベル
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          part.category.displayName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (part.isFeatured) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '広告',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 名前
                  Text(
                    part.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (part.brand != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      part.brand!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  // 価格 + 評価 + 互換性
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: 4,
                    children: [
                      // 価格
                      Text(
                        part.priceDisplay,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: part.priceFrom == null
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.primary,
                        ),
                      ),
                      // 評価
                      if (part.rating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 13, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              part.rating!.toStringAsFixed(1),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      // 互換性バッジ（車両指定時）
                      if (compatibility != null)
                        _CompatibilityBadge(level: compatibility),
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

  Widget _buildImagePlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.build_outlined,
        color: theme.colorScheme.onSurfaceVariant,
        size: 32,
      ),
    );
  }

  String _getMakerId(String makerName) {
    const makerMap = {
      'トヨタ': 'toyota',
      'ホンダ': 'honda',
      '日産': 'nissan',
      'マツダ': 'mazda',
      'スバル': 'subaru',
      'スズキ': 'suzuki',
      'ダイハツ': 'daihatsu',
      '三菱': 'mitsubishi',
      'レクサス': 'lexus',
    };
    return makerMap[makerName] ?? makerName.toLowerCase();
  }
}

// ---------------------------------------------------------------------------
// 互換性バッジ
// ---------------------------------------------------------------------------

class _CompatibilityBadge extends StatelessWidget {
  final CompatibilityLevel level;

  const _CompatibilityBadge({required this.level});

  Color _backgroundColor(BuildContext context) {
    switch (level) {
      case CompatibilityLevel.perfect:
        return Colors.green.shade50;
      case CompatibilityLevel.compatible:
        return Colors.blue.shade50;
      case CompatibilityLevel.conditional:
        return Colors.orange.shade50;
      case CompatibilityLevel.incompatible:
        return Colors.red.shade50;
    }
  }

  Color _textColor(BuildContext context) {
    switch (level) {
      case CompatibilityLevel.perfect:
        return Colors.green.shade700;
      case CompatibilityLevel.compatible:
        return Colors.blue.shade700;
      case CompatibilityLevel.conditional:
        return Colors.orange.shade700;
      case CompatibilityLevel.incompatible:
        return Colors.red.shade700;
    }
  }

  IconData get _icon {
    switch (level) {
      case CompatibilityLevel.perfect:
        return Icons.check_circle_outline;
      case CompatibilityLevel.compatible:
        return Icons.check_circle_outlined;
      case CompatibilityLevel.conditional:
        return Icons.info_outline;
      case CompatibilityLevel.incompatible:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _backgroundColor(context),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 11, color: _textColor(context)),
          const SizedBox(width: 3),
          Text(
            level.displayName,
            style: TextStyle(
              color: _textColor(context),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
