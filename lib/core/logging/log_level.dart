/// Log levels for structured logging
enum LogLevel {
  /// Development only - detailed debug information
  debug,

  /// General information about application state
  info,

  /// Potential issues that don't prevent operation
  warning,

  /// Recoverable errors
  error,

  /// Critical failures that may crash the app
  fatal,
}

/// Extension to provide log level utilities
extension LogLevelExtension on LogLevel {
  /// Returns the numeric value for comparison (higher = more severe)
  int get severity => index;

  /// Returns the string representation for logging
  String get label => switch (this) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.warning => 'WARN',
        LogLevel.error => 'ERROR',
        LogLevel.fatal => 'FATAL',
      };

  /// Returns whether this level should be reported to crash analytics
  bool get shouldReportToCrashlytics => switch (this) {
        LogLevel.debug => false,
        LogLevel.info => false,
        LogLevel.warning => false,
        LogLevel.error => true,
        LogLevel.fatal => true,
      };
}
