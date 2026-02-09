import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/logging/log_level.dart';

/// Centralized logging service interface
///
/// Provides structured logging with support for:
/// - Multiple log levels (debug, info, warning, error, fatal)
/// - Automatic AppError categorization
/// - Crash reporting integration
/// - User identification for crash reports
abstract class LoggingService {
  /// Log a debug message (development only)
  void debug(String message, {String? tag, Map<String, dynamic>? data});

  /// Log an informational message
  void info(String message, {String? tag, Map<String, dynamic>? data});

  /// Log a warning message
  void warning(String message, {String? tag, Map<String, dynamic>? data});

  /// Log an error message
  void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  });

  /// Log a fatal error message
  void fatal(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  });

  /// Log an AppError with automatic level categorization
  ///
  /// Automatically determines log level based on AppError type:
  /// - NetworkError, CacheError → warning (usually transient)
  /// - ValidationError → info (user input errors)
  /// - AuthError, PermissionError, NotFoundError → error
  /// - ServerError, UnknownError → error
  void logAppError(AppError appError, {String? tag, StackTrace? stackTrace});

  /// Set user identifier for crash reports
  Future<void> setUserId(String? userId);

  /// Get the minimum log level for this service
  LogLevel get minimumLevel;
}
