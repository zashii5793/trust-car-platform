import 'package:flutter/material.dart';

import '../../../services/shop_audit_service.dart';
import '../../../widgets/common/loading_indicator.dart';
import 'ledger_paged_list.dart';

String _time(DateTime d) =>
    '${d.year}/${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

/// 店主が「誰がいつ、どの顧客に何をしたか」を確かめる画面。
///
/// 記録は後から書き換え・削除できない（ルール）。新しい順に20件ずつ。
class AuditLogScreen extends StatelessWidget {
  final ShopAuditService service;
  final String shopId;

  const AuditLogScreen(
      {super.key, required this.service, required this.shopId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('操作の記録')),
      body: LedgerPagedList<ShopAuditEntry>(
        loader: (cursor) => service.list(shopId: shopId, cursor: cursor),
        itemBuilder: (context, e) => ListTile(
          leading: const Icon(Icons.history),
          title: Text([
            e.actorName,
            e.action?.label ?? '（不明な操作）',
          ].join(' が ')),
          subtitle: Text([
            _time(e.at),
            if (e.targetLabel != null) e.targetLabel!,
            if (e.detail != null) e.detail!,
          ].join('・')),
        ),
        empty: AppEmptyState(
          icon: Icons.history,
          title: 'まだ記録はありません',
          description: '顧客を見る・直す・取り込む・明細を送るといった操作が、'
              'ここに残ります。',
          buttonLabel: '顧客台帳に戻る',
          onButtonPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
