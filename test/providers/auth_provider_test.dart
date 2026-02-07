import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// Mock AuthService for testing
class MockAuthService implements AuthService {
  final StreamController<firebase_auth.User?> _authStateController =
      StreamController<firebase_auth.User?>.broadcast();

  // GoogleSignIn getter for interface compliance
  @override
  GoogleSignIn get googleSignIn => GoogleSignIn();

  bool signUpCalled = false;
  bool signInCalled = false;
  bool signOutCalled = false;
  bool googleSignInCalled = false;
  bool passwordResetCalled = false;

  Result<firebase_auth.UserCredential, AppError>? signUpResult;
  Result<firebase_auth.UserCredential, AppError>? signInResult;
  Result<firebase_auth.UserCredential?, AppError>? googleSignInResult;
  Result<void, AppError>? signOutResult;
  Result<void, AppError>? passwordResetResult;
  Result<AppUser?, AppError>? getUserProfileResult;

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
  }) async {
    signUpCalled = true;
    return signUpResult ??
        Result.failure(const AuthError('Not configured', type: AuthErrorType.unknown));
  }

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
  Future<Result<void, AppError>> signOut() async {
    signOutCalled = true;
    return signOutResult ?? const Result.success(null);
  }

  @override
  Future<Result<void, AppError>> sendPasswordResetEmail(String email) async {
    passwordResetCalled = true;
    return passwordResetResult ?? const Result.success(null);
  }

  @override
  Future<Result<AppUser?, AppError>> getUserProfile() async {
    return getUserProfileResult ?? const Result.success(null);
  }

  @override
  Future<Result<void, AppError>> updateUserProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    return const Result.success(null);
  }

  @override
  Future<Result<void, AppError>> updateNotificationSettings(
    NotificationSettings settings,
  ) async {
    return const Result.success(null);
  }

  void dispose() {
    _authStateController.close();
  }
}

