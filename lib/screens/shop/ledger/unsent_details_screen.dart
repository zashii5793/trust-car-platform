import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../services/detail_delivery_service.dart';
import '../../../services/shop_audit_service.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/loading_indicator.dart';
import 'ledger_format.dart';

/// 送っていない明細（2026-09-29 プロダクト評価 #4「明細送付を入庫の流れに組み込む」）。
///
/// 取り込んだ整備履歴のうち、アプリとつながっているお客さんの伝票で、まだ
/// 明細を送っていないものを並べる。選んでまとめて送る。送り方は顧客を開いて
/// 1件ずつ送るときと同じ（店から開いたスレッドに明細を置く）。
///
/// 上に「明細送付率（送った入庫 ÷ アプリ利用客の入庫）」を出す。
class UnsentDetailsScreen extends StatefulWidget {
  final DetailDeliveryService service;
  final String shopId;
  final String shopName;

  /// 送る人（いまログインしている店主・スタッフ）の uid。
  final String senderUid;

  final AuditRecorder? onAudit;

  const UnsentDetailsScreen({
    super.key,
    required this.service,
    required this.shopId,
    required this.shopName,
    required this.senderUid,
    this.onAudit,
  });

  @override
  State<UnsentDetailsScreen> createState() => _UnsentDetailsScreenState();
}

