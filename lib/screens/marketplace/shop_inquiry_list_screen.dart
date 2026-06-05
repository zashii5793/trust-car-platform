import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/inquiry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/inquiry_service.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/loading_indicator.dart';

/// Filter options displayed in the chip row.
///
/// [null] means "all statuses" (no filter applied).
typedef _StatusFilter = InquiryStatus?;

/// Shop owner's inquiry list screen.
///
/// Displays all inquiries for the given [shopId], sorted by updated date.
/// Unread inquiries are visually highlighted with a left border and bold text.
/// A filter chip row below the AppBar allows filtering by status.
class ShopInquiryListScreen extends StatefulWidget {
  final String shopId;

  const ShopInquiryListScreen({super.key, required this.shopId});

  @override
  State<ShopInquiryListScreen> createState() => _ShopInquiryListScreenState();
}

class _ShopInquiryListScreenState extends State<ShopInquiryListScreen> {
  /// Currently selected status filter. null = show all.
  _StatusFilter _selectedStatus;

  /// Ordered list of filter options shown in the chip row.
  static const List<({_StatusFilter status, String label})> _filterOptions = [
    (status: null, label: 'すべて'),
    (status: InquiryStatus.pending, label: '未対応'),
    (status: InquiryStatus.inProgress, label: '対応中'),
    (status: InquiryStatus.closed, label: 'クローズ'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShopProvider>().loadShopInquiries(widget.shopId);
    });
  }

  /// Switch the active status filter and reload from Firestore.
  void _applyFilter(_StatusFilter status) {
    if (_selectedStatus == status) return;
    setState(() => _selectedStatus = status);
    context.read<ShopProvider>().loadShopInquiries(
          widget.shopId,
          status: status,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('問い合わせ一覧')),
      body: Column(
        children: [
          // Status filter chip row
          _FilterChipRow(
            options: _filterOptions,
            selectedStatus: _selectedStatus,
            onSelected: _applyFilter,
          ),
          // Inquiry list
          Expanded(
            child: Consumer<ShopProvider>(
              builder: (context, provider, _) {
                if (provider.isLoadingShopInquiries) {
                  return const AppLoadingCenter(message: '問い合わせを読み込み中...');
                }

                final inquiries = provider.shopInquiries;

                if (inquiries.isEmpty) {
                  return AppEmptyState(
                    icon: _selectedStatus != null
                        ? Icons.filter_list_off
                        : Icons.mail_outline,
                    title: _selectedStatus != null
                        ? '該当する問い合わせがありません'
                        : '問い合わせはありません',
                    description: _selectedStatus != null
                        ? 'フィルターを変更してみてください'
                        : 'ユーザーからの問い合わせがここに表示されます',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => provider.loadShopInquiries(
                    widget.shopId,
                    status: _selectedStatus,
                  ),
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    itemCount: inquiries.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final inquiry = inquiries[index];
                      return _InquiryTile(
                        inquiry: inquiry,
                        onTap: () => _showDetail(context, inquiry),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Show inquiry detail in a bottom sheet.
  ///
  /// If the inquiry has unread messages for the shop, marks it as read before
  /// opening the sheet so the unread badge disappears immediately.
  Future<void> _showDetail(BuildContext context, Inquiry inquiry) async {
    // Mark as read optimistically when tapping an unread inquiry
    if (inquiry.unreadCountShop > 0) {
      // Local update first for instant UI feedback
      if (context.mounted) {
        context.read<ShopProvider>().markInquiryAsReadLocally(inquiry.id);
      }
      // Persist to Firestore in the background (fire-and-forget)
      InquiryService().markAsRead(inquiryId: inquiry.id, isUser: false);
    }

    if (!context.mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => _InquiryDetailSheet(
        inquiry: inquiry,
        shopProvider: context.read<ShopProvider>(),
        senderId:
            context.read<AuthProvider>().firebaseUser?.uid ?? inquiry.shopId,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip row
// ---------------------------------------------------------------------------

/// Horizontally scrollable row of filter chips for status selection.
class _FilterChipRow extends StatelessWidget {
  final List<({_StatusFilter status, String label})> options;
  final _StatusFilter selectedStatus;
  final void Function(_StatusFilter) onSelected;

  const _FilterChipRow({
    required this.options,
    required this.selectedStatus,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: options.map((opt) {
            final isSelected = selectedStatus == opt.status;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: FilterChip(
                label: Text(opt.label),
                selected: isSelected,
                onSelected: (_) => onSelected(opt.status),
                selectedColor: primary.withValues(alpha: 0.15),
                checkmarkColor: primary,
                labelStyle: TextStyle(
                  color: isSelected ? primary : theme.colorScheme.onSurface,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
                side: isSelected
                    ? BorderSide(color: primary)
                    : BorderSide(color: theme.colorScheme.outlineVariant),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inquiry list tile
// ---------------------------------------------------------------------------

class _InquiryTile extends StatelessWidget {
  final Inquiry inquiry;
  final Future<void> Function() onTap;

  const _InquiryTile({required this.inquiry, required this.onTap});

  bool get _hasUnread => inquiry.unreadCountShop > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        // Unread: highlight left border
        decoration: _hasUnread
            ? const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.info,
                    width: 4,
                  ),
                ),
              )
            : null,
        padding: EdgeInsets.only(
          left: _hasUnread ? AppSpacing.sm : AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status icon
            _StatusIcon(status: inquiry.status, hasUnread: _hasUnread),
            AppSpacing.horizontalMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject + unread badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          inquiry.subject,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: _hasUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_hasUnread) ...[
                        AppSpacing.horizontalXs,
                        _UnreadBadge(count: inquiry.unreadCountShop),
                      ],
                    ],
                  ),
                  AppSpacing.verticalXxs,
                  // Type chip + date
                  Row(
                    children: [
                      _TypeChip(type: inquiry.type),
                      AppSpacing.horizontalSm,
                      Text(
                        _formatDate(inquiry.updatedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.verticalXxs,
                  // Message preview
                  Text(
                    inquiry.initialMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _hasUnread
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${dt.month}/${dt.day}';
  }
}

// ---------------------------------------------------------------------------
// Status icon widget
// ---------------------------------------------------------------------------

class _StatusIcon extends StatelessWidget {
  final InquiryStatus status;
  final bool hasUnread;

  const _StatusIcon({required this.status, required this.hasUnread});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      InquiryStatus.pending => (Icons.mark_email_unread_outlined, AppColors.info),
      InquiryStatus.inProgress => (Icons.pending_outlined, AppColors.warning),
      InquiryStatus.replied => (Icons.mark_email_read_outlined, AppColors.success),
      InquiryStatus.closed => (Icons.check_circle_outline, AppColors.textTertiary),
      InquiryStatus.cancelled => (Icons.cancel_outlined, AppColors.error),
    };

    return Icon(icon, color: color, size: AppSpacing.iconMd);
  }
}

// ---------------------------------------------------------------------------
// Unread count badge
// ---------------------------------------------------------------------------

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.info,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inquiry type chip
// ---------------------------------------------------------------------------

class _TypeChip extends StatelessWidget {
  final InquiryType type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.displayName,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inquiry detail bottom sheet (with reply input)
// ---------------------------------------------------------------------------

class _InquiryDetailSheet extends StatefulWidget {
  final Inquiry inquiry;

  /// ShopProvider passed directly to avoid BuildContext scope issues inside
  /// showModalBottomSheet's builder.
  final ShopProvider shopProvider;

  /// Firebase UID of the shop owner — used as senderId when sending replies.
  final String senderId;

  const _InquiryDetailSheet({
    required this.inquiry,
    required this.shopProvider,
    required this.senderId,
  });

  @override
  State<_InquiryDetailSheet> createState() => _InquiryDetailSheetState();
}

class _InquiryDetailSheetState extends State<_InquiryDetailSheet> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isUpdatingStatus = false;

  // Local copy of the inquiry to reflect status changes immediately.
  late Inquiry _inquiry;

  @override
  void initState() {
    super.initState();
    _inquiry = widget.inquiry;
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll the message list to the bottom.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Send a reply message from the shop side.
  Future<void> _sendReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);

    final result = await widget.shopProvider.sendInquiryMessage(
      inquiryId: _inquiry.id,
      senderId: widget.senderId,
      content: content,
    );

    if (!mounted) return;

    setState(() => _isSending = false);

    result.when(
      success: (_) {
        _replyController.clear();
        _scrollToBottom();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('返信を送信しました')),
        );
      },
      failure: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err.userMessage),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }

  /// Show confirmation dialog and update inquiry status.
  Future<void> _changeStatus(InquiryStatus newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('ステータス変更'),
        content: Text('ステータスを「${newStatus.displayName}」に変更しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('変更する'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isUpdatingStatus = true);

    final success = await widget.shopProvider.updateInquiryStatus(
      _inquiry.id,
      newStatus,
    );

    if (!mounted) return;

    setState(() => _isUpdatingStatus = false);

    if (success) {
      // Reflect the new status locally for immediate feedback.
      setState(() {
        _inquiry = _inquiry.copyWith(status: newStatus);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ステータスを「${newStatus.displayName}」に変更しました'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.shopProvider.errorMessage ?? 'ステータスの変更に失敗しました',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, __) {
        return Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Scrollable content area
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: AppSpacing.paddingScreen,
                children: [
                  // Subject
                  Text(
                    _inquiry.subject,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.verticalXs,
                  // Meta row: type chip + status chip
                  Row(
                    children: [
                      _TypeChip(type: _inquiry.type),
                      AppSpacing.horizontalSm,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(_inquiry.status)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _inquiry.status.displayName,
                          style: TextStyle(
                            fontSize: 10,
                            color: _statusColor(_inquiry.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.verticalMd,
                  Divider(color: theme.dividerColor),
                  AppSpacing.verticalMd,
                  // Initial message (user's first message)
                  _MessageBubble(
                    content: _inquiry.initialMessage,
                    isFromShop: false,
                    sentAt: _inquiry.createdAt,
                  ),
                  if (_inquiry.vehicleDisplay != null) ...[
                    AppSpacing.verticalSm,
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_car_outlined,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                        AppSpacing.horizontalXs,
                        Text(
                          _inquiry.vehicleDisplay!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                  AppSpacing.verticalMd,
                  // Real-time message thread
                  StreamBuilder<List<InquiryMessage>>(
                    stream: widget.shopProvider
                        .streamInquiryMessages(_inquiry.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final messages = snapshot.data ?? [];
                      if (messages.isEmpty) {
                        return Text(
                          'まだ返信はありません',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        );
                      }
                      return Column(
                        children: messages
                            .map(
                              (msg) => _MessageBubble(
                                content: msg.content,
                                isFromShop: msg.isFromShop,
                                sentAt: msg.sentAt,
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  // Date info footer
                  AppSpacing.verticalMd,
                  Text(
                    '送信日時: ${_formatDateTime(_inquiry.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_inquiry.repliedAt != null)
                    Text(
                      '返信日時: ${_formatDateTime(_inquiry.repliedAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            // Status change action bar (above reply input)
            _StatusActionBar(
              status: _inquiry.status,
              isLoading: _isUpdatingStatus,
              onChangeStatus: _changeStatus,
            ),
            // Reply input area (fixed at bottom)
            _ReplyInputBar(
              controller: _replyController,
              isSending: _isSending,
              onSend: _sendReply,
            ),
          ],
        );
      },
    );
  }

  Color _statusColor(InquiryStatus status) {
    return switch (status) {
      InquiryStatus.pending => AppColors.info,
      InquiryStatus.inProgress => AppColors.warning,
      InquiryStatus.replied => AppColors.success,
      InquiryStatus.closed => AppColors.textTertiary,
      InquiryStatus.cancelled => AppColors.error,
    };
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  final String content;
  final bool isFromShop;
  final DateTime sentAt;

  const _MessageBubble({
    required this.content,
    required this.isFromShop,
    required this.sentAt,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment =
        isFromShop ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isFromShop
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isFromShop
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: isFromShop
                    ? const Radius.circular(12)
                    : const Radius.circular(2),
                bottomRight: isFromShop
                    ? const Radius.circular(2)
                    : const Radius.circular(12),
              ),
            ),
            child: Text(content, style: TextStyle(color: textColor)),
          ),
          const SizedBox(height: 2),
          Text(
            _formatTime(sentAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status action bar
// ---------------------------------------------------------------------------

/// Shows the current status badge and action buttons to change the status.
///
/// - pending / replied: shows "対応中にする" + "クローズ" buttons
/// - inProgress: shows "クローズ" button only
/// - closed / cancelled: shows "再オープン" button
class _StatusActionBar extends StatelessWidget {
  final InquiryStatus status;
  final bool isLoading;
  final void Function(InquiryStatus) onChangeStatus;

  const _StatusActionBar({
    required this.status,
    required this.isLoading,
    required this.onChangeStatus,
  });

  Color _statusColor(InquiryStatus s) {
    return switch (s) {
      InquiryStatus.pending => AppColors.info,
      InquiryStatus.inProgress => AppColors.warning,
      InquiryStatus.replied => AppColors.success,
      InquiryStatus.closed => AppColors.textTertiary,
      InquiryStatus.cancelled => AppColors.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine which action buttons to show based on current status.
    final List<_StatusButton> buttons = switch (status) {
      InquiryStatus.pending || InquiryStatus.replied => [
          _StatusButton(
            label: '対応中にする',
            status: InquiryStatus.inProgress,
            color: AppColors.warning,
          ),
          _StatusButton(
            label: 'クローズ',
            status: InquiryStatus.closed,
            color: AppColors.textTertiary,
          ),
        ],
      InquiryStatus.inProgress => [
          _StatusButton(
            label: 'クローズ',
            status: InquiryStatus.closed,
            color: AppColors.textTertiary,
          ),
        ],
      InquiryStatus.closed || InquiryStatus.cancelled => [
          _StatusButton(
            label: '再オープン',
            status: InquiryStatus.pending,
            color: AppColors.info,
          ),
        ],
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          // Current status badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.displayName,
              style: TextStyle(
                fontSize: 11,
                color: _statusColor(status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          AppSpacing.horizontalSm,
          // Spacer pushes buttons to the right
          const Spacer(),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ...buttons.map(
              (btn) => Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: btn.color,
                    side: BorderSide(color: btn.color),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => onChangeStatus(btn.status),
                  child: Text(btn.label),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Data class for a single status action button.
class _StatusButton {
  final String label;
  final InquiryStatus status;
  final Color color;

  const _StatusButton({
    required this.label,
    required this.status,
    required this.color,
  });
}

// ---------------------------------------------------------------------------
// Reply input bar
// ---------------------------------------------------------------------------

class _ReplyInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _ReplyInputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm + bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: '返信メッセージを入力...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                isDense: true,
              ),
            ),
          ),
          AppSpacing.horizontalSm,
          SizedBox(
            width: 44,
            height: 44,
            child: isSending
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    onPressed: onSend,
                    icon: const Icon(Icons.send),
                    color: theme.colorScheme.primary,
                    tooltip: '送信',
                  ),
          ),
        ],
      ),
    );
  }
}
