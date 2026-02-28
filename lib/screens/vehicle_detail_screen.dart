import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/vehicle.dart';
import '../models/maintenance_record.dart';
import '../providers/maintenance_provider.dart';
import '../core/constants/colors.dart';
import '../core/constants/spacing.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/loading_indicator.dart';
import 'add_maintenance_screen.dart';
import 'export/export_dialog.dart';
import 'parts/part_recommendation_screen.dart';
import 'vehicle_edit_screen.dart';
import 'maintenance_stats_screen.dart';

class VehicleDetailScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  late Vehicle _vehicle;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
  }

  String _formatNumber(int number) {
    final formatter = NumberFormat('#,###');
    return formatter.format(number);
  }

  Future<void> _navigateToEdit() async {
    final result = await Navigator.push<Vehicle>(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleEditScreen(vehicle: _vehicle),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _vehicle = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_vehicle.maker} ${_vehicle.model}'),
        actions: [
          // PDF出力ボタン
          Consumer<MaintenanceProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'PDFで出力',
                onPressed: provider.records.isEmpty
                    ? null
                    : () {
                        showExportDialog(
                          context: context,
                          vehicle: _vehicle,
                          records: provider.records,
                        );
                      },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.build_circle_outlined),
            tooltip: 'パーツ提案',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PartRecommendationScreen(vehicle: _vehicle),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '編集',
            onPressed: _navigateToEdit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 車両画像
            _VehicleImage(
              imageUrl: _vehicle.imageUrl,
              isDark: isDark,
            ),

            // 車両基本情報
            Padding(
              padding: AppSpacing.paddingScreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_vehicle.maker} ${_vehicle.model}',
                    style: theme.textTheme.displayMedium,
                  ),
                  AppSpacing.verticalSm,
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: '年式',
                    value: '${_vehicle.year}年',
                  ),
                  _InfoRow(
                    icon: Icons.star_outline,
                    label: 'グレード',
                    value: _vehicle.grade,
                  ),
                  _InfoRow(
                    icon: Icons.speed,
                    label: '走行距離',
                    value: '${_formatNumber(_vehicle.mileage)} km',
                  ),
                  if (_vehicle.inspectionExpiryDate != null)
                    _InfoRow(
                      icon: Icons.verified_outlined,
                      label: '車検満了日',
                      value: DateFormat('yyyy年MM月dd日')
                          .format(_vehicle.inspectionExpiryDate!),
                      valueColor: _vehicle.isInspectionExpired
                          ? AppColors.error
                          : _vehicle.isInspectionDueSoon
                              ? AppColors.warning
                              : null,
                    ),
                  if (_vehicle.insuranceExpiryDate != null)
                    _InfoRow(
                      icon: Icons.shield_outlined,
                      label: '自賠責満了日',
                      value: DateFormat('yyyy年MM月dd日')
                          .format(_vehicle.insuranceExpiryDate!),
                      valueColor: (_vehicle.daysUntilInsuranceExpiry != null &&
                              _vehicle.daysUntilInsuranceExpiry! < 0)
                          ? AppColors.error
                          : _vehicle.isInsuranceDueSoon
                              ? AppColors.warning
                              : null,
                    ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 統計情報
            _StatisticsSection(
              vehicleId: _vehicle.id,
              onDetailsTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MaintenanceStatsScreen(
                      vehicleName: '${_vehicle.maker} ${_vehicle.model}',
                    ),
                  ),
                );
              },
            ),

            const Divider(height: 1),

            // 履歴セクション
            Padding(
              padding: AppSpacing.paddingScreen,
              child: Text(
                'メンテナンス履歴',
                style: theme.textTheme.headlineLarge,
              ),
            ),

            // 履歴タイムライン
            _MaintenanceTimeline(
              vehicleId: _vehicle.id,
              currentVehicleMileage: _vehicle.mileage,
            ),

            AppSpacing.verticalLg,
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddMaintenanceScreen(
                vehicleId: _vehicle.id,
                currentVehicleMileage: _vehicle.mileage,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('履歴を追加'),
      ),
    );
  }
}

