import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/maintenance_record.dart';
import '../providers/maintenance_provider.dart';
import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../widgets/common/app_card.dart';

/// 整備記録の統計・可視化画面
class MaintenanceStatsScreen extends StatelessWidget {
  final String vehicleName;

  const MaintenanceStatsScreen({super.key, required this.vehicleName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('メンテナンス統計'),
      ),
      body: Consumer<MaintenanceProvider>(
        builder: (context, provider, child) {
          if (provider.records.isEmpty) {
            return const Center(
              child: Text('メンテナンス履歴がありません'),
            );
          }

          final records = provider.records;
          final stats = _MaintenanceStats.fromRecords(records);

          return SingleChildScrollView(
            padding: AppSpacing.paddingScreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // サマリーカード
                _SummaryCards(stats: stats),
                AppSpacing.verticalLg,

                // 年間コスト推移
                Text('年間コスト', style: theme.textTheme.headlineLarge),
                AppSpacing.verticalSm,
                _YearlyCostSection(stats: stats),
                AppSpacing.verticalLg,

                // 月別コスト推移（直近12ヶ月）
                Text('月別コスト推移（直近12ヶ月）', style: theme.textTheme.headlineLarge),
                AppSpacing.verticalSm,
                _MonthlyCostChart(records: records),
                AppSpacing.verticalLg,

                // タイプ別内訳
                Text('タイプ別内訳', style: theme.textTheme.headlineLarge),
                AppSpacing.verticalSm,
                _TypeBreakdown(stats: stats),
                AppSpacing.verticalLg,

                // 店舗別集計
                if (stats.shopCosts.isNotEmpty) ...[
                  Text('店舗別集計', style: theme.textTheme.headlineLarge),
                  AppSpacing.verticalSm,
                  _ShopBreakdown(stats: stats),
                  AppSpacing.verticalLg,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 統計データの計算結果
class _MaintenanceStats {
  final int totalCost;
  final int recordCount;
  final int averageCostPerRecord;
  final Map<MaintenanceType, int> costByType;
  final Map<MaintenanceType, int> countByType;
  final Map<int, int> costByYear;
  final Map<String, int> shopCosts;
  final DateTime? oldestRecord;
  final DateTime? newestRecord;

  _MaintenanceStats({
    required this.totalCost,
    required this.recordCount,
    required this.averageCostPerRecord,
    required this.costByType,
    required this.countByType,
    required this.costByYear,
    required this.shopCosts,
    this.oldestRecord,
    this.newestRecord,
  });

  factory _MaintenanceStats.fromRecords(List<MaintenanceRecord> records) {
    if (records.isEmpty) {
      return _MaintenanceStats(
        totalCost: 0,
        recordCount: 0,
        averageCostPerRecord: 0,
        costByType: {},
        countByType: {},
        costByYear: {},
        shopCosts: {},
      );
    }

    final totalCost = records.fold(0, (sum, r) => sum + r.cost);
    final costByType = <MaintenanceType, int>{};
    final countByType = <MaintenanceType, int>{};
    final costByYear = <int, int>{};
    final shopCosts = <String, int>{};

    for (final record in records) {
      costByType[record.type] = (costByType[record.type] ?? 0) + record.cost;
      countByType[record.type] = (countByType[record.type] ?? 0) + 1;
      costByYear[record.date.year] = (costByYear[record.date.year] ?? 0) + record.cost;
      if (record.shopName != null && record.shopName!.isNotEmpty) {
        shopCosts[record.shopName!] = (shopCosts[record.shopName!] ?? 0) + record.cost;
      }
    }

    final sorted = List<MaintenanceRecord>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));

    return _MaintenanceStats(
      totalCost: totalCost,
      recordCount: records.length,
      averageCostPerRecord: totalCost ~/ records.length,
      costByType: costByType,
      countByType: countByType,
      costByYear: costByYear,
      shopCosts: shopCosts,
      oldestRecord: sorted.first.date,
      newestRecord: sorted.last.date,
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final _MaintenanceStats stats;

  const _SummaryCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                icon: Icons.receipt_long,
                label: '総費用',
                value: '¥${fmt.format(stats.totalCost)}',
                color: AppColors.primary,
              ),
            ),
            AppSpacing.horizontalSm,
            Expanded(
              child: _MiniStatCard(
                icon: Icons.history,
                label: '履歴数',
                value: '${stats.recordCount}件',
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        AppSpacing.verticalSm,
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                icon: Icons.calculate,
                label: '平均費用/回',
                value: '¥${fmt.format(stats.averageCostPerRecord)}',
                color: Colors.teal,
              ),
            ),
            AppSpacing.horizontalSm,
            Expanded(
              child: _MiniStatCard(
                icon: Icons.category,
                label: '種類数',
                value: '${stats.costByType.length}種類',
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              AppSpacing.horizontalXs,
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
          AppSpacing.verticalXs,
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _YearlyCostSection extends StatelessWidget {
  final _MaintenanceStats stats;

  const _YearlyCostSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###');
    final sortedYears = stats.costByYear.keys.toList()..sort();

    return AppCard(
      child: Column(
        children: [
          for (final year in sortedYears)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      '$year年',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AppSpacing.horizontalSm,
                  Expanded(
                    child: _HorizontalBar(
                      value: stats.costByYear[year]!,
                      maxValue: stats.costByYear.values.reduce((a, b) => a > b ? a : b),
                      color: AppColors.primary,
                    ),
                  ),
                  AppSpacing.horizontalSm,
                  Text(
                    '¥${fmt.format(stats.costByYear[year])}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
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

class _MonthlyCostChart extends StatelessWidget {
  final List<MaintenanceRecord> records;

  const _MonthlyCostChart({required this.records});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###');
    final now = DateTime.now();

    // 直近12ヶ月分のデータを集計
    final monthlyCosts = <String, int>{};
    for (int i = 11; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('yyyy/MM').format(month);
      monthlyCosts[key] = 0;
    }

    for (final record in records) {
      final key = DateFormat('yyyy/MM').format(record.date);
      if (monthlyCosts.containsKey(key)) {
        monthlyCosts[key] = monthlyCosts[key]! + record.cost;
      }
    }

    final maxCost = monthlyCosts.values.isEmpty
        ? 1
        : monthlyCosts.values.reduce((a, b) => a > b ? a : b);

    return AppCard(
      child: Column(
        children: [
          for (final entry in monthlyCosts.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 55,
                    child: Text(
                      '${entry.key.substring(5)}月',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: _HorizontalBar(
                      value: entry.value,
                      maxValue: maxCost == 0 ? 1 : maxCost,
                      color: AppColors.secondary,
                    ),
                  ),
                  AppSpacing.horizontalXs,
                  SizedBox(
                    width: 80,
                    child: Text(
                      entry.value > 0 ? '¥${fmt.format(entry.value)}' : '-',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: entry.value > 0 ? FontWeight.bold : null,
                      ),
                      textAlign: TextAlign.right,
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

class _TypeBreakdown extends StatelessWidget {
  final _MaintenanceStats stats;

  const _TypeBreakdown({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###');

    // コスト降順でソート
    final sortedTypes = stats.costByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      child: Column(
        children: [
          for (int i = 0; i < sortedTypes.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: sortedTypes[i].key.color,
                    child: Icon(
                      sortedTypes[i].key.icon,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  AppSpacing.horizontalSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sortedTypes[i].key.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${stats.countByType[sortedTypes[i].key]}回',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${fmt.format(sortedTypes[i].value)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(sortedTypes[i].value / stats.totalCost * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: sortedTypes[i].key.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShopBreakdown extends StatelessWidget {
  final _MaintenanceStats stats;

  const _ShopBreakdown({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,###');

    final sortedShops = stats.shopCosts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      child: Column(
        children: [
          for (int i = 0; i < sortedShops.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  const Icon(Icons.store, size: 20, color: Colors.grey),
                  AppSpacing.horizontalSm,
                  Expanded(
                    child: Text(
                      sortedShops[i].key,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '¥${fmt.format(sortedShops[i].value)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HorizontalBar extends StatelessWidget {
  final int value;
  final int maxValue;
  final Color color;

  const _HorizontalBar({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue > 0 ? value / maxValue : 0.0;

    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusXs,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: ratio.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.7),
            borderRadius: AppSpacing.borderRadiusXs,
          ),
        ),
      ),
    );
  }
}