class _UnsentDetailsScreenState extends State<UnsentDetailsScreen> {
  DetailDeliveryList? _list;
  String? _error;
  final _selected = <String>{};
  bool _sending = false;
  int _done = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final r = await widget.service.pending(shopId: widget.shopId);
    if (!mounted) return;
    setState(() {
      _list = r.valueOrNull;
      _error = r.errorOrNull?.userMessage;
      // 一覧に無くなったものは選択から外す
      final ids = {for (final d in _list?.drafts ?? const []) d.recordId};
      _selected.removeWhere((id) => !ids.contains(id));
    });
  }

  List<DetailDraft> get _drafts => _list?.drafts ?? const [];

  List<DetailDraft> get _chosen =>
      _drafts.where((d) => _selected.contains(d.recordId)).toList();

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        _selected.addAll(_drafts.map((d) => d.recordId));
      } else {
        _selected.clear();
      }
    });
  }

  Future<void> _send() async {
    final chosen = _chosen;
    if (chosen.isEmpty) return;
    final people = chosen.map((d) => d.customerId).toSet().length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('整備明細をまとめて送りますか？'),
        content: Text('${chosen.length}件の整備明細を、$people人のお客さんのアプリに'
            '送ります。届いた明細は、お客さんが「記録に追加」で自分の記録に'
            '入れられます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('やめる'),
          ),
          FilledButton(
            key: const Key('detail_send_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('送る'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _sending = true;
      _done = 0;
      _total = chosen.length;
    });
    final r = await widget.service.sendAll(
      shopId: widget.shopId,
      shopName: widget.shopName,
      senderId: widget.senderUid,
      drafts: chosen,
      onProgress: (done, total) {
        if (mounted) {
          setState(() {
            _done = done;
            _total = total;
          });
        }
      },
    );
    if (!mounted) return;
    setState(() => _sending = false);

    final result = r.valueOrNull;
    if (result == null) {
      _snack('送れませんでした: ${r.errorOrNull?.userMessage ?? ''}');
      return;
    }

    // 操作の記録は、1件ずつ送るときと同じ「整備明細を送った」をお客さんごとに
    final sentIds = result.sentRecordIds.toSet();
    final byCustomer = <String, List<DetailDraft>>{};
    for (final d in chosen.where((d) => sentIds.contains(d.recordId))) {
      byCustomer.putIfAbsent(d.customerId, () => []).add(d);
    }
    for (final e in byCustomer.entries) {
      widget.onAudit?.call(
        ShopAuditAction.sendDetail,
        targetId: e.key,
        targetLabel: e.value.first.customerName,
        detail: '送っていない明細からまとめて送った・${e.value.length}件',
      );
    }

    final parts = [
      '${result.sent}件の整備明細を送りました',
      if (result.alreadySent > 0) '${result.alreadySent}件は送ってあったので飛ばしました',
      if (result.failures.isNotEmpty)
        '${result.failures.length}件は送れませんでした（${result.failures.first.message}）',
    ];
    _snack(parts.join('。'));
    _selected.clear();
    await _load();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        appBar: AppBar(title: const Text('送っていない明細')),
        body: list == null
            ? (_error == null
                ? const AppLoadingCenter()
                : AppEmptyState(
                    icon: Icons.error_outline,
                    title: '読み込めませんでした',
                    description: _error,
                    buttonLabel: 'もう一度',
                    onButtonPressed: _load,
                  ))
            : _body(context, list),
        bottomNavigationBar: list == null || list.drafts.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: AppSpacing.paddingScreen,
                  child: FilledButton.icon(
                    key: const Key('detail_send_selected'),
                    onPressed: _sending || _selected.isEmpty ? null : _send,
                    icon: const Icon(Icons.send_outlined),
                    label: Text('まとめて送る（${_selected.length}件）'),
                    style: FilledButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(AppSpacing.tapTargetMin),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _body(BuildContext context, DetailDeliveryList list) {
    final theme = Theme.of(context);
    final allSelected =
        list.drafts.isNotEmpty && _selected.length == list.drafts.length;
    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        _RateCard(list: list),
        if (_sending) ...[
          AppSpacing.verticalSm,
          LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
        ],
        AppSpacing.verticalMd,
        if (list.drafts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: AppEmptyState(
              icon: Icons.mark_email_read_outlined,
              title: '送っていない明細はありません',
              description: '台帳の「CSVから取り込む」で整備履歴を取り込むと、'
                  'アプリを使っているお客さんの入庫がここに並びます。',
              buttonLabel: '台帳に戻る',
              onButtonPressed: () => Navigator.maybePop(context),
            ),
          )
        else ...[
          CheckboxListTile(
            key: const Key('detail_select_all'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: allSelected,
            onChanged: _sending ? null : _toggleAll,
            title: Text('すべて選ぶ（${list.drafts.length}件）'),
          ),
          const Divider(height: 1),
          for (final d in list.drafts)
            CheckboxListTile(
              key: Key('detail_draft_${d.recordId}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _selected.contains(d.recordId),
              onChanged: _sending
                  ? null
                  : (v) => setState(() {
                        if (v == true) {
                          _selected.add(d.recordId);
                        } else {
                          _selected.remove(d.recordId);
                        }
                      }),
              title: Text(
                [d.customerName, if (d.vehicleLabel.isNotEmpty) d.vehicleLabel]
                    .join('　'),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text([
                ledgerDate(d.date),
                if (d.typeText.isNotEmpty) d.typeText,
                '${ledgerNumber(d.totalCost)}円',
                if (d.mileage != null) '${ledgerNumber(d.mileage!)}km',
              ].join('・')),
            ),
          AppSpacing.verticalSm,
          Text(
            '送る中身は取り込んだ伝票のまま（実施日・作業内容・金額・走行距離）です。'
            '内訳を足したいときは、顧客を開いて1件ずつ送ってください。',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _RateCard extends StatelessWidget {
  final DetailDeliveryList list;

  const _RateCard({required this.list});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = list.rate;
    return AppCard(
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('明細送付率', style: theme.textTheme.bodySmall),
              Text(
                rate == null ? '—' : '${(rate * 100).round()}%',
                key: const Key('detail_rate'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: rate != null && rate < 0.5 ? AppColors.warning : null,
                ),
              ),
            ],
          ),
          AppSpacing.horizontalMd,
          Expanded(
            child: Text(
              '直近${list.days}日・アプリ利用客の入庫 ${list.linkedRecords}件のうち '
              '${list.sentRecords}件に明細を送りました',
              key: const Key('detail_rate_note'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
