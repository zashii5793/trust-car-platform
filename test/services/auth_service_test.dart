import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';

void main() {
  group('AuthService Result Pattern Tests', () {
    group('Auth Error Mapping', () {
      test('mapFirebaseError maps user-not-found to AuthError', () {
        final error = mapFirebaseError(Exception('[firebase_auth/user-not-found] No user found'));

        expect(error, isA<AuthError>());
        final authError = error as AuthError;
        expect(authError.type, AuthErrorType.userNotFound);
        expect(authError.userMessage, 'ユーザーが見つかりません');
        expect(authError.isRetryable, false);
      });

      test('mapFirebaseError maps wrong-password to AuthError', () {
        final error = mapFirebaseError(Exception('[firebase_auth/wrong-password] Wrong password'));

        expect(error, isA<AuthError>());
        final authError = error as AuthError;
        expect(authError.type, AuthErrorType.invalidCredentials);
        expect(authError.userMessage, 'メールアドレスまたはパスワードが正しくありません');
      });

      test('mapFirebaseError maps invalid-credential to AuthError', () {
        final error = mapFirebaseError(Exception('[firebase_auth/invalid-credential] Invalid'));

        expect(error, isA<AuthError>());
        expect((error as AuthError).type, AuthErrorType.invalidCredentials);
      });

      test('mapFirebaseError maps email-already-in-use to AuthError', () {
        final error = mapFirebaseError(Exception('[firebase_auth/email-already-in-use] Already used'));

        expect(error, isA<AuthError>());
        final authError = error as AuthError;
        expect(authError.type, AuthErrorType.emailAlreadyInUse);
        expect(authError.userMessage, 'このメールアドレスは既に使用されています');
      });

      test('mapFirebaseError maps weak-password to AuthError', () {
        final error = mapFirebaseError(Exception('[firebase_auth/weak-password] Too short'));

        expect(error, isA<AuthError>());
        final authError = error as AuthError;
        expect(authError.type, AuthErrorType.weakPassword);
        expect(authError.userMessage, contains('パスワード'));
      });

      test('mapFirebaseError maps too-many-requests to AuthError', () {
        final error = mapFirebaseError(Exception('[firebase_auth/too-many-requests] Rate limited'));

        expect(error, isA<AuthError>());
        final authError = error as AuthError;
        expect(authError.type, AuthErrorType.tooManyRequests);
        expect(authError.isRetryable, true);
        expect(authError.userMessage, contains('しばらく待って'));
      });

      test('mapFirebaseError maps network error', () {
        final error = mapFirebaseError(Exception('network-request-failed'));

        expect(error, isA<NetworkError>());
        expect(error.isRetryable, true);
      });

      test('mapFirebaseError maps permission-denied', () {
        final error = mapFirebaseError(Exception('[cloud_firestore/permission-denied] Access denied'));

        expect(error, isA<PermissionError>());
        expect(error.isRetryable, false);
      });

      test('mapFirebaseError maps not-found', () {
        final error = mapFirebaseError(Exception('[cloud_firestore/not-found] Document not found'));

        expect(error, isA<NotFoundError>());
      });

      test('mapFirebaseError maps unavailable to NetworkError', () {
        final error = mapFirebaseError(Exception('[cloud_firestore/unavailable] Service unavailable'));

        expect(error, isA<NetworkError>());
        expect(error.isRetryable, true);
      });

      test('mapFirebaseError maps unknown error', () {
        final error = mapFirebaseError(Exception('Something completely unexpected'));

        expect(error, isA<UnknownError>());
        expect(error.isRetryable, false);
      });
    });

    group('AuthError types', () {
      test('all AuthErrorType values have user messages', () {
        for (final type in AuthErrorType.values) {
          final error = AppError.auth('test', type: type);
          expect(error.userMessage, isNotEmpty);
        }
      });

      test('only tooManyRequests is retryable', () {
        for (final type in AuthErrorType.values) {
          final error = AppError.auth('test', type: type) as AuthError;
          if (type == AuthErrorType.tooManyRequests) {
            expect(error.isRetryable, true, reason: '$type should be retryable');
          } else {
            expect(error.isRetryable, false, reason: '$type should not be retryable');
          }
        }
      });

      test('AuthError toString includes type', () {
        const error = AppError.auth('test msg', type: AuthErrorType.userNotFound);
        expect(error.toString(), contains('userNotFound'));
        expect(error.toString(), contains('test msg'));
      });
    });

    group('Result pattern with auth operations', () {
      test('successful auth result holds credential', () {
        final result = Result<String, AppError>.success('user_uid_123');

        expect(result.isSuccess, true);
        expect(result.valueOrNull, 'user_uid_123');
      });

      test('failed auth result holds AppError', () {
        final result = Result<String, AppError>.failure(
          const AppError.auth('Invalid credentials', type: AuthErrorType.invalidCredentials),
        );

        expect(result.isFailure, true);
        result.when(
          success: (_) => fail('Should not succeed'),
          failure: (error) {
            expect(error, isA<AuthError>());
            expect((error as AuthError).type, AuthErrorType.invalidCredentials);
          },
        );
      });

      test('successful void result for sign out', () {
        const result = Result<void, AppError>.success(null);

        expect(result.isSuccess, true);
      });

      test('nullable result for Google sign-in cancellation', () {
        const result = Result<String?, AppError>.success(null);

        expect(result.isSuccess, true);
        expect(result.valueOrNull, null);
      });

      test('result getOrElse provides fallback for failure', () {
        final result = Result<String, AppError>.failure(
          const AppError.network('offline'),
        );

        expect(result.getOrElse('fallback'), 'fallback');
      });

      test('result when handles both cases', () {
        final successResult = Result<String, AppError>.success('ok');
        final failureResult = Result<String, AppError>.failure(
          const AppError.auth('fail', type: AuthErrorType.sessionExpired),
        );

        final successValue = successResult.when(
          success: (v) => 'success: $v',
          failure: (e) => 'error: ${e.userMessage}',
        );

        final failureValue = failureResult.when(
          success: (v) => 'success: $v',
          failure: (e) => 'error: ${e.userMessage}',
        );

        expect(successValue, 'success: ok');
        expect(failureValue, contains('セッションが期限切れ'));
      });
    });

    group('Session expired error', () {
      test('session expired triggers correct user message', () {
        const error = AppError.auth('User not logged in', type: AuthErrorType.sessionExpired);

        expect(error.userMessage, 'セッションが期限切れです。再度ログインしてください');
        expect(error.isRetryable, false);
      });
    });

    group('Network errors in auth context', () {
      test('network error during auth is retryable', () {
        const error = AppError.network('Connection timeout');

        expect(error.isRetryable, true);
        expect(error.userMessage, 'ネットワーク接続を確認してください');
      });

      test('custom network error message', () {
        const error = AppError.network(
          'Connection timeout',
          userMessage: 'サーバーに接続できません',
        );

        expect(error.userMessage, 'サーバーに接続できません');
      });
    });
  });
}
