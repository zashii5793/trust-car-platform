import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/car_purchase_inquiry.dart';
import '../../models/model_cost_report.dart';
import '../../services/car_purchase_inquiry_service.dart';
import '../../services/model_cost_report_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/loading_indicator.dart';
import 'model_cost_compare_screen.dart';
import '../../core/utils/first_week_tracker.dart';
import '../../services/analytics_service.dart' show FirstWeekStep;

final _yen = NumberFormat('#,###');

String _money(int v) => '${_yen.format(v)}円';

/// 車種別の維持費レポート（`docs/SHOP_CRM_DESIGN_2026-09-27.md` §8）。
///
/// 「この車に乗ると、年にいくらかかるか」を、同じ車に乗っている人の
/// 実際の記録から出す。**自分の記録が溜まっていなくても、初日から見られる。**
class ModelCostReportScreen extends StatefulWidget {
  final ModelCostReport report;

  /// ほかの車種を探す画面へ。渡さなければボタンを出さない。
  final VoidCallback? onBrowseOthers;

  /// 中古車検索（カーセンサー / Goo-net）へのリンクを出すか。
  ///
  /// 車種を選んで調べている人（買う前の人）向け。自分の車の詳細から開いた
  /// ときは出さない（もう持っている車種を探させても意味が薄い）。
  final bool showUsedCarSearch;

  const ModelCostReportScreen({
    super.key,
    required this.report,
    this.onBrowseOthers,
    this.showUsedCarSearch = false,
  });

  @override
  State<ModelCostReportScreen> createState() => _ModelCostReportScreenState();
}

