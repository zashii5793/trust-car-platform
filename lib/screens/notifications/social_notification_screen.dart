import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/follow.dart';
import '../../services/follow_service.dart';
import '../../services/popular_accessories_service.dart';
import '../../services/post_service.dart';
import '../../widgets/common/loading_indicator.dart';
import '../accessories/showcase_detail_screen.dart';
import '../sns/post_detail_screen.dart';

/// Social activity feed (likes / comments / follows on SNS posts and accessory
/// showcases). Tapping an item marks it read and deep-links to the source:
///   - `showcaseId` → [ShowcaseDetailScreen] (resolves the id to a showcase)
///   - `postId`     → [PostDetailScreen]     (resolves the id to a post)
///
/// Services are injectable for testing; production callers pass only [userId].
class SocialNotificationScreen extends StatelessWidget {
  SocialNotificationScreen({
    super.key,
    required this.userId,
    FollowService? followService,
    PopularAccessoriesService? showcaseService,
    PostService? postService,
  })  : followService = followService ?? sl.get<FollowService>(),
        showcaseService =
            showcaseService ?? sl.get<PopularAccessoriesService>(),
        postService = postService ?? sl.get<PostService>();

  final String userId;
  final FollowService followService;
  final PopularAccessoriesService showcaseService;
  final PostService postService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          TextButton(
            onPressed: () => followService.markAllNotificationsAsRead(userId),
            child: const Text('すべて既読'),
          ),
        ],
      ),
      body: StreamBuilder<List<SocialNotification>>(
        stream: followService.watchNotifications(userId: userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingCenter();
          }
          if (snapshot.hasError) {
            return const AppErrorState(message: '通知を読み込めませんでした');
          }
          final notifications = snapshot.data ?? const <SocialNotification>[];
          if (notifications.isEmpty) {
            return const AppEmptyState(
              icon: Icons.notifications_none,
              title: '通知はありません',
              description: 'いいねやコメントがあるとここに表示されます',
            );
          }
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _NotificationTile(
              notification: notifications[index],
              onTap: () => _open(context, notifications[index]),
            ),
          );
        },
      ),
    );
  }

  /// Marks the notification read and navigates to its source screen.
  Future<void> _open(BuildContext context, SocialNotification n) async {
    if (!n.isRead) {
      await followService.markNotificationAsRead(n.id);
    }
    if (!context.mounted) return;

    if (n.showcaseId != null && n.showcaseId!.isNotEmpty) {
      final result = await showcaseService.getShowcaseById(n.showcaseId!);
      if (!context.mounted) return;
      final showcase = result.valueOrNull;
      if (showcase == null) {
        _showGone(context);
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ShowcaseDetailScreen(
            showcase: showcase,
            service: showcaseService,
            currentUserId: userId,
          ),
        ),
      );
    } else if (n.postId != null && n.postId!.isNotEmpty) {
      final result = await postService.getPost(n.postId!);
      if (!context.mounted) return;
      final post = result.valueOrNull;
      if (post == null) {
        _showGone(context);
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PostDetailScreen(post: post),
        ),
      );
    }
    // follow-type notifications have no navigation target (marking read only).
  }

  void _showGone(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('投稿を開けませんでした（削除された可能性があります）')),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final SocialNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final photo = n.actorPhotoUrl;
    return ListTile(
      onTap: onTap,
      tileColor: n.isRead ? null : AppColors.primary.withValues(alpha: 0.06),
      leading: CircleAvatar(
        backgroundImage:
            (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
        child: (photo == null || photo.isEmpty)
            ? const Icon(Icons.person_outline)
            : null,
      ),
      title: Text(n.message, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (n.previewText != null && n.previewText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                n.previewText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              _relativeTime(n.createdAt),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      trailing: n.isRead
          ? null
          : const Icon(Icons.circle, size: 10, color: AppColors.primary),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${time.year}/${time.month}/${time.day}';
  }
}
