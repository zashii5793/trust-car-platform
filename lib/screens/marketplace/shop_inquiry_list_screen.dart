import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/inquiry.dart';
import '../../providers/shop_provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/loading_indicator.dart';

/// Shop owner's inquiry list screen.
///
/// Displays all inquiries for the given [shopId], sorted by updated date.
/// Unread inquiries are visually highlighted with a left border and bold text.
class ShopInquiryListScreen extends StatefulWidget {
  final String shopId;

  const ShopInquiryListScreen({super.key, required this.shopId});

  @override
  State<ShopInquiryListScreen> createState() => _ShopInquiryListScreenState();
}

class _ShopInquiryListScreenState extends State<ShopInquiryListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShopProvider>().loadShopInquiries(widget.shopId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('問い合わせ一覧')),
      body: Consumer<ShopProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingShopInquiries) {
            return const AppLoadingCenter(message: '問い合わせを読み込み中...');
          }

          final inquiries = provider.shopInquiries;

          if (inquiries.isEmpty) {
            return const _EmptyView();
          }

          return RefreshIndicator(
            onRefresh: () =>
                provider.loadShopInquiries(widget.shopId),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
    );
  }

  /// Show inquiry detail in a bottom sheet.
  void _showDetail(BuildContext context, Inquiry inquiry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _InquiryDetailSheet(inquiry: inquiry),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mail_outline,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          AppSpacing.verticalMd,
          Text(
            'まだ問い合わせはありません',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inquiry list tile
// ---------------------------------------------------------------------------

class _InquiryTile extends StatelessWidget {
  final Inquiry inquiry;
  final VoidCallback onTap;

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
// Inquiry detail bottom sheet
// ---------------------------------------------------------------------------

class _InquiryDetailSheet extends StatelessWidget {
  final Inquiry inquiry;

  const _InquiryDetailSheet({required this.inquiry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
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
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: AppSpacing.paddingScreen,
                children: [
                  // Subject
                  Text(
                    inquiry.subject,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.verticalXs,
                  // Meta row
                  Row(
                    children: [
                      _TypeChip(type: inquiry.type),
                      AppSpacing.horizontalSm,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(inquiry.status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          inquiry.status.displayName,
                          style: TextStyle(
                            fontSize: 10,
                            color: _statusColor(inquiry.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.verticalMd,
                  Divider(color: theme.dividerColor),
                  AppSpacing.verticalMd,
                  // Initial message
                  Text(
                    inquiry.initialMessage,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (inquiry.vehicleDisplay != null) ...[
                    AppSpacing.verticalMd,
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_car_outlined,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                        AppSpacing.horizontalXs,
                        Text(
                          inquiry.vehicleDisplay!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                  AppSpacing.verticalXl,
                  // Date info
                  Text(
                    '送信日時: ${_formatDateTime(inquiry.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (inquiry.repliedAt != null)
                    Text(
                      '返信日時: ${_formatDateTime(inquiry.repliedAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
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
