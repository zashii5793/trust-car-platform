import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../services/vehicle_history_sharing_service.dart';
import '../../widgets/common/loading_indicator.dart';

/// Lets a vehicle owner manage which shops can read their maintenance history.
///
/// Shows the list of currently permitted shop IDs and allows revocation.
/// New permissions are granted by entering a shop ID via the add dialog.
class VehicleHistorySharingScreen extends StatefulWidget {
  final String vehicleId;
  final String ownerId;
  final String vehicleName;

  const VehicleHistorySharingScreen({
    super.key,
    required this.vehicleId,
    required this.ownerId,
    required this.vehicleName,
  });

  @override
  State<VehicleHistorySharingScreen> createState() =>
      _VehicleHistorySharingScreenState();
}

class _VehicleHistorySharingScreenState
    extends State<VehicleHistorySharingScreen> {
  late final VehicleHistorySharingService _service;
  List<String>? _shopIds;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = sl.get<VehicleHistorySharingService>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result =
        await _service.getPermittedShops(vehicleId: widget.vehicleId);
    if (!mounted) return;
    result.when(
      success: (ids) => setState(() {
        _shopIds = ids;
        _isLoading = false;
      }),
      failure: (e) => setState(() {
        _error = e.userMessage;
        _isLoading = false;
      }),
    );
  }

  Future<void> _confirmRevoke(String shopId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('共有を解除しますか?'),
        content: Text('$shopId への整備履歴アクセスを解除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('解除する'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await _service.revokePermission(
      vehicleId: widget.vehicleId,
      shopId: shopId,
      ownerId: widget.ownerId,
    );
    if (!mounted) return;

    result.when(
      success: (_) {
        setState(() => _shopIds?.remove(shopId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('共有を解除しました')),
        );
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.userMessage),
          backgroundColor: AppColors.error,
        ),
      ),
    );
  }

  Future<void> _showGrantDialog() async {
    final controller = TextEditingController();
    final shopId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('整備工場に共有'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '工場ID',
            hintText: '共有したい整備工場のIDを入力',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('共有する'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (shopId == null || shopId.isEmpty || !mounted) return;

    final result = await _service.grantPermission(
      vehicleId: widget.vehicleId,
      shopId: shopId,
      ownerId: widget.ownerId,
    );
    if (!mounted) return;

    result.when(
      success: (_) {
        setState(() => _shopIds?.add(shopId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('整備工場に整備履歴を共有しました')),
        );
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.userMessage),
          backgroundColor: AppColors.error,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.vehicleName} の整備履歴共有'),
        actions: [
          IconButton(
            key: const Key('add_sharing_btn'),
            icon: const Icon(Icons.add),
            tooltip: '工場に共有',
            onPressed: _showGrantDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoadingCenter(message: '読み込み中...')
          : _error != null
              ? AppErrorState(message: _error!, onRetry: _load)
              : _shopIds == null || _shopIds!.isEmpty
                  ? _EmptyState(onAdd: _showGrantDialog)
                  : _PermissionList(
                      shopIds: _shopIds!,
                      onRevoke: _confirmRevoke,
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.paddingScreen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            AppSpacing.verticalMd,
            Text(
              'まだ共有していません',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalXs,
            Text(
              '整備工場に整備履歴を共有すると、\nより的確なサービスを受けられます。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalLg,
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('工場に共有する'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Permission list
// ---------------------------------------------------------------------------

class _PermissionList extends StatelessWidget {
  final List<String> shopIds;
  final void Function(String shopId) onRevoke;

  const _PermissionList({required this.shopIds, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.paddingScreen,
          child: Text(
            '${shopIds.length}件の整備工場と整備履歴を共有中',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: shopIds.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _PermissionTile(
              shopId: shopIds[i],
              onRevoke: () => onRevoke(shopIds[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final String shopId;
  final VoidCallback onRevoke;

  const _PermissionTile({required this.shopId, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        child: Icon(Icons.store_outlined, size: 20),
      ),
      title: Text(shopId),
      subtitle: const Text('整備履歴を閲覧できます'),
      trailing: IconButton(
        icon: const Icon(Icons.block_outlined),
        tooltip: '共有を解除',
        color: AppColors.error,
        onPressed: onRevoke,
      ),
    );
  }
}
