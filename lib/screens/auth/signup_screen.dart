import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/loading_indicator.dart';

/// サインアップ画面
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUpWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _nameController.text.trim(),
    );

    if (mounted) {
      if (success) {
        // サインアップ成功時はログイン画面に戻る（AuthWrapperが自動でホームに遷移）
        Navigator.of(context).pop();
        showSuccessSnackBar(context, 'アカウントを作成しました');
      } else {
        showErrorSnackBar(context, authProvider.errorMessage ?? 'サインアップに失敗しました');
      }
    }
  }

  Future<void> _handleGoogleSignup() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
      } else if (authProvider.errorMessage != null) {
        showErrorSnackBar(context, authProvider.errorMessage!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('新規登録'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingScreen,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return AppLoadingOverlay(
                    isLoading: authProvider.isLoading,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 説明テキスト
                          Text(
                            'アカウントを作成して\n愛車の管理を始めましょう',
                            style: theme.textTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          AppSpacing.verticalXxl,

                          // 表示名
                          AppTextField(
                            controller: _nameController,
                            labelText: '表示名',
                            hintText: '例: 山田太郎',
                            prefixIcon: const Icon(Icons.person_outlined),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '表示名を入力してください';
                              }
                              return null;
                            },
                          ),
                          AppSpacing.verticalMd,

                          // メールアドレス
                          AppTextField.email(
                            controller: _emailController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'メールアドレスを入力してください';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return '有効なメールアドレスを入力してください';
                              }
                              return null;
                            },
                          ),
                          AppSpacing.verticalMd,

                          // パスワード
                          AppTextField.password(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'パスワードを入力してください';
                              }
                              if (value.length < 6) {
                                return 'パスワードは6文字以上で入力してください';
                              }
                              return null;
                            },
                          ),
                          AppSpacing.verticalMd,

                          // パスワード確認
                          AppTextField.password(
                            controller: _confirmPasswordController,
                            labelText: 'パスワード（確認）',
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'パスワードを再入力してください';
                              }
                              if (value != _passwordController.text) {
                                return 'パスワードが一致しません';
                              }
                              return null;
                            },
                          ),
                          AppSpacing.verticalLg,

                          // サインアップボタン
                          AppButton.primary(
                            label: 'アカウントを作成',
                            onPressed: _handleSignup,
                            isFullWidth: true,
                            size: AppButtonSize.large,
                          ),
                          AppSpacing.verticalMd,

                          // 区切り線
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                child: Text(
                                  'または',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          AppSpacing.verticalMd,

                          // Google サインアップ
                          OutlinedButton.icon(
                            onPressed: _handleGoogleSignup,
                            icon: Image.network(
                              'https://www.google.com/favicon.ico',
                              width: 20,
                              height: 20,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.g_mobiledata, size: 20),
                            ),
                            label: const Text('Google で登録'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                            ),
                          ),
                          AppSpacing.verticalXxl,

                          // 利用規約
                          Text(
                            '登録することで、利用規約とプライバシーポリシーに同意したことになります。',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
