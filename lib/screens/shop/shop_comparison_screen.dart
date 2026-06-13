import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/shop.dart';
import '../../services/shop_comparison_service.dart';

/// 複数の整備工場を並べて比較する画面。
///
/// [shops] に2〜5工場を渡すと [ShopComparisonService] でスコアリングし、
/// おすすめ工場バッジ付きで降順表示する。
/// [primaryNeed] を指定するとそのサービスを提供しているか強調表示する。
class ShopComparisonScreen extends StatefulWidget {
  final List<Shop> shops;
  final ServiceCategory? primaryNeed;

  const ShopComparisonScreen({
    super.key,
    required this.shops,
    this.primaryNeed,
  });

  @override
  State<ShopComparisonScreen> createState() => _ShopComparisonScreenState();
}

class _ShopComparisonScreenState extends State<ShopComparisonScreen> {
  late final ShopComparisonService _service;
  late final List<ShopComparisonResult> _results;
  Shop? _recommended;

  @override
  void initState() {
    super.initState();
    _service = sl.get<ShopComparisonService>();
    _results = _service.compare(
      shops: widget.shops,
      requiredServices:
          widget.primaryNeed != null ? [widget.primaryNeed!] : null,
    );
    _recommended = widget.primaryNeed != null
        ? _service.recommend(
            results: _results,
            primaryNeed: widget.primaryNeed!,
          )
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('工場比較 (${widget.shops.length}件)'),
      ),
      body: Column(
        children: [
          if (widget.primaryNeed != null)
            _NeedBanner(need: widget.primaryNeed!),
          Expanded(
            child: ListView.separated(
              key: const Key('comparison_list'),
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _results.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _ComparisonCard(
                result: _results[i],
                rank: i + 1,
                isRecommended: _recommended?.id == _results[i].shop.id,
                primaryNeed: widget.primaryNeed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 「〇〇を希望」バナー ──────────────────────────────────────────────────────

class _NeedBanner extends StatelessWidget {
  final ServiceCategory need;
  const _NeedBanner({required this.need});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              '希望サービス: ${need.displayName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 比較カード ───────────────────────────────────────────────────────────────

class _ComparisonCard extends StatelessWidget {
  final ShopComparisonResult result;
  final int rank;
  final bool isRecommended;
  final ServiceCategory? primaryNeed;

  const _ComparisonCard({
    required this.result,
    required this.rank,
    required this.isRecommended,
    this.primaryNeed,
  });

  Shop get shop => result.shop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('comparison_card_${shop.id}'),
      shape: isRecommended
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.primary, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー行
            Row(
              children: [
                _RankBadge(rank: rank),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        shop.type.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isRecommended) _RecommendedBadge(),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // 評価・距離・対応日数
            Row(
              children: [
                _RatingWidget(
                    rating: shop.rating, reviewCount: shop.reviewCount),
                const SizedBox(width: AppSpacing.md),
                if (result.distanceKm != null) ...[
                  const Icon(Icons.place_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text(
                    '${result.distanceKm!.toStringAsFixed(1)} km',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                const Icon(Icons.schedule_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text(
                  _responseDayLabel(result.estimatedResponseDays),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // サービス一覧
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: 4,
              children: [
                for (final svc in shop.services)
                  _ServiceChip(
                    service: svc,
                    highlighted: svc == primaryNeed,
                  ),
              ],
            ),

            // スコアバー
            const SizedBox(height: AppSpacing.sm),
            _ScoreBar(result: result),
          ],
        ),
      ),
    );
  }

  String _responseDayLabel(int days) => switch (days) {
        1 => '当日対応',
        2 => '翌日対応',
        _ => '2〜3日',
      };
}

// ── ランクバッジ ──────────────────────────────────────────────────────────────

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final color = rank == 1
        ? const Color(0xFFFFB300)
        : rank == 2
            ? const Color(0xFF90A4AE)
            : const Color(0xFFBCAAA4);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

// ── おすすめバッジ ────────────────────────────────────────────────────────────

class _RecommendedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'おすすめ',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── 評価表示 ─────────────────────────────────────────────────────────────────

class _RatingWidget extends StatelessWidget {
  final double? rating;
  final int reviewCount;
  const _RatingWidget({required this.rating, required this.reviewCount});

  @override
  Widget build(BuildContext context) {
    if (rating == null) {
      return Text(
        '評価なし',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textTertiary),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, size: 14, color: Color(0xFFFFB300)),
        const SizedBox(width: 2),
        Text(
          rating!.toStringAsFixed(1),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        Text(
          ' ($reviewCount件)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

// ── サービスチップ ────────────────────────────────────────────────────────────

class _ServiceChip extends StatelessWidget {
  final ServiceCategory service;
  final bool highlighted;
  const _ServiceChip({required this.service, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.textTertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: highlighted
            ? const Border.fromBorderSide(
                BorderSide(color: AppColors.primary, width: 1),
              )
            : null,
      ),
      child: Text(
        service.displayName,
        style: TextStyle(
          fontSize: 11,
          color: highlighted ? AppColors.primary : AppColors.textSecondary,
          fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

// ── AIスコアバー ─────────────────────────────────────────────────────────────

class _ScoreBar extends StatelessWidget {
  final ShopComparisonResult result;
  const _ScoreBar({required this.result});

  double _computeScore() {
    final rating = result.shop.rating ?? 0.0;
    final reviewCount = result.shop.reviewCount;
    final ratingScore = rating * math.log(reviewCount + 1);
    final distancePenalty = (result.distanceKm ?? 0.0) * 0.05;
    return ratingScore - distancePenalty;
  }

  @override
  Widget build(BuildContext context) {
    final score = _computeScore();
    final capped = score.clamp(0.0, 30.0) / 30.0;
    return Row(
      children: [
        Text(
          'AIスコア',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: capped,
              minHeight: 6,
              backgroundColor: AppColors.textTertiary.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          score.toStringAsFixed(1),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
