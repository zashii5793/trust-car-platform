import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/post_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/post.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/loading_indicator.dart';
import 'post_create_screen.dart';

/// SNS フィード画面
///
/// カテゴリフィルタ付きの投稿フィード。
/// - プルリフレッシュ対応
/// - 無限スクロール（ページネーション）
/// - いいねの楽観的更新
class SnsFeedScreen extends StatefulWidget {
  const SnsFeedScreen({super.key});

  @override
  State<SnsFeedScreen> createState() => _SnsFeedScreenState();
}

class _SnsFeedScreenState extends State<SnsFeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostProvider>().loadFeed();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<PostProvider>().loadMoreFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _CategoryFilterBar(),
          Expanded(
            child: Consumer<PostProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const AppLoadingCenter(message: 'フィードを読み込み中...');
                }

                if (provider.error != null && provider.feedPosts.isEmpty) {
                  return AppErrorState(
                    message: provider.errorMessage ?? 'エラーが発生しました',
                    onRetry: () => provider.refreshFeed(),
                  );
                }

                if (provider.feedPosts.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.article_outlined,
                    title: '投稿がありません',
                    description: 'まだ投稿がありません。最初の投稿をしてみましょう！',
                    buttonLabel: '投稿する',
                    onButtonPressed: () => _openCreatePost(context),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => provider.refreshFeed(),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: provider.feedPosts.length +
                        (provider.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.feedPosts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final post = provider.feedPosts[index];
                      return _PostCard(post: post);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreatePost(context),
        tooltip: '投稿する',
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  void _openCreatePost(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PostCreateScreen()),
    ).then((_) {
      // 投稿後にフィードを更新
      // ignore: use_build_context_synchronously
      if (mounted) context.read<PostProvider>().refreshFeed();
    });
  }
}

// ---------------------------------------------------------------------------
// カテゴリフィルタバー
// ---------------------------------------------------------------------------

/// カテゴリに対応するアイコンを返す
IconData _categoryIcon(PostCategory cat) {
  switch (cat) {
    case PostCategory.maintenance:
      return Icons.build_outlined;
    case PostCategory.customization:
      return Icons.palette_outlined;
    case PostCategory.drive:
      return Icons.directions_car_outlined;
    case PostCategory.question:
      return Icons.help_outline;
    case PostCategory.sale:
      return Icons.sell_outlined;
    default:
      return Icons.article_outlined;
  }
}

class _CategoryFilterBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<PostProvider>(
      builder: (context, provider, child) {
        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _CategoryChip(
                label: 'すべて',
                icon: Icons.all_inclusive,
                selected: provider.selectedCategory == null,
                onTap: () => provider.selectCategory(null),
              ),
              ...PostCategory.values.map(
                (cat) => _CategoryChip(
                  label: cat.displayName,
                  icon: _categoryIcon(cat),
                  selected: provider.selectedCategory == cat,
                  onTap: () => provider.selectCategory(cat),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: icon != null
            ? Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : theme.colorScheme.onSurface,
              )
            : null,
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : theme.colorScheme.onSurface,
        ),
        selectedColor: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 投稿カード
// ---------------------------------------------------------------------------

class _PostCard extends StatelessWidget {
  final Post post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppSpacing.borderRadiusLg,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(post: post),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _PostContent(post: post),
          ),
          if (post.media.isNotEmpty) _PostMediaRow(media: post.media),
          _PostFooter(post: post),
        ],
      ),
    );
  }
}

// ---- ヘッダー（アバター・ユーザー名・カテゴリ・時刻） ----

class _PostHeader extends StatelessWidget {
  final Post post;

  const _PostHeader({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          // アバター
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            backgroundImage: post.userPhotoUrl != null
                ? NetworkImage(post.userPhotoUrl!)
                : null,
            child: post.userPhotoUrl == null
                ? Text(
                    (post.userDisplayName?.isNotEmpty ?? false)
                        ? post.userDisplayName![0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          // 名前・時刻
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.userDisplayName ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatTime(post.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // カテゴリバッジ
          _CategoryBadge(category: post.category),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return DateFormat('M月d日').format(dt);
  }
}

class _CategoryBadge extends StatelessWidget {
  final PostCategory category;

  const _CategoryBadge({required this.category});

  Color _color(PostCategory cat) {
    switch (cat) {
      case PostCategory.maintenance:
        return AppColors.info;
      case PostCategory.customization:
        return AppColors.secondary;
      case PostCategory.drive:
        return AppColors.success;
      case PostCategory.question:
        return AppColors.warning;
      case PostCategory.sale:
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_categoryIcon(category), size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            category.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- 本文・ハッシュタグ ----

class _PostContent extends StatelessWidget {
  final Post post;

  const _PostContent({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.content,
          style: theme.textTheme.bodyMedium,
        ),
        if (post.hashtags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: post.hashtags
                .map((tag) => Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---- 画像ロー ----

class _PostMediaRow extends StatelessWidget {
  final List<PostMedia> media;

  const _PostMediaRow({required this.media});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        itemCount: media.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              media[index].url,
              width: 160,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 160,
                height: 160,
                color: AppColors.backgroundLight,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.textTertiary),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---- フッター（いいね・コメント数） ----

class _PostFooter extends StatelessWidget {
  final Post post;

  const _PostFooter({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 12, 6),
      child: Row(
        children: [
          // いいねボタン
          Consumer2<PostProvider, AuthProvider>(
            builder: (context, postProvider, authProvider, child) {
              final userId = authProvider.firebaseUser?.uid ?? '';
              final liked = postProvider.isLiked(post.id);
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: userId.isNotEmpty
                    ? () => postProvider.toggleLike(post.id, userId)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: liked ? AppColors.error : tertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likeCount}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: liked ? AppColors.error : tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          // コメント数（表示のみ）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, size: 18, color: tertiary),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
                  style: theme.textTheme.bodySmall?.copyWith(color: tertiary),
                ),
              ],
            ),
          ),
          const Spacer(),
          // 投稿者が自分なら削除ボタン
          Consumer2<PostProvider, AuthProvider>(
            builder: (context, postProvider, authProvider, child) {
              final userId = authProvider.firebaseUser?.uid ?? '';
              if (post.userId != userId || userId.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: tertiary),
                onPressed: () => _confirmDelete(context, postProvider, userId),
                tooltip: '削除',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              );
            },
          ),
        ],
      ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PostProvider provider,
    String userId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('投稿を削除'),
        content: const Text('この投稿を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await provider.deletePost(post.id, userId);
    }
  }
}
