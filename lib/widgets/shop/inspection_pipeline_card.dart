import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/inspection_pipeline.dart';

/// Shows the shop how many inspections it is about to win — and how many it lost.
///
/// `docs/BUSINESS_MODEL_RETHINK_2026-08-27.md` §2-4。
///
/// オーナーへの聞き取りで、**年間の取りこぼし台数は「把握できていない」**
/// という回答だった。分母が無いので、何台逃しているのかも、手を打って効いたかも
/// 分からない。ここはその分母を作る。
///
/// **数えられないときに「0台」と出さない。** 「取りこぼし0台」と
/// 「まだ分からない」はまったく違う。混ぜると経営判断を誤らせる。
class InspectionPipelineCard extends StatelessWidget {
  final InspectionPipeline pipeline;

  /// 「9月」「今月」など、どの期間の話かを見出しに出す。
  final String periodLabel;

  const InspectionPipelineCard({
    super.key,
    required this.pipeline,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const Key('inspection_pipeline_card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available, color: AppColors.primary),
                AppSpacing.horizontalXs,
                Expanded(
                  child: Text(
                    '$periodLabel の車検',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            AppSpacing.verticalMd,
            if (!pipeline.canCount)
              _NotCountable(pipeline: pipeline)
            else ...[
              Row(
                children: [
                  _Figure(
                    label: '満了を迎える',
                    value: pipeline.dueCount,
                    color: AppColors.primary,
                  ),
                  _Figure(
                    label: '入庫済み',
                    value: pipeline.completedCount,
                    color: AppColors.success,
                  ),
                  _Figure(
                    key: const Key('missed_figure'),
                    label: '取りこぼし',
                    value: pipeline.missedCount,
                    color: pipeline.missedCount > 0
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ],
              ),
              if (pipeline.unknownExpiryCount > 0) ...[
                AppSpacing.verticalMd,
                _UnknownExpiryNote(count: pipeline.unknownExpiryCount),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Figure({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Semantics(
        label: '$label $value台',
        child: ExcludeSemantics(
          child: Column(
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              AppSpacing.verticalXxs,
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$value',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text('台', style: theme.textTheme.bodySmall),
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

/// 数えられないときに出すもの。**「0台」とは書かない。**
class _NotCountable extends StatelessWidget {
  final InspectionPipeline pipeline;

  const _NotCountable({required this.pipeline});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unknown = pipeline.unknownExpiryCount;

    return Container(
      key: const Key('pipeline_not_countable'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'まだ数えられません',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSpacing.verticalXxs,
          Text(
            unknown > 0
                ? '車検満了日が入っていないお客様が $unknown 名います。'
                    '満了日が入ると、取りこぼしが数えられるようになります。'
                : 'この期間に満了を迎えるお客様がいません。',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _UnknownExpiryNote extends StatelessWidget {
  final int count;

  const _UnknownExpiryNote({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      key: const Key('unknown_expiry_note'),
      children: [
        Icon(
          Icons.info_outline,
          size: AppSpacing.iconSm,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        AppSpacing.horizontalXs,
        Expanded(
          child: Text(
            // 数字の外に何台いるかを言わないと、上の数字が全体だと誤解される。
            '車検満了日が未入力のお客様が $count 名います。この数字には入っていません。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}
