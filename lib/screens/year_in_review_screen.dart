import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../models/maintenance_record.dart';
import '../models/year_in_review.dart';

/// 「あなたのクルマの1年」。
///
/// `docs/HABIT_DESIGN.md` 打ち手2。
///
/// 1年で整備記録は数十件溜まる。だがそれを見返す画面は履歴の一覧と統計しか
/// なく、どちらも**自分から開かないと見えない**。溜めることには協力して
/// もらっているのに、溜まった価値を突き返していない。
///
/// この画面は Firebase を知らない。[YearInReview] を渡されて描くだけなので、
/// 通知から開くのも、車両詳細から開くのも、同じ形でできる。
class YearInReviewScreen extends StatelessWidget {
  final YearInReview review;
  final String vehicleName;

  const YearInReviewScreen({
    super.key,
    required this.review,
    required this.vehicleName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('この1年のふりかえり')),
      body: review.hasEnoughData
          ? _buildReview(context)
          : _buildNotEnoughData(context),
    );
  }

  // -------------------------------------------------------------------------

  Widget _buildReview(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###');
    final period = DateFormat('yyyy年M月');

    return SingleChildScrollView(
      key: const Key('review_body'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vehicleName.trim().isEmpty ? 'あなたのクルマ' : vehicleName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSpacing.verticalXxs,
          Text(
            '${period.format(review.periodFrom)} 〜 ${period.format(review.periodTo)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          AppSpacing.verticalLg,

          // ---- かかった費用（いちばん知りたい数字を大きく） ----
          Text(
            'かかった費用',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          AppSpacing.verticalXxs,
          Text(
            '${fmt.format(review.totalCost)} 円',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),

          AppSpacing.verticalMd,
          if (review.peerAverageCost != null)
            _buildPeerComparison(context, fmt),

          AppSpacing.verticalLg,
          _buildStatRow(context, fmt),

          AppSpacing.verticalLg,
          if (review.mostExpensive != null)
            _buildMostExpensive(context, fmt, review.mostExpensive!),

          if (review.costByType.isNotEmpty) ...[
            AppSpacing.verticalLg,
            _buildBreakdown(context, fmt),
          ],
        ],
      ),
    );
  }

  /// 同じ車種の人と比べる。
  ///
  /// **自分の数字だけでは良し悪しが分からない。** 18万円が高いのか安いのかは、
  /// 同じ車に乗っている人と比べて初めて分かる。ここが無いと、ただの家計簿になる。
  Widget _buildPeerComparison(BuildContext context, NumberFormat fmt) {
    final theme = Theme.of(context);
    final diff = review.costDiffFromPeers!;
    final cheaper = review.isCheaperThanPeers;
    final color = cheaper ? AppColors.success : AppColors.warning;

    return Container(
      key: const Key('peer_comparison'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                cheaper ? Icons.trending_down : Icons.trending_up,
                size: AppSpacing.iconSm,
                color: color,
              ),
              AppSpacing.horizontalXs,
              Expanded(
                child: Text(
                  cheaper
                      ? '同じ車種の人より ${fmt.format(diff.abs())}円 安く済んでいます'
                      : '同じ車種の人より ${fmt.format(diff.abs())}円 多くかかっています',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.verticalXxs,
          Text(
            '同じ車種の平均: ${fmt.format(review.peerAverageCost)}円',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, NumberFormat fmt) {
    final stats = <Widget>[
      _StatTile(
        key: const Key('count_stat'),
        label: '整備した回数',
        value: '${review.recordCount}',
        unit: '回',
        icon: Icons.build_outlined,
      ),
      // 走行距離は出せないことがある。0km と書くと「1年で0km」と読まれるので、
      // 欄ごと出さない（YearInReview._distanceOf のコメントを参照）。
      if (review.distanceKm != null)
        _StatTile(
          key: const Key('distance_stat'),
          label: '走った距離',
          value: fmt.format(review.distanceKm),
          unit: 'km',
          icon: Icons.route_outlined,
        ),
      if (review.mostVisitedShop != null)
        _StatTile(
          key: const Key('shop_stat'),
          label: 'よく行った店',
          value: review.mostVisitedShop!,
          icon: Icons.store_outlined,
        ),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: stats,
    );
  }

  Widget _buildMostExpensive(
    BuildContext context,
    NumberFormat fmt,
    MaintenanceRecord record,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(record.type.icon, color: record.type.color),
        title: const Text('いちばん高かった整備'),
        subtitle: Text(
          '${record.type.displayName} ・ ${DateFormat('yyyy年M月').format(record.date)}',
        ),
        trailing: Text(
          '${fmt.format(record.cost)}円',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdown(BuildContext context, NumberFormat fmt) {
    final theme = Theme.of(context);
    final entries = review.costByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('内訳', style: theme.textTheme.titleSmall),
        AppSpacing.verticalXs,
        ...entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                Icon(e.key.icon, size: AppSpacing.iconSm, color: e.key.color),
                AppSpacing.horizontalXs,
                Expanded(
                  child: Text(
                    e.key.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${fmt.format(e.value)}円',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 記録が足りないとき。
  ///
  /// **1件だけの「ふりかえり」は、見せられた側が白ける。**
  /// 何をすれば見られるようになるかだけ書いて、引き取ってもらう。
  Widget _buildNotEnoughData(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      key: const Key('not_enough_data'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.insights_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
            ),
            AppSpacing.verticalMd,
            Semantics(
              header: true,
              child: Text(
                'まだふりかえるには早いようです',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            AppSpacing.verticalXs,
            Text(
              '整備の記録が${YearInReview.minimumRecords}件たまると、'
              '1年でかかった費用や走った距離をまとめて見られます。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;

  const _StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$label $value${unit ?? ''}',
      child: ExcludeSemantics(
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            borderRadius: AppSpacing.borderRadiusMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: AppSpacing.iconSm, color: AppColors.primary),
                  AppSpacing.horizontalXs,
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.verticalXxs,
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 2),
                      Text(unit!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
