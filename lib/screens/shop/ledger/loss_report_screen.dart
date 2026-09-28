import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../services/shop_ledger_service.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/loading_indicator.dart';
import 'ledger_format.dart';

/// 車検の取りこぼし（2026-09-29 プロダクト評価 #1）。
///
/// 店の経営の数字（車検の粗利 = 満了台数 × (1 − 取りこぼし率) × 1台の粗利）の
/// 起点。**これまで取りこぼしの台数は誰も把握できていなかった。**
///
/// 整備履歴の取込が古いときは率を出さない。入庫したのに記録が無い車まで
/// 取りこぼしに見えて、実際より悪い数字を信じてしまうため。
class LossReportScreen extends StatefulWidget {
  final ShopLedgerService service;
  final String shopId;
  final void Function(String customerId)? onOpenCustomer;

  const LossReportScreen({
    super.key,
    required this.service,
    required this.shopId,
    this.onOpenCustomer,
  });

  @override
  State<LossReportScreen> createState() => _LossReportScreenState();
}

class _LossReportScreenState extends State<LossReportScreen> {
  LossReport? _report;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await widget.service.lossReport(shopId: widget.shopId);
    if (!mounted) return;
    setState(() {
      _report = r.valueOrNull;
      _error = r.errorOrNull?.userMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('車検の取りこぼし')),
      body: r == null
          ? (_error == null
              ? const AppLoadingCenter()
              : AppEmptyState(
                  icon: Icons.error_outline,
                  title: '集計できませんでした',
                  description: _error,
                  buttonLabel: 'もう一度',
                  onButtonPressed: _load,
                ))
          : _body(context, r),
    );
  }

  Widget _body(BuildContext context, LossReport r) {
    final theme = Theme.of(context);
    final maxExpired =
        r.months.map((m) => m.expired).fold<int>(1, (a, b) => b > a ? b : a);
    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('直近12か月の取りこぼし率', style: theme.textTheme.bodyMedium),
              AppSpacing.verticalXs,
              Text(
                r.isStale
                    ? 'まだ出せません'
                    : (r.rate == null
                        ? '満了した車はまだありません'
                        : '${(r.rate! * 100).round()}%'),
                key: const Key('loss_rate'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: r.isStale ? null : AppColors.primary,
                ),
              ),
              if (!r.isStale && r.rate != null)
                Text('満了した ${r.expired}台のうち ${r.lost}台が、車検で入庫していません'),
              if (r.isStale) ...[
                AppSpacing.verticalXs,
                Text(
                  r.lastImportAt == null
                      ? '整備履歴がまだ取り込まれていません。取込が無いと、入庫した車まで'
                          '取りこぼしに見えるため、率は出していません。'
                      : '最後に整備履歴を取り込んだのが ${ledgerDate(r.lastImportAt!)} です。'
                          '30日より古いと、入庫した車まで取りこぼしに見えるため、率は出していません。',
                  key: const Key('loss_stale_note'),
                  style: const TextStyle(color: AppColors.warning),
                ),
                AppSpacing.verticalXs,
                const Text('顧客台帳の右上の取込ボタン →「整備履歴」から取り込めます。'),
              ],
            ],
          ),
        ),
        AppSpacing.verticalMd,
        Text('満了した月ごと', style: theme.textTheme.titleMedium),
        AppSpacing.verticalXs,
        for (final m in r.months)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text('${m.month.year % 100}年${m.month.month}月'),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth * m.expired / maxExpired;
                      final lostW =
                          m.expired == 0 ? 0.0 : w * m.lost / m.expired;
                      return Row(
                        children: [
                          Container(
                            width: w - lostW,
                            height: 12,
                            color: AppColors.primary.withValues(alpha: 0.6),
                          ),
                          Container(
                            width: lostW,
                            height: 12,
                            color: AppColors.error.withValues(alpha: 0.7),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    m.expired == 0 ? '—' : '${m.lost} / ${m.expired}台',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        Text('青＝車検で入庫、赤＝入庫なし', style: theme.textTheme.bodySmall),
        AppSpacing.verticalLg,
        Text('声をかける相手（${r.lostVehicles.length}台）',
            style: theme.textTheme.titleMedium),
        if (r.lostVehicles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text('取りこぼした車はありません。'),
          ),
        for (final v in r.lostVehicles)
          ListTile(
            key: Key('loss_${v.id}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.directions_car_outlined),
            title: Text(v.customerName),
            subtitle: Text([
              v.displayName,
              if (v.plate != null) v.plate!,
            ].join('・')),
            trailing: Text('満了 ${ledgerDate(v.inspectionExpiry!)}'),
            onTap: widget.onOpenCustomer == null
                ? null
                : () => widget.onOpenCustomer!(v.customerId),
          ),
        AppSpacing.verticalMd,
        Text(
          '数え方: いまの満了日が直近12か月に過ぎた車のうち、満了日の60日前から'
          '今日までに「車検」「継続検査」の整備履歴が無いものを取りこぼしとしています。'
          '名簿を取り直して満了日が先に進んだ車は、数えなくなります。',
          style: theme.textTheme.bodySmall,
        ),
        AppSpacing.verticalXl,
      ],
    );
  }
}
