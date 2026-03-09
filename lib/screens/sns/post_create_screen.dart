import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/post.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/app_button.dart';

/// 投稿作成画面
///
/// カテゴリ選択・本文入力・公開設定を備えた投稿フォーム。
class PostCreateScreen extends StatefulWidget {
  const PostCreateScreen({super.key});

  @override
  State<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();

  PostCategory _selectedCategory = PostCategory.general;
  PostVisibility _selectedVisibility = PostVisibility.public;

  static const int _maxLength = 1000;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final postProvider = context.read<PostProvider>();
    final user = authProvider.firebaseUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    final success = await postProvider.createPost(
      userId: user.uid,
      content: _contentController.text,
      category: _selectedCategory,
      visibility: _selectedVisibility,
      userDisplayName: user.displayName,
      userPhotoUrl: user.photoURL,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿しました')),
      );
    } else {
      final errorMessage =
          postProvider.submitErrorMessage ?? '投稿に失敗しました。もう一度お試しください。';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
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
        title: const Text('投稿を作成'),
        actions: [
          Consumer<PostProvider>(
            builder: (context, provider, child) {
              return provider.isSubmitting
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      onPressed: _submit,
                      child: const Text('投稿'),
                    );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.paddingScreen,
          children: [
            // ── カテゴリ選択 ──────────────────────────────────────────────────
            Text(
              'カテゴリ',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.verticalSm,
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: PostCategory.values
                  .map((cat) => ChoiceChip(
                        label: Text(cat.displayName, style: const TextStyle(fontSize: 12)),
                        selected: _selectedCategory == cat,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                        selectedColor: theme.colorScheme.primary,
                        labelStyle: TextStyle(
                          color: _selectedCategory == cat
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ))
                  .toList(),
            ),

            AppSpacing.verticalLg,

            // ── 本文 ──────────────────────────────────────────────────────────
            Text(
              '本文',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.verticalSm,
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _contentController,
              builder: (context, value, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextFormField(
                      controller: _contentController,
                      maxLines: 8,
                      maxLength: _maxLength,
                      decoration: const InputDecoration(
                        hintText:
                            'カーライフについて投稿しましょう。#ハッシュタグ も使えます。',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return '本文を入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${value.text.length} / $_maxLength',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: value.text.length >= _maxLength
                            ? AppColors.error
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                );
              },
            ),

            AppSpacing.verticalLg,

            // ── 公開設定 ──────────────────────────────────────────────────────
            Text(
              '公開設定',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.verticalSm,
            ...PostVisibility.values.map(
              (vis) => RadioListTile<PostVisibility>(
                title: Text(vis.displayName),
                subtitle: Text(_visibilityDescription(vis)),
                value: vis,
                groupValue: _selectedVisibility,
                onChanged: (v) =>
                    setState(() => _selectedVisibility = v!),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),

            AppSpacing.verticalXxl,

            // ── 送信ボタン ────────────────────────────────────────────────────
            Consumer<PostProvider>(
              builder: (context, provider, child) {
                return AppButton.primary(
                  onPressed: provider.isSubmitting ? null : _submit,
                  label: provider.isSubmitting ? '投稿中...' : '投稿する',
                  isFullWidth: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _visibilityDescription(PostVisibility vis) {
    switch (vis) {
      case PostVisibility.public:
        return '全員が閲覧できます';
      case PostVisibility.followers:
        return 'フォロワーのみ閲覧できます';
      case PostVisibility.private_:
        return '自分のみ閲覧できます';
    }
  }
}
