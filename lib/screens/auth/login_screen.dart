import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/loading_indicator.dart';
import 'signup_screen.dart';

/// ログイン画面
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!success && mounted) {
      showErrorSnackBar(context, authProvider.errorMessage ?? 'ログインに失敗しました');
    }
  }

  Future<void> _handleGoogleLogin() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();

    if (!success && mounted && authProvider.errorMessage != null) {
      showErrorSnackBar(context, authProvider.errorMessage!);
    }
  }

  void _navigateToSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SignupScreen()),
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      showErrorSnackBar(context, 'メールアドレスを入力してください');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendPasswordResetEmail(email);

    if (mounted) {
      if (success) {
        showSuccessSnackBar(context, 'パスワードリセットメールを送信しました');
      } else {
        showErrorSnackBar(context, authProvider.errorMessage ?? 'メール送信に失敗しました');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ロゴとタイトル
                          Icon(
                            Icons.directions_car,
                            size: 80,
                            color: theme.colorScheme.primary,
                          ),
                          AppSpacing.verticalMd,
                          Text(
                            'クルマ統合管理',
                            style: theme.textTheme.displayMedium,
                            textAlign: TextAlign.center,
                          ),
                          AppSpacing.verticalXs,
                          Text(
                            '信頼を設計する、新時代のカーライフ',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          AppSpacing.verticalXxl,

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
                              return null;
                            },
                          ),
                          AppSpacing.verticalXs,

                          // パスワードを忘れた場合
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _handleForgotPassword,
                              child: const Text('パスワードを忘れた場合'),
                            ),
                          ),
                          AppSpacing.verticalMd,

                          // ログインボタン
                          AppButton.primary(
                            label: 'ログイン',
                            onPressed: _handleEmailLogin,
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

                          // Google ログイン
                          OutlinedButton.icon(
                            onPressed: _handleGoogleLogin,
                            icon: Image.network(
                              'https://www.google.com/favicon.ico',
                              width: 20,
                              height: 20,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.g_mobiledata, size: 20),
                            ),
                            label: const Text('Google でログイン'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                            ),
                          ),
                          AppSpacing.verticalXxl,

                          // サインアップリンク
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'アカウントをお持ちでない方は',
                                style: theme.textTheme.bodyMedium,
                              ),
                              TextButton(
                                onPressed: _navigateToSignup,
                                child: const Text('新規登録'),
                              ),
                            ],
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
