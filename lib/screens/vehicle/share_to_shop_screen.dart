import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/error/app_error.dart';
import '../../core/result/result.dart';
import '../../models/maintenance_record.dart';
import '../../models/shop.dart';
import '../../models/vehicle.dart';
import '../../models/vehicle_share.dart';
import '../../services/vehicle_share_service.dart';
import '../../widgets/common/app_card.dart';
import '../../core/utils/first_week_tracker.dart';
import '../../services/analytics_service.dart' show FirstWeekStep;

/// 店を名前で探す関数。テストで差し替えられるように外から渡す。
typedef ShopSearch = Future<Result<List<Shop>, AppError>> Function(String q);

/// 初めて行く店に「この車のこれまで」を渡す（`docs/SHOP_CRM_DESIGN_2026-09-27.md` §7）。
///
/// 店を替えると、これまで履歴はゼロから始まっていた。紙の記録簿を
/// 持っていく代わりに、アプリから写しを渡す。
///
/// **何を渡すかは、ここで本人が選ぶ。** 既定は「車と整備の中身だけ」で、
/// ナンバー・費用・連絡先は本人がオンにしたときだけ渡る。
class ShareToShopScreen extends StatefulWidget {
  final Vehicle vehicle;
  final List<MaintenanceRecord> records;
  final String ownerId;
  final String? defaultContactName;
  final VehicleShareService service;
  final ShopSearch searchShops;

  const ShareToShopScreen({
    super.key,
    required this.vehicle,
    required this.records,
    required this.ownerId,
    required this.service,
    required this.searchShops,
    this.defaultContactName,
  });

  @override
  State<ShareToShopScreen> createState() => _ShareToShopScreenState();
}

class _ShareToShopScreenState extends State<ShareToShopScreen> {
  final _query = TextEditingController();
  late final _contactName =
      TextEditingController(text: widget.defaultContactName);
  final _contactPhone = TextEditingController();
  final _message = TextEditingController();
  Timer? _debounce;

  List<ActiveShare> _active = const [];
  List<Shop> _results = const [];
  bool _searching = false;
  Shop? _shop;

  bool _includePlate = false;
  bool _includeRecords = true;
  bool _includeCosts = false;
  bool _includeContact = false;
  int _days = 30;

