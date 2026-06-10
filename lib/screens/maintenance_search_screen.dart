import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/maintenance_record.dart';
import '../providers/maintenance_provider.dart';
import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../widgets/common/loading_indicator.dart';

/// 整備履歴検索画面
///
/// 現在リスニング中の車両の整備記録を、キーワード・タイプ・並び順で
/// 絞り込んで一覧表示する。フィルタはすべて端末内で完結する。
class MaintenanceSearchScreen extends StatefulWidget {
  const MaintenanceSearchScreen({super.key});

  @override
  State<MaintenanceSearchScreen> createState() =>
      _MaintenanceSearchScreenState();
}

class _MaintenanceSearchScreenState extends State<MaintenanceSearchScreen> {
  final TextEditingController _keywordController = TextEditingController();
  final Set<MaintenanceType> _selectedTypes = {};
  MaintenanceSortBy _sortBy = MaintenanceSortBy.dateDesc;

  /// よく使われるタイプをチップとして先頭に出す
  static const _quickFilterTypes = [
    MaintenanceType.oilChange,
    MaintenanceType.tireChange,
    MaintenanceType.carInspection,
    MaintenanceType.legalInspection12,
    MaintenanceType.repair,
    MaintenanceType.partsReplacement,
    MaintenanceType.washing,
  ];

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  String _sortLabel(MaintenanceSortBy sort) {
    switch (sort) {
      case MaintenanceSortBy.dateDesc:
        return '日付が新しい順';
      case MaintenanceSortBy.dateAsc:
        return '日付が古い順';
      case MaintenanceSortBy.costDesc:
        return '費用が高い順';
      case MaintenanceSortBy.costAsc:
        return '費用が安い順';
      case MaintenanceSortBy.mileageDesc:
        return '走行距離が多い順';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<MaintenanceProvider>();

    final results = provider.searchRecords(
      keyword: _keywordController.text,
      types: _selectedTypes,
      sortBy: _sortBy,
    );
    final totalCost = results.fold<int>(0, (sum, r) => sum + r.cost);
    final costFormat = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(
        title: const Text('整備履歴を検索'),
        actions: [
          PopupMenuButton<MaintenanceSortBy>(
            icon: const Icon(Icons.sort),
            tooltip: '並び替え',
            initialValue: _sortBy,
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => MaintenanceSortBy.values
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          if (s == _sortBy)
                            const Icon(Icons.check,
                                size: 16, color: AppColors.primary)
                          else
                            const SizedBox(width: 16),
                          AppSpacing.horizontalXs,
                          Text(_sortLabel(s)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- 検索フィールド ----
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: TextField(
              controller: _keywordController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'タイトル・店舗名・メモで検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _keywordController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'クリア',
                        onPressed: () {
                          _keywordController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),

          // ---- タイプフィルタチップ ----
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              children: _quickFilterTypes.map((type) {
                final selected = _selectedTypes.contains(type);
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: FilterChip(
                    label: Text(type.displayName),
                    selected: selected,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      setState(() {
                        if (selected) {
                          _selectedTypes.remove(type);
                        } else {
                          _selectedTypes.add(type);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // ---- 結果サマリー ----
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(
              children: [
                Text(
                  '${results.length}件',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                AppSpacing.horizontalSm,
                Text(
                  '合計 ¥${costFormat.format(totalCost)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  _sortLabel(_sortBy),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ---- 結果リスト ----
          Expanded(
            child: results.isEmpty
                ? const AppEmptyState(
                    icon: Icons.search_off,
                    title: '該当する整備記録がありません',
                    description: 'キーワードやフィルタを変更してみてください',
                  )
                : ListView.builder(
                    padding: AppSpacing.paddingScreen,
                    itemCount: results.length,
                    itemBuilder: (context, index) =>
                        _SearchResultCard(record: results[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 検索結果カード
// ---------------------------------------------------------------------------

class _SearchResultCard extends StatelessWidget {
  final MaintenanceRecord record;

  const _SearchResultCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('yyyy/MM/dd');
    final costFormat = NumberFormat('#,###');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: record.typeColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(record.typeIcon,
                            size: 16, color: record.typeColor),
                        AppSpacing.horizontalXs,
                        Expanded(
                          child: Text(
                            record.title,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '¥${costFormat.format(record.cost)}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.verticalXxs,
                    Row(
                      children: [
                        Icon(Icons.event,
                            size: 12,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.textTertiary),
                        AppSpacing.horizontalXxs,
                        Text(
                          dateFormat.format(record.date),
                          style: theme.textTheme.bodySmall,
                        ),
                        if (record.mileageAtService != null) ...[
                          AppSpacing.horizontalSm,
                          Icon(Icons.speed,
                              size: 12,
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.textTertiary),
                          AppSpacing.horizontalXxs,
                          Text(
                            '${costFormat.format(record.mileageAtService)} km',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        if (record.shopName != null &&
                            record.shopName!.isNotEmpty) ...[
                          AppSpacing.horizontalSm,
                          Icon(Icons.store,
                              size: 12,
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.textTertiary),
                          AppSpacing.horizontalXxs,
                          Flexible(
                            child: Text(
                              record.shopName!,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
