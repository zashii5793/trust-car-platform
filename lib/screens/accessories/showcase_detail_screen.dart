import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/accessory_showcase.dart';
import '../../models/showcase_comment.dart';
import '../../models/comment_report.dart';
import '../../services/popular_accessories_service.dart';

/// Detail view for a single accessory showcase post with its comment thread.
///
/// This is the lightweight "share a good part + discuss it" experience that
/// replaces the frozen C2C parts marketplace: no buying/selling, just comments.
class ShowcaseDetailScreen extends StatefulWidget {
  final AccessoryShowcase showcase;
  final PopularAccessoriesService service;

  /// Current signed-in user id. Empty string means anonymous/unknown.
  final String currentUserId;

  const ShowcaseDetailScreen({
    super.key,
    required this.showcase,
    required this.service,
    required this.currentUserId,
  });

  @override
  State<ShowcaseDetailScreen> createState() => _ShowcaseDetailScreenState();
}

class _ShowcaseDetailScreenState extends State<ShowcaseDetailScreen> {
  final _inputController = TextEditingController();

  List<ShowcaseComment> _comments = [];
  Set<String> _likedIds = {};
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await widget.service.getComments(widget.showcase.id);
    if (!mounted) return;
    await result.when(
      success: (list) async {
        // Load which of these comments the current user has liked.
        var liked = <String>{};
        if (widget.currentUserId.isNotEmpty && list.isNotEmpty) {
          final likedResult = await widget.service.getMyLikedCommentIds(
            showcaseId: widget.showcase.id,
            commentIds: list.map((c) => c.id).toList(),
            userId: widget.currentUserId,
          );
          liked = likedResult.valueOrNull ?? <String>{};
        }
        if (!mounted) return;
        setState(() {
          _comments = list;
          _likedIds = liked;
          _isLoading = false;
        });
      },
      failure: (e) async => setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      }),
    );
  }

  Future<void> _toggleLike(ShowcaseComment comment) async {
    if (widget.currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('いいねするにはログインが必要です')),
      );
      return;
    }

    final wasLiked = _likedIds.contains(comment.id);
    final index = _comments.indexWhere((c) => c.id == comment.id);
    if (index == -1) return;

    // Optimistic update.
    setState(() {
      if (wasLiked) {
        _likedIds.remove(comment.id);
        _comments[index] = comment.copyWith(
          likeCount: comment.likeCount > 0 ? comment.likeCount - 1 : 0,
        );
      } else {
        _likedIds.add(comment.id);
        _comments[index] = comment.copyWith(likeCount: comment.likeCount + 1);
      }
    });

    final result = wasLiked
        ? await widget.service.unlikeComment(
            showcaseId: widget.showcase.id,
            commentId: comment.id,
            userId: widget.currentUserId,
          )
        : await widget.service.likeComment(
            showcaseId: widget.showcase.id,
            commentId: comment.id,
            userId: widget.currentUserId,
          );
    if (!mounted) return;

    result.when(
      success: (_) {},
      failure: (e) {
        // Revert optimistic update on failure.
        setState(() {
          final i = _comments.indexWhere((c) => c.id == comment.id);
          if (wasLiked) {
            _likedIds.add(comment.id);
            if (i != -1) {
              _comments[i] =
                  _comments[i].copyWith(likeCount: _comments[i].likeCount + 1);
            }
          } else {
            _likedIds.remove(comment.id);
            if (i != -1) {
              _comments[i] = _comments[i].copyWith(
                likeCount:
                    _comments[i].likeCount > 0 ? _comments[i].likeCount - 1 : 0,
              );
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      },
    );
  }

  Future<void> _sendComment() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;
    if (widget.currentUserId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('コメントするにはログインが必要です')));
      return;
    }

    setState(() => _isSending = true);
    final result = await widget.service.addComment(
      showcaseId: widget.showcase.id,
      userId: widget.currentUserId,
      content: text,
    );
    if (!mounted) return;
    setState(() => _isSending = false);

    result.when(
      success: (comment) {
        _inputController.clear();
        setState(() => _comments = [..._comments, comment]);
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      ),
    );
  }

  Future<void> _deleteComment(ShowcaseComment comment) async {
    final result = await widget.service.deleteComment(
      showcaseId: widget.showcase.id,
      commentId: comment.id,
      userId: widget.currentUserId,
    );
    if (!mounted) return;
    result.when(
      success: (_) =>
          setState(() => _comments.removeWhere((c) => c.id == comment.id)),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      ),
    );
  }

  Future<void> _editComment(ShowcaseComment comment) async {
    final newContent = await showDialog<String>(
      context: context,
      builder: (_) => _EditCommentDialog(initial: comment.content),
    );

    if (newContent == null ||
        newContent.isEmpty ||
        newContent == comment.content) {
      return;
    }

    final result = await widget.service.updateComment(
      showcaseId: widget.showcase.id,
      commentId: comment.id,
      userId: widget.currentUserId,
      content: newContent,
    );
    if (!mounted) return;
    result.when(
      success: (updated) => setState(() {
        final i = _comments.indexWhere((c) => c.id == comment.id);
        if (i != -1) _comments[i] = updated;
      }),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      ),
    );
  }

  Future<void> _reportComment(ShowcaseComment comment) async {
    if (widget.currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通報するにはログインが必要です')),
      );
      return;
    }

    final reason = await showDialog<ReportReason>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('このコメントを通報'),
        children: [
          for (final r in ReportReason.values)
            SimpleDialogOption(
              key: Key('report_reason_${r.name}'),
              onPressed: () => Navigator.pop(dialogContext, r),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text(r.label),
              ),
            ),
        ],
      ),
    );
    if (reason == null) return;

    final result = await widget.service.reportComment(
      showcaseId: widget.showcase.id,
      commentId: comment.id,
      reporterId: widget.currentUserId,
      reason: reason,
    );
    if (!mounted) return;
    result.when(
      success: (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通報を受け付けました。ご協力ありがとうございます。')),
      ),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showcase = widget.showcase;
    return Scaffold(
      appBar: AppBar(title: Text(showcase.itemName)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _ShowcaseHeader(showcase: showcase),
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                Text(
                  _isLoading ? 'コメント' : 'コメント (${_comments.length})',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_errorMessage != null)
                  Center(
                    child: Column(
                      children: [
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: _loadComments,
                          child: const Text('再読み込み'),
                        ),
                      ],
                    ),
                  )
                else if (_comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(
                      child: Text(
                        'まだコメントがありません。最初のコメントを書いてみましょう。',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ..._comments.map(
                    (c) => _CommentTile(
                      comment: c,
                      isOwner: c.userId == widget.currentUserId,
                      isLiked: _likedIds.contains(c.id),
                      onDelete: () => _deleteComment(c),
                      onEdit: () => _editComment(c),
                      onToggleLike: () => _toggleLike(c),
                      onReport: () => _reportComment(c),
                    ),
                  ),
              ],
            ),
          ),
          _CommentInputBar(
            controller: _inputController,
            isSending: _isSending,
            onSend: _sendComment,
          ),
        ],
      ),
    );
  }
}

