import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../core/utils/inspection_urgency.dart';
import '../../models/vehicle.dart';
import '../../providers/fleet_provider.dart';
import '../../services/fleet_service.dart';

/// Fleet management dashboard for business account managers.
///
/// Creates its own [FleetProvider] scoped to [companyId].
class FleetDashboardScreen extends StatelessWidget {
  final String companyId;

  const FleetDashboardScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FleetProvider(
        fleetService: sl.get<FleetService>(),
        companyId: companyId,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('フリート管理'),
          actions: [
            Consumer<FleetProvider>(
              builder: (context, p, _) => IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: p.refresh,
              ),
            ),
          ],
        ),
        body: Consumer<FleetProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.errorMessage != null) {
              return Center(child: Text(provider.errorMessage!));
            }
            return _FleetBody(provider: provider);
          },
        ),
      ),
    );
  }
}

class _FleetBody extends StatelessWidget {
  final FleetProvider provider;

  const _FleetBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    final stats = provider.stats;
    final vehicles = provider.filteredVehicles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stats != null) _StatsHeader(stats: stats),
        _FleetCodeTile(companyId: provider.companyId),
        _FilterChipBar(provider: provider),
        const Divider(height: 1),
        Expanded(
          child: vehicles.isEmpty
              ? _EmptyState(filter: provider.filter)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm),
                  itemCount: vehicles.length,
                  itemBuilder: (_, i) =>
                      _VehicleCard(vehicle: vehicles[i]),
                ),
        ),
      ],
    );
  }
}

// ── Stats header ─────────────────────────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  final FleetStats stats;
  const _StatsHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          _StatChip(
            label: '合計',
            value: stats.total,
            color: Colors.white,
          ),
          const SizedBox(width: AppSpacing.md),
          _StatChip(
            label: '緊急',
            value: stats.critical,
            color: AppColors.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatChip(
            label: '注意',
            value: stats.warning,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatChip(
            label: '正常',
            value: stats.normal,
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip(
      {required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold),
        ),
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

// ── Fleet code tile ───────────────────────────────────────────────────────────

class _FleetCodeTile extends StatelessWidget {
  final String companyId;
  const _FleetCodeTile({required this.companyId});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const Key('fleet_company_code'),
      leading: const Icon(Icons.qr_code, color: AppColors.primary),
      title: const Text('フリートコード（招待用）'),
      subtitle: Text(
        companyId,
        style: const TextStyle(
            fontFamily: 'monospace', fontSize: 13),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy),
        tooltip: 'コピー',
        onPressed: () {
          Clipboard.setData(ClipboardData(text: companyId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('フリートコードをコピーしました'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}

// ── Filter chips ─────────────────────────────────────────────────────────────

class _FilterChipBar extends StatelessWidget {
  final FleetProvider provider;
  const _FilterChipBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          _Chip(
            key: const Key('fleet_filter_all'),
            label: 'すべて',
            selected: provider.filter == FleetFilter.all,
            onTap: () => provider.setFilter(FleetFilter.all),
          ),
          const SizedBox(width: AppSpacing.xs),
          _Chip(
            key: const Key('fleet_filter_critical'),
            label: '緊急',
            selected: provider.filter == FleetFilter.critical,
            selectedColor: AppColors.error,
            onTap: () => provider.setFilter(FleetFilter.critical),
          ),
          const SizedBox(width: AppSpacing.xs),
          _Chip(
            key: const Key('fleet_filter_warning'),
            label: '注意',
            selected: provider.filter == FleetFilter.warning,
            selectedColor: AppColors.warning,
            onTap: () => provider.setFilter(FleetFilter.warning),
          ),
          const SizedBox(width: AppSpacing.xs),
          _Chip(
            key: const Key('fleet_filter_normal'),
            label: '正常',
            selected: provider.filter == FleetFilter.normal,
            selectedColor: AppColors.success,
            onTap: () => provider.setFilter(FleetFilter.normal),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? AppColors.primary;
    return FilterChip(
      key: key,
      label: Text(label),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.15),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: selected ? color : AppColors.textSecondary,
        fontWeight:
            selected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

// ── Vehicle card ─────────────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  const _VehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final urgency = inspectionUrgencyForDays(vehicle.daysUntilInspection);
    final urgencyKey = switch (urgency) {
      InspectionUrgency.critical => 'critical',
      InspectionUrgency.warning => 'warning',
      _ => 'normal',
    };

    return Card(
      key: Key('fleet_vehicle_card_$urgencyKey'),
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: ListTile(
        leading: _UrgencyIcon(urgency: urgency),
        title: Text(
          vehicle.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: _VehicleSubtitle(vehicle: vehicle),
        trailing: Text(
          '${vehicle.year}年式',
          style: const TextStyle(
              color: AppColors.textTertiary, fontSize: 12),
        ),
      ),
    );
  }
}

class _UrgencyIcon extends StatelessWidget {
  final InspectionUrgency urgency;
  const _UrgencyIcon({required this.urgency});

  @override
  Widget build(BuildContext context) {
    return switch (urgency) {
      InspectionUrgency.critical => const Icon(Icons.warning_amber_rounded,
          color: AppColors.error, size: AppSpacing.iconMd),
      InspectionUrgency.warning => const Icon(Icons.access_time_rounded,
          color: AppColors.warning, size: AppSpacing.iconMd),
      _ => const Icon(Icons.check_circle_outline_rounded,
          color: AppColors.success, size: AppSpacing.iconMd),
    };
  }
}

class _VehicleSubtitle extends StatelessWidget {
  final Vehicle vehicle;
  const _VehicleSubtitle({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final days = vehicle.daysUntilInspection;
    String inspectionText;
    if (days == null) {
      inspectionText = '車検日未登録';
    } else if (days < 0) {
      inspectionText = '車検期限切れ';
    } else {
      inspectionText = '車検まで $days 日';
    }

    return Text(
      inspectionText,
      style: const TextStyle(fontSize: 12),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final FleetFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final message = filter == FleetFilter.all
        ? 'フリートに車両がありません\nフリートコードを社員に共有して車両を追加しましょう'
        : 'この緊急度の車両はありません';
    return Center(
      key: const Key('fleet_empty_state'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car_outlined,
                size: AppSpacing.iconXl,
                color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
