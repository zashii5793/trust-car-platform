import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../models/vehicle_share.dart';
import '../../../services/shop_ledger_service.dart';
import '../../../services/vehicle_share_service.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/loading_indicator.dart';
import 'customer_detail_screen.dart';
import 'ledger_format.dart';

/// アプリのユーザーから渡された車の写し（`docs/SHOP_CRM_DESIGN_2026-09-27.md` §7）。
///
/// 初めて来るお客さんが、これまでの整備を持ってきてくれる。
/// ここから台帳に登録できる。
class SharedVehiclesScreen extends StatefulWidget {
  final VehicleShareService service;
  final ShopLedgerService ledger;
  final String shopId;
  final DateTime? today;

  const SharedVehiclesScreen({
    super.key,
    required this.service,
    required this.ledger,
    required this.shopId,
    this.today,
  });

  @override
  State<SharedVehiclesScreen> createState() => _SharedVehiclesScreenState();
}

class _SharedVehiclesScreenState extends State<SharedVehiclesScreen> {
  List<VehicleShare>? _shares;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await widget.service.sharesForShop(widget.shopId);
    if (!mounted) return;
    setState(() {
      _shares = r.valueOrNull ?? const [];
      _error = r.errorOrNull?.userMessage;
    });
  }

  Future<void> _open(VehicleShare share) async {
    widget.service.markSeen(shopId: widget.shopId, vehicleId: share.vehicleId);
    final imported = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _SharedVehicleDetail(
          share: share,
          service: widget.service,
          ledger: widget.ledger,
          today: widget.today,
        ),
      ),
    );
    if (imported == true) _changed = true;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final shares = _shares;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('共有された車')),
        body: shares == null
            ? const AppLoadingCenter()
            : shares.isEmpty
                ? AppEmptyState(
                    icon: Icons.inbox_outlined,
                    title: _error ?? 'まだ共有された車はありません',
                    description: 'お客さんがアプリの車両画面から「お店に共有する」を'
                        '選ぶと、ここに届きます。',
                    buttonLabel: '顧客台帳に戻る',
                    onButtonPressed: () => Navigator.pop(context, _changed),
                  )
                : ListView(
                    children: [
                      for (final s in shares)
                        ListTile(
                          key: Key('shared_${s.vehicleId}'),
                          onTap: () => _open(s),
                          leading: CircleAvatar(
                            child: Icon(s.importedCustomerId != null
                                ? Icons.how_to_reg
                                : Icons.directions_car),
                          ),
                          title: Text(s.displayName),
                          subtitle: Text([
                            s.contactName ?? '（お名前未共有）',
                            '整備記録${s.records.length}件',
                            '${ledgerDate(s.sharedAt)} 受け取り',
                          ].join('・')),
                          trailing: s.importedCustomerId != null
                              ? const Text('登録済み')
                              : (s.seenAt == null
                                  ? const Text('未読',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold))
                                  : null),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _SharedVehicleDetail extends StatefulWidget {
  final VehicleShare share;
  final VehicleShareService service;
  final ShopLedgerService ledger;
  final DateTime? today;

  const _SharedVehicleDetail({
    required this.share,
    required this.service,
    required this.ledger,
    this.today,
  });

  @override
  State<_SharedVehicleDetail> createState() => _SharedVehicleDetailState();
}

class _SharedVehicleDetailState extends State<_SharedVehicleDetail> {
  bool _importing = false;
  String? _error;

  Future<void> _import() async {
    setState(() {
      _importing = true;
      _error = null;
    });
    final r = await widget.service.importToLedger(
      ledger: widget.ledger,
      share: widget.share,
    );
    if (!mounted) return;
    await r.when(
      success: (customerId) async {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerDetailScreen(
              service: widget.ledger,
              shopId: widget.share.shopId,
              customerId: customerId,
              today: widget.today,
            ),
          ),
          result: true,
        );
      },
      failure: (e) async => setState(() {
        _error = e.userMessage;
        _importing = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.share;
    final theme = Theme.of(context);
    final facts = <(String, String?)>[
      ('お名前', s.contactName),
      ('電話番号', s.contactPhone),
      ('ナンバー', s.plate),
      ('年式', s.year == null ? null : '${s.year}年'),
      ('走行距離', s.mileage == null ? null : '${ledgerNumber(s.mileage!)}km'),
      (
        '車検満了日',
        s.inspectionExpiry == null ? null : ledgerDate(s.inspectionExpiry!)
      ),
      ('共有の期限', ledgerDate(s.expiresAt)),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.displayName)),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          if (s.message != null)
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline),
                  AppSpacing.horizontalSm,
                  Expanded(child: Text(s.message!)),
                ],
              ),
            ),
          AppSpacing.verticalSm,
          AppCard(
            child: Column(
              children: [
                for (final (label, value) in facts)
                  if (value != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 88,
                            child:
                                Text(label, style: theme.textTheme.bodySmall),
                          ),
                          Expanded(child: Text(value)),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          AppSpacing.verticalMd,
          Text(
            'これまでの整備（${s.records.length}件'
            '${s.includesCosts ? '' : '・費用は非公開'}）',
            style: theme.textTheme.titleMedium,
          ),
          if (s.records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('整備記録は共有されていません。'),
            ),
          for (final r in s.records)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${ledgerDate(r.date)}  ${r.title}'),
              subtitle: Text([
                r.type,
                if (r.mileage != null) '${ledgerNumber(r.mileage!)}km',
                if (r.shopName != null) r.shopName!,
              ].join('・')),
              trailing:
                  r.cost == null ? null : Text('¥${ledgerNumber(r.cost!)}'),
            ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          AppSpacing.verticalMd,
          if (s.importedCustomerId == null)
            FilledButton.icon(
              key: const Key('shared_import'),
              onPressed: _importing ? null : _import,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(_importing ? '登録しています…' : '顧客台帳に登録する'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSpacing.tapTargetMin),
              ),
            )
          else
            const Text('この車は顧客台帳に登録済みです。'),
          AppSpacing.verticalXl,
        ],
      ),
    );
  }
}
