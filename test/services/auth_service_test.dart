import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/services/auth_service.dart';

void main() {
  group('AuthService Result Pattern Tests', () {
    group('Auth Error Mapping', () {
      test('mapFirebaseError maps user-not-found to AuthError', () {
        final error = mapFirebaseError(
            Exception('[firebase_auth/user-not-found] No user found'));

        expect(error, isA<AuthError>());
        final authError = error as AuthError;
        expect(authError.type, AuthErrorType.userNotFound);
        expect(authError.userMessage, 'メールアドレスまたはパスワードが正しくありません');
        expect(authError.isRetryable, false);
      });

      test('mapFirebaseError maps wrong-password to AuthError', () {
        final error = mapFirebaseError(
            Exception('[firebase_auth/wrong-password] Wrong password'));

        expect(error, isA<AuthError>());
        final authError = error as AuthError;
        expect(authError.type, AuthErrorType.invalidCredentials);
        expect(authError.userMessage, 'メールアドレスまたはパスワードが正しくありません');
      });

      test('mapFirebaseError maps invalid-credential to AuthError', () {
        final error = mapFirebaseError(
            Exception('[firebase_auth/invalid-credential] Invalid'));

        expect(error, isA<AuthError>());
        expect((error as AuthError).type, AuthErrorType.invalidCredentials);
      });

      test('mapFirebaseError maps email-already-in-use to AuthError', () {
        final error = mapFirebaseError(
            Exception('[firebase_auth/email-already-in-use] Already used'));

        expect(error, isA<AuthError>());
        final authError = error as AuthError;
        expect(authError.type, AuthErrorType.emailAlreadyInUse);
        expect(authError.userMessage, 'このメールアドレスはすでに登録されています');
      });

      test('mapFirebaseError maps weak-password to AuthError', () {
        final error = mapFirebaseError(
            Exception('[firebase_auth/weak-password] Too short'));

        expect(error, isA<AuthError>());
        final authError = error as AuthError;
        expect(authError.type, AuthErrorType.weakPassword);
        expect(authError.userMessage, contains('パスワード'));
      });

      test('mapFirebaseError maps too-many-requests to AuthError', () {
        final error = mapFirebaseError(
            Exception('[firebase_auth/too-many-requests] Rate limited'));

        expect(error, isA<AuthError>());
        final authError = error as AuthError;
        expect(authError.type, AuthErrorType.tooManyRequests);
        expect(authError.isRetryable, true);
        expect(authError.userMessage, contains('しばらく待って'));
      });

      test('mapFirebaseError maps requires-recent-login to sessionExpired', () {
        // アカウント削除で直近ログインが古い場合の再認証シグナル
        final error = mapFirebaseError(Exception(
            '[firebase_auth/requires-recent-login] Please reauthenticate'));

        expect(error, isA<AuthError>());
        final authError = error as AuthError;
        expect(authError.type, AuthErrorType.sessionExpired);
        expect(authError.userMessage, contains('再度ログイン'));
      });

      test('mapFirebaseError maps network error', () {
        final error = mapFirebaseError(Exception('network-request-failed'));

        expect(error, isA<NetworkError>());
        expect(error.isRetryable, true);
      });

      test('mapFirebaseError maps permission-denied', () {
        final error = mapFirebaseError(
            Exception('[cloud_firestore/permission-denied] Access denied'));

        expect(error, isA<PermissionError>());
        expect(error.isRetryable, false);
      });

      test('mapFirebaseError maps not-found', () {
        final error = mapFirebaseError(
            Exception('[cloud_firestore/not-found] Document not found'));

        expect(error, isA<NotFoundError>());
      });

      test('mapFirebaseError maps unavailable to NetworkError', () {
        final error = mapFirebaseError(
            Exception('[cloud_firestore/unavailable] Service unavailable'));

        expect(error, isA<NetworkError>());
        expect(error.isRetryable, true);
      });

      test('mapFirebaseError maps unknown error', () {
        final error =
            mapFirebaseError(Exception('Something completely unexpected'));

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
            expect(error.isRetryable, true,
                reason: '$type should be retryable');
          } else {
            expect(error.isRetryable, false,
                reason: '$type should not be retryable');
          }
        }
      });

      test('AuthError toString includes type', () {
        const error =
            AppError.auth('test msg', type: AuthErrorType.userNotFound);
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
          const AppError.auth('Invalid credentials',
              type: AuthErrorType.invalidCredentials),
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
        const error = AppError.auth('User not logged in',
            type: AuthErrorType.sessionExpired);

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

  group('Sign in with Apple helpers', () {
    group('generateNonce', () {
      test('デフォルトの長さは32', () {
        expect(AuthService.generateNonce().length, 32);
      });

      test('指定した長さの nonce を生成する', () {
        expect(AuthService.generateNonce(16).length, 16);
        expect(AuthService.generateNonce(64).length, 64);
      });

      test('許可された文字集合のみで構成される', () {
        const allowed =
            '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
        final nonce = AuthService.generateNonce(200);
        for (final ch in nonce.split('')) {
          expect(allowed.contains(ch), isTrue, reason: '不正な文字: $ch');
        }
      });

      test('呼び出しごとに異なる値を生成する（ランダム性）', () {
        final a = AuthService.generateNonce();
        final b = AuthService.generateNonce();
        expect(a, isNot(equals(b)));
      });

      group('Edge Cases', () {
        test('長さ0は空文字を返す', () {
          expect(AuthService.generateNonce(0), '');
        });
      });
    });

    group('sha256OfString', () {
      test('同じ入力は常に同じハッシュ（決定的）', () {
        expect(
          AuthService.sha256OfString('trust-car'),
          AuthService.sha256OfString('trust-car'),
        );
      });

      test('既知のベクトル: "abc" の SHA-256', () {
        expect(
          AuthService.sha256OfString('abc'),
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        );
      });

      test('出力は64桁の16進文字列', () {
        final hash = AuthService.sha256OfString('any-nonce-value');
        expect(hash.length, 64);
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
      });

      test('異なる入力は異なるハッシュ', () {
        expect(
          AuthService.sha256OfString('a'),
          isNot(equals(AuthService.sha256OfString('b'))),
        );
      });

      group('Edge Cases', () {
        test('空文字のハッシュ（既知ベクトル）', () {
          expect(
            AuthService.sha256OfString(''),
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          );
        });
      });
    });
  });
}