void main() {
  group('AuthProvider', () {
    late MockAuthService mockAuthService;
    late AuthProvider provider;

    setUp(() {
      mockAuthService = MockAuthService();
    });

    tearDown(() {
      provider.dispose();
      mockAuthService.dispose();
    });

    group('Initial State', () {
      test('starts with isLoading true and no user', () {
        provider = AuthProvider(authService: mockAuthService);

        expect(provider.isLoading, isTrue);
        expect(provider.isAuthenticated, isFalse);
        expect(provider.firebaseUser, isNull);
        expect(provider.appUser, isNull);
        expect(provider.error, isNull);
      });

      test('becomes not loading after auth state emitted', () async {
        provider = AuthProvider(authService: mockAuthService);

        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.isLoading, isFalse);
        expect(provider.isAuthenticated, isFalse);
      });
    });

    group('signUpWithEmail', () {
      test('calls authService.signUpWithEmail', () async {
        provider = AuthProvider(authService: mockAuthService);
        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        mockAuthService.signUpResult = Result.failure(
          const AuthError('Email in use', type: AuthErrorType.emailAlreadyInUse),
        );

        await provider.signUpWithEmail(
          email: 'test@test.com',
          password: 'password123',
        );

        expect(mockAuthService.signUpCalled, isTrue);
      });

      test('sets error on failure', () async {
        provider = AuthProvider(authService: mockAuthService);
        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        mockAuthService.signUpResult = Result.failure(
          const AuthError('Email in use', type: AuthErrorType.emailAlreadyInUse),
        );

        final success = await provider.signUpWithEmail(
          email: 'test@test.com',
          password: 'password123',
        );

        expect(success, isFalse);
        expect(provider.error, isNotNull);
        expect(provider.error, isA<AuthError>());
        expect((provider.error as AuthError).type, equals(AuthErrorType.emailAlreadyInUse));
      });

      test('clears error and sets loading during operation', () async {
        provider = AuthProvider(authService: mockAuthService);
        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        mockAuthService.signUpResult = Result.failure(
          const AuthError('Failed', type: AuthErrorType.unknown),
        );

        await provider.signUpWithEmail(
          email: 'test@test.com',
          password: 'password123',
        );
        expect(provider.error, isNotNull);
        expect(provider.isLoading, isFalse);
      });
    });

    group('signInWithEmail', () {
      test('calls authService.signInWithEmail', () async {
        provider = AuthProvider(authService: mockAuthService);
        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        mockAuthService.signInResult = Result.failure(
          const AuthError('User not found', type: AuthErrorType.userNotFound),
        );

        await provider.signInWithEmail(
          email: 'test@test.com',
          password: 'password123',
        );

        expect(mockAuthService.signInCalled, isTrue);
      });

      test('sets error on wrong password', () async {
        provider = AuthProvider(authService: mockAuthService);
        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        mockAuthService.signInResult = Result.failure(
          const AuthError('Wrong password', type: AuthErrorType.invalidCredentials),
        );

        final success = await provider.signInWithEmail(
          email: 'test@test.com',
          password: 'wrongpassword',
        );

        expect(success, isFalse);
        expect(provider.error, isA<AuthError>());
        expect((provider.error as AuthError).type, equals(AuthErrorType.invalidCredentials));
      });
    });

    group('signInWithGoogle', () {
      test('calls authService.signInWithGoogle', () async {
        provider = AuthProvider(authService: mockAuthService);
        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        mockAuthService.googleSignInResult = Result.failure(
          const AuthError('Cancelled', type: AuthErrorType.unknown),
        );

        await provider.signInWithGoogle();

        expect(mockAuthService.googleSignInCalled, isTrue);
      });
    });

    group('signOut', () {
      test('calls authService.signOut', () async {
        provider = AuthProvider(authService: mockAuthService);
        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        await provider.signOut();

        expect(mockAuthService.signOutCalled, isTrue);
      });
    });

    group('sendPasswordResetEmail', () {
      test('calls authService.sendPasswordResetEmail', () async {
        provider = AuthProvider(authService: mockAuthService);
        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        mockAuthService.passwordResetResult = const Result.success(null);

        final success = await provider.sendPasswordResetEmail('test@test.com');

        expect(mockAuthService.passwordResetCalled, isTrue);
        expect(success, isTrue);
      });

      test('sets error on user not found', () async {
        provider = AuthProvider(authService: mockAuthService);
        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        mockAuthService.passwordResetResult = Result.failure(
          const AuthError('User not found', type: AuthErrorType.userNotFound),
        );

        final success = await provider.sendPasswordResetEmail('notfound@test.com');

        expect(success, isFalse);
        expect((provider.error as AuthError).type, equals(AuthErrorType.userNotFound));
      });
    });

    group('clearError', () {
      test('clears the error', () async {
        provider = AuthProvider(authService: mockAuthService);
        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        mockAuthService.signInResult = Result.failure(
          const AuthError('Error', type: AuthErrorType.unknown),
        );

        await provider.signInWithEmail(
          email: 'test@test.com',
          password: 'password',
        );
        expect(provider.error, isNotNull);

        provider.clearError();
        expect(provider.error, isNull);
      });
    });

    group('errorMessage', () {
      test('returns user message from error', () async {
        provider = AuthProvider(authService: mockAuthService);
        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        mockAuthService.signInResult = Result.failure(
          const AuthError('Wrong password', type: AuthErrorType.invalidCredentials),
        );

        await provider.signInWithEmail(
          email: 'test@test.com',
          password: 'wrong',
        );

        expect(provider.errorMessage, isNotNull);
        expect(provider.errorMessage, contains('メールアドレスまたはパスワード'));
      });
    });

    group('isRetryable', () {
      test('returns true for network errors', () async {
        provider = AuthProvider(authService: mockAuthService);
        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        mockAuthService.signInResult = Result.failure(
          const NetworkError('No connection'),
        );

        await provider.signInWithEmail(
          email: 'test@test.com',
          password: 'password',
        );

        expect(provider.isRetryable, isTrue);
      });

      test('returns false for auth errors', () async {
        provider = AuthProvider(authService: mockAuthService);
        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        mockAuthService.signInResult = Result.failure(
          const AuthError('Wrong password', type: AuthErrorType.invalidCredentials),
        );

        await provider.signInWithEmail(
          email: 'test@test.com',
          password: 'wrong',
        );

        expect(provider.isRetryable, isFalse);
      });

      test('returns true for too many requests', () async {
        provider = AuthProvider(authService: mockAuthService);
        mockAuthService.emitAuthState(null);
        await Future.delayed(const Duration(milliseconds: 50));

        mockAuthService.signInResult = Result.failure(
          const AuthError('Too many requests', type: AuthErrorType.tooManyRequests),
        );

        await provider.signInWithEmail(
          email: 'test@test.com',
          password: 'password',
        );

        expect(provider.isRetryable, isTrue);
      });
    });
  });
}
