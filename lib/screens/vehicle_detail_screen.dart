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
import 'vehicle_edit_screen.dart';

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
                ],
              ),
            ),

            const Divider(height: 1),

            // 統計情報
            _StatisticsSection(vehicleId: _vehicle.id),

            const Divider(height: 1),

            // 履歴セクション
            Padding(
              padding: AppSpacing.paddingScreen,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'メンテナンス履歴',
                    style: theme.textTheme.headlineLarge,
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddMaintenanceScreen(vehicleId: _vehicle.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('追加'),
                  ),
                ],
              ),
            ),

            // 履歴一覧
            _MaintenanceList(vehicleId: _vehicle.id),

            AppSpacing.verticalLg,
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddMaintenanceScreen(vehicleId: _vehicle.id),
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

  const _InfoRow({
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
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _StatisticsSection extends StatelessWidget {
  final String vehicleId;

  const _StatisticsSection({required this.vehicleId});

  @override
  Widget build(BuildContext context) {
    return Consumer<MaintenanceProvider>(
      builder: (context, provider, child) {
        final totalCost = provider.getTotalCost();
        final recordCount = provider.records.length;

        return Padding(
          padding: AppSpacing.paddingScreen,
          child: Row(
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

class _MaintenanceList extends StatelessWidget {
  final String vehicleId;

  const _MaintenanceList({required this.vehicleId});

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

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: maintenanceProvider.records.length,
          separatorBuilder: (context, index) => AppSpacing.verticalXs,
          itemBuilder: (context, index) {
            final record = maintenanceProvider.records[index];
            return _MaintenanceRecordCard(record: record);
          },
        );
      },
    );
  }
}

class _MaintenanceRecordCard extends StatelessWidget {
  final MaintenanceRecord record;

  const _MaintenanceRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = record.typeColor;
    final dateFormat = DateFormat('yyyy/MM/dd');

    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor,
          child: Icon(
            record.typeIcon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          record.title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.verticalXxs,
            Text(
              dateFormat.format(record.date),
              style: theme.textTheme.bodySmall,
            ),
            Text(
              '¥${NumberFormat('#,###').format(record.cost)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: typeColor,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.1),
            borderRadius: AppSpacing.borderRadiusXs,
          ),
          child: Text(
            record.typeDisplayName,
            style: TextStyle(
              color: typeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        contentPadding: AppSpacing.paddingCard,
      ),
    );
  }
}