  bool _sharing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActive();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadActive() async {
    final r = await widget.service.activeSharesOf(
      ownerId: widget.ownerId,
      vehicleId: widget.vehicle.id,
    );
    if (!mounted) return;
    setState(() => _active = r.valueOrNull ?? const []);
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final text = q.trim();
      if (text.isEmpty) {
        setState(() => _results = const []);
        return;
      }
      setState(() => _searching = true);
      final r = await widget.searchShops(text);
      if (!mounted) return;
      setState(() {
        _results = r.valueOrNull ?? const [];
        _searching = false;
      });
    });
  }

  Future<void> _revoke(ActiveShare s) async {
    final r = await widget.service.revoke(
      vehicleId: widget.vehicle.id,
      shopId: s.shopId,
    );
    if (!mounted) return;
    if (r.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.errorOrNull!.userMessage)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${s.shopName} への共有を取り消しました')),
    );
    await _loadActive();
  }

  Future<void> _share() async {
    final shop = _shop;
    if (shop == null) return;
    setState(() {
      _sharing = true;
      _error = null;
    });
    final r = await widget.service.share(
      ownerId: widget.ownerId,
      vehicle: widget.vehicle,
      shopId: shop.id,
      shopName: shop.name,
      records: _includeRecords ? widget.records : const [],
      days: _days,
      includePlate: _includePlate,
      includeCosts: _includeRecords && _includeCosts,
      contactName: _includeContact ? _contactName.text : null,
      contactPhone: _includeContact ? _contactPhone.text : null,
      message: _message.text,
    );
    if (!mounted) return;
    r.when(
      success: (_) {
        trackFirstWeekStep(FirstWeekStep.shopLinked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${shop.name} に渡しました')),
        );
        Navigator.pop(context, true);
      },
      failure: (e) => setState(() {
        _error = e.userMessage;
        _sharing = false;
      }),
    );
  }

  String _summary(Shop shop) {
    final parts = <String>[
      widget.vehicle.displayName,
      if (_includePlate && (widget.vehicle.licensePlate ?? '').isNotEmpty)
        'ナンバー',
      if (_includeRecords)
        '整備記録${widget.records.length}件（費用${_includeCosts ? 'あり' : 'なし'}）',
      if (_includeContact) '連絡先',
    ];
    return '${shop.name} に、${parts.join('・')} を$_days日間渡します。';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shop = _shop;
    return Scaffold(
      appBar: AppBar(title: const Text('お店に共有する')),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          const Text(
            '初めて行くお店に、この車のこれまでを渡せます。'
            '渡すのは今の時点の写しで、あとから取り消せます。',
          ),
          if (_active.isNotEmpty) ...[
            AppSpacing.verticalMd,
            Text('共有中のお店', style: theme.textTheme.titleMedium),
            for (final s in _active)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.store_outlined),
                title: Text(s.shopName),
                subtitle: s.expiresAt == null
                    ? null
                    : Text('${_date(s.expiresAt!)} まで'),
                trailing: TextButton(
                  key: Key('revoke_${s.shopId}'),
                  onPressed: () => _revoke(s),
                  child: const Text('取り消す'),
                ),
              ),
          ],
          AppSpacing.verticalLg,
          Text('1. お店を選ぶ', style: theme.textTheme.titleMedium),
          AppSpacing.verticalXs,
          if (shop != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.store, color: AppColors.primary),
                title: Text(shop.name),
                subtitle: shop.address == null ? null : Text(shop.address!),
                trailing: TextButton(
                  onPressed: () => setState(() => _shop = null),
                  child: const Text('選び直す'),
                ),
              ),
            )
          else ...[
            TextField(
              key: const Key('share_shop_query'),
              controller: _query,
              onChanged: _onQuery,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'お店の名前（先頭から）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_searching &&
                _query.text.trim().isNotEmpty &&
                _results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text('見つかりませんでした。お店がアプリに載っていない'
                    'ときは、整備記録を CSV で出してお店に渡せます'
                    '（車両の画面の右上メニュー）。'),
              ),
            for (final s in _results)
              ListTile(
                key: Key('share_shop_${s.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.store_outlined),
                title: Text(s.name),
                subtitle: s.address == null ? null : Text(s.address!),
                onTap: () => setState(() => _shop = s),
              ),
          ],
          AppSpacing.verticalLg,
          Text('2. 渡す内容を選ぶ', style: theme.textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('車種・年式・走行距離・車検満了日'),
            subtitle: const Text('必ず渡します'),
            value: true,
            onChanged: null,
          ),
          SwitchListTile(
            key: const Key('share_include_records'),
            contentPadding: EdgeInsets.zero,
            title: Text('整備記録（${widget.records.length}件）'),
            value: _includeRecords,
            onChanged: (v) => setState(() => _includeRecords = v),
          ),
          if (_includeRecords)
            SwitchListTile(
              key: const Key('share_include_costs'),
              contentPadding: const EdgeInsets.only(left: AppSpacing.lg),
              title: const Text('整備の費用も渡す'),
              value: _includeCosts,
              onChanged: (v) => setState(() => _includeCosts = v),
            ),
          SwitchListTile(
            key: const Key('share_include_plate'),
            contentPadding: EdgeInsets.zero,
            title: const Text('ナンバー'),
            subtitle: (widget.vehicle.licensePlate ?? '').isEmpty
                ? const Text('この車にはナンバーが登録されていません')
                : null,
            value: _includePlate,
            onChanged: (widget.vehicle.licensePlate ?? '').isEmpty
                ? null
                : (v) => setState(() => _includePlate = v),
          ),
          SwitchListTile(
            key: const Key('share_include_contact'),
            contentPadding: EdgeInsets.zero,
            title: const Text('お名前と電話番号'),
            subtitle: const Text('お店から連絡してほしいとき'),
            value: _includeContact,
            onChanged: (v) => setState(() => _includeContact = v),
          ),
          if (_includeContact) ...[
            TextField(
              key: const Key('share_contact_name'),
              controller: _contactName,
              decoration: const InputDecoration(
                labelText: 'お名前',
                border: OutlineInputBorder(),
              ),
            ),
            AppSpacing.verticalSm,
            TextField(
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '電話番号',
                border: OutlineInputBorder(),
              ),
            ),
            AppSpacing.verticalSm,
          ],
          TextField(
            controller: _message,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'お店への一言（任意）',
              hintText: '例: 車検の見積もりをお願いします',
              border: OutlineInputBorder(),
            ),
          ),
          AppSpacing.verticalMd,
          Text('渡しておく期間', style: theme.textTheme.bodyMedium),
          AppSpacing.verticalXs,
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7日')),
              ButtonSegment(value: 30, label: Text('30日')),
              ButtonSegment(value: 90, label: Text('90日')),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
          AppSpacing.verticalLg,
          if (shop != null)
            AppCard(
              child: Text(
                _summary(shop),
                key: const Key('share_summary'),
              ),
            ),
          if (_error != null) ...[
            AppSpacing.verticalSm,
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          AppSpacing.verticalMd,
          FilledButton.icon(
            key: const Key('share_submit'),
            onPressed: (shop == null || _sharing) ? null : _share,
            icon: const Icon(Icons.send),
            label: Text(_sharing ? '渡しています…' : 'このお店に渡す'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSpacing.tapTargetMin),
            ),
          ),
          AppSpacing.verticalXl,
        ],
      ),
    );
  }

  static String _date(DateTime d) => '${d.year}/${d.month}/${d.day}';
}
