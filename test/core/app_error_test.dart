import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

void main() {
  group('AppError', () {
    group('NetworkError', () {
      test('デフォルトのユーザーメッセージを持つ', () {
        const error = AppError.network('Connection failed');

        expect(error.message, 'Connection failed');
        expect(error.userMessage, 'ネットワーク接続を確認してください');
        expect(error.isRetryable, true);
      });

      test('カスタムユーザーメッセージを設定できる', () {
        const error = AppError.network(
          'Connection failed',
          userMessage: 'カスタムメッセージ',
        );

        expect(error.userMessage, 'カスタムメッセージ');
      });
    });

    group('AuthError', () {
      test('各タイプに適切なユーザーメッセージがある', () {
        const errors = [
          AppError.auth('', type: AuthErrorType.invalidCredentials),
          AppError.auth('', type: AuthErrorType.userNotFound),
          AppError.auth('', type: AuthErrorType.emailAlreadyInUse),
          AppError.auth('', type: AuthErrorType.weakPassword),
          AppError.auth('', type: AuthErrorType.sessionExpired),
          AppError.auth('', type: AuthErrorType.tooManyRequests),
          AppError.auth('', type: AuthErrorType.unknown),
        ];

        for (final error in errors) {
          expect(error.userMessage, isNotEmpty);
          expect(error.userMessage, isNot(''));
        }
      });

      test('tooManyRequestsのみリトライ可能', () {
        const retryable = AppError.auth('', type: AuthErrorType.tooManyRequests);
        const notRetryable = AppError.auth('', type: AuthErrorType.invalidCredentials);

        expect(retryable.isRetryable, true);
        expect(notRetryable.isRetryable, false);
      });
    });

    group('ValidationError', () {
      test('フィールド名付きでメッセージを生成', () {
        const error = AppError.validation('Invalid input', field: 'email');

        expect(error.userMessage, contains('email'));
        expect(error.isRetryable, false);
      });

      test('フィールド名なしでも動作する', () {
        const error = AppError.validation('Invalid input');

        expect(error.userMessage, isNotEmpty);
      });
    });

    group('NotFoundError', () {
      test('リソースタイプ付きでメッセージを生成', () {
        const error = AppError.notFound('Not found', resourceType: '車両');

        expect(error.userMessage, contains('車両'));
        expect(error.isRetryable, false);
      });
    });

    group('PermissionError', () {
      test('適切なユーザーメッセージを持つ', () {
        const error = AppError.permission('Access denied');

        expect(error.userMessage, contains('権限'));
        expect(error.isRetryable, false);
      });
    });

    group('ServerError', () {
      test('ステータスコード付きで生成できる', () {
        const error = AppError.server('Internal error', statusCode: 500);

        expect(error.isRetryable, true);
        expect(error.toString(), contains('500'));
      });
    });

    group('CacheError', () {
      test('リトライ可能', () {
        const error = AppError.cache('Cache miss');

        expect(error.isRetryable, true);
      });
    });

    group('UnknownError', () {
      test('元のエラーを保持できる', () {
        final originalError = Exception('Original');
        final error = AppError.unknown('Unknown', originalError: originalError);

        expect((error as UnknownError).originalError, originalError);
        expect(error.isRetryable, false);
      });
    });

    group('mapFirebaseError', () {
      test('user-not-foundをAuthErrorに変換', () {
        final error = mapFirebaseError('user-not-found error');

        expect(error, isA<AuthError>());
        expect((error as AuthError).type, AuthErrorType.userNotFound);
      });

      test('wrong-passwordをAuthErrorに変換', () {
        final error = mapFirebaseError('wrong-password error');

        expect(error, isA<AuthError>());
        expect((error as AuthError).type, AuthErrorType.invalidCredentials);
      });

      test('permission-deniedをPermissionErrorに変換', () {
        final error = mapFirebaseError('permission-denied error');

        expect(error, isA<PermissionError>());
      });

      test('network関連をNetworkErrorに変換', () {
        final error = mapFirebaseError('network connection error');

        expect(error, isA<NetworkError>());
      });

      test('不明なエラーをUnknownErrorに変換', () {
        final error = mapFirebaseError('some random error');

        expect(error, isA<UnknownError>());
      });
    });
  });
}
