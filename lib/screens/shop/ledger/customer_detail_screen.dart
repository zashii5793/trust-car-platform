import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../models/shop_ledger.dart';
import '../../../services/shop_ledger_service.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/loading_indicator.dart';
import 'customer_edit_screen.dart';
import 'ledger_format.dart';
import 'ledger_vehicle_edit_screen.dart';

/// 顧客1件の詳細。車両の追加・編集もここから行う。
///
/// 何か変えたら、閉じるときに true を返す（一覧を読み直してもらうため）。
class CustomerDetailScreen extends StatefulWidget {
  final ShopLedgerService service;
  final String shopId;
  final String customerId;
  final DateTime? today;

  const CustomerDetailScreen({
    super.key,
    required this.service,
    required this.shopId,
    required this.customerId,
    this.today,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  LedgerCustomer? _customer;
  List<LedgerVehicle> _vehicles = const [];
  bool _loading = true;
  String? _error;
  bool _changed = false;

  DateTime get _today => widget.today ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final customer = await widget.service.getCustomer(
      shopId: widget.shopId,
      customerId: widget.customerId,
    );
    final vehicles = await widget.service.vehiclesOf(
      shopId: widget.shopId,
      customerId: widget.customerId,
    );
    if (!mounted) return;
    setState(() {
      _customer = customer.valueOrNull;
      _vehicles = vehicles.valueOrNull ?? const [];
      _error = customer.errorOrNull?.userMessage;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<LedgerCustomer>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerEditScreen(
          service: widget.service,
          shopId: widget.shopId,
          existing: _customer,
        ),
      ),
    );
    if (updated == null) return;
    _changed = true;
    await _load();
  }

  Future<void> _editVehicle([LedgerVehicle? vehicle]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LedgerVehicleEditScreen(
          service: widget.service,
          shopId: widget.shopId,
          customerId: widget.customerId,
          existing: vehicle,
        ),
      ),
    );
    if (saved != true) return;
    _changed = true;
    await _load();
  }

  Future<void> _delete() async {
    final customer = _customer;
    if (customer == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この顧客を削除しますか？'),
        content: Text(
          '${customer.name} と、登録されている車両 ${_vehicles.length}台を'
          '台帳から削除します。元に戻せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('やめる'),
          ),
          TextButton(
            key: const Key('customer_delete_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await widget.service.deleteCustomer(
      shopId: widget.shopId,
      customerId: customer.id,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorOrNull!.userMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_customer?.name ?? '顧客'),
          actions: [
            if (_customer != null) ...[
              IconButton(
                key: const Key('customer_edit'),
                tooltip: '編集',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _edit,
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') _delete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('顧客を削除')),
                ],
              ),
            ],
          ],
        ),
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const AppLoadingCenter();
    final c = _customer;
    if (c == null) {
      return AppEmptyState(
        icon: Icons.person_off_outlined,
        title: 'この顧客は見つかりませんでした',
        description: _error ?? '別のスタッフが削除した可能性があります。',
        buttonLabel: '台帳に戻る',
        onButtonPressed: () => Navigator.pop(context, true),
      );
    }
    final theme = Theme.of(context);

    final rows = <(String, String?)>[
      ('区分', c.kind.label),
      ('フリガナ', c.nameKana),
      if (c.kind == LedgerCustomerKind.corporate) ('ご担当者', c.contactPerson),
      ('電話番号', c.phone),
      ('メール', c.email),
      ('住所', [c.postalCode, c.address].whereType<String>().join(' ')),
      ('最終来店', c.lastVisitAt == null ? null : ledgerDate(c.lastVisitAt!)),
      ('アプリ', c.isLinked ? '利用中' : '未利用'),
      ('メモ', c.note),
    ];

    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, value) in rows)
                if (value != null && value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 88,
                          child: Text(label, style: theme.textTheme.bodySmall),
                        ),
                        Expanded(child: Text(value)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        AppSpacing.verticalLg,
        Row(
          children: [
            Text(
              '車両（${_vehicles.length}台）',
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton.icon(
              key: const Key('vehicle_add'),
              onPressed: () => _editVehicle(),
              icon: const Icon(Icons.add),
              label: const Text('車両を追加'),
            ),
          ],
        ),
        if (_vehicles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text('まだ車両が登録されていません。'),
          ),
        for (final v in _vehicles)
          Card(
            child: ListTile(
              onTap: () => _editVehicle(v),
              leading: const Icon(Icons.directions_car),
              title: Text(v.displayName),
              subtitle: Text([
                if (v.plate != null) v.plate!,
                if (v.year != null) '${v.year}年式',
                if (v.lastMileage != null) '${v.lastMileage}km',
              ].join('・')),
              trailing: v.inspectionExpiry == null
                  ? null
                  : _InspectionLabel(
                      expiry: v.inspectionExpiry!,
                      today: _today,
                    ),
            ),
          ),
      ],
    );
  }
}

class _InspectionLabel extends StatelessWidget {
  final DateTime expiry;
  final DateTime today;

  const _InspectionLabel({required this.expiry, required this.today});

  @override
  Widget build(BuildContext context) {
    final days = ledgerDaysUntil(expiry, today);
    final urgent = days < 31;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('車検満了', style: TextStyle(fontSize: 11)),
        Text(
          ledgerDate(expiry),
          style: TextStyle(
            color: urgent ? AppColors.error : null,
            fontWeight: urgent ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }
}