class _ShowcaseHeader extends StatelessWidget {
  final AccessoryShowcase showcase;
  const _ShowcaseHeader({required this.showcase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          showcase.itemName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (showcase.brand != null && showcase.brand!.isNotEmpty)
          Text(
            showcase.brand!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(Icons.star, size: 16, color: AppColors.warning),
            const SizedBox(width: 2),
            Text('${showcase.rating}.0', style: theme.textTheme.bodySmall),
            const SizedBox(width: AppSpacing.sm),
            Text(
              showcase.category.displayName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        if (showcase.review != null && showcase.review!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(showcase.review!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final ShowcaseComment comment;
  final bool isOwner;
  final bool isLiked;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onToggleLike;
  final VoidCallback onReport;

  const _CommentTile({
    required this.comment,
    required this.isOwner,
    required this.isLiked,
    required this.onDelete,
    required this.onEdit,
    required this.onToggleLike,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: Key('showcase_comment_${comment.id}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 16,
            child: Icon(Icons.person_outline, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.userDisplayName?.isNotEmpty == true
                      ? comment.userDisplayName!
                      : 'ユーザー',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(comment.content, style: theme.textTheme.bodyMedium),
                if (comment.isEdited)
                  Text(
                    '（編集済み）',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          // Like button + count
          InkWell(
            key: Key('like_comment_${comment.id}'),
            onTap: onToggleLike,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: isLiked ? AppColors.error : AppColors.textTertiary,
                  ),
                  if (comment.likeCount > 0) ...[
                    const SizedBox(width: 2),
                    Text(
                      '${comment.likeCount}',
                      key: Key('like_count_${comment.id}'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isOwner) ...[
            IconButton(
              key: Key('edit_comment_${comment.id}'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.textTertiary,
              onPressed: onEdit,
            ),
            IconButton(
              key: Key('delete_comment_${comment.id}'),
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.textTertiary,
              onPressed: onDelete,
            ),
          ] else
            IconButton(
              key: Key('report_comment_${comment.id}'),
              icon: const Icon(Icons.flag_outlined, size: 18),
              color: AppColors.textTertiary,
              tooltip: '通報',
              onPressed: onReport,
            ),
        ],
      ),
    );
  }
}

class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _CommentInputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.xs,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('showcase_comment_input'),
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'コメントを書く…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              key: const Key('showcase_comment_send'),
              icon: isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              color: AppColors.primary,
              onPressed: isSending ? null : onSend,
            ),
          ],
        ),
      ),
    );
  }
}

/// Edit dialog that owns its [TextEditingController] so it is disposed only
/// after the dialog is fully removed (avoids use-after-dispose during the
/// dismiss animation).
class _EditCommentDialog extends StatefulWidget {
  final String initial;
  const _EditCommentDialog({required this.initial});

  @override
  State<_EditCommentDialog> createState() => _EditCommentDialogState();
}

class _EditCommentDialogState extends State<_EditCommentDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('コメントを編集'),
      content: TextField(
        key: const Key('edit_comment_field'),
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        decoration: const InputDecoration(hintText: 'コメントを編集…'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('edit_comment_save'),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
