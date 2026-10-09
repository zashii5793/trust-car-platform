import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/inquiry.dart';
import '../../models/maintenance_record.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../models/vehicle.dart';
import '../../services/inquiry_maintenance_importer.dart';
import '../../services/shop_detail_inbox_service.dart';
import '../../widgets/shop/import_vehicle_sheet.dart';

/// 問い合わせスレッド画面（ユーザー側）
///
/// 工場とのメッセージをチャット形式で表示する。
/// オープン中の問い合わせにはテキスト入力フィールドを表示し、
/// クローズ済みは入力不可にして理由を表示する。
class InquiryThreadScreen extends StatefulWidget {
  final Inquiry inquiry;

  /// Adds shop-sent details to the records. Defaults to the registered one.
  final ShopDetailInboxService? detailInbox;

  /// Message to highlight when opened from the home card or a notification.
  final String? focusMessageId;

  const InquiryThreadScreen({
    super.key,
    required this.inquiry,
    this.detailInbox,
    this.focusMessageId,
  });

  @override
  State<InquiryThreadScreen> createState() => _InquiryThreadScreenState();
}

class _InquiryThreadScreenState extends State<InquiryThreadScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  /// Details already in the user's records. Loaded once per screen from the
  /// marks on the messages and from the records, so reopening the thread
  /// still says "追加済み" (it used to live only in the card's state).
  final Set<String> _importedIds = {};
  bool _importedLoaded = false;

  ShopDetailInboxService? get _inbox =>
      widget.detailInbox ?? sl.tryGet<ShopDetailInboxService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShopProvider>().markUserInquiryAsReadLocally(
            widget.inquiry.id,
          );
    });
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// First time the messages arrive: find which details are already added,
  /// and tell the shop the details reached the user (read).
  void _onFirstMessages(List<InquiryMessage> messages) {
    if (_importedLoaded) return;
    _importedLoaded = true;
    final inbox = _inbox;
    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (inbox == null || uid == null) return;
    if (!messages.any((m) => m.hasMaintenanceDetail)) return;
    Future(() async {
      final ids = await inbox.importedMessageIds(
        userId: uid,
        inquiryId: widget.inquiry.id,
        messages: messages,
      );
      if (!mounted) return;
      final found = ids.valueOrNull;
      if (found != null && found.isNotEmpty) {
        setState(() => _importedIds.addAll(found));
      }
      await inbox.markSeen(inquiryId: widget.inquiry.id, messages: messages);
    });
  }

  void _onImported(String messageId) {
    setState(() => _importedIds.add(messageId));
    // The home card and the notifications count details not yet added.
    try {
      context.read<NotificationProvider>().refreshShopDetails();
    } catch (_) {
      // No NotificationProvider above this screen (tests): nothing to update.
    }
  }

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _isSending) return;

    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;

    setState(() => _isSending = true);
    _textController.clear();

    await context.read<ShopProvider>().sendUserReply(
          inquiryId: widget.inquiry.id,
          userId: uid,
          content: content,
        );

    if (mounted) {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = widget.inquiry.isOpen;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.inquiry.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.md, bottom: AppSpacing.xs),
            child: Row(
              children: [
                if (widget.inquiry.shopName != null) ...[
                  Icon(Icons.store_outlined,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    widget.inquiry.shopName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: StreamBuilder<List<InquiryMessage>>(
              stream: context
                  .read<ShopProvider>()
                  .streamInquiryMessages(widget.inquiry.id),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'メッセージはまだありません',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                _onFirstMessages(messages);
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    return _MessageBubble(
                      message: m,
                      inquiry: widget.inquiry,
                      currentUserId:
                          context.read<AuthProvider>().firebaseUser?.uid ?? '',
                      imported:
                          m.isDetailImported || _importedIds.contains(m.id),
                      highlighted: m.id == widget.focusMessageId,
                      inbox: _inbox,
                      onImported: () => _onImported(m.id),
                    );
                  },
                );
              },
            ),
          ),

          // Input area or closed notice
          if (isOpen)
            _MessageInputBar(
              controller: _textController,
              isSending: _isSending,
              onSend: _sendMessage,
            )
          else
            _ClosedNotice(status: widget.inquiry.status),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MessageBubble
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  final InquiryMessage message;
  final Inquiry inquiry;
  final String currentUserId;
  final bool imported;
  final bool highlighted;
  final ShopDetailInboxService? inbox;
  final VoidCallback onImported;

  const _MessageBubble({
    required this.message,
    required this.inquiry,
    required this.currentUserId,
    required this.imported,
    required this.highlighted,
    required this.inbox,
    required this.onImported,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = !message.isFromShop;
    final bubbleColor =
        isMe ? AppColors.primary : theme.colorScheme.surfaceContainerHighest;
    final textColor = isMe ? Colors.white : theme.colorScheme.onSurface;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(AppSpacing.radiusMd),
      topRight: const Radius.circular(AppSpacing.radiusMd),
      bottomLeft: Radius.circular(isMe ? AppSpacing.radiusMd : 4),
      bottomRight: Radius.circular(isMe ? 4 : AppSpacing.radiusMd),
    );
    final shopName = inquiry.shopName?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          // The sender by the shop's name: "工場" alone did not say who
          // sent the detail (usability test 2026-10-09).
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Text(
                (shopName == null || shopName.isEmpty) ? '工場' : shopName,
                key: const Key('thread_shop_sender'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: bubbleRadius,
                  ),
                  child: Text(
                    message.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // 工場が整備明細を添付した場合: ワンタップ取込カード（pull モデル）
          if (message.maintenancePayload != null)
            _MaintenanceImportCard(
              payload: InquiryMaintenancePayload.fromMap(
                message.maintenancePayload!,
              ),
              messageId: message.id,
              inquiry: inquiry,
              userId: currentUserId,
              imported: imported,
              highlighted: highlighted,
              inbox: inbox,
              onImported: onImported,
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(
              _formatTime(message.sentAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Date and time, because a thread with a shop you keep going back to spans
  /// months — a bare `10:15` cannot tell June 29th from July 11th. The year is
  /// added only when it is not the current one, to keep the line short.
  /// The shop-side screen has always shown `6/29 10:15`; this side had not.
  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final date = dt.year == DateTime.now().year
        ? '${dt.month}/${dt.day}'
        : '${dt.year}/${dt.month}/${dt.day}';
    return '$date $h:$m';
  }
}

// ---------------------------------------------------------------------------
// MaintenanceImportCard — shop-attached maintenance detail, user pulls in
// ---------------------------------------------------------------------------

class _MaintenanceImportCard extends StatefulWidget {
  final InquiryMaintenancePayload payload;
  final String messageId;
  final Inquiry inquiry;
  final String userId;

  /// Already in the user's records (kept on the message / the record, so it
  /// survives reopening the thread).
  final bool imported;
  final bool highlighted;
  final ShopDetailInboxService? inbox;
  final VoidCallback onImported;

  const _MaintenanceImportCard({
    required this.payload,
    required this.messageId,
    required this.inquiry,
    required this.userId,
    required this.imported,
    required this.highlighted,
    required this.inbox,
    required this.onImported,
  });

  @override
  State<_MaintenanceImportCard> createState() => _MaintenanceImportCardState();
}

class _MaintenanceImportCardState extends State<_MaintenanceImportCard> {
  bool _importing = false;
  bool _importedHere = false;
  bool _noVehicles = false;

  bool get _imported => widget.imported || _importedHere;

  /// The car as the shop named it, or the car the user asked about.
  String? get _vehicleText =>
      widget.payload.vehicleDisplay ?? widget.inquiry.vehicleDisplay;

  /// どの車の明細かを決める。車が無ければ null（[_noVehicles] を立てる）。
  ///
  /// - 利用者がこの車について問い合わせたスレッドなら、その車
  /// - 1台だけならその車
  /// - それ以外は選んでもらう。店が車を指定していれば、その車を初期選択に
  Future<String?> _chooseVehicle() async {
    List<Vehicle> vehicles;
    try {
      vehicles = context
          .read<VehicleProvider>()
          .vehicles
          .where((v) => v.userId == widget.userId)
          .toList();
    } catch (_) {
      vehicles = const [];
    }
    _noVehicles = vehicles.isEmpty;
    if (vehicles.isEmpty) return null;

    final asked = widget.inquiry.vehicleId;
    if (asked != null && vehicles.any((v) => v.id == asked)) return asked;
    if (vehicles.length == 1) return vehicles.single.id;

    return showImportVehicleSheet(
      context,
      vehicles: vehicles,
      initialVehicleId: suggestImportVehicleId(
        payload: widget.payload,
        vehicles: vehicles,
      ),
      shopVehicleLabel: widget.payload.vehicleDisplay,
    );
  }

  Future<void> _import() async {
    if (_importing || _imported) return;
    final messenger = ScaffoldMessenger.of(context);
    final inbox = widget.inbox;
    if (inbox == null || widget.userId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('整備記録の追加に失敗しました')),
      );
      return;
    }

    final vehicleId = await _chooseVehicle();
    if (vehicleId == null) {
      if (mounted && _noVehicles) {
        messenger.showSnackBar(
          const SnackBar(content: Text('先に車両を登録してから取り込んでください')),
        );
      }
      return;
    }

    setState(() => _importing = true);
    try {
      final result = await inbox.importDetail(
        userId: widget.userId,
        inquiryId: widget.inquiry.id,
        messageId: widget.messageId,
        payload: widget.payload,
        vehicleId: vehicleId,
      );
      if (!mounted) return;
      result.when(
        success: (r) {
          setState(() => _importedHere = true);
          widget.onImported();
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                  r.alreadyImported ? 'この明細はすでに記録に追加してあります' : '整備記録に追加しました'),
            ),
          );
        },
        failure: (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('整備記録の追加に失敗しました（${e.userMessage}）')),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.payload;
    final typeLabel = MaintenanceType.fromString(p.typeKey).displayName;
    final title = p.title.isEmpty ? '整備記録' : p.title;
    // "12ヶ月点検・12ヶ月点検": do not repeat the same words.
    final heading = title.contains(typeLabel) ? title : '$typeLabel・$title';
    final vehicle = _vehicleText;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      child: Container(
        key: Key('detail_card_${widget.messageId}'),
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: widget.highlighted
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.35),
            width: widget.highlighted ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build_circle_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '整備明細',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (vehicle != null) ...[
              const SizedBox(height: 4),
              Row(
                key: const Key('detail_card_vehicle'),
                children: [
                  Icon(Icons.directions_car_outlined,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(vehicle, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              heading,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              [
                if (p.cost > 0) formatYen(p.cost),
                if (p.mileageAtService != null)
                  '${formatThousands(p.mileageAtService!)}km',
                '${p.date.year}/${p.date.month}/${p.date.day}',
              ].join(' ・ '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Say before adding that the shop's record cannot be edited
            // (the rules lock amount, date and work on shop records).
            Text(
              '店が出した記録です。記録に追加すると、金額・日付・作業内容は'
              '変えられません（メモや写真は足せます）。',
              key: const Key('detail_locked_notice'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: _imported
                  ? OutlinedButton.icon(
                      key: const Key('import_maintenance_done'),
                      onPressed: null,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('追加済み'),
                    )
                  : FilledButton.icon(
                      key: const Key('import_maintenance_btn'),
                      onPressed: _importing ? null : _import,
                      icon: _importing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add, size: 16),
                      label: const Text('記録に追加'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MessageInputBar
// ---------------------------------------------------------------------------

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _MessageInputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = controller.text.trim().isNotEmpty && !isSending;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'メッセージを入力...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  isDense: true,
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            AnimatedOpacity(
              opacity: canSend ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: IconButton(
                onPressed: canSend ? onSend : null,
                icon: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ClosedNotice
// ---------------------------------------------------------------------------

class _ClosedNotice extends StatelessWidget {
  final InquiryStatus status;

  const _ClosedNotice({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = status == InquiryStatus.cancelled
        ? 'この問い合わせはキャンセルされました'
        : 'この問い合わせはクローズされました';

    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
