import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/inquiry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import 'inquiry_thread_screen.dart';

/// ユーザーが送信した問い合わせ一覧画面
///
/// 各アイテムには件名・工場名・ステータス・未読バッジを表示し、
/// タップすると InquiryThreadScreen へ遷移する。
class MyInquiriesScreen extends StatefulWidget {
  const MyInquiriesScreen({super.key});

  @override
  State<MyInquiriesScreen> createState() => _MyInquiriesScreenState();
}

class _MyInquiriesScreenState extends State<MyInquiriesScreen> {
  ShopProvider? _shopProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _shopProvider = context.read<ShopProvider>();
      final uid = context.read<AuthProvider>().firebaseUser?.uid;
      if (uid != null) {
        _shopProvider!.watchUserInquiries(uid);
      }
    });
  }

  @override
  void dispose() {
    _shopProvider?.stopWatchingUserInquiries();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('マイ問い合わせ')),
      body: Consumer<ShopProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingUserInquiries) {
            return const AppLoadingCenter(message: '読み込み中...');
          }

          final inquiries = provider.userInquiries;

          if (inquiries.isEmpty) {
            return const AppEmptyState(
              icon: Icons.inbox_outlined,
              title: '問い合わせはありません',
              description: '工場詳細画面から問い合わせを送れます',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: inquiries.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              return _InquiryCard(inquiry: inquiries[index]);
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// InquiryCard
// ---------------------------------------------------------------------------

class _InquiryCard extends StatelessWidget {
  final Inquiry inquiry;

  const _InquiryCard({required this.inquiry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = inquiry.unreadCountUser;
    final isUnread = unread > 0;

    return Card(
      elevation: isUnread ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: isUnread
            ? BorderSide(color: AppColors.primary, width: 1.5)
            : BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InquiryThreadScreen(inquiry: inquiry),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 件名 + 未読バッジ
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      inquiry.subject,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight:
                            isUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isUnread) ...[
                    const SizedBox(width: AppSpacing.xs),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // 工場名
              if (inquiry.shopName != null)
                Row(
                  children: [
                    Icon(Icons.store_outlined,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      inquiry.shopName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: AppSpacing.xs),

              // ステータス + 日付
              Row(
                children: [
                  _StatusChip(status: inquiry.status),
                  const Spacer(),
                  Text(
                    _formatDate(inquiry.updatedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '今日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return '昨日';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${dt.month}/${dt.day}';
  }
}

// ---------------------------------------------------------------------------
// StatusChip
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  final InquiryStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      InquiryStatus.pending => ('返信待ち', AppColors.warning),
      InquiryStatus.inProgress => ('対応中', AppColors.info),
      InquiryStatus.replied => ('回答済み', AppColors.success),
      InquiryStatus.closed => ('クローズ', AppColors.textSecondary),
      InquiryStatus.cancelled => ('キャンセル', AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