class _VehicleImage extends StatelessWidget {
  final String? imageUrl;
  final bool isDark;

  const _VehicleImage({this.imageUrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        height: 250,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 250,
      color: isDark ? AppColors.darkCard : AppColors.backgroundLight,
      child: Center(
        child: Icon(
          Icons.directions_car,
          size: 100,
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppSpacing.iconSm,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
          ),
          AppSpacing.horizontalXs,
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: valueColor,
              fontWeight:
                  valueColor != null ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsSection extends StatelessWidget {
  final String vehicleId;
  final VoidCallback? onDetailsTap;

  const _StatisticsSection({required this.vehicleId, this.onDetailsTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<MaintenanceProvider>(
      builder: (context, provider, child) {
        final totalCost = provider.getTotalCost();
        final recordCount = provider.records.length;

        return Padding(
          padding: AppSpacing.paddingScreen,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.receipt_long,
                      label: '総費用',
                      value: '¥${NumberFormat('#,###').format(totalCost)}',
                      color: AppColors.primary,
                    ),
                  ),
                  AppSpacing.horizontalMd,
                  Expanded(
                    child: _StatCard(
                      icon: Icons.history,
                      label: '履歴数',
                      value: '$recordCount 件',
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              if (recordCount > 0 && onDetailsTap != null) ...[
                AppSpacing.verticalSm,
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: onDetailsTap,
                    icon: const Icon(Icons.bar_chart, size: 18),
                    label: const Text('統計の詳細を見る'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
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
              Icon(icon, size: AppSpacing.iconSm, color: color),
              AppSpacing.horizontalXs,
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
          AppSpacing.verticalXs,
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline: replaces the old flat list
// ---------------------------------------------------------------------------

class _MaintenanceTimeline extends StatelessWidget {
  final String vehicleId;
  final int currentVehicleMileage;

  const _MaintenanceTimeline({
    required this.vehicleId,
    required this.currentVehicleMileage,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MaintenanceProvider>(
      builder: (context, maintenanceProvider, child) {
        if (maintenanceProvider.isLoading) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: AppLoadingCenter(),
          );
        }

        if (maintenanceProvider.records.isEmpty) {
          return const AppEmptyState(
            icon: Icons.history,
            title: 'メンテナンス履歴がありません',
            description: '「履歴を追加」ボタンから追加できます',
          );
        }

        final records = maintenanceProvider.records;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          itemCount: records.length,
          itemBuilder: (context, index) {
            return _TimelineItem(
              record: records[index],
              isFirst: index == 0,
              isLast: index == records.length - 1,
              onTap: () => _showMaintenanceDetailSheet(
                context,
                records[index],
                maintenanceProvider,
                currentVehicleMileage,
              ),
            );
          },
        );
      },
    );
  }

  /// Show the record detail as a modal BottomSheet.
  void _showMaintenanceDetailSheet(
    BuildContext context,
    MaintenanceRecord record,
    MaintenanceProvider provider,
    int currentVehicleMileage,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _MaintenanceDetailSheet(
        record: record,
        provider: provider,
        currentVehicleMileage: currentVehicleMileage,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single timeline row
// ---------------------------------------------------------------------------

class _TimelineItem extends StatelessWidget {
  final MaintenanceRecord record;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _TimelineItem({
    required this.record,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  static const double _lineWidth = 2.0;
  static const double _leftColumnWidth = 48.0;
  static const double _avatarRadius = 18.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = record.typeColor;
    final isDark = theme.brightness == Brightness.dark;
    final lineColor = isDark ? AppColors.darkCard : AppColors.divider;
    final dateFormat = DateFormat('yyyy/MM/dd');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Left: timeline line + icon ----
          SizedBox(
            width: _leftColumnWidth,
            child: Column(
              children: [
                // Top segment of the line
                SizedBox(
                  width: _lineWidth,
                  height: _avatarRadius + 4,
                  child: isFirst
                      ? const SizedBox.shrink()
                      : ColoredBox(color: lineColor),
                ),
                // Icon circle
                CircleAvatar(
                  radius: _avatarRadius,
                  backgroundColor: typeColor,
                  child: Icon(
                    record.typeIcon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                // Bottom segment of the line — stretches to fill remaining height
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : Center(
                          child: SizedBox(
                            width: _lineWidth,
                            child: ColoredBox(color: lineColor),
                          ),
                        ),
                ),
              ],
            ),
          ),

          AppSpacing.horizontalSm,

          // ---- Right: card ----
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: AppSpacing.md,
              ),
              child: GestureDetector(
                onTap: onTap,
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date + type badge
                      Row(
                        children: [
                          Text(
                            dateFormat.format(record.date),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.textTertiary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: AppSpacing.borderRadiusXs,
                            ),
                            child: Text(
                              record.typeDisplayName,
                              style: TextStyle(
                                color: typeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.verticalXxs,
                      // Title
                      Text(
                        record.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppSpacing.verticalXxs,
                      // Cost
                      Text(
                        '¥${NumberFormat('#,###').format(record.cost)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                      // Shop name (optional)
                      if (record.shopName != null &&
                          record.shopName!.isNotEmpty) ...[
                        AppSpacing.verticalXxs,
                        Row(
                          children: [
                            Icon(
                              Icons.store_outlined,
                              size: 13,
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              record.shopName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail BottomSheet
// ---------------------------------------------------------------------------

class _MaintenanceDetailSheet extends StatelessWidget {
  final MaintenanceRecord record;
  final MaintenanceProvider provider;
  final int currentVehicleMileage;

  const _MaintenanceDetailSheet({
    required this.record,
    required this.provider,
    required this.currentVehicleMileage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = record.typeColor;
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('yyyy年MM月dd日');

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: AppSpacing.paddingScreen,
                children: [
                  // Header: icon + title + date
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: typeColor,
                        child: Icon(
                          record.typeIcon,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      AppSpacing.horizontalMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              dateFormat.format(record.date),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  AppSpacing.verticalMd,

                  // Cost (large)
                  Text(
                    '¥${NumberFormat('#,###').format(record.cost)}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                  ),

                  AppSpacing.verticalMd,
                  const Divider(),
                  AppSpacing.verticalSm,

                  // Shop name
                  if (record.shopName != null && record.shopName!.isNotEmpty)
                    _DetailRow(
                      icon: Icons.store_outlined,
                      label: '整備店',
                      value: record.shopName!,
                    ),

                  // Mileage
                  if (record.mileageAtService != null)
                    _DetailRow(
                      icon: Icons.speed_outlined,
                      label: '施工時走行距離',
                      value:
                          '${NumberFormat('#,###').format(record.mileageAtService)} km',
                    ),

                  // Description
                  if (record.description != null &&
                      record.description!.isNotEmpty) ...[
                    AppSpacing.verticalSm,
                    Text(
                      'メモ',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary,
                      ),
                    ),
                    AppSpacing.verticalXxs,
                    Text(
                      record.description!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],

                  // Work items
                  if (record.workItems.isNotEmpty) ...[
                    AppSpacing.verticalMd,
                    Text(
                      '作業内容',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary,
                      ),
                    ),
                    AppSpacing.verticalXxs,
                    ...record.workItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xxs,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16),
                            AppSpacing.horizontalXs,
                            Expanded(
                              child: Text(
                                item.name,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              '¥${NumberFormat('#,###').format(item.laborCost)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  AppSpacing.verticalLg,

                  // Edit button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddMaintenanceScreen(
                              vehicleId: record.vehicleId,
                              currentVehicleMileage: currentVehicleMileage,
                              existingRecord: record,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('この記録を編集'),
                    ),
                  ),

                  AppSpacing.verticalSm,

                  // Delete button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(context),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('この記録を削除'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),

                  AppSpacing.verticalMd,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('記録を削除'),
        content: const Text('この整備記録を削除します。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await provider.deleteMaintenanceRecord(record.id);
      if (context.mounted) {
        if (success) {
          Navigator.pop(context); // close the sheet only on success
        } else {
          showErrorSnackBar(context, '削除に失敗しました。再度お試しください。');
        }
      }
    }
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
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
          ),
          AppSpacing.horizontalXs,
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
