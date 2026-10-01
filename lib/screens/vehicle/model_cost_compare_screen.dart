import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/utils/first_week_tracker.dart';
import '../../models/model_cost_report.dart';
import '../../services/analytics_service.dart' show FirstWeekStep;
import 'model_cost_report_screen.dart';

final _yen = NumberFormat('#,###');

String _money(int v) => '${_yen.format(v)}円';

/// 車種を並べて比べる（Issue #208）。
///
/// 一覧で選んだ2〜3車種の目安と内訳を横に並べる。出せない項目は「—」で、
/// **0円で埋めない**。持ち主が5人に満たないレポートは並べない。
class ModelCostCompareScreen extends StatefulWidget {
  final List<ModelCostReport> reports;

  const ModelCostCompareScreen({super.key, required this.reports});

  @override
  State<ModelCostCompareScreen> createState() => _ModelCostCompareScreenState();
}

class _ModelCostCompareScreenState extends State<ModelCostCompareScreen> {
  @override
  void initState() {
    super.initState();
    // 比べる画面も維持費を見たことになる（レポート画面と同じ扱い）
    trackFirstWeekStep(FirstWeekStep.modelCostViewed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 同じ車種を2回並べない（ID が同じものは最初の1つだけ）
    final seen = <String>{};
    final reports =
        widget.reports.where((r) => r.isPublishable && seen.add(r.id)).toList();
    String cell(int? v) => v == null ? '—' : _money(v);

    final rows = <(String, String, List<String>)>[
      (
        '1年あたりの目安',
        '整備＋車検＋燃料',
        [for (final r in reports) cell(r.annualEstimate)],
      ),
      (
        '整備・修理',
        '年あたり',
        [for (final r in reports) cell(r.maintenanceAnnual?.median)],
      ),
      (
        '車検',
        '1回あたり',
        [for (final r in reports) cell(r.inspectionPerEvent?.median)],
      ),
      (
        '燃料',
        '年あたり',
        [for (final r in reports) cell(r.fuelAnnual?.median)],
      ),
      (
        '記録した持ち主',
        '',
        [for (final r in reports) '${r.ownerCount}人'],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('維持費を比べる')),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          Table(
            key: const Key('model_cost_compare_table'),
            columnWidths: {
              0: const FlexColumnWidth(1.2),
              for (var i = 0; i < reports.length; i++)
                i + 1: const FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(
              horizontalInside: BorderSide(color: theme.dividerColor),
            ),
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  for (final r in reports)
                    InkWell(
                      key: Key('model_cost_compare_open_${r.id}'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ModelCostReportScreen(
                            report: r,
                            showUsedCarSearch: true,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                          horizontal: AppSpacing.xxs,
                        ),
                        child: Text(
                          r.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              for (final (label, unit, values) in rows)
                TableRow(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: theme.textTheme.bodyMedium),
                          if (unit.isNotEmpty)
                            Text(unit, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    for (final v in values)
                      Text(
                        v,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
            ],
          ),
          AppSpacing.verticalMd,
          _Note(
            icon: Icons.fact_check_outlined,
            text: [
              '同じ車に乗っている人の実際の記録から出した中央値です。'
                  '税金・保険・駐車場は入っていません。',
              '「—」は、記録している持ち主が5人に満たないなどで出せない項目です。',
              if (reports.any((r) => r.isMakerLevel))
                '（メーカー全体）は、車種で5人に届かないためメーカー全体の数字です。',
              '車種名を押すと、くわしいレポートと中古車の検索が見られます。',
            ].join(''),
          ),
          AppSpacing.verticalXl,
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSpacing.iconSm, color: theme.hintColor),
        AppSpacing.horizontalXs,
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}
