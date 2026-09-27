import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../models/shop_ledger.dart';
import '../../../services/shop_ledger_service.dart';
import '../../../services/vehicle_share_service.dart';
import '../../../widgets/common/loading_indicator.dart';
import 'customer_detail_screen.dart';
import 'customer_edit_screen.dart';
import 'ledger_csv_import_screen.dart';
import 'shared_vehicles_screen.dart';
import 'ledger_format.dart';
import 'ledger_paged_list.dart';

/// 店の顧客台帳（`docs/SHOP_CRM_DESIGN_2026-09-27.md` §5）。
///
/// 3つの見方を用意する。店が顧客を見るときの問いがそれぞれ違うため。
///
/// - **顧客**：この人は誰で、何台持っているか（名前・ナンバーで引く）
/// - **車検が近い**：今月・来月、誰に声をかけるか（顧客をまたいで満了日順）
/// - **しばらく来ていない**：離れかけているのは誰か
class CustomerLedgerScreen extends StatefulWidget {
  final ShopLedgerService service;

  /// ユーザーから渡された車の写しを読むため。渡さなければ入口を出さない。
  final VehicleShareService? shareService;
  final String shopId;
  final String shopName;

  /// 「今日」。テスト（特にゴールデン）で日付を止めるために渡せる。
  final DateTime? today;

  const CustomerLedgerScreen({
    super.key,
    required this.service,
    this.shareService,
    required this.shopId,
    required this.shopName,
    this.today,
  });

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _searchController = TextEditingController();
  Timer? _debounce;

  LedgerCounts? _counts;
  String _search = '';
  LedgerCustomerSort _sort = LedgerCustomerSort.kana;

  /// 登録・編集・削除のあとに、一覧を先頭から読み直すための番号。
  int _revision = 0;

