import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/post_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/post.dart';
import '../../models/comment.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../services/post_service.dart';

/// 投稿詳細画面
///
/// 投稿本文・メディア・コメント一覧・コメント投稿フォームを表示。
/// 画面表示時に閲覧数をインクリメントする。
class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  // 返信対象コメント（nullの場合はトップレベルコメント）
  Comment? _replyTarget;

  // コメントタイルのキー管理（返信投稿後に返信リストを再ロードするため）
  final Map<String, GlobalKey<_CommentTileState>> _commentTileKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostProvider>().loadComments(widget.post.id);
      // 閲覧数インクリメント（fire-and-forget）
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.firebaseUser?.uid ?? '';
    if (userId.isEmpty) return;

    final replyTargetId = _replyTarget?.id;

    final success = await context.read<PostProvider>().addComment(
      postId: widget.post.id,
      userId: userId,
      content: text,
      userDisplayName: authProvider.firebaseUser?.displayName,
      userPhotoUrl: authProvider.firebaseUser?.photoURL,
      parentCommentId: replyTargetId,
    );

    if (success && mounted) {
      _commentController.clear();
      setState(() => _replyTarget = null);
      _focusNode.unfocus();

      // 返信投稿の場合は対象コメントタイルの返信リストをリセット・再ロード
      if (replyTargetId != null) {
        _commentTileKeys[replyTargetId]?.currentState
            ?.resetAndReloadReplies();
      }

      // 最下部へスクロール
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('投稿の詳細'),
        actions: [
          // 投稿者自身のみ削除ボタンを表示
          Consumer2<PostProvider, AuthProvider>(
            builder: (context, postProvider, authProvider, child) {
              final userId = authProvider.firebaseUser?.uid ?? '';
              if (widget.post.userId != userId || userId.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '投稿を削除',
                onPressed: () => _confirmDeletePost(context, postProvider, userId),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<PostProvider>().loadComments(widget.post.id),
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  // ---- 投稿本文エリア ----
                  _PostDetailBody(post: widget.post, isDark: isDark),

                  // ---- コメントヘッダー ----
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        AppSpacing.horizontalXs,
                        Text(
                          'コメント',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // ---- コメント一覧 ----
                  Consumer<PostProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoadingComments) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (provider.comments.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 40,
                                  color: isDark
                                      ? AppColors.darkTextTertiary
                                      : AppColors.textTertiary,
                                ),
                                AppSpacing.verticalSm,
                                Text(
                                  'まだコメントがありません\n最初のコメントをしてみましょう',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextTertiary
                                        : AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: provider.comments
                            .map((comment) {
                              final key = _commentTileKeys.putIfAbsent(
                                comment.id,
                                () => GlobalKey<_CommentTileState>(),
                              );
                              return _CommentTile(
                                key: key,
                                comment: comment,
                                postId: widget.post.id,
                                isDark: isDark,
                                onReply: (c) {
                                  setState(() => _replyTarget = c);
                                  _focusNode.requestFocus();
                                },
                              );
                            })
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ---- 返信ターゲット表示 ----
          if (_replyTarget != null)
            Container(
              color: isDark
                  ? AppColors.darkCard
                  : AppColors.primary.withValues(alpha: 0.05),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  AppSpacing.horizontalXs,
                  Expanded(
                    child: Text(
                      '${_replyTarget!.userDisplayName ?? 'ユーザー'} さんへ返信',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyTarget = null),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

          // ---- コメント入力フォーム ----
          _CommentInputBar(
            controller: _commentController,
            focusNode: _focusNode,
            onSubmit: _submitComment,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePost(
    BuildContext context,
    PostProvider provider,
    String userId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('投稿を削除'),
        content: const Text('この投稿を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await provider.deletePost(widget.post.id, userId);
      // ignore: use_build_context_synchronously
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// ---------------------------------------------------------------------------
// 投稿本文エリア
// ---------------------------------------------------------------------------

class _PostDetailBody extends StatelessWidget {
  final Post post;
  final bool isDark;

  const _PostDetailBody({required this.post, required this.isDark});

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    return DateFormat('yyyy年M月d日 HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;

    return Container(
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- ヘッダー ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.15),
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
                AppSpacing.horizontalMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userDisplayName ?? '',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatTime(post.createdAt),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: tertiary),
                      ),
                    ],
                  ),
                ),
                _CategoryBadgeDetail(category: post.category),
              ],
            ),
          ),

          // ---- 本文 ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post.content,
              style: theme.textTheme.bodyLarge,
            ),
          ),

          // ---- ハッシュタグ ----
          if (post.hashtags.isNotEmpty) ...[
            AppSpacing.verticalXs,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 2,
                children: post.hashtags
                    .map((tag) => Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],

          // ---- メディア ----
          if (post.media.isNotEmpty) ...[
            AppSpacing.verticalSm,
            _MediaGallery(media: post.media),
          ],

          AppSpacing.verticalSm,

          // ---- いいね・コメント数バー ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Consumer2<PostProvider, AuthProvider>(
                  builder: (context, postProvider, authProvider, child) {
                    final userId = authProvider.firebaseUser?.uid ?? '';
                    final liked = postProvider.isLiked(post.id);
                    return GestureDetector(
                      onTap: userId.isNotEmpty
                          ? () => postProvider.toggleLike(post.id, userId)
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            liked ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: liked ? AppColors.error : tertiary,
                          ),
                          AppSpacing.horizontalXs,
                          Text(
                            '${post.likeCount}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: liked ? AppColors.error : tertiary),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                AppSpacing.horizontalMd,
                Icon(Icons.chat_bubble_outline, size: 18, color: tertiary),
                AppSpacing.horizontalXs,
                Consumer<PostProvider>(
                  builder: (context, provider, _) => Text(
                    '${provider.comments.isNotEmpty ? provider.comments.length : post.commentCount}',
                    style: theme.textTheme.bodySmall?.copyWith(color: tertiary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// メディアギャラリー（単枚 or グリッド）
// ---------------------------------------------------------------------------

class _MediaGallery extends StatelessWidget {
  final List<PostMedia> media;

  const _MediaGallery({required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.length == 1) {
      return _buildNetworkImage(media[0].url, double.infinity, 240);
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      padding: EdgeInsets.zero,
      children: media
          .take(4)
          .map((m) => _buildNetworkImage(m.url, double.infinity, double.infinity))
          .toList(),
    );
  }

  Widget _buildNetworkImage(String url, double width, double height) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.backgroundLight,
        child: const Icon(
          Icons.broken_image_outlined,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// カテゴリバッジ（詳細画面用）
// ---------------------------------------------------------------------------

IconData _categoryIconDetail(PostCategory cat) {
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

class _CategoryBadgeDetail extends StatelessWidget {
  final PostCategory category;

  const _CategoryBadgeDetail({required this.category});

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_categoryIconDetail(category), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            category.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// コメントタイル
// ---------------------------------------------------------------------------

class _CommentTile extends StatefulWidget {
  final Comment comment;
  final String postId;
  final bool isDark;
  final void Function(Comment) onReply;

  const _CommentTile({
    super.key,
    required this.comment,
    required this.postId,
    required this.isDark,
    required this.onReply,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _isExpanded = false;
  bool _isLoadingReplies = false;
  List<Comment> _replies = [];

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return DateFormat('M月d日').format(dt);
  }

  // 返信を取得して展開する
  Future<void> _toggleReplies() async {
    if (_isExpanded) {
      // 展開済みなら畳む
      setState(() => _isExpanded = false);
      return;
    }

    if (_replies.isNotEmpty) {
      // ロード済みなら再取得せず展開
      setState(() => _isExpanded = true);
      return;
    }

    // 未ロードなら取得してから展開
    setState(() => _isLoadingReplies = true);
    try {
      final postService = ServiceLocator.instance.get<PostService>();
      final result = await postService.getReplies(
        commentId: widget.comment.id,
      );
      result.when(
        success: (replies) {
          if (mounted) {
            setState(() {
              _replies = replies;
              _isExpanded = true;
            });
          }
        },
        failure: (_) {
          // エラー時は何もしない（ローディングを止めるだけ）
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingReplies = false);
      }
    }
  }

  // 返信投稿後に呼び出す: リセットして再ロード
  Future<void> resetAndReloadReplies() async {
    setState(() {
      _replies = [];
      _isExpanded = false;
    });
    await _toggleReplies();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tertiary =
        widget.isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- メインコメント行 ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // アバター
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                backgroundImage: widget.comment.userPhotoUrl != null
                    ? NetworkImage(widget.comment.userPhotoUrl!)
                    : null,
                child: widget.comment.userPhotoUrl == null
                    ? Text(
                        (widget.comment.userDisplayName?.isNotEmpty ?? false)
                            ? widget.comment.userDisplayName![0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              AppSpacing.horizontalSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名前 + 時刻
                    Row(
                      children: [
                        Text(
                          widget.comment.userDisplayName ?? 'ユーザー',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AppSpacing.horizontalXs,
                        Text(
                          _formatTime(widget.comment.createdAt),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: tertiary, fontSize: 11),
                        ),
                      ],
                    ),
                    AppSpacing.verticalXxs,
                    // 本文
                    Text(
                      widget.comment.content,
                      style: theme.textTheme.bodyMedium,
                    ),
                    AppSpacing.verticalXxs,
                    // アクション行
                    Row(
                      children: [
                        // 返信ボタン
                        GestureDetector(
                          onTap: () => widget.onReply(widget.comment),
                          child: Text(
                            '返信',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // 自分のコメントなら削除ボタン
                        Consumer2<PostProvider, AuthProvider>(
                          builder: (context, postProvider, authProvider, child) {
                            final userId = authProvider.firebaseUser?.uid ?? '';
                            if (widget.comment.userId != userId ||
                                userId.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: GestureDetector(
                                onTap: () async {
                                  await postProvider.deleteComment(
                                    commentId: widget.comment.id,
                                    userId: userId,
                                    postId: widget.postId,
                                  );
                                },
                                child: Text(
                                  '削除',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        // 返信数バッジ（タップで展開/畳む）
                        if (widget.comment.replyCount > 0) ...[
                          AppSpacing.horizontalSm,
                          GestureDetector(
                            onTap: _isLoadingReplies ? null : _toggleReplies,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isLoadingReplies)
                                  SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: theme.colorScheme.primary,
                                    ),
                                  )
                                else
                                  Icon(
                                    _isExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                const SizedBox(width: 2),
                                Text(
                                  '返信${widget.comment.replyCount}件',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ---- インライン返信一覧 ----
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              children: _replies
                  .map((reply) => _ReplyTile(
                        reply: reply,
                        postId: widget.postId,
                        isDark: widget.isDark,
                        formatTime: _formatTime,
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 返信タイル（インデント表示）
// ---------------------------------------------------------------------------

class _ReplyTile extends StatelessWidget {
  final Comment reply;
  final String postId;
  final bool isDark;
  final String Function(DateTime) formatTime;

  const _ReplyTile({
    required this.reply,
    required this.postId,
    required this.isDark,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // アバター（やや小さめ）
          CircleAvatar(
            radius: 13,
            backgroundColor:
                theme.colorScheme.primary.withValues(alpha: 0.15),
            backgroundImage: reply.userPhotoUrl != null
                ? NetworkImage(reply.userPhotoUrl!)
                : null,
            child: reply.userPhotoUrl == null
                ? Text(
                    (reply.userDisplayName?.isNotEmpty ?? false)
                        ? reply.userDisplayName![0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          AppSpacing.horizontalSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名前 + 時刻
                Row(
                  children: [
                    Text(
                      reply.userDisplayName ?? 'ユーザー',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    AppSpacing.horizontalXs,
                    Text(
                      formatTime(reply.createdAt),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: tertiary, fontSize: 10),
                    ),
                  ],
                ),
                AppSpacing.verticalXxs,
                // 本文
                Text(
                  reply.content,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
                AppSpacing.verticalXxs,
                // 自分の返信なら削除リンク
                Consumer2<PostProvider, AuthProvider>(
                  builder: (context, postProvider, authProvider, child) {
                    final userId = authProvider.firebaseUser?.uid ?? '';
                    if (reply.userId != userId || userId.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return GestureDetector(
                      onTap: () async {
                        await postProvider.deleteComment(
                          commentId: reply.id,
                          userId: userId,
                          postId: postId,
                        );
                      },
                      child: Text(
                        '削除',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// コメント入力バー
// ---------------------------------------------------------------------------

class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final bool isDark;

  const _CommentInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppColors.darkCard
                  : AppColors.backgroundSecondary,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'コメントを入力...',
                  hintStyle: TextStyle(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkCard
                      : AppColors.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Consumer<PostProvider>(
              builder: (context, provider, child) {
                return IconButton(
                  onPressed:
                      provider.isSubmittingComment ? null : onSubmit,
                  icon: provider.isSubmittingComment
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: theme.colorScheme.primary,
                        ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary
                        .withValues(alpha: 0.1),
                    shape: const CircleBorder(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
