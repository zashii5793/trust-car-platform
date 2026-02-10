// Golden tests for screen screenshots
// Run: flutter test --update-goldens test/golden/
// Images saved to: test/golden/goldens/

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';

import 'package:trust_car_platform/screens/auth/login_screen.dart';
import 'package:trust_car_platform/screens/auth/signup_screen.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// Import NotificationSettings for the mock

// =============================================================================
// Mock AuthService (from login_screen_test.dart pattern)
// =============================================================================

class MockAuthService implements AuthService {
  final StreamController<firebase_auth.User?> _authStateController =
      StreamController<firebase_auth.User?>.broadcast();

  @override
  GoogleSignIn get googleSignIn => GoogleSignIn();

  @override
  Stream<firebase_auth.User?> get authStateChanges => _authStateController.stream;

  @override
  firebase_auth.User? get currentUser => null;

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
  }) async =>
      Result.failure(const AuthError('Not implemented'));

  @override
  Future<Result<firebase_auth.UserCredential?, AppError>> signInWithGoogle() async =>
      Result.failure(const AuthError('Not implemented'));

  @override
  Future<Result<void, AppError>> signOut() async => const Result.success(null);

  @override
  Future<Result<void, AppError>> sendPasswordResetEmail(String email) async =>
      const Result.success(null);

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

// =============================================================================
// Helper Functions
// =============================================================================

Widget wrapWithMaterialApp(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    ),
    home: child,
  );
}

Widget createLoginScreen() {
  final authService = MockAuthService();
  return wrapWithMaterialApp(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(authService: authService),
      child: const LoginScreen(),
    ),
  );
}

Widget createSignupScreen() {
  final authService = MockAuthService();
  return wrapWithMaterialApp(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(authService: authService),
      child: const SignupScreen(),
    ),
  );
}

// =============================================================================
// Golden Tests
// =============================================================================

void main() {
  group('Screen Golden Tests - Auth Screens', () {
    testWidgets('LoginScreen - initial state', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/login_screen.png'),
      );
    });

    testWidgets('SignupScreen - initial state', (tester) async {
      await tester.pumpWidget(createSignupScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/signup_screen.png'),
      );
    });

    testWidgets('LoginScreen - with input', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      // Enter email and password
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'test@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/login_screen_filled.png'),
      );
    });

    testWidgets('LoginScreen - validation error', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      await tester.pump();

      // Tap login without input to trigger validation
      await tester.tap(find.text('ログイン'));
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/login_screen_error.png'),
      );
    });

    testWidgets('SignupScreen - validation error', (tester) async {
      await tester.pumpWidget(createSignupScreen());
      await tester.pump();

      // Tap register without input to trigger validation
      await tester.tap(find.text('アカウントを作成'));
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/signup_screen_error.png'),
      );
    });
  });
}
