import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/part_listing.dart';
import '../../models/vehicle.dart';
import '../../providers/part_recommendation_provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/loading_indicator.dart';

/// AIパーツ提案画面
///
/// 設計思想:
/// - AIは提案する、決めない（ランキング・ベスト1ラベルなし）
/// - メリット＋デメリットをフラットに表示
/// - ユーザーが自分で判断できる情報を提供する
class PartRecommendationScreen extends StatefulWidget {
  final Vehicle vehicle;

  const PartRecommendationScreen({super.key, required this.vehicle});

  @override
  State<PartRecommendationScreen> createState() =>
      _PartRecommendationScreenState();
}

class _PartRecommendationScreenState extends State<PartRecommendationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<PartRecommendationProvider>(context, listen: false);
      provider.loadRecommendations(widget.vehicle);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PartRecommendationProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('パーツ提案'),
                Text(
                  widget.vehicle.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
            actions: [
              if (!provider.isLoading)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '再読み込み',
                  onPressed: () =>
                      provider.loadRecommendations(widget.vehicle),
                ),
            ],
          ),
          body: Column(
            children: [
              _CategoryFilterBar(provider: provider, vehicle: widget.vehicle),
              Expanded(child: _buildBody(provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(PartRecommendationProvider provider) {
    if (provider.isLoading) {
      return const AppLoadingCenter();
    }

    if (provider.error != null) {
      return _ErrorState(
        message: provider.errorMessage ?? 'エラーが発生しました',
        onRetry: () => provider.loadRecommendations(widget.vehicle),
      );
    }

    final items = provider.filteredRecommendations;

    if (items.isEmpty) {
      return AppEmptyState(
        icon: Icons.search_off,
        title: provider.selectedCategory != null
            ? '${provider.selectedCategory!.displayName}の提案はありません'
            : '現在ご利用いただける提案はありません',
        description: 'マーケットプレイスにパーツ情報が登録されると\nここに提案が表示されます',
      );
    }

    return ListView.builder(
      padding: AppSpacing.paddingScreen,
      itemCount: items.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _RecommendationCard(
            recommendation: items[index],
            vehicle: widget.vehicle,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// カテゴリフィルターバー
// ---------------------------------------------------------------------------

class _CategoryFilterBar extends StatelessWidget {
  final PartRecommendationProvider provider;
  final Vehicle vehicle;

  const _CategoryFilterBar({
    required this.provider,
    required this.vehicle,
  });

  @override
  Widget build(BuildContext context) {
    // Show only categories that have results (or all if no results yet)
    final availableCategories = PartCategory.values;

    return Container(
      height: 48,
      color: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        itemCount: availableCategories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // "すべて" chip
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: FilterChip(
                label: const Text('すべて'),
                selected: provider.selectedCategory == null,
                onSelected: (_) {
                  provider.selectCategory(null);
                  provider.loadRecommendations(vehicle);
                },
              ),
            );
          }
          final category = availableCategories[index - 1];
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: FilterChip(
              label: Text(category.displayName),
              selected: provider.selectedCategory == category,
              onSelected: (_) {
                provider.selectCategory(category);
                provider.loadRecommendations(vehicle, category: category);
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 提案カード
// ---------------------------------------------------------------------------

class _RecommendationCard extends StatelessWidget {
  final PartRecommendation recommendation;
  final Vehicle vehicle;

  const _RecommendationCard({
    required this.recommendation,
    required this.vehicle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final part = recommendation.part;
    final pros = part.pros.take(2).toList();
    final cons = part.cons.take(1).toList();

    return AppCard(
      onTap: () => _showDetail(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー行: カテゴリ + 対応バッジ
          Row(
            children: [
              _CategoryBadge(category: part.category),
              AppSpacing.horizontalXs,
              _CompatibilityBadge(
                compatibility: recommendation.compatibility,
                note: recommendation.compatibilityNote,
              ),
              const Spacer(),
              if (part.isFeatured)
                const Icon(Icons.star, color: AppColors.warning, size: 16),
            ],
          ),
          AppSpacing.verticalSm,

          // パーツ名
          Text(
            part.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // ブランド
          if (part.brand != null) ...[
            AppSpacing.verticalXxs,
            Text(
              part.brand!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],

          AppSpacing.verticalSm,

          // 価格
          Text(
            part.priceDisplay,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),

          // pros / cons
          if (pros.isNotEmpty || cons.isNotEmpty) ...[
            AppSpacing.verticalSm,
            const Divider(height: 1),
            AppSpacing.verticalSm,
            ...pros.map((p) => _ProConRow(text: p.text, isPro: true)),
            ...cons.map((c) => _ProConRow(text: c.text, isPro: false)),
          ],

          // 関連度バー（控えめに表示）
          AppSpacing.verticalSm,
          _RelevanceBar(score: recommendation.relevanceScore),

          AppSpacing.verticalSm,

          // 詳細ボタン
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDetail(context),
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('詳細・注意点を確認する'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PartDetailSheet(
        recommendation: recommendation,
        vehicle: vehicle,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// カテゴリバッジ
// ---------------------------------------------------------------------------

class _CategoryBadge extends StatelessWidget {
  final PartCategory category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusXs,
      ),
      child: Text(
        category.displayName,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 対応バッジ
// ---------------------------------------------------------------------------

class _CompatibilityBadge extends StatelessWidget {
  final CompatibilityLevel compatibility;
  final String? note;

  const _CompatibilityBadge({required this.compatibility, this.note});

  Color get _color {
    switch (compatibility) {
      case CompatibilityLevel.perfect:
        return AppColors.success;
      case CompatibilityLevel.compatible:
        return AppColors.info;
      case CompatibilityLevel.conditional:
        return AppColors.warning;
      case CompatibilityLevel.incompatible:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusXs,
        border: Border.all(color: _color.withValues(alpha: 0.5)),
      ),
      child: Text(
        compatibility.displayName,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pro/Con 行
// ---------------------------------------------------------------------------

class _ProConRow extends StatelessWidget {
  final String text;
  final bool isPro;

  const _ProConRow({required this.text, required this.isPro});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPro ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            size: 14,
            color: isPro ? AppColors.success : AppColors.warning,
          ),
          AppSpacing.horizontalXs,
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 関連度バー（控えめ）
// ---------------------------------------------------------------------------

class _RelevanceBar extends StatelessWidget {
  final double score; // 0.0 - 1.0

  const _RelevanceBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          '適合度',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.textTertiary,
              ),
        ),
        AppSpacing.horizontalXs,
        Expanded(
          child: ClipRRect(
            borderRadius: AppSpacing.borderRadiusSm,
            child: LinearProgressIndicator(
              value: score,
              minHeight: 4,
              backgroundColor: AppColors.border.withValues(alpha: isDark ? 0.3 : 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(
                score >= 0.7
                    ? AppColors.success
                    : score >= 0.4
                        ? AppColors.info
                        : AppColors.warning,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// パーツ詳細BottomSheet
// ---------------------------------------------------------------------------

class _PartDetailSheet extends StatelessWidget {
  final PartRecommendation recommendation;
  final Vehicle vehicle;

  const _PartDetailSheet({
    required this.recommendation,
    required this.vehicle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final part = recommendation.part;
    final pros = part.pros;
    final cons = part.cons;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: AppSpacing.paddingScreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ハンドル
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // カテゴリ + 対応バッジ
              Row(
                children: [
                  _CategoryBadge(category: part.category),
                  AppSpacing.horizontalXs,
                  _CompatibilityBadge(
                    compatibility: recommendation.compatibility,
                    note: recommendation.compatibilityNote,
                  ),
                ],
              ),
              AppSpacing.verticalMd,

              // パーツ名
              Text(
                part.name,
                style: theme.textTheme.headlineLarge,
              ),

              if (part.brand != null) ...[
                AppSpacing.verticalXs,
                Text(
                  part.brand!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],

              AppSpacing.verticalMd,

              // 説明
              Text(
                part.description,
                style: theme.textTheme.bodyLarge,
              ),

              AppSpacing.verticalMd,

              // 価格
              _DetailRow(
                icon: Icons.sell_outlined,
                label: '価格',
                value: part.priceDisplay,
              ),

              // 対応状況
              _DetailRow(
                icon: Icons.check_circle_outline,
                label: '対応状況',
                value:
                    '${recommendation.compatibility.displayName}（${recommendation.compatibility.description}）',
              ),

              if (recommendation.compatibilityNote != null)
                _DetailRow(
                  icon: Icons.info_outline,
                  label: '備考',
                  value: recommendation.compatibilityNote!,
                ),

              if (part.partNumber != null)
                _DetailRow(
                  icon: Icons.tag,
                  label: '品番',
                  value: part.partNumber!,
                ),

              AppSpacing.verticalMd,

              // メリット
              if (pros.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.thumb_up_outlined,
                  title: 'メリット',
                  color: AppColors.success,
                ),
                AppSpacing.verticalSm,
                ...pros.map((p) => _ProConDetailRow(text: p.text, isPro: true)),
                AppSpacing.verticalMd,
              ],

              // デメリット
              if (cons.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.thumb_down_outlined,
                  title: 'デメリット・注意点',
                  color: AppColors.warning,
                ),
                AppSpacing.verticalSm,
                ...cons.map((c) => _ProConDetailRow(text: c.text, isPro: false)),
                AppSpacing.verticalMd,
              ],

              // 免責注記
              Container(
                padding: AppSpacing.paddingCard,
                decoration: BoxDecoration(
                  color: AppColors.infoBackground,
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info, color: AppColors.info, size: 16),
                    AppSpacing.horizontalXs,
                    Expanded(
                      child: Text(
                        'この情報はAIによる参考提案です。取付前に必ずお近くの専門店へご相談ください。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              AppSpacing.verticalXl,

              // 閉じるボタン
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ),
              AppSpacing.verticalMd,
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        AppSpacing.horizontalXs,
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _ProConDetailRow extends StatelessWidget {
  final String text;
  final bool isPro;

  const _ProConDetailRow({required this.text, required this.isPro});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPro ? Icons.check : Icons.priority_high,
            size: 16,
            color: isPro ? AppColors.success : AppColors.warning,
          ),
          AppSpacing.horizontalXs,
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
          ),
          AppSpacing.horizontalXs,
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// エラー表示
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingScreen,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            AppSpacing.verticalMd,
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalLg,
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }
}
