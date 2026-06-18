import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/inquiry.dart';
import '../../models/maintenance_record.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/inquiry_maintenance_importer.dart';

/// 問い合わせスレッド画面（ユーザー側）
///
/// 工場とのメッセージをチャット形式で表示する。
/// オープン中の問い合わせにはテキスト入力フィールドを表示し、
/// クローズ済みは入力不可にして理由を表示する。
class InquiryThreadScreen extends StatefulWidget {
  final Inquiry inquiry;

  const InquiryThreadScreen({super.key, required this.inquiry});

  @override
  State<InquiryThreadScreen> createState() => _InquiryThreadScreenState();
}

class _InquiryThreadScreenState extends State<InquiryThreadScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  // 返信に添付する写真（最大4枚）
  final List<Uint8List> _pendingImages = [];
  static const int _maxImages = 4;

  Future<void> _pickImages() async {
    final remaining = _maxImages - _pendingImages.length;
    if (remaining <= 0) return;
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked.isEmpty) return;
    final bytesList = <Uint8List>[];
    for (final x in picked.take(remaining)) {
      bytesList.add(await x.readAsBytes());
    }
    if (!mounted) return;
    setState(() => _pendingImages.addAll(bytesList));
  }

  void _removePendingImage(int i) => setState(() => _pendingImages.removeAt(i));

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

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if ((content.isEmpty && _pendingImages.isEmpty) || _isSending) return;

    final uid = context.read<AuthProvider>().firebaseUser?.uid;
    if (uid == null) return;
    // Capture the provider before any await to avoid using BuildContext across
    // async gaps.
    final shopProvider = context.read<ShopProvider>();

    final images = List<Uint8List>.from(_pendingImages);
    setState(() {
      _isSending = true;
      _pendingImages.clear();
    });
    _textController.clear();

    // 添付画像を Storage にアップロード
    final attachmentUrls = <String>[];
    if (images.isNotEmpty) {
      final fb = sl.get<FirebaseService>();
      final base =
          'inquiries/${widget.inquiry.id}/$uid/${DateTime.now().millisecondsSinceEpoch}';
      for (var i = 0; i < images.length; i++) {
        final r = await fb.uploadImageBytes(images[i], '$base/$i.jpg');
        final url = r.valueOrNull;
        if (url != null) attachmentUrls.add(url);
      }
    }

    await shopProvider.sendUserReply(
      inquiryId: widget.inquiry.id,
      userId: uid,
      content: content,
      attachmentUrls: attachmentUrls,
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
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _MessageBubble(
                      message: messages[index],
                      currentUserId:
                          context.read<AuthProvider>().firebaseUser?.uid ?? '',
                      inquiryId: widget.inquiry.id,
                      vehicleId: widget.inquiry.vehicleId,
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
              pendingImages: _pendingImages,
              maxImages: _maxImages,
              onPickImages: _pickImages,
              onRemoveImage: _removePendingImage,
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
  final String currentUserId;
  final String inquiryId;
  final String? vehicleId;

  const _MessageBubble({
    required this.message,
    required this.currentUserId,
    required this.inquiryId,
    required this.vehicleId,
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Text(
                '工場',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (message.content.trim().isNotEmpty)
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
          // 添付画像（写真）
          if (message.attachmentUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _AttachmentThumbnails(urls: message.attachmentUrls),
            ),
          // 工場が整備明細を添付した場合: ワンタップ取込カード（pull モデル）
          if (message.maintenancePayload != null)
            _MaintenanceImportCard(
              payload: InquiryMaintenancePayload.fromMap(
                message.maintenancePayload!,
              ),
              vehicleId: vehicleId,
              userId: currentUserId,
              inquiryId: inquiryId,
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

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// MaintenanceImportCard — shop-attached maintenance detail, user pulls in
// ---------------------------------------------------------------------------

class _MaintenanceImportCard extends StatefulWidget {
  final InquiryMaintenancePayload payload;
  final String? vehicleId;
  final String userId;
  final String inquiryId;

  const _MaintenanceImportCard({
    required this.payload,
    required this.vehicleId,
    required this.userId,
    required this.inquiryId,
  });

  @override
  State<_MaintenanceImportCard> createState() => _MaintenanceImportCardState();
}

class _MaintenanceImportCardState extends State<_MaintenanceImportCard> {
  bool _importing = false;
  bool _imported = false;

  Future<void> _import() async {
    if (_importing || _imported) return;
    final messenger = ScaffoldMessenger.of(context);

    if (widget.vehicleId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('車両が特定できないため取り込めません')),
      );
      return;
    }

    setState(() => _importing = true);
    try {
      final record = buildMaintenanceRecordFromPayload(
        payload: widget.payload,
        vehicleId: widget.vehicleId!,
        userId: widget.userId,
        inquiryId: widget.inquiryId,
      );
      final result =
          await sl.get<FirebaseService>().addMaintenanceRecord(record);
      if (!mounted) return;
      result.when(
        success: (_) {
          setState(() => _imported = true);
          messenger.showSnackBar(
            const SnackBar(content: Text('整備記録に追加しました')),
          );
        },
        failure: (_) {
          messenger.showSnackBar(
            const SnackBar(content: Text('整備記録の追加に失敗しました')),
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

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
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
            const SizedBox(height: 4),
            Text(
              '$typeLabel・${p.title.isEmpty ? '整備記録' : p.title}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              [
                if (p.cost > 0) '¥${p.cost}',
                if (p.mileageAtService != null) '${p.mileageAtService}km',
                '${p.date.year}/${p.date.month}/${p.date.day}',
              ].join(' ・ '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: _imported
                  ? OutlinedButton.icon(
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
  final List<Uint8List> pendingImages;
  final int maxImages;
  final VoidCallback onPickImages;
  final ValueChanged<int> onRemoveImage;

  const _MessageInputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.pendingImages,
    required this.maxImages,
    required this.onPickImages,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend =
        (controller.text.trim().isNotEmpty || pendingImages.isNotEmpty) &&
            !isSending;
    final canAttach = pendingImages.length < maxImages && !isSending;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 送信前の添付プレビュー
            if (pendingImages.isNotEmpty)
              SizedBox(
                height: 68,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < pendingImages.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 6),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                pendingImages[i],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => onRemoveImage(i),
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(Icons.close,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: canAttach ? onPickImages : null,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  tooltip: '写真を添付',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'メッセージを入力...',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
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
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AttachmentThumbnails — 受信/送信済みメッセージの添付画像（タップで全画面）
// ---------------------------------------------------------------------------

class _AttachmentThumbnails extends StatelessWidget {
  final List<String> urls;

  const _AttachmentThumbnails({required this.urls});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < urls.length; i++)
            GestureDetector(
              onTap: () => _showImageViewer(context, urls, i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  urls[i],
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 96,
                    height: 96,
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                          width: 96,
                          height: 96,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 添付画像を全画面で閲覧する（スワイプで複数枚 + ピンチズーム）。
void _showImageViewer(BuildContext context, List<String> urls, int initial) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (dialogContext) {
      final controller = PageController(initialPage: initial);
      return Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: urls.length,
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  urls[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ),
          ),
        ],
      );
    },
  );
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