class _ModelCostReportScreenState extends State<ModelCostReportScreen> {
  @override
  void initState() {
    super.initState();
    // 開いたときに1回だけ（build は何度も走る）
    trackFirstWeekStep(FirstWeekStep.modelCostViewed);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final onBrowseOthers = widget.onBrowseOthers;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('維持費レポート')),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          Text(r.title, style: theme.textTheme.headlineSmall),
          AppSpacing.verticalXs,
          Text(
            '持ち主 ${r.ownerCount}人・${r.vehicleCount}台の記録から',
            style: theme.textTheme.bodySmall,
          ),
          if (r.isMakerLevel) ...[
            AppSpacing.verticalSm,
            const _Note(
              icon: Icons.info_outline,
              text: 'この車種は、まだ集計できる人数（5人）に届いていません。'
                  'メーカー全体の数字を出しています。',
            ),
          ],
          AppSpacing.verticalMd,
          _EstimateCard(report: r),
          AppSpacing.verticalMd,
          Text('内訳', style: theme.textTheme.titleMedium),
          AppSpacing.verticalXs,
          _StatTile(
            label: '整備・修理（車検を除く）',
            unit: '年あたり',
            stat: r.maintenanceAnnual,
          ),
          _StatTile(
            label: '車検',
            unit: '1回あたり',
            stat: r.inspectionPerEvent,
          ),
          _StatTile(
            label: '燃料',
            unit: '年あたり',
            stat: r.fuelAnnual,
            missing: '給油を記録している人がまだ少ないため、出せません',
          ),
          if (r.byAge.isNotEmpty) ...[
            AppSpacing.verticalMd,
            Text('年数でどう変わるか', style: theme.textTheme.titleMedium),
            Text(
              '1年間にかかった整備・車検の費用（燃料を除く）',
              style: theme.textTheme.bodySmall,
            ),
            AppSpacing.verticalSm,
            _AgeBars(items: r.byAge),
          ],
          if (r.topItems.isNotEmpty) ...[
            AppSpacing.verticalMd,
            Text('よくある整備', style: theme.textTheme.titleMedium),
            AppSpacing.verticalXs,
            for (final t in r.topItems)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(t.type),
                subtitle: Text('${t.owners}人が実施'),
                trailing: Text('1回 ${_money(t.medianCost)}'),
              ),
          ],
          AppSpacing.verticalMd,
          _Note(
            icon: Icons.fact_check_outlined,
            text: [
              '同じ車に乗っている人の実際の記録から出した中央値です。'
                  '乗り方・地域・お店によって変わります。',
              if (r.shopOwners > 0) '整備工場の実績（${r.shopOwners}人分）を匿名で含みます。',
              '持ち主が5人に満たない数字は出していません。',
              if (r.updatedAt != null)
                '${r.updatedAt!.year}/${r.updatedAt!.month}/${r.updatedAt!.day} 時点',
            ].join(''),
          ),
          if (widget.showUsedCarSearch) ...[
            AppSpacing.verticalMd,
            _UsedCarSearchLinks(report: r),
          ],
          if (onBrowseOthers != null) ...[
            AppSpacing.verticalMd,
            OutlinedButton.icon(
              key: const Key('model_cost_browse_others'),
              onPressed: onBrowseOthers,
              icon: const Icon(Icons.search),
              label: const Text('ほかの車種と比べる'),
            ),
          ],
          AppSpacing.verticalXl,
        ],
      ),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  final ModelCostReport report;

  const _EstimateCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estimate = report.annualEstimate;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1年あたりの目安', style: theme.textTheme.bodyMedium),
          AppSpacing.verticalXs,
          Text(
            estimate == null ? 'まだ出せません' : '約 ${_money(estimate)}',
            key: const Key('model_cost_estimate'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          AppSpacing.verticalXs,
          Text(
            estimate == null
                ? '1年以上記録している人が5人に届くと出せます。'
                : [
                    '整備・修理',
                    if (report.inspectionPerEvent != null) '車検（2年に1回として）',
                    if (report.fuelAnnual != null) '燃料',
                  ].join('＋'),
            style: theme.textTheme.bodySmall,
          ),
          if (estimate != null) ...[
            AppSpacing.verticalXxs,
            Text(
              '税金・保険・駐車場は入っていません',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String unit;
  final CostStat? stat;
  final String missing;

  const _StatTile({
    required this.label,
    required this.unit,
    required this.stat,
    this.missing = 'まだ人数が足りないため、出せません',
  });

  @override
  Widget build(BuildContext context) {
    final s = stat;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        s == null
            ? missing
            : '$unit・多くの人は ${_money(s.p25)}〜${_money(s.p75)}（${s.n}人）',
      ),
      trailing: s == null
          ? null
          : Text(
              _money(s.median),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
    );
  }
}

class _AgeBars extends StatelessWidget {
  final List<CostByAge> items;

  const _AgeBars({required this.items});

  @override
  Widget build(BuildContext context) {
    final max =
        items.map((e) => e.median).fold<int>(1, (a, b) => b > a ? b : a);
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final e in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text(e.label)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 14,
                        width: c.maxWidth * (e.median / max).clamp(0.02, 1.0),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.7),
                          borderRadius: AppSpacing.borderRadiusXs,
                        ),
                      ),
                    ),
                  ),
                ),
                AppSpacing.horizontalXs,
                SizedBox(
                  width: 96,
                  child: Text(
                    _money(e.median),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
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

Future<void> _openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// この車種の中古車を探すリンク（Issue #208「中古車検索リンクの隣に置く」）。
///
/// URL は CarPurchaseInquiryService と同じ規則で作る。メーカー全体の
/// レポートなら、メーカーだけで探す。
class _UsedCarSearchLinks extends StatelessWidget {
  final ModelCostReport report;

  const _UsedCarSearchLinks({required this.report});

  @override
  Widget build(BuildContext context) {
    final links = CarPurchaseInquiryService.searchLinksFor(
      CarPurchaseCondition(maker: report.maker, model: report.model),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          report.model == null ? '${report.maker}の中古車を探す' : 'この車種の中古車を探す',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        AppSpacing.verticalXs,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (var i = 0; i < links.length; i++)
              OutlinedButton.icon(
                key: Key('model_cost_used_car_$i'),
                onPressed: () => _openExternal(links[i].url),
                icon: const Icon(Icons.open_in_new, size: AppSpacing.iconSm),
                label: Text(links[i].siteName),
              ),
          ],
        ),
      ],
    );
  }
}

