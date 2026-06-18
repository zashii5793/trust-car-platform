import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/accessory_showcase.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/popular_accessories_service.dart';
import 'showcase_detail_screen.dart';

/// Community accessory showcase screen.
///
/// Shows trending accessories by category and lets users submit their own.
class AccessoryShowcaseScreen extends StatefulWidget {
  const AccessoryShowcaseScreen({super.key});

  @override
  State<AccessoryShowcaseScreen> createState() =>
      _AccessoryShowcaseScreenState();
}

class _AccessoryShowcaseScreenState extends State<AccessoryShowcaseScreen>
    with SingleTickerProviderStateMixin {
  late final PopularAccessoriesService _service;
  late final TabController _tabController;

  final _categories = [null, ...AccessoryCategory.values];
  final _trendsByCategory = <AccessoryCategory?, List<AccessoryTrend>>{};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = sl.get<PopularAccessoriesService>();
    _tabController = TabController(
      length: _categories.length,
      vsync: this,
    );
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Load top across all + per-category
    final topResult = await _service.getTopAccessories(limit: 20);
    final futures = AccessoryCategory.values.map(
      (cat) => _service.getPopularTrends(category: cat, limit: 10),
    );
    final catResults = await Future.wait(futures);

    if (!mounted) return;

    if (topResult.isFailure) {
      setState(() {
        _errorMessage = topResult.when(
          success: (_) => null,
          failure: (e) => e.message,
        );
        _isLoading = false;
      });
      return;
    }

    final newMap = <AccessoryCategory?, List<AccessoryTrend>>{
      null: topResult.valueOrNull ?? [],
    };
    for (var i = 0; i < AccessoryCategory.values.length; i++) {
      newMap[AccessoryCategory.values[i]] = catResults[i].valueOrNull ?? [];
    }
    setState(() {
      _trendsByCategory.addAll(newMap);
      _isLoading = false;
    });
  }

  /// Opens the individual showcase posts behind an aggregated [trend] so the
  /// user can read reviews and join the comment thread.
  Future<void> _openTrendShowcases(AccessoryTrend trend) async {
    final result = await _service.getShowcasesByCategory(trend.category);
    if (!mounted) return;

    final showcases = (result.valueOrNull ?? [])
        .where((s) => s.itemName == trend.itemName && s.brand == trend.brand)
        .toList();

    if (showcases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿が見つかりませんでした')),
      );
      return;
    }

    final uid = context.read<AuthProvider>().appUser?.id ?? '';

    void openDetail(AccessoryShowcase showcase) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ShowcaseDetailScreen(
            showcase: showcase,
            service: _service,
            currentUserId: uid,
          ),
        ),
      );
    }

    if (showcases.length == 1) {
      openDetail(showcases.first);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '${trend.itemName} の投稿',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ...showcases.map(
              (s) => ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(
                  '★${s.rating} ${s.review ?? 'レビューなし'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  openDetail(s);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSubmitSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SubmitShowcaseSheet(
        service: _service,
        onSubmitted: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('みんなのアクセサリー'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _categories.map((cat) {
            return Tab(text: cat?.displayName ?? 'すべて');
          }).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('submit_showcase_fab'),
        onPressed: _openSubmitSheet,
        icon: const Icon(Icons.add_outlined),
        label: const Text('投稿する'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!,
                          style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                          onPressed: _load, child: const Text('再読み込み')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: _categories.map((cat) {
                    final trends = _trendsByCategory[cat] ?? [];
                    if (trends.isEmpty) {
                      return const _EmptyTrends();
                    }
                    return _TrendList(
                      trends: trends,
                      onTapTrend: _openTrendShowcases,
                    );
                  }).toList(),
                ),
    );
  }
}

// ── Trend list ────────────────────────────────────────────────────────────────

class _TrendList extends StatelessWidget {
  final List<AccessoryTrend> trends;
  final ValueChanged<AccessoryTrend> onTapTrend;
  const _TrendList({required this.trends, required this.onTapTrend});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: trends.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _TrendCard(
        rank: i + 1,
        trend: trends[i],
        onTap: () => onTapTrend(trends[i]),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final int rank;
  final AccessoryTrend trend;
  final VoidCallback onTap;
  const _TrendCard({
    required this.rank,
    required this.trend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('trend_card_${trend.itemName}'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rank badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? AppColors.primary
                      : AppColors.backgroundSecondary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: rank <= 3 ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trend.itemName,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (trend.brand != null)
                      Text(
                        trend.brand!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        _MetaChip(
                          icon: Icons.people_outline,
                          label: '${trend.showcaseCount}人が使用',
                        ),
                        _MetaChip(
                          icon: Icons.star_outline,
                          label: '${trend.averageRating.toStringAsFixed(1)}★',
                        ),
                        if (trend.averagePriceApprox != null)
                          _MetaChip(
                            icon: Icons.sell_outlined,
                            label:
                                '¥${_formatPrice(trend.averagePriceApprox!.toDouble())}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _CategoryBadge(category: trend.category),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    final p = price.round();
    if (p >= 10000) {
      return '${(p / 10000).toStringAsFixed(1)}万';
    }
    return '$p';
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final AccessoryCategory category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.displayName,
        style: const TextStyle(fontSize: 10, color: AppColors.primary),
      ),
    );
  }
}

class _EmptyTrends extends StatelessWidget {
  const _EmptyTrends();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined,
                size: AppSpacing.iconXl, color: AppColors.textTertiary),
            SizedBox(height: AppSpacing.md),
            Text(
              'まだ投稿がありません',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '最初に「投稿する」ボタンからアクセサリーを投稿しましょう',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Submit showcase bottom sheet ──────────────────────────────────────────────

class _SubmitShowcaseSheet extends StatefulWidget {
  final PopularAccessoriesService service;
  final VoidCallback onSubmitted;

  const _SubmitShowcaseSheet({
    required this.service,
    required this.onSubmitted,
  });

  @override
  State<_SubmitShowcaseSheet> createState() => _SubmitShowcaseSheetState();
}

class _SubmitShowcaseSheetState extends State<_SubmitShowcaseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _brandController = TextEditingController();
  final _reviewController = TextEditingController();
  final _priceController = TextEditingController();

  AccessoryCategory _category = AccessoryCategory.electronics;
  int _rating = 4;
  bool _isSaving = false;

  @override
  void dispose() {
    _itemNameController.dispose();
    _brandController.dispose();
    _reviewController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final uid = context.read<AuthProvider>().appUser?.id ?? '';
    final vehicles = context.read<VehicleProvider>().vehicles;
    final vehicleId = vehicles.isNotEmpty ? vehicles.first.id : null;

    final priceText = _priceController.text.trim();
    final price = priceText.isEmpty ? null : int.tryParse(priceText);

    final result = await widget.service.submitShowcase(
      userId: uid,
      category: _category,
      itemName: _itemNameController.text.trim(),
      brand: _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      rating: _rating,
      priceApprox: price,
      review: _reviewController.text.trim().isEmpty
          ? null
          : _reviewController.text.trim(),
      vehicleId: vehicleId,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    result.when(
      success: (_) {
        Navigator.pop(context);
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投稿しました！')),
        );
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('アクセサリーを投稿',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),

            // Category
            InputDecorator(
              decoration: const InputDecoration(labelText: 'カテゴリ *'),
              child: DropdownButton<AccessoryCategory>(
                key: const Key('showcase_category_dropdown'),
                value: _category,
                isDense: true,
                underline: const SizedBox.shrink(),
                isExpanded: true,
                items: AccessoryCategory.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.displayName),
                        ))
                    .toList(),
                onChanged: (c) {
                  if (c != null) setState(() => _category = c);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Item name
            TextFormField(
              key: const Key('showcase_item_name_field'),
              controller: _itemNameController,
              decoration: const InputDecoration(
                labelText: '商品名 *',
                hintText: 'Vantrue N2 Pro など',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '商品名を入力してください' : null,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Brand
            TextFormField(
              key: const Key('showcase_brand_field'),
              controller: _brandController,
              decoration: const InputDecoration(
                labelText: 'ブランド',
                hintText: 'Vantrue など（任意）',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Price
            TextFormField(
              key: const Key('showcase_price_field'),
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: '購入価格（円）',
                hintText: '15000 など（任意）',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),

            // Rating
            Text('評価 *', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = star),
                  child: Icon(
                    star <= _rating ? Icons.star : Icons.star_outline,
                    color: AppColors.warning,
                    size: 32,
                    key: Key('rating_star_$star'),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Review
            TextFormField(
              key: const Key('showcase_review_field'),
              controller: _reviewController,
              decoration: const InputDecoration(
                labelText: 'レビュー（任意）',
                hintText: '取り付けが簡単で夜間の映像もクリア...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Submit
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('showcase_submit_button'),
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('投稿する'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
