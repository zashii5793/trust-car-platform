import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../core/ui/app_dialog.dart';
import '../../models/newsletter.dart';
import '../../services/newsletter_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/loading_indicator.dart';
import 'newsletter_compose_screen.dart';

/// Displays sent and draft newsletters for a shop owner or admin author.
class NewsletterListScreen extends StatefulWidget {
  final String authorId;
  final String authorName;

  const NewsletterListScreen({
    super.key,
    required this.authorId,
    required this.authorName,
  });

  @override
  State<NewsletterListScreen> createState() => _NewsletterListScreenState();
}

class _NewsletterListScreenState extends State<NewsletterListScreen> {
  NewsletterService get _service => sl.get<NewsletterService>();

  List<Newsletter> _newsletters = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _service.getMyNewsletters(widget.authorId);
    if (!mounted) return;
    result.when(
      success: (list) => setState(() {
        _newsletters = list;
        _isLoading = false;
      }),
      failure: (err) => setState(() {
        _error = err.userMessage;
        _isLoading = false;
      }),
    );
  }

  Future<void> _send(Newsletter newsletter) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: 'ニュースレターを配信',
      message:
          '「${newsletter.title}」を${newsletter.audience.displayName}に配信しますか？',
      confirmText: '配信する',
    );
    if (confirmed != true || !mounted) return;

    final result = await _service.sendNewsletter(newsletter.id);
    if (!mounted) return;
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('配信キューに登録しました。まもなく送信されます。'),
            backgroundColor: AppColors.success,
          ),
        );
        _load();
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

  Future<void> _delete(Newsletter newsletter) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '下書きを削除',
      message: '「${newsletter.title}」を削除しますか？',
      confirmText: '削除',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    final result = await _service.deleteNewsletter(newsletter.id);
    if (!mounted) return;
    result.when(
      success: (_) => _load(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('ニュースレター管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewsletterComposeScreen(
                authorId: widget.authorId,
                authorName: widget.authorName,
              ),
            ),
          );
          _load();
        },
        icon: const Icon(Icons.edit),
        label: const Text('新規作成'),
      ),
      body: _isLoading
          ? const AppLoadingCenter(message: 'ニュースレターを読み込み中...')
          : _error != null
              ? AppErrorState(message: _error!, onRetry: _load)
              : _newsletters.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.mail_outline,
                      title: 'ニュースレターがありません',
                      description: '右下の「新規作成」からニュースレターを作成してみましょう',
                    )
                  : ListView.builder(
                      padding: AppSpacing.paddingScreen,
                      itemCount: _newsletters.length,
                      itemBuilder: (context, index) {
                        final n = _newsletters[index];
                        return _NewsletterCard(
                          newsletter: n,
                          isDark: isDark,
                          onEdit: n.status != NewsletterStatus.sent
                              ? () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NewsletterComposeScreen(
                                        authorId: widget.authorId,
                                        authorName: widget.authorName,
                                        existing: n,
                                      ),
                                    ),
                                  );
                                  _load();
                                }
                              : null,
                          onSend: n.status == NewsletterStatus.draft
                              ? () => _send(n)
                              : null,
                          onDelete: n.status != NewsletterStatus.sent
                              ? () => _delete(n)
                              : null,
                        );
                      },
                    ),
    );
  }
}

class _NewsletterCard extends StatelessWidget {
  final Newsletter newsletter;
  final bool isDark;
  final VoidCallback? onEdit;
  final VoidCallback? onSend;
  final VoidCallback? onDelete;

  const _NewsletterCard({
    required this.newsletter,
    required this.isDark,
    this.onEdit,
    this.onSend,
    this.onDelete,
  });

  Color get _statusColor {
    switch (newsletter.status) {
      case NewsletterStatus.draft:
        return AppColors.textSecondary;
      case NewsletterStatus.scheduled:
        return AppColors.warning;
      case NewsletterStatus.sent:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return AppCard(
      margin: AppSpacing.marginListItem,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: AppSpacing.borderRadiusXs,
                ),
                child: Text(
                  newsletter.status.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ),
              AppSpacing.horizontalXs,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: AppSpacing.borderRadiusXs,
                ),
                child: Text(
                  newsletter.category.displayName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.info,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateFormat.format(newsletter.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
          AppSpacing.verticalXs,
          Text(
            newsletter.title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.verticalXxs,
          Text(
            newsletter.body,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (newsletter.status == NewsletterStatus.sent) ...[
            AppSpacing.verticalXs,
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 14,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.textTertiary,
                ),
                AppSpacing.horizontalXxs,
                Text(
                  '${newsletter.recipientCount}名に配信済み',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (newsletter.sentAt != null) ...[
                  AppSpacing.horizontalSm,
                  Text(
                    dateFormat.format(newsletter.sentAt!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (onEdit != null || onSend != null || onDelete != null) ...[
            AppSpacing.verticalSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('削除'),
                  ),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('編集'),
                  ),
                if (onSend != null)
                  FilledButton.icon(
                    onPressed: onSend,
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('配信'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
