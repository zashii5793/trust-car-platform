import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/accessory_showcase.dart';
import '../../models/showcase_comment.dart';
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
    result.when(
      success: (list) => setState(() {
        _comments = list;
        _isLoading = false;
      }),
      failure: (e) => setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      }),
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
                  'コメント',
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
                      canDelete: c.userId == widget.currentUserId,
                      onDelete: () => _deleteComment(c),
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
  final bool canDelete;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
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
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              key: Key('delete_comment_${comment.id}'),
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.textTertiary,
              onPressed: onDelete,
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