  DateTime get _today => widget.today ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    final result = await widget.service.counts(widget.shopId);
    if (!mounted) return;
    setState(() => _counts = result.valueOrNull ?? LedgerCounts.empty);
  }

  void _refreshAll() {
    setState(() => _revision++);
    _loadCounts();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    // 1文字打つたびに問い合わせない。
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _search = value.trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _search = '');
  }

  /// 数字が入っていたら、ナンバーの末尾の番号として引く。
  bool get _isPlateSearch => RegExp(r'[0-9０-９]').hasMatch(_search);

  Future<void> _openCustomer(String customerId) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(
          service: widget.service,
          shopId: widget.shopId,
          customerId: customerId,
          today: widget.today,
        ),
      ),
    );
    if (changed == true) _refreshAll();
  }

  Future<void> _addCustomer() async {
    final created = await Navigator.push<LedgerCustomer>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerEditScreen(
          service: widget.service,
          shopId: widget.shopId,
        ),
      ),
    );
    if (created == null || !mounted) return;
    _refreshAll();
    await _openCustomer(created.id);
  }

  Future<void> _openShared() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SharedVehiclesScreen(
          service: widget.shareService!,
          ledger: widget.service,
          shopId: widget.shopId,
          today: widget.today,
        ),
      ),
    );
    if (changed == true) _refreshAll();
  }

  /// 整備実績を、車種別の維持費レポートの匿名の集計に使ってよいか。
  ///
  /// **既定は協力しない。** 店の実績は店のもので、同意なしに集計に入れない。
  Future<void> _openStatistics() async {
    final current = await widget.service.allowsStatistics(widget.shopId);
    if (!mounted) return;
    var value = current.valueOrNull ?? false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('車種別レポートへの協力'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '取り込んだ整備履歴を、「この車種は年にいくらかかるか」の'
                '集計に使います。お客さんの名前・連絡先・ナンバーは使いません。'
                '持ち主が5人に満たない数字は出しません。',
              ),
              AppSpacing.verticalSm,
              SwitchListTile(
                key: const Key('ledger_stats_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('匿名の集計に協力する'),
                value: value,
                onChanged: (v) async {
                  final r = await widget.service.setAllowsStatistics(
                    shopId: widget.shopId,
                    value: v,
                  );
                  if (r.isSuccess) {
                    setLocal(() => value = v);
                  } else if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('切り替えられるのは店主のアカウントだけです')),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importCsv() async {
    final imported = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LedgerCsvImportScreen(
          service: widget.service,
          shopId: widget.shopId,
        ),
      ),
    );
    if (imported == true) _refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('顧客台帳'),
        actions: [
          if (widget.shareService != null)
            IconButton(
              key: const Key('ledger_shared_vehicles'),
              tooltip: '共有された車',
              icon: const Icon(Icons.inbox_outlined),
              onPressed: _openShared,
            ),
          IconButton(
            key: const Key('ledger_import_csv'),
            tooltip: 'CSVから取り込む',
            icon: const Icon(Icons.upload_file),
            onPressed: _importCsv,
          ),
          PopupMenuButton<String>(
            key: const Key('ledger_more'),
            onSelected: (v) {
              if (v == 'stats') _openStatistics();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'stats',
                child: Text('車種別レポートへの協力'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '顧客'),
            Tab(text: '車検が近い'),
            Tab(text: 'しばらく来ていない'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('ledger_add_customer'),
        onPressed: _addCustomer,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('顧客を追加'),
      ),
      body: Column(
        children: [
          _CountsBar(counts: _counts),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _customersTab(),
                _inspectionTab(),
                _lapsedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _customersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('ledger_search'),
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'フリガナ または ナンバー末尾（例: 1234）',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              AppSpacing.horizontalXs,
              PopupMenuButton<LedgerCustomerSort>(
                key: const Key('ledger_sort'),
                tooltip: '並べ替え',
                icon: const Icon(Icons.sort),
                initialValue: _sort,
                onSelected: (s) => setState(() => _sort = s),
                itemBuilder: (_) => [
                  for (final s in LedgerCustomerSort.values)
                    PopupMenuItem(value: s, child: Text(s.label)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isPlateSearch ? _plateResults() : _customerList(),
        ),
      ],
    );
  }

  Widget _customerList() {
    return LedgerPagedList<LedgerCustomer>(
      reloadKey: '$_revision|$_search|${_sort.name}',
      loader: (cursor) => widget.service.listCustomers(
        shopId: widget.shopId,
        sort: _sort,
        search: _search,
        cursor: cursor,
      ),
      itemBuilder: (context, c) => _CustomerTile(
        customer: c,
        today: _today,
        onTap: () => _openCustomer(c.id),
      ),
      empty: _search.isEmpty
          ? AppEmptyState(
              icon: Icons.people_outline,
              title: 'まだ顧客が登録されていません',
              description: '整備管理ソフトの名簿があれば、右上の取込ボタンから'
                  'CSV でまとめて入れられます。1人ずつなら右下の「顧客を追加」から。',
              buttonLabel: '顧客を追加',
              onButtonPressed: _addCustomer,
            )
          : AppEmptyState(
              icon: Icons.search_off,
              title: '「$_search」に当たる顧客はいません',
              description: 'フリガナの先頭から入力してください。'
                  'まだ台帳に無いお客さんなら、ここから登録できます。',
              buttonLabel: '新しい顧客として追加',
              onButtonPressed: _addCustomer,
            ),
    );
  }

  /// ナンバーは件数が少ない（同じ末尾番号は店内で数台）ので、ページングしない。
  Widget _plateResults() {
    return FutureBuilder(
      key: ValueKey('plate|$_revision|$_search'),
      future: widget.service.findVehiclesByPlateNumber(
        shopId: widget.shopId,
        number: _search,
      ),
      builder: (context, snap) {
        if (!snap.hasData) return const AppLoadingCenter();
        final vehicles = snap.data!.valueOrNull ?? const <LedgerVehicle>[];
        if (vehicles.isEmpty) {
          return AppEmptyState(
            icon: Icons.search_off,
            title: 'ナンバー末尾「${ledgerDigits(_search)}」の車はありません',
            description: 'ナンバーが未登録の車は、名前（フリガナ）で探してください。',
            buttonLabel: '検索を消す',
            onButtonPressed: _clearSearch,
          );
        }
        return ListView(
          children: [
            for (final v in vehicles)
              _VehicleTile(
                vehicle: v,
                today: _today,
                onTap: () => _openCustomer(v.customerId),
              ),
          ],
        );
      },
    );
  }

  Widget _inspectionTab() {
    return LedgerPagedList<LedgerVehicle>(
      reloadKey: _revision,
      loader: (cursor) => widget.service.listVehiclesByInspection(
        shopId: widget.shopId,
        from: _today,
        cursor: cursor,
      ),
      itemBuilder: (context, v) => _VehicleTile(
        vehicle: v,
        today: _today,
        onTap: () => _openCustomer(v.customerId),
      ),
      empty: AppEmptyState(
        icon: Icons.event_available,
        title: '車検満了日が入っている車はまだありません',
        description: '顧客の車両に満了日を入れると、ここに近い順で並びます。',
        buttonLabel: '顧客一覧へ',
        onButtonPressed: () => _tabs.animateTo(0),
      ),
    );
  }

  Widget _lapsedTab() {
    // 1年。車検は2年ごとでも、点検・オイル交換で年1回は来るのが普通。
    final since = DateTime(_today.year - 1, _today.month, _today.day);
    return LedgerPagedList<LedgerCustomer>(
      reloadKey: _revision,
      loader: (cursor) => widget.service.listLapsedCustomers(
        shopId: widget.shopId,
        since: since,
        cursor: cursor,
      ),
      itemBuilder: (context, c) => _CustomerTile(
        customer: c,
        today: _today,
        showLastVisit: true,
        onTap: () => _openCustomer(c.id),
      ),
      empty: AppEmptyState(
        icon: Icons.check_circle_outline,
        title: '1年以上来ていない顧客はいません',
        description: '最後に来た日が入っている顧客だけを数えています。',
        buttonLabel: '車検が近い車を見る',
        onButtonPressed: () => _tabs.animateTo(1),
      ),
    );
  }
}

class _CountsBar extends StatelessWidget {
  final LedgerCounts? counts;

  const _CountsBar({required this.counts});

  @override
  Widget build(BuildContext context) {
    final c = counts;
    final theme = Theme.of(context);
    Widget item(String label, String value, {Key? key}) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                key: key,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        );
    String n(int? v) => v == null ? '—' : '$v';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        children: [
          item('顧客', n(c?.total), key: const Key('ledger_count_total')),
          item('個人', n(c?.individual)),
          item('法人', n(c?.corporate)),
          item('アプリ利用中', n(c?.linked)),
        ],
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final LedgerCustomer customer;
  final DateTime today;
  final bool showLastVisit;
  final VoidCallback onTap;

  const _CustomerTile({
    required this.customer,
    required this.today,
    required this.onTap,
    this.showLastVisit = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final details = <String>[
      '${c.vehicleCount}台',
      if (showLastVisit && c.lastVisitAt != null)
        '最終来店 ${ledgerDate(c.lastVisitAt!)}（${ledgerMonthsAgo(c.lastVisitAt!, today)}）'
      else if (c.nextInspectionAt != null)
        '次の車検 ${ledgerDate(c.nextInspectionAt!)}',
    ];

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Icon(
          c.kind == LedgerCustomerKind.corporate
              ? Icons.business
              : Icons.person,
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
          if (c.isLinked) ...[
            AppSpacing.horizontalXs,
            const _Badge(label: 'アプリ', color: AppColors.secondary),
          ],
        ],
      ),
      subtitle: Text(details.join('・')),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  final LedgerVehicle vehicle;
  final DateTime today;
  final VoidCallback onTap;

  const _VehicleTile({
    required this.vehicle,
    required this.today,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    final exp = v.inspectionExpiry;
    final days = exp == null ? null : ledgerDaysUntil(exp, today);

    return ListTile(
      onTap: onTap,
      leading: const CircleAvatar(child: Icon(Icons.directions_car)),
      title: Text(
        [v.displayName, if (v.plate != null) v.plate!].join('　'),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(v.customerName),
      trailing: exp == null
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(ledgerDate(exp)),
                Text(
                  days! < 0 ? '切れています' : 'あと$days日',
                  style: TextStyle(
                    color: days < 31 ? AppColors.error : null,
                    fontWeight: days < 31 ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: AppSpacing.borderRadiusXs,
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
