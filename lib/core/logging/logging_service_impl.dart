import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/logging/crashlytics_wrapper.dart';
import 'package:trust_car_platform/core/logging/log_level.dart';
import 'package:trust_car_platform/core/logging/logging_service.dart';

/// Implementation of LoggingService
///
/// Features:
/// - Console output via developer.log() with proper log levels
/// - Crashlytics integration for non-fatal error reporting
/// - Environment-aware logging (verbose in debug, minimal in release)
/// - Automatic AppError to LogLevel mapping
class LoggingServiceImpl implements LoggingService {
  LoggingServiceImpl({
    LogLevel? minimumLevel,
    CrashlyticsWrapper? crashlytics,
  })  : _minimumLevel = minimumLevel ??
            (kDebugMode ? LogLevel.debug : LogLevel.warning),
        _crashlytics = crashlytics ?? CrashlyticsWrapper.instance;

  final LogLevel _minimumLevel;
  final CrashlyticsWrapper _crashlytics;

  @override
  LogLevel get minimumLevel => _minimumLevel;

  @override
  void debug(String message, {String? tag, Map<String, dynamic>? data}) {
    _log(LogLevel.debug, message, tag: tag, data: data);
  }

  @override
  void info(String message, {String? tag, Map<String, dynamic>? data}) {
    _log(LogLevel.info, message, tag: tag, data: data);
  }

  @override
  void warning(String message, {String? tag, Map<String, dynamic>? data}) {
    _log(LogLevel.warning, message, tag: tag, data: data);
  }

  @override
  void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void fatal(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.fatal,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void logAppError(AppError appError, {String? tag, StackTrace? stackTrace}) {
    final level = _mapAppErrorToLevel(appError);
    final effectiveTag = tag ?? _getTagForAppError(appError);

    _log(
      level,
      appError.message,
      tag: effectiveTag,
      error: appError,
      stackTrace: stackTrace,
      data: _getDataForAppError(appError),
    );
  }

  @override
  Future<void> setUserId(String? userId) async {
    await _crashlytics.setUserId(userId);
    if (kDebugMode && userId != null) {
      debug('User ID set', tag: 'Auth', data: {'userId': userId});
    }
  }

  /// Map AppError type to appropriate log level
  LogLevel _mapAppErrorToLevel(AppError error) {
    return switch (error) {
      // Transient errors - warning level
      NetworkError() => LogLevel.warning,
      CacheError() => LogLevel.warning,

      // User input errors - info level
      ValidationError() => LogLevel.info,

      // Operational errors - error level
      AuthError() => LogLevel.error,
      PermissionError() => LogLevel.error,
      NotFoundError() => LogLevel.error,
      ServerError() => LogLevel.error,
      UnknownError() => LogLevel.error,
    };
  }

  /// Get a tag based on AppError type
  String _getTagForAppError(AppError error) {
    return switch (error) {
      NetworkError() => 'Network',
      AuthError() => 'Auth',
      ValidationError() => 'Validation',
      NotFoundError() => 'NotFound',
      PermissionError() => 'Permission',
      ServerError() => 'Server',
      CacheError() => 'Cache',
      UnknownError() => 'Unknown',
    };
  }

  /// Extract additional data from AppError for logging
  Map<String, dynamic>? _getDataForAppError(AppError error) {
    return switch (error) {
      AuthError(:final type) => {'authErrorType': type.name},
      ServerError(:final statusCode) when statusCode != null => {
          'statusCode': statusCode
        },
      UnknownError(:final originalError) when originalError != null => {
          'originalError': originalError.toString()
        },
      _ => null,
    };
  }

  /// Core logging method
  void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    // Skip if below minimum level
    if (level.severity < _minimumLevel.severity) {
      return;
    }

    // Format the message
    final formattedMessage = _formatMessage(level, message, tag, data);

    // Output to console
    _logToConsole(level, formattedMessage, error, stackTrace, tag);

    // Report to Crashlytics if appropriate
    if (level.shouldReportToCrashlytics && error != null) {
      _reportToCrashlytics(
        error,
        stackTrace ?? StackTrace.current,
        reason: message,
        fatal: level == LogLevel.fatal,
      );
    }
  }

  /// Format log message with timestamp and metadata
  String _formatMessage(
    LogLevel level,
    String message,
    String? tag,
    Map<String, dynamic>? data,
  ) {
    final buffer = StringBuffer();

    // Timestamp
    buffer.write('[${DateTime.now().toIso8601String()}] ');

    // Level
    buffer.write('[${level.label}] ');

    // Tag
    if (tag != null) {
      buffer.write('[$tag] ');
    }

    // Message
    buffer.write(message);

    // Data
    if (data != null && data.isNotEmpty) {
      buffer.write(' | data: $data');
    }

    return buffer.toString();
  }

  /// Output to console using developer.log
  void _logToConsole(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  ) {
    // Only output in debug mode or for error/fatal
    if (!kDebugMode && level.severity < LogLevel.error.severity) {
      return;
    }

    developer.log(
      message,
      name: tag ?? 'App',
      level: _mapLevelToInt(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Map LogLevel to developer.log level integer
  int _mapLevelToInt(LogLevel level) {
    // developer.log levels: 0=finest, 300=finer, 400=fine, 500=config,
    // 700=info, 800=warning, 900=severe, 1000=shout
    return switch (level) {
      LogLevel.debug => 500,
      LogLevel.info => 700,
      LogLevel.warning => 800,
      LogLevel.error => 900,
      LogLevel.fatal => 1000,
    };
  }

  /// Report error to Crashlytics
  Future<void> _reportToCrashlytics(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    await _crashlytics.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: fatal,
    );
  }
}
