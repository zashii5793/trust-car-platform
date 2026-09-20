import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/fuel_record.dart';
import '../../services/fuel_service.dart';
import 'add_fuel_screen.dart';

/// 給油の記録を振り返る画面。
///
/// `docs/HABIT_DESIGN.md` 打ち手1で「唯一の月単位の接点」と位置づけながら、
/// **記録はできるのに見る場所が無かった**（保存した直後に燃費が1回出るだけ）。
/// 1年で75件たまる記録なので、溜めた意味が見えないと続かない。
///
/// 出すのは4つ。**入れた量ではなく、かかった額と燃費**を先に置く。
///
/// ```
///  回数        何回入れたか
///  平均燃費    満タン法。継ぎ足しは次の満タンの量に足す
///  給油代      払った額の合計
///  1kmあたり   維持費の実感にいちばん近い数字
/// ```
class FuelHistoryScreen extends StatefulWidget {
  final FuelService service;
  final String vehicleId;
  final String userId;

  /// 見出しに出す車名。
  final String vehicleName;

  /// 記録するときに入力欄へ添える、いまの走行距離。
  final int? currentOdometer;

  const FuelHistoryScreen({
    super.key,
    required this.service,
    required this.vehicleId,
    required this.userId,
    required this.vehicleName,
    this.currentOdometer,
  });

  @override
  State<FuelHistoryScreen> createState() => _FuelHistoryScreenState();
}

class _FuelHistoryScreenState extends State<FuelHistoryScreen> {
  List<FuelEntry>? _entries;
  FuelSummary _summary = FuelSummary.empty;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await widget.service.recordsFor(
      widget.vehicleId,
      userId: widget.userId,
    );
    if (!mounted) return;

    result.when(
      success: (records) => setState(() {
        _entries = FuelEfficiency.history(records);
        _summary = FuelSummary.of(records);
        _error = null;
      }),
      failure: (err) => setState(() {
        _entries = const [];
        _error = err.userMessage;
      }),
    );
  }

  Future<void> _addRecord() async {
    // いまの走行距離は、直近の給油があればそちらを優先する。車両側の値は
    // 更新を忘れていることがある。
    final lastOdometer =
        _entries?.map((e) => e.record.odometer).whereType<int>().firstOrNull ??
            widget.currentOdometer;

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AddFuelScreen(
          service: widget.service,
          vehicleId: widget.vehicleId,
          userId: widget.userId,
          lastOdometer: lastOdometer,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _delete(FuelRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この記録を消しますか'),
        content: Text(
          '${DateFormat('yyyy/MM/dd').format(record.date)} の給油'
          '（${record.liters.toStringAsFixed(2)}L）を消します。'
          '\n\n消すと、前後の回の燃費も計算し直されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('やめる'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('消す'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await widget.service.delete(record.id);
    if (!mounted) return;
    result.when(
      success: (_) => _load(),
      failure: (err) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.userMessage)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('給油の記録'),
        actions: [
          IconButton(
            key: const Key('fuel_history_add_button'),
            icon: const Icon(Icons.add),
            tooltip: '給油を記録',
            onPressed: _addRecord,
          ),
        ],
      ),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: entries.isEmpty
                  ? _EmptyState(error: _error, onAdd: _addRecord)
                  : ListView.separated(
                      padding: AppSpacing.paddingScreen,
                      itemCount: entries.length + 1,
                      separatorBuilder: (_, i) => i == 0
                          ? AppSpacing.verticalSm
                          : const Divider(height: 1),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _FuelSummaryCard(
                            summary: _summary,
                            vehicleName: widget.vehicleName,
                          );
                        }
                        return _FuelRow(
                          entry: entries[i - 1],
                          onDelete: () => _delete(entries[i - 1].record),
                        );
                      },
                    ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? error;
  final VoidCallback onAdd;

  const _EmptyState({required this.error, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        AppSpacing.verticalXl,
        Icon(
          Icons.local_gas_station_outlined,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        AppSpacing.verticalMd,
        Text(
          error ?? 'まだ給油の記録がありません',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall,
        ),
        AppSpacing.verticalXs,
        Text(
          '入力は日付・給油量・金額・走行距離の4つだけ。'
          '満タンで2回記録すると、燃費が出ます。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        AppSpacing.verticalMd,
        Center(
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('給油を記録する'),
          ),
        ),
      ],
    );
  }
}

class _FuelSummaryCard extends StatelessWidget {
  final FuelSummary summary;
  final String vehicleName;

  const _FuelSummaryCard({required this.summary, required this.vehicleName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final yen = NumberFormat('#,###');

    return Card(
      child: Padding(
        padding: AppSpacing.paddingCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vehicleName,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            AppSpacing.verticalSm,
            Row(
              children: [
                _SummaryItem(
                  label: '給油',
                  value: '${summary.count}回',
                ),
                _SummaryItem(
                  label: '平均燃費',
                  value: summary.averageKmPerLiter == null
                      ? '—'
                      : '${summary.averageKmPerLiter!.toStringAsFixed(1)} km/L',
                  highlight: true,
                ),
              ],
            ),
            AppSpacing.verticalSm,
            Row(
              children: [
                _SummaryItem(
                  label: '給油代',
                  value: '¥${yen.format(summary.totalCost)}',
                ),
                _SummaryItem(
                  label: '1kmあたり',
                  value: summary.costPerKm == null
                      ? '—'
                      : '¥${summary.costPerKm!.toStringAsFixed(1)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryItem({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Semantics(
        label: '$label $value',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              AppSpacing.verticalXxs,
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: highlight ? AppColors.accentDrive : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FuelRow extends StatelessWidget {
  final FuelEntry entry;
  final VoidCallback onDelete;

  const _FuelRow({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = entry.record;
    final yen = NumberFormat('#,###');
    final pricePerLiter = record.pricePerLiter;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      title: Row(
        children: [
          Text(
            DateFormat('yyyy/MM/dd').format(record.date),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          // 満タンでない回は、燃費が出ない理由がその場で分かるようにする。
          if (!record.isFullTank) ...[
            AppSpacing.horizontalXs,
            Text('継ぎ足し', style: theme.textTheme.bodySmall),
          ],
        ],
      ),
      subtitle: Text(
        [
          '${record.liters.toStringAsFixed(2)} L',
          if (pricePerLiter != null) '¥${pricePerLiter.toStringAsFixed(1)}/L',
          if (record.odometer != null) '${yen.format(record.odometer)} km',
        ].join(' ・ '),
        style: theme.textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '¥${yen.format(record.cost)}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.verticalXxs,
          Text(
            entry.kmPerLiter == null
                ? '—'
                : '${entry.kmPerLiter!.toStringAsFixed(1)} km/L',
            style: theme.textTheme.bodySmall?.copyWith(
              color: entry.kmPerLiter == null ? null : AppColors.accentDrive,
              fontWeight: entry.kmPerLiter == null ? null : FontWeight.w600,
            ),
          ),
        ],
      ),
      onLongPress: onDelete,
    );
  }
}
