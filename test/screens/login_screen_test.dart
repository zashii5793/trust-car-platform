import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:trust_car_platform/screens/auth/login_screen.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// Mock AuthService (reusing pattern from auth_provider_test.dart)
class MockAuthService implements AuthService {
  final StreamController<firebase_auth.User?> _authStateController =
      StreamController<firebase_auth.User?>.broadcast();

  @override
  GoogleSignIn get googleSignIn => GoogleSignIn();

  bool signInCalled = false;
  bool googleSignInCalled = false;
  bool passwordResetCalled = false;

  Result<firebase_auth.UserCredential, AppError>? signInResult;
  Result<firebase_auth.UserCredential?, AppError>? googleSignInResult;
  Result<void, AppError>? passwordResetResult;

  @override
  Stream<firebase_auth.User?> get authStateChanges => _authStateController.stream;

  @override
  firebase_auth.User? get currentUser => null;

  void emitAuthState(firebase_auth.User? user) {
    _authStateController.add(user);
  }

  @override
  Future<Result<firebase_auth.UserCredential, AppError>> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async =>
      Result.failure(const AuthError('Not implemented'));

  @override
  Future<Result<firebase_auth.UserCredential, AppError>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalled = true;
    return signInResult ??
        Result.failure(const AuthError('Not configured', type: AuthErrorType.unknown));
  }

  @override
  Future<Result<firebase_auth.UserCredential?, AppError>> signInWithGoogle() async {
    googleSignInCalled = true;
    return googleSignInResult ??
        Result.failure(const AuthError('Not configured', type: AuthErrorType.unknown));
  }

  @override
  Future<Result<void, AppError>> signOut() async => const Result.success(null);

  @override
  Future<Result<void, AppError>> sendPasswordResetEmail(String email) async {
    passwordResetCalled = true;
    return passwordResetResult ?? const Result.success(null);
  }

  @override
  Future<Result<AppUser?, AppError>> getUserProfile() async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> updateUserProfile({
    String? displayName,
    String? photoUrl,
  }) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> updateNotificationSettings(
    NotificationSettings settings,
  ) async =>
      const Result.success(null);

  void dispose() {
    _authStateController.close();
  }
}

Widget createLoginScreen({MockAuthService? mockAuthService}) {
  final authService = mockAuthService ?? MockAuthService();

  return MaterialApp(
    home: ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(authService: authService),
      child: const LoginScreen(),
    ),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('displays app title and tagline', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      expect(find.text('クルマ統合管理'), findsOneWidget);
      expect(find.text('信頼を設計する、新時代のカーライフ'), findsOneWidget);
    });

    testWidgets('displays car icon', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      expect(find.byIcon(Icons.directions_car), findsOneWidget);
    });

    testWidgets('displays email text field', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      expect(find.text('メールアドレス'), findsOneWidget);
    });

    testWidgets('displays password text field', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      expect(find.text('パスワード'), findsOneWidget);
    });

    testWidgets('displays login button', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      expect(find.text('ログイン'), findsOneWidget);
    });

    testWidgets('displays Google login button', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      expect(find.text('Google でログイン'), findsOneWidget);
    });

    testWidgets('displays signup link', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      expect(find.text('新規登録'), findsOneWidget);
      expect(find.text('アカウントをお持ちでない方は'), findsOneWidget);
    });

    testWidgets('displays forgot password link', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      expect(find.text('パスワードを忘れた場合'), findsOneWidget);
    });

    testWidgets('shows validation error when email is empty', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      // Tap login without entering anything
      await tester.tap(find.text('ログイン'));
      await tester.pump();

      expect(find.text('メールアドレスを入力してください'), findsOneWidget);
    });

    testWidgets('shows validation error when password is empty', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      // Enter email but not password
      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.tap(find.text('ログイン'));
      await tester.pump();

      expect(find.text('パスワードを入力してください'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid email format', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      // Enter invalid email
      await tester.enterText(
        find.byType(TextFormField).first,
        'invalid-email',
      );
      await tester.tap(find.text('ログイン'));
      await tester.pump();

      expect(find.text('有効なメールアドレスを入力してください'), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      // Initially password is hidden
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      // Tap to show password
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      // Now password is visible
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('displays "または" divider', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      expect(find.text('または'), findsOneWidget);
    });
  });
}
