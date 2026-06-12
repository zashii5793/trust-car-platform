import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/post_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../models/post.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/loading_indicator.dart';
import 'post_create_screen.dart';
import 'post_detail_screen.dart';

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
          _VehicleModelFilterBar(),
          Expanded(
            child: Consumer<PostProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const AppLoadingCenter(message: 'フィードを読み込み中...');
                }

                if (provider.error != null && provider.feedPosts.isEmpty) {
                  return AppErrorState(
                    message: provider.errorMessage ?? 'データを読み込めませんでした',
                    onRetry: () => provider.refreshFeed(),
                  );
                }

                if (provider.feedPosts.isEmpty) {
                  // Vehicle model filter active but no results
                  if (provider.selectedModelName != null) {
                    return AppEmptyState(
                      icon: Icons.directions_car_outlined,
                      title: 'この車種の投稿がまだありません',
                      description:
                          '「${provider.selectedModelName}」の投稿がまだありません。\n最初の投稿をしてみましょう！',
                      buttonLabel: 'すべて表示',
                      onButtonPressed: () =>
                          provider.filterByVehicleModel(null),
                    );
                  }
                  // Category filter active but no results
                  if (provider.selectedCategory != null) {
                    return AppEmptyState(
                      icon: Icons.filter_list_off,
                      title: 'この絞り込みには投稿がありません',
                      description:
                          '「${provider.selectedCategory!.displayName}」カテゴリの投稿がまだありません。\n他のカテゴリも探してみましょう。',
                      buttonLabel: 'すべて表示',
                      onButtonPressed: () => provider.selectCategory(null),
                    );
                  }
                  // No posts at all
                  return AppEmptyState(
                    icon: Icons.forum_outlined,
                    title: '投稿がまだありません',
                    description:
                        '他のユーザーの投稿や、\n気になるハッシュタグを探してみましょう\n\n右下のボタンから最初の投稿をしてみましょう',
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

/// カテゴリに対応するアクセントカラーを返す
Color _categoryColor(PostCategory cat) {
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

// ---------------------------------------------------------------------------
// 同車種フィルタバー（自分の所有車両モデルで絞り込む）
// ---------------------------------------------------------------------------

class _VehicleModelFilterBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<VehicleProvider, PostProvider>(
      builder: (context, vehicleProvider, postProvider, _) {
        final vehicles = vehicleProvider.vehicles;
        if (vehicles.isEmpty) return const SizedBox.shrink();

        // Collect unique model names across user's vehicles
        final modelNames = vehicles
            .map((v) => '${v.maker} ${v.model}')
            .toSet()
            .toList();

        return SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              if (postProvider.selectedModelName != null)
                _ModelChip(
                  key: const Key('sns_vehicle_filter_clear'),
                  label: 'すべて',
                  icon: Icons.close,
                  selected: false,
                  onTap: () => postProvider.filterByVehicleModel(null),
                ),
              ...modelNames.map(
                (name) => _ModelChip(
                  key: Key('sns_vehicle_filter_$name'),
                  label: '同じ $name オーナー',
                  icon: Icons.directions_car,
                  selected: postProvider.selectedModelName == name,
                  onTap: () => postProvider.filterByVehicleModel(
                    postProvider.selectedModelName == name ? null : name,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  const _ModelChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon,
            size: 13,
            color: selected
                ? Colors.white
                : AppColors.accentDrive),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          fontSize: 11,
          color: selected ? Colors.white : theme.colorScheme.onSurface,
        ),
        selectedColor: AppColors.accentDrive,
        backgroundColor: AppColors.accentDrive.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
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

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: post),
      ),
    ).then((_) {
      // 詳細から戻った際にフィードのコメント数などを反映
      // ignore: use_build_context_synchronously
      if (context.mounted) context.read<PostProvider>().refreshFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = _categoryColor(post.category);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(context),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // カテゴリ別左アクセントバー
              Container(width: 4, color: accentColor),
              Expanded(
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
              ),
            ],
          ),
        ),
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
          if (post.visibility != PostVisibility.public) ...[
            const SizedBox(width: 4),
            _VisibilityBadge(visibility: post.visibility),
          ],
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

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
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
            runSpacing: 4,
            children: post.hashtags.map((tag) {
              return InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('#$tag のハッシュタグ検索は近日公開予定です'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---- 公開範囲バッジ（public 以外のみ表示） ----

class _VisibilityBadge extends StatelessWidget {
  final PostVisibility visibility;

  const _VisibilityBadge({required this.visibility});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (visibility) {
      PostVisibility.followers => (Icons.group, 'フォロワー', Colors.blue),
      PostVisibility.private_ => (Icons.lock, '非公開', Colors.grey),
      PostVisibility.public => (Icons.public, '', Colors.green),
    };

    if (visibility == PostVisibility.public) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
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
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: tertiary),
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
                    onPressed: () =>
                        _confirmDelete(context, postProvider, userId),
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
