import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/newsletter.dart';
import '../../services/newsletter_service.dart';
import '../../widgets/common/loading_indicator.dart';

/// Screen for composing a new newsletter or editing a draft.
class NewsletterComposeScreen extends StatefulWidget {
  final String authorId;
  final String authorName;
  final Newsletter? existing; // null = new draft

  const NewsletterComposeScreen({
    super.key,
    required this.authorId,
    required this.authorName,
    this.existing,
  });

  @override
  State<NewsletterComposeScreen> createState() =>
      _NewsletterComposeScreenState();
}

class _NewsletterComposeScreenState extends State<NewsletterComposeScreen> {
  NewsletterService get _service => sl.get<NewsletterService>();

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  NewsletterAudience _audience = NewsletterAudience.allUsers;
  NewsletterCategory _category = NewsletterCategory.maintenanceTips;
  bool _isSaving = false;
  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final n = widget.existing;
    if (n != null) {
      _titleController.text = n.title;
      _bodyController.text = n.body;
      _audience = n.audience;
      _category = n.category;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final now = DateTime.now();
    final newsletter = Newsletter(
      id: widget.existing?.id ?? '',
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      authorId: widget.authorId,
      authorName: widget.authorName,
      audience: _audience,
      category: _category,
      status: NewsletterStatus.draft,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );

    bool success;
    String? errMsg;

    if (_isNew) {
      final result = await _service.createNewsletter(newsletter);
      success = result.isSuccess;
      errMsg = result.errorOrNull?.userMessage;
    } else {
      final result = await _service.updateNewsletter(
        newsletter.copyWith(id: widget.existing!.id),
      );
      success = result.isSuccess;
      errMsg = result.errorOrNull?.userMessage;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('下書きを保存しました'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg ?? '保存に失敗しました'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'ニュースレター作成' : '下書きを編集'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveDraft,
              child: const Text('保存'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.paddingScreen,
          children: [
            // ---- タイトル ----
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'タイトル *',
                hintText: '例: 冬前のタイヤ点検のご案内',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'タイトルを入力してください' : null,
              textInputAction: TextInputAction.next,
            ),

            AppSpacing.verticalMd,

            // ---- 本文 ----
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: '本文 *',
                hintText: 'ユーザーへのメッセージを入力してください',
                alignLabelWithHint: true,
              ),
              minLines: 6,
              maxLines: 20,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '本文を入力してください' : null,
            ),

            AppSpacing.verticalMd,

            // ---- カテゴリ ----
            Text('カテゴリ', style: theme.textTheme.labelMedium),
            AppSpacing.verticalXs,
            Wrap(
              spacing: AppSpacing.xs,
              children: NewsletterCategory.values.map((cat) {
                final selected = _category == cat;
                return ChoiceChip(
                  label: Text(cat.displayName),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = cat),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : null,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),

            AppSpacing.verticalMd,

            // ---- 配信対象 ----
            Text('配信対象', style: theme.textTheme.labelMedium),
            AppSpacing.verticalXs,
            ...NewsletterAudience.values.map((aud) {
              return RadioListTile<NewsletterAudience>(
                title: Text(aud.displayName),
                value: aud,
                groupValue: _audience,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  if (v != null) setState(() => _audience = v);
                },
              );
            }),

            AppSpacing.verticalMd,

            // ---- 注意 ----
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: AppSpacing.borderRadiusSm,
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.info),
                  AppSpacing.horizontalXs,
                  Expanded(
                    child: Text(
                      '「保存」は下書き保存です。配信はニュースレター一覧画面の「配信」ボタンから実行してください。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            AppSpacing.verticalXxl,
          ],
        ),
      ),
    );
  }
}
