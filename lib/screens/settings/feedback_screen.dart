import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/user_feedback.dart';
import '../../services/feedback_service.dart';

/// Send a request or a bug report from inside the app.
///
/// The only contact route used to be "email support@trustcar.jp". Small but
/// useful observations never survive that much friction, so they never reached
/// us. This screen is deliberately short: pick one of three, write, send.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    super.key,
    required this.service,
    required this.userId,
    this.fromScreen,
  });

  final FeedbackService service;
  final String userId;

  /// Where the user was when they decided to write. Sent along so a bug report
  /// does not have to explain which screen it is about.
  final String? fromScreen;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();

  FeedbackType _type = FeedbackType.request;
  bool _isSending = false;
  bool _isSent = false;
  String? _messageError;
  String? _emailError;
  String? _submitError;

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text;
    final email = _emailController.text;

    final messageError = UserFeedback.validateMessage(message);
    final emailError = UserFeedback.validateContactEmail(email);

    setState(() {
      _messageError = messageError;
      _emailError = emailError;
      _submitError = null;
    });

    if (messageError != null || emailError != null) return;

    setState(() => _isSending = true);

    final result = await widget.service.submit(
      userId: widget.userId,
      type: _type,
      message: message,
      screen: widget.fromScreen,
      contactEmail: email,
    );

    if (!mounted) return;

    result.when(
      success: (_) => setState(() {
        _isSending = false;
        _isSent = true;
      }),
      failure: (error) => setState(() {
        _isSending = false;
        _submitError = error.userMessage;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('ご意見・ご要望')),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingScreen,
        child: widget.userId.isEmpty
            ? _SignedOutNotice(theme: theme)
            : _isSent
                ? _ThanksMessage(theme: theme)
                : _buildForm(theme),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '気づいたことを教えてください',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '短くて構いません。返信をお約束はできませんが、すべて目を通しています。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 20),

        // ---- 種別 ----
        Wrap(
          spacing: 8,
          children: FeedbackType.values.map((type) {
            return ChoiceChip(
              key: Key('feedback_type_${type.storageName}'),
              label: Text(type.displayName),
              selected: _type == type,
              onSelected: (_) => setState(() => _type = type),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // ---- 本文 ----
        TextField(
          key: const Key('feedback_message'),
          controller: _messageController,
          minLines: 5,
          maxLines: 10,
          maxLength: UserFeedback.maxMessageLength,
          decoration: InputDecoration(
            hintText: _type == FeedbackType.bug
                ? '例）フリート管理を開くとエラーになります'
                : '例）車検の通知をもう少し早く出してほしいです',
            border: const OutlineInputBorder(),
            errorText: _messageError,
          ),
        ),
        const SizedBox(height: 12),

        // ---- 返信先（任意） ----
        TextField(
          key: const Key('feedback_email'),
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: '返信先メールアドレス（任意）',
            helperText: '記入いただくと、必要なときにこちらから連絡できます',
            border: const OutlineInputBorder(),
            errorText: _emailError,
          ),
        ),

        if (_submitError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _submitError!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('feedback_submit'),
            onPressed: _isSending ? null : _submit,
            child: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('送信する'),
          ),
        ),
      ],
    );
  }
}

class _ThanksMessage extends StatelessWidget {
  const _ThanksMessage({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('feedback_thanks'),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle_outline,
            size: 64, color: AppColors.success),
        const SizedBox(height: 16),
        Text(
          'ありがとうございます',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'いただいた内容は開発チームで確認します。\n'
          '今後の改善に使わせていただきます。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}

class _SignedOutNotice extends StatelessWidget {
  const _SignedOutNotice({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.lock_outline, size: 56, color: AppColors.textTertiary),
        const SizedBox(height: 16),
        Text(
          'ご意見を送るにはログインが必要です',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'いただいた内容に返信できるようにするため、\n'
          'ログインした状態で送信をお願いしています。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
