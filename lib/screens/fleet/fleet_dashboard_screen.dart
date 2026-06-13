import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../core/utils/inspection_urgency.dart';
import '../../core/utils/expiry_summary.dart';
import '../../models/shop.dart';
import '../../models/vehicle.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/fleet_service.dart';
import '../../services/fleet_csv_export_service.dart';
import '../../services/fleet_inquiry_composer.dart';
import '../marketplace/inquiry_screen.dart';
import '../marketplace/shop_list_screen.dart';
import 'fleet_member_screen.dart';

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
              builder: (context, p, _) {
                final uid = context.read<AuthProvider>().appUser?.id ?? '';
                return IconButton(
                  key: const Key('fleet_members_button'),
                  icon: const Icon(Icons.group_outlined),
                  tooltip: 'メンバー管理',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => FleetMemberScreen(
                        companyId: companyId,
                        currentUserId: uid,
                      ),
                    ),
                  ),
                );
              },
            ),
            Consumer<FleetProvider>(
              builder: (context, p, _) => IconButton(
                key: const Key('fleet_bulk_inquiry_button'),
                icon: const Icon(Icons.send_outlined),
                tooltip: '車検一括問い合わせ',
                onPressed: p.allVehicles.isEmpty
                    ? null
                    : () => _startBulkInquiry(context, p.allVehicles),
              ),
            ),
            Consumer<FleetProvider>(
              builder: (context, p, _) => IconButton(
                key: const Key('fleet_csv_export_button'),
                icon: const Icon(Icons.file_download_outlined),
                tooltip: 'CSVエクスポート',
                onPressed: p.allVehicles.isEmpty
                    ? null
                    : () => _exportCsv(context, p.allVehicles),
              ),
            ),
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

  /// Bulk inspection inquiry: pick vehicles due soon, choose a shop, then
  /// open InquiryScreen prefilled with the generated message.
  Future<void> _startBulkInquiry(
      BuildContext context, List<Vehicle> vehicles) async {
    final targets = FleetInquiryComposer.vehiclesNeedingInspection(vehicles);

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('車検が60日以内の車両はありません（車検満了日の登録もご確認ください）')),
      );
      return;
    }

    // Confirm target vehicles before choosing a shop.
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('車検一括問い合わせ（${targets.length}台）'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: targets
                .map((v) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '・${v.displayName}'
                        '${v.licensePlate != null ? '（${v.licensePlate}）' : ''}',
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('工場を選ぶ'),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    if (!context.mounted) return;
    final shop = await Navigator.push<Shop>(
      context,
      MaterialPageRoute(
        builder: (_) => const ShopListScreen(selectMode: true),
      ),
    );
    if (shop == null || !context.mounted) return;

    final draft = FleetInquiryComposer.compose(targets);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InquiryScreen(
          shop: shop,
          prefillSubject: draft.subject,
          prefillMessage: draft.message,
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, List<Vehicle> vehicles) async {
    final messenger = ScaffoldMessenger.of(context);

    // Best-effort maintenance aggregation; CSV still works without it.
    final summariesResult = await sl
        .get<FleetService>()
        .getMaintenanceSummaries(vehicles.map((v) => v.id).toList());
    final summaries = summariesResult.valueOrNull ?? {};

    final result = sl
        .get<FleetCsvExportService>()
        .buildCsv(vehicles, maintenanceSummaries: summaries);

    await result.when(
      success: (csv) async {
        File? file;
        try {
          final tempDir = await getTemporaryDirectory();
          final now = DateTime.now();
          final stamp = '${now.year}'
              '${now.month.toString().padLeft(2, '0')}'
              '${now.day.toString().padLeft(2, '0')}';
          file = File('${tempDir.path}/fleet_vehicles_$stamp.csv');
          await file.writeAsString(csv);

          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'text/csv')],
            subject: 'フリート車両一覧 ($stamp)',
          );
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('CSVの共有に失敗しました: $e')),
          );
        } finally {
          // CSV contains license plates and staff names — do not leave a
          // plaintext copy in the temp directory after sharing.
          try {
            if (file != null && await file.exists()) {
              await file.delete();
            }
          } catch (_) {}
        }
      },
      failure: (error) async {
        messenger.showSnackBar(
          SnackBar(content: Text('CSVの生成に失敗しました: ${error.userMessage}')),
        );
      },
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
        _InsuranceOverviewTile(vehicles: provider.allVehicles),
        _FleetCodeTile(companyId: provider.companyId),
        _FilterChipBar(provider: provider),
        const Divider(height: 1),
        Expanded(
          child: vehicles.isEmpty
              ? _EmptyState(filter: provider.filter)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: vehicles.length,
                  itemBuilder: (_, i) => _VehicleCard(vehicle: vehicles[i]),
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
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
              color: color, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

// ── Insurance overview tile ───────────────────────────────────────────────────

/// Compact fleet-wide voluntary-insurance status (任意保険の満期/未登録).
class _InsuranceOverviewTile extends StatelessWidget {
  final List<Vehicle> vehicles;
  const _InsuranceOverviewTile({required this.vehicles});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = summarizeFleetInsurance(vehicles);
    if (s.total == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        children: [
          const Icon(Icons.security, size: 16, color: AppColors.textSecondary),
          AppSpacing.horizontalXs,
          Text(
            '任意保険',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          if (s.expired > 0) ...[
            _InsBadge(label: '期限切れ', count: s.expired, color: AppColors.error),
            AppSpacing.horizontalSm,
          ],
          if (s.expiringSoon > 0) ...[
            _InsBadge(
                label: '間近', count: s.expiringSoon, color: AppColors.warning),
            AppSpacing.horizontalSm,
          ],
          if (s.missing > 0)
            _InsBadge(
                label: '未登録', count: s.missing, color: AppColors.textTertiary),
          if (s.needsAttention == 0 && s.missing == 0)
            Text(
              'すべて登録済み',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: AppColors.success),
            ),
        ],
      ),
    );
  }
}

