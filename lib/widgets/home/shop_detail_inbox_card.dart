import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../providers/notification_provider.dart';
import '../../screens/marketplace/inquiry_thread_screen.dart';
import '../../services/inquiry_maintenance_importer.dart';
import '../../services/shop_detail_inbox_service.dart';

/// Home card: maintenance details shops sent that are not in the records yet.
///
/// Before this, a detail sat three screens deep (マーケット → 問い合わせ →
/// 「整備明細のお届け」) and the user did not notice it had arrived
/// (usability test 2026-10-09, shop #14). Nothing is shown when there are none.
class ShopDetailInboxCard extends StatefulWidget {
  /// Opens a detail. Defaults to the thread with the detail highlighted.
  final void Function(BuildContext context, ReceivedShopDetail detail)?
      onOpenDetail;

  const ShopDetailInboxCard({super.key, this.onOpenDetail});

  @override
  State<ShopDetailInboxCard> createState() => _ShopDetailInboxCardState();
}

class _ShopDetailInboxCardState extends State<ShopDetailInboxCard> {
  @override
  void initState() {
    super.initState();
    // Load on its own: the home screen only refreshes notifications when the
    // user has cars, and a detail can arrive before the first car is added.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().refreshShopDetails();
    });
  }

  void _open(ReceivedShopDetail detail) {
    final onOpen = widget.onOpenDetail;
    if (onOpen != null) {
      onOpen(context, detail);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InquiryThreadScreen(
          inquiry: detail.inquiry,
          focusMessageId: detail.message.id,
        ),
      ),
    ).then((_) {
      if (mounted) context.read<NotificationProvider>().refreshShopDetails();
    });
  }

  Future<void> _onTap(List<ReceivedShopDetail> details) async {
    if (details.length == 1) {
      _open(details.single);
      return;
    }
    final picked = await showModalBottomSheet<ReceivedShopDetail>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ListTile(title: Text('店から届いた明細')),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final d in details)
                    ListTile(
                      key: Key('home_shop_detail_${d.message.id}'),
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(_line(d)),
                      subtitle: Text(d.shopName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(ctx, d),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) _open(picked);
  }

  static String _line(ReceivedShopDetail d) {
    final p = d.payload;
    return [
      p.vehicleDisplay ?? d.inquiry.vehicleDisplay,
      p.title.isEmpty ? '整備記録' : p.title,
      if (p.cost > 0) formatYen(p.cost),
    ].whereType<String>().join('・');
  }

  @override
  Widget build(BuildContext context) {
    final details = context.watch<NotificationProvider>().pendingShopDetails;
    if (details.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final latest = details.first;

    return Card(
      key: const Key('home_shop_detail_card'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => _onTap(details),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  color: AppColors.primary, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '店から届いた明細（未取り込み ${details.length}件）',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${latest.shopName}：${_line(latest)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '押すと明細を開きます。「記録に追加」で整備記録に入ります',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