/// 見られる車種の一覧。**買う前に調べる**ための入口。
///
/// 車を登録していない人（ホームの最初の画面）と、メニューからも開ける。
/// チェックを入れた車種を並べて比べられる（[ModelCostCompareScreen]）。
class ModelCostBrowseScreen extends StatefulWidget {
  final ModelCostReportService service;

  const ModelCostBrowseScreen({super.key, required this.service});

  @override
  State<ModelCostBrowseScreen> createState() => _ModelCostBrowseScreenState();
}

class _ModelCostBrowseScreenState extends State<ModelCostBrowseScreen> {
  /// 一度に比べられる車種の数（スマホの幅で読める列数）。
  static const int maxCompare = 3;

  List<ModelCostReport>? _all;
  String _filter = '';

  /// 比べるために選んだ車種のID（選んだ順）。
  final List<String> _selected = [];

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < maxCompare) {
        _selected.add(id);
      }
    });
  }

  void _compare() {
    final all = _all ?? const <ModelCostReport>[];
    final reports = [
      for (final id in _selected) ...all.where((r) => r.id == id),
    ];
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ModelCostCompareScreen(reports: reports),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await widget.service.listAvailable();
    if (!mounted) return;
    setState(() => _all = r.valueOrNull ?? const []);
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final key = modelCostKey(_filter);
    final shown = all == null
        ? const <ModelCostReport>[]
        : all
            .where((r) =>
                key.isEmpty ||
                modelCostKey('${r.maker}${r.model ?? ''}').contains(key) ||
                modelCostKey(r.model ?? '').contains(key))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('車種ごとの維持費')),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: AppSpacing.paddingScreen,
                child: ElevatedButton.icon(
                  key: const Key('model_cost_compare'),
                  onPressed: _selected.length >= 2 ? _compare : null,
                  icon: const Icon(Icons.compare_arrows),
                  label: Text(
                    _selected.length >= 2
                        ? '${_selected.length}車種を比べる'
                        : 'もう1車種選ぶと比べられます',
                  ),
                ),
              ),
            ),
      body: all == null
          ? const AppLoadingCenter()
          : Column(
              children: [
                Padding(
                  padding: AppSpacing.paddingScreen,
                  child: TextField(
                    key: const Key('model_cost_filter'),
                    onChanged: (v) => setState(() => _filter = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'メーカー・車種（例: クーパー）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (all.length >= 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      'チェックを入れると、$maxCompare車種まで並べて比べられます',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Expanded(
                  child: shown.isEmpty
                      ? AppEmptyState(
                          icon: Icons.bar_chart_outlined,
                          title: all.isEmpty
                              ? 'まだ見られる車種がありません'
                              : '「$_filter」の車種はまだありません',
                          description: '同じ車の持ち主が5人集まった車種から、'
                              '順に見られるようになります。',
                          buttonLabel: '戻る',
                          onButtonPressed: () => Navigator.pop(context),
                        )
                      : ListView(
                          children: [
                            for (final r in shown)
                              ListTile(
                                key: Key('model_cost_${r.id}'),
                                leading: Checkbox(
                                  key: Key('model_cost_select_${r.id}'),
                                  value: _selected.contains(r.id),
                                  onChanged: _selected.contains(r.id) ||
                                          _selected.length < maxCompare
                                      ? (_) => _toggle(r.id)
                                      : null,
                                ),
                                title: Text(r.title),
                                subtitle: Text('持ち主 ${r.ownerCount}人'),
                                trailing: Text(
                                  r.annualEstimate == null
                                      ? '—'
                                      : '年 約${_money(r.annualEstimate!)}',
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => ModelCostReportScreen(
                                      report: r,
                                      showUsedCarSearch: true,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