class _InsBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _InsBadge(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        '$label $count',
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
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
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
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
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
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
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusMd,
        onTap: () => _showAssignmentSheet(context),
        child: ListTile(
          leading: _UrgencyIcon(urgency: urgency),
          title: Text(
            vehicle.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VehicleSubtitle(vehicle: vehicle),
              if (vehicle.assigneeName != null)
                Text(
                  '担当: ${vehicle.assigneeName}',
                  key: Key('fleet_vehicle_assignee_${vehicle.id}'),
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.primary),
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${vehicle.year}年式',
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 12),
              ),
              const Icon(Icons.chevron_right,
                  size: 16, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignmentSheet(BuildContext context) {
    final companyId = context.read<FleetProvider>().companyId;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AssignmentSheet(
        vehicle: vehicle,
        companyId: companyId,
      ),
    );
  }
}

// ── Assignment bottom sheet ───────────────────────────────────────────────────

class _AssignmentSheet extends StatefulWidget {
  final Vehicle vehicle;
  final String companyId;

  const _AssignmentSheet({required this.vehicle, required this.companyId});

  @override
  State<_AssignmentSheet> createState() => _AssignmentSheetState();
}

class _AssignmentSheetState extends State<_AssignmentSheet> {
  late TextEditingController _nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.vehicle.assigneeName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.vehicle.displayName,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.verticalSm,
          Text(
            '担当者名を入力してください（空欄で担当者をクリア）',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          AppSpacing.verticalMd,
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '担当者名',
              hintText: '例: 田中太郎',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          AppSpacing.verticalMd,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.firebaseUser?.uid;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('ログインが必要です')));
        }
        return;
      }
      final name = _nameController.text.trim();
      final result = await sl.get<FleetService>().assignVehicle(
            widget.vehicle.id,
            name.isEmpty ? '' : userId,
            name,
            widget.companyId,
          );
      if (!mounted) return;
      result.when(
        success: (_) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(name.isEmpty ? '担当者をクリアしました' : '担当者を設定しました'),
            ),
          );
        },
        failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
                size: AppSpacing.iconXl, color: AppColors.textTertiary),
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
