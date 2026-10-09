import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../services/detail_delivery_service.dart';
import '../../services/inquiry_maintenance_importer.dart';

/// "送った明細" on the customer page: each detail sent to this customer's
/// app, with whether it arrived and was added to their records.
///
/// Before this, sending only added a canned line to the thread and the shop
/// could not tell what happened next (usability test 2026-10-09, shop #10).
class SentDetailsSection extends StatefulWidget {
  final String shopId;
  final String userId;

  /// Bump to reload (e.g. after sending a detail).
  final int refreshToken;

  /// Defaults to the registered service; nothing is shown without one.
  final DetailDeliveryService? service;

  const SentDetailsSection({
    super.key,
    required this.shopId,
    required this.userId,
    this.refreshToken = 0,
    this.service,
  });

  @override
  State<SentDetailsSection> createState() => _SentDetailsSectionState();
}

class _SentDetailsSectionState extends State<SentDetailsSection> {
  List<SentDetail>? _details;
  String? _error;

  DetailDeliveryService? get _service =>
      widget.service ?? sl.tryGet<DetailDeliveryService>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SentDetailsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.userId != widget.userId) {
      _load();
    }
  }

  Future<void> _load() async {
    final service = _service;
    if (service == null) return;
    final r = await service.sentDetails(
      shopId: widget.shopId,
      userId: widget.userId,
    );
    if (!mounted) return;
    setState(() {
      _details = r.valueOrNull;
      _error = r.errorOrNull?.userMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_service == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final details = _details;

    return Column(
      key: const Key('sent_details_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSpacing.verticalLg,
        Text(
          '送った明細${details == null ? '' : '（${details.length}件）'}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_error != null)
          Text(_error!, style: theme.textTheme.bodySmall)
        else if (details == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: LinearProgressIndicator(),
          )
        else if (details.isEmpty)
          Text('まだ明細を送っていません。', style: theme.textTheme.bodySmall)
        else
          for (final d in details) _SentDetailTile(detail: d),
      ],
    );
  }
}

class _SentDetailTile extends StatelessWidget {
  final SentDetail detail;

  const _SentDetailTile({required this.detail});

  @override
  Widget build(BuildContext context) {
    final p = detail.payload;
    final status = detail.status;
    final color = switch (status) {
      SentDetailStatus.imported => AppColors.success,
      SentDetailStatus.seen => AppColors.info,
      SentDetailStatus.delivered => AppColors.textSecondary,
    };
    final sent = detail.sentAt;
    final imported = detail.importedAt;
    final statusText = status == SentDetailStatus.imported && imported != null
        ? '${status.label}（${imported.month}/${imported.day}）'
        : status.label;

    return Card(
      key: Key('sent_detail_${detail.message.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(
          status == SentDetailStatus.imported
              ? Icons.check_circle
              : Icons.receipt_long_outlined,
          color: color,
        ),
        title: Text([
          p.title.isEmpty ? '整備記録' : p.title,
          if (p.cost > 0) formatYen(p.cost),
        ].join('・')),
        subtitle: Text([
          '送付 ${sent.year}/${sent.month}/${sent.day}',
          if (p.vehicleDisplay != null) p.vehicleDisplay!,
        ].join('・')),
        trailing: Text(
          statusText,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ),
    );
  }
}
