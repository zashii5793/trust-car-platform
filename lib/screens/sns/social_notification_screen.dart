import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/follow.dart';
import '../../core/di/service_locator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_notification_provider.dart';
import '../../services/popular_accessories_service.dart';
import '../../widgets/common/loading_indicator.dart';
import '../accessories/showcase_detail_screen.dart';

/// ソーシャル通知一覧画面（いいね・コメント・フォロー）
///
/// Scaffold なし — HomeScreen の AppBar / BottomNavigationBar に統合。
/// showcaseId が設定された通知はタップで ShowcaseDetailScreen へ遷移。
class SocialNotificationScreen extends StatefulWidget {
  const SocialNotificationScreen({super.key});

  @override
  State<SocialNotificationScreen> createState() =>
      _SocialNotificationScreenState();
}

class _SocialNotificationScreenState extends State<SocialNotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final uid = authProvider.firebaseUser?.uid ?? '';
      context.read<SocialNotificationProvider>().init(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SocialNotificationProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const AppLoadingCenter();
        }

        if (provider.error != null) {
          return AppEmptyState(
            icon: Icons.error_outline,
            title: 'エラーが発生しました',
            description: provider.error!,
          );
        }

        if (provider.notifications.isEmpty) {
          return const AppEmptyState(
            icon: Icons.notifications_none,
            title: '通知はありません',
            description: 'いいね・コメント・フォローがあるとここに表示されます',
          );
        }

        final hasUnread = provider.unreadCount > 0;

        return Column(
          children: [
            if (hasUnread)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('全て既読'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.primary,
                      ),
                      onPressed: provider.markAllAsRead,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: provider.loadNotifications,
                child: ListView.builder(
                  padding: AppSpacing.paddingScreen,
                  itemCount: provider.notifications.length,
                  itemBuilder: (context, index) {
                    final n = provider.notifications[index];
                    return _NotificationTile(
                      notification: n,
                      onTap: () => _handleTap(context, provider, n),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    SocialNotificationProvider provider,
    SocialNotification notification,
  ) async {
    if (!notification.isRead) {
      await provider.markAsRead(notification.id);
    }

    if (!context.mounted) return;

    if (notification.showcaseId != null) {
      _navigateToShowcase(context, notification.showcaseId!);
    }
    // postId ナビゲーションは将来拡張 (PostDetailScreen)
  }

  Future<void> _navigateToShowcase(
    BuildContext context,
    String showcaseId,
  ) async {
    final service = sl.get<PopularAccessoriesService>();
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.firebaseUser?.uid ?? '';

    final result = await service.getShowcaseById(showcaseId);
    if (!context.mounted) return;

    result.when(
      success: (showcase) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShowcaseDetailScreen(
              showcase: showcase,
              service: service,
              currentUserId: currentUserId,
            ),
          ),
        );
      },
      failure: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ショーケースが見つかりませんでした')),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final SocialNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isUnread
              ? AppColors.primary.withAlpha(20)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isUnread
                ? AppColors.primary.withAlpha(60)
                : theme.dividerColor,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(notification.createdAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4, left: 4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    final photoUrl = notification.actorPhotoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(photoUrl),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.primary.withAlpha(40),
      child: Icon(
        _iconForType(notification.type),
        size: 18,
        color: AppColors.primary,
      ),
    );
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return Icons.favorite;
      case NotificationType.comment:
        return Icons.comment;
      case NotificationType.follow:
        return Icons.person_add;
      case NotificationType.mention:
        return Icons.alternate_email;
      case NotificationType.reply:
        return Icons.reply;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inHours < 1) return '${diff.inMinutes}分前';
    if (diff.inDays < 1) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return DateFormat('M月d日').format(dt);
  }
}
