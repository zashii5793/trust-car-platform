import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/shop.dart';
import '../../models/shop_case_study.dart';
import '../../services/shop_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/loading_indicator.dart';

/// Shop owner screen for managing before/after case studies (施工事例).
class CaseStudyManagementScreen extends StatefulWidget {
  final String shopId;

  const CaseStudyManagementScreen({super.key, required this.shopId});

  @override
  State<CaseStudyManagementScreen> createState() =>
      _CaseStudyManagementScreenState();
}

class _CaseStudyManagementScreenState extends State<CaseStudyManagementScreen> {
  final ShopService _service = sl.get<ShopService>();

  List<ShopCaseStudy> _studies = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudies();
  }

  Future<void> _loadStudies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _service.getCaseStudies(widget.shopId);
    if (!mounted) return;
    result.when(
      success: (list) => setState(() {
        _studies = list;
        _isLoading = false;
      }),
      failure: (err) => setState(() {
        _error = err.userMessage;
        _isLoading = false;
      }),
    );
  }

  Future<void> _showAddDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final study = await showDialog<ShopCaseStudy>(
      context: context,
      builder: (_) =>
          _AddCaseStudyDialog(shopId: widget.shopId, service: _service),
    );
    if (study == null) return;

    final result = await _service.addCaseStudy(study);
    if (!mounted) return;
    result.when(
      success: (saved) => setState(() => _studies.insert(0, saved)),
      failure: (err) =>
          messenger.showSnackBar(SnackBar(content: Text(err.userMessage))),
    );
  }

  Future<void> _delete(ShopCaseStudy study) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('施工事例を削除しますか？'),
        content: Text('「${study.title}」を削除します。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _service.deleteCaseStudy(widget.shopId, study.id);
    if (!mounted) return;
    result.when(
      success: (_) =>
          setState(() => _studies.removeWhere((s) => s.id == study.id)),
      failure: (err) =>
          messenger.showSnackBar(SnackBar(content: Text(err.userMessage))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('施工事例管理'),
        actions: [
          IconButton(
            key: const Key('add_case_study_btn'),
            icon: const Icon(Icons.add),
            onPressed: _showAddDialog,
            tooltip: '施工事例を追加',
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoadingCenter(message: '読み込み中...')
          : _error != null
              ? AppErrorState(
                  message: _error!,
                  onRetry: _loadStudies,
                )
              : _studies.isEmpty
                  ? _EmptyState(onAdd: _showAddDialog)
                  : ListView.separated(
                      padding: AppSpacing.paddingScreen,
                      itemCount: _studies.length,
                      separatorBuilder: (_, __) => AppSpacing.verticalSm,
                      itemBuilder: (_, i) => _CaseStudyTile(
                        study: _studies[i],
                        onDelete: () => _delete(_studies[i]),
                      ),
                    ),
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.paddingScreen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 64, color: theme.colorScheme.outline),
            AppSpacing.verticalMd,
            Text(
              'まだ施工事例がありません',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalXs,
            Text(
              'ビフォーアフター写真と説明を追加して\nお客様にアピールしましょう。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalLg,
            AppButton(
              label: '施工事例を追加',
              onPressed: onAdd,
              icon: Icons.add_photo_alternate_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CaseStudyTile extends StatelessWidget {
  final ShopCaseStudy study;
  final VoidCallback onDelete;

  const _CaseStudyTile({required this.study, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.sm),
        leading: study.afterImageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.xs),
                child: Image.network(
                  study.afterImageUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined, size: 56),
                ),
              )
            : Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                ),
                child: const Icon(Icons.photo_outlined),
              ),
        title: Text(
          study.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: study.category != null
            ? Text(
                study.category!.displayName,
                style: theme.textTheme.labelSmall,
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDelete,
          tooltip: '削除',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add dialog
// ---------------------------------------------------------------------------

class _AddCaseStudyDialog extends StatefulWidget {
  final String shopId;
  final ShopService service;

  const _AddCaseStudyDialog({required this.shopId, required this.service});

  @override
  State<_AddCaseStudyDialog> createState() => _AddCaseStudyDialogState();
}

class _AddCaseStudyDialogState extends State<_AddCaseStudyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  ServiceCategory? _category;
  XFile? _beforeImage;
  XFile? _afterImage;
  bool _isUploading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isBefore) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      if (isBefore) {
        _beforeImage = picked;
      } else {
        _afterImage = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    String? beforeUrl;
    String? afterUrl;

    if (_beforeImage != null) {
      final result = await widget.service
          .uploadCaseStudyImage(widget.shopId, _beforeImage!, 'before');
      if (!mounted) return;
      if (result.isFailure) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorOrNull!.userMessage)),
        );
        return;
      }
      beforeUrl = result.valueOrNull;
    }

    if (_afterImage != null) {
      final result = await widget.service
          .uploadCaseStudyImage(widget.shopId, _afterImage!, 'after');
      if (!mounted) return;
      if (result.isFailure) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorOrNull!.userMessage)),
        );
        return;
      }
      afterUrl = result.valueOrNull;
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      ShopCaseStudy(
        id: '',
        shopId: widget.shopId,
        title: _titleCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        beforeImageUrl: beforeUrl,
        afterImageUrl: afterUrl,
        category: _category,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('施工事例を追加'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _titleCtrl,
                labelText: 'タイトル',
                hintText: '例: エンジンオイル交換',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'タイトルを入力してください' : null,
              ),
              AppSpacing.verticalSm,
              DropdownButtonFormField<ServiceCategory>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'カテゴリ（任意）',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                items: ServiceCategory.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.displayName),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _category = v),
              ),
              AppSpacing.verticalSm,
              AppTextField(
                controller: _descCtrl,
                labelText: '説明（任意）',
                hintText: '施工内容や工夫した点など',
                maxLines: 3,
              ),
              AppSpacing.verticalMd,
              Text('ビフォー写真（任意）', style: theme.textTheme.labelMedium),
              AppSpacing.verticalXs,
              _ImagePickerTile(
                key: const Key('before_image_picker'),
                image: _beforeImage,
                onTap: () => _pickImage(true),
                onClear: () => setState(() => _beforeImage = null),
              ),
              AppSpacing.verticalSm,
              Text('アフター写真（任意）', style: theme.textTheme.labelMedium),
              AppSpacing.verticalXs,
              _ImagePickerTile(
                key: const Key('after_image_picker'),
                image: _afterImage,
                onTap: () => _pickImage(false),
                onClear: () => setState(() => _afterImage = null),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('save_case_study_btn'),
          onPressed: _isUploading ? null : _submit,
          child: _isUploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('追加'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ImagePickerTile extends StatelessWidget {
  final XFile? image;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _ImagePickerTile({
    super.key,
    required this.image,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (image != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.xs),
            child: Image.file(
              File(image!.path),
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onClear,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_photo_alternate_outlined),
      label: const Text('写真を選択'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
    );
  }
}
