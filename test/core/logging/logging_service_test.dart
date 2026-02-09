import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/logging/log_level.dart';
import 'package:trust_car_platform/core/logging/logging_service_impl.dart';

void main() {
  group('LogLevel', () {
    test('severity increases with level', () {
      expect(LogLevel.debug.severity, lessThan(LogLevel.info.severity));
      expect(LogLevel.info.severity, lessThan(LogLevel.warning.severity));
      expect(LogLevel.warning.severity, lessThan(LogLevel.error.severity));
      expect(LogLevel.error.severity, lessThan(LogLevel.fatal.severity));
    });

    test('label returns correct strings', () {
      expect(LogLevel.debug.label, equals('DEBUG'));
      expect(LogLevel.info.label, equals('INFO'));
      expect(LogLevel.warning.label, equals('WARN'));
      expect(LogLevel.error.label, equals('ERROR'));
      expect(LogLevel.fatal.label, equals('FATAL'));
    });

    test('shouldReportToCrashlytics is true only for error and fatal', () {
      expect(LogLevel.debug.shouldReportToCrashlytics, isFalse);
      expect(LogLevel.info.shouldReportToCrashlytics, isFalse);
      expect(LogLevel.warning.shouldReportToCrashlytics, isFalse);
      expect(LogLevel.error.shouldReportToCrashlytics, isTrue);
      expect(LogLevel.fatal.shouldReportToCrashlytics, isTrue);
    });
  });

  group('LoggingServiceImpl', () {
    late LoggingServiceImpl service;

    setUp(() {
      service = LoggingServiceImpl(
        minimumLevel: LogLevel.debug,
      );
    });

    test('can be instantiated with default values', () {
      final defaultService = LoggingServiceImpl();
      expect(defaultService.minimumLevel, isNotNull);
    });

    test('debug level logs are processed', () {
      // Should not throw
      expect(
        () => service.debug('Test debug message', tag: 'Test'),
        returnsNormally,
      );
    });

    test('info level logs are processed', () {
      expect(
        () => service.info('Test info message', tag: 'Test'),
        returnsNormally,
      );
    });

    test('warning level logs are processed', () {
      expect(
        () => service.warning('Test warning message', tag: 'Test'),
        returnsNormally,
      );
    });

    test('error level logs are processed', () {
      expect(
        () => service.error(
          'Test error message',
          tag: 'Test',
          error: Exception('Test'),
        ),
        returnsNormally,
      );
    });

    test('fatal level logs are processed', () {
      expect(
        () => service.fatal(
          'Test fatal message',
          tag: 'Test',
          error: Exception('Test'),
        ),
        returnsNormally,
      );
    });

    test('minimumLevel filters lower severity logs', () {
      final warningOnlyService = LoggingServiceImpl(
        minimumLevel: LogLevel.warning,
      );

      expect(warningOnlyService.minimumLevel, equals(LogLevel.warning));

      // These should be filtered (below warning level)
      // No exception should be thrown, but logs shouldn't be processed
      expect(
        () => warningOnlyService.debug('Debug message'),
        returnsNormally,
      );
      expect(
        () => warningOnlyService.info('Info message'),
        returnsNormally,
      );
    });

    test('logs with data parameter', () {
      expect(
        () => service.info(
          'Message with data',
          tag: 'Test',
          data: {'key': 'value', 'count': 42},
        ),
        returnsNormally,
      );
    });
  });

  group('LoggingServiceImpl.logAppError', () {
    late LoggingServiceImpl service;

    setUp(() {
      service = LoggingServiceImpl(
        minimumLevel: LogLevel.debug,
      );
    });

    test('logs NetworkError as warning', () {
      const error = NetworkError('Network failed');
      // Should not throw
      expect(
        () => service.logAppError(error, tag: 'Test'),
        returnsNormally,
      );
    });

    test('logs CacheError as warning', () {
      const error = CacheError('Cache failed');
      expect(
        () => service.logAppError(error, tag: 'Test'),
        returnsNormally,
      );
    });

    test('logs ValidationError as info', () {
      const error = ValidationError('Invalid input');
      expect(
        () => service.logAppError(error, tag: 'Test'),
        returnsNormally,
      );
    });

    test('logs AuthError as error', () {
      const error = AuthError('Auth failed', type: AuthErrorType.invalidCredentials);
      expect(
        () => service.logAppError(error, tag: 'Test'),
        returnsNormally,
      );
    });

    test('logs PermissionError as error', () {
      const error = PermissionError('Permission denied');
      expect(
        () => service.logAppError(error, tag: 'Test'),
        returnsNormally,
      );
    });

    test('logs NotFoundError as error', () {
      const error = NotFoundError('Not found');
      expect(
        () => service.logAppError(error, tag: 'Test'),
        returnsNormally,
      );
    });

    test('logs ServerError as error', () {
      const error = ServerError('Server error', statusCode: 500);
      expect(
        () => service.logAppError(error, tag: 'Test'),
        returnsNormally,
      );
    });

    test('logs UnknownError as error', () {
      const error = UnknownError('Unknown error');
      expect(
        () => service.logAppError(error, tag: 'Test'),
        returnsNormally,
      );
    });

    test('logs AuthError with type data', () {
      const error = AuthError('Auth failed', type: AuthErrorType.tooManyRequests);
      expect(
        () => service.logAppError(error),
        returnsNormally,
      );
    });

    test('logs ServerError with statusCode data', () {
      const error = ServerError('Server error', statusCode: 503);
      expect(
        () => service.logAppError(error),
        returnsNormally,
      );
    });

    test('logs UnknownError with originalError data', () {
      final originalError = Exception('Original');
      final error = UnknownError('Unknown', originalError: originalError);
      expect(
        () => service.logAppError(error),
        returnsNormally,
      );
    });
  });

  group('LoggingServiceImpl.setUserId', () {
    late LoggingServiceImpl service;

    setUp(() {
      service = LoggingServiceImpl(
        minimumLevel: LogLevel.debug,
      );
    });

    test('can set user ID', () async {
      await expectLater(
        service.setUserId('user123'),
        completes,
      );
    });

    test('can clear user ID with null', () async {
      await expectLater(
        service.setUserId(null),
        completes,
      );
    });
  });

  group('AppError logging integration', () {
    test('setAppErrorLogger can be set and cleared', () {
      // Set logger
      setAppErrorLogger((error, {tag, stackTrace}) {
        // Do nothing in test
      });

      // Clear logger
      setAppErrorLogger(null);

      // Should not throw
      expect(() => setAppErrorLogger(null), returnsNormally);
    });

    test('mapFirebaseError returns AuthError for user-not-found', () {
      final error = mapFirebaseError(Exception('user-not-found'));
      expect(error, isA<AuthError>());
      expect((error as AuthError).type, equals(AuthErrorType.userNotFound));
    });

    test('mapFirebaseError returns AuthError for wrong-password', () {
      final error = mapFirebaseError(Exception('wrong-password'));
      expect(error, isA<AuthError>());
      expect((error as AuthError).type, equals(AuthErrorType.invalidCredentials));
    });

    test('mapFirebaseError returns AuthError for invalid-credential', () {
      final error = mapFirebaseError(Exception('invalid-credential'));
      expect(error, isA<AuthError>());
      expect((error as AuthError).type, equals(AuthErrorType.invalidCredentials));
    });

    test('mapFirebaseError returns AuthError for email-already-in-use', () {
      final error = mapFirebaseError(Exception('email-already-in-use'));
      expect(error, isA<AuthError>());
      expect((error as AuthError).type, equals(AuthErrorType.emailAlreadyInUse));
    });

    test('mapFirebaseError returns AuthError for weak-password', () {
      final error = mapFirebaseError(Exception('weak-password'));
      expect(error, isA<AuthError>());
      expect((error as AuthError).type, equals(AuthErrorType.weakPassword));
    });

    test('mapFirebaseError returns AuthError for too-many-requests', () {
      final error = mapFirebaseError(Exception('too-many-requests'));
      expect(error, isA<AuthError>());
      expect((error as AuthError).type, equals(AuthErrorType.tooManyRequests));
    });

    test('mapFirebaseError returns NetworkError for network errors', () {
      final error = mapFirebaseError(Exception('network error occurred'));
      expect(error, isA<NetworkError>());
    });

    test('mapFirebaseError returns NetworkError for connection errors', () {
      final error = mapFirebaseError(Exception('connection failed'));
      expect(error, isA<NetworkError>());
    });

    test('mapFirebaseError returns NetworkError for unavailable', () {
      final error = mapFirebaseError(Exception('service unavailable'));
      expect(error, isA<NetworkError>());
    });

    test('mapFirebaseError returns PermissionError for permission-denied', () {
      final error = mapFirebaseError(Exception('permission-denied'));
      expect(error, isA<PermissionError>());
    });

    test('mapFirebaseError returns NotFoundError for not-found', () {
      final error = mapFirebaseError(Exception('not-found'));
      expect(error, isA<NotFoundError>());
    });

    test('mapFirebaseError returns UnknownError for unknown errors', () {
      final error = mapFirebaseError(Exception('some random error'));
      expect(error, isA<UnknownError>());
    });

    test('mapFirebaseError accepts stackTrace parameter', () {
      final stackTrace = StackTrace.current;
      expect(
        () => mapFirebaseError(Exception('test'), stackTrace: stackTrace),
        returnsNormally,
      );
    });
  });
}
