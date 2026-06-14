import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/vehicle.dart';
import '../../providers/auth_provider.dart';
import '../../services/vehicle_retirement_service.dart';

/// Shows all retired vehicles (sold, scrapped, leaseReturned, transferred)
/// for the current user, with an option to restore them.
class RetiredVehiclesScreen extends StatefulWidget {
  const RetiredVehiclesScreen({super.key});

  @override
  State<RetiredVehiclesScreen> createState() => _RetiredVehiclesScreenState();
}

class _RetiredVehiclesScreenState extends State<RetiredVehiclesScreen> {
  late final VehicleRetirementService _service;
  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = sl.get<VehicleRetirementService>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final uid = context.read<AuthProvider>().appUser?.id ?? '';
    final result = await _service.getRetiredVehicles(uid);
    if (!mounted) return;
    result.when(
      success: (vehicles) => setState(() {
        _vehicles = vehicles
          ..sort((a, b) => (b.retiredAt ?? DateTime(0))
              .compareTo(a.retiredAt ?? DateTime(0)));
        _isLoading = false;
      }),
      failure: (e) => setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      }),
    );
  }

  Future<void> _restore(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('車両を復元しますか？'),
        content: Text(
          '${vehicle.maker} ${vehicle.model} を使用中の車両に戻します。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('復元する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!mounted) return;
    final uid = context.read<AuthProvider>().appUser?.id ?? '';
    final result = await _service.restoreVehicle(
      vehicleId: vehicle.id,
      ownerId: uid,
    );
    if (!mounted) return;
    result.when(
      success: (_) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('車両を復元しました')),
        );
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('過去の車両'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!,
                style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: _load, child: const Text('再読み込み')),
          ],
        ),
      );
    }
    if (_vehicles.isEmpty) {
      return const Center(
        key: Key('retired_vehicles_empty'),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_outlined,
                  size: AppSpacing.iconXl, color: AppColors.textTertiary),
              SizedBox(height: AppSpacing.md),
              Text(
                '過去の車両はありません',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                '売却・廃車・リース返却した車両がここに表示されます',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _vehicles.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _RetiredVehicleCard(
          vehicle: _vehicles[i],
          onRestore: () => _restore(_vehicles[i]),
        ),
      ),
    );
  }
}

// ── Retired vehicle card ──────────────────────────────────────────────────────

class _RetiredVehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onRestore;

  const _RetiredVehicleCard({required this.vehicle, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusInfo = _statusInfo(vehicle.status);

    return Card(
      key: Key('retired_vehicle_${vehicle.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusInfo.$2.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusInfo.$3, color: statusInfo.$2, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle.maker} ${vehicle.model}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _StatusBadge(label: statusInfo.$1, color: statusInfo.$2),
                      const SizedBox(width: AppSpacing.sm),
                      if (vehicle.retiredAt != null)
                        Text(
                          _formatDate(vehicle.retiredAt!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  if (vehicle.retirementNote != null &&
                      vehicle.retirementNote!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      vehicle.retirementNote!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (vehicle.isDataRetained) ...[
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.bookmark_outlined,
                            size: 12, color: AppColors.primary),
                        SizedBox(width: 2),
                        Text(
                          '整備記録を保持中',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Restore button
            TextButton.icon(
              key: Key('restore_vehicle_${vehicle.id}'),
              onPressed: onRestore,
              icon: const Icon(Icons.restore_outlined, size: 16),
              label: const Text('復元'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color, IconData) _statusInfo(VehicleStatus status) =>
      switch (status) {
        VehicleStatus.sold => ('売却済み', AppColors.warning, Icons.sell_outlined),
        VehicleStatus.scrapped => (
            '廃車済み',
            AppColors.error,
            Icons.delete_outline
          ),
        VehicleStatus.leaseReturned => (
            'リース返却',
            AppColors.secondary,
            Icons.assignment_return_outlined
          ),
        VehicleStatus.transferred => (
            '譲渡済み',
            AppColors.primary,
            Icons.swap_horiz_outlined
          ),
        VehicleStatus.active => (
            '使用中',
            AppColors.success,
            Icons.check_circle_outline
          ),
      };

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
