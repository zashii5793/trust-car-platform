import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Wrapper for Firebase Crashlytics with null-safety and platform handling
///
/// Handles cases where Crashlytics is not available (e.g., web platform)
/// or not enabled (e.g., debug mode).
class CrashlyticsWrapper {
  CrashlyticsWrapper._();

  static CrashlyticsWrapper? _instance;
  FirebaseCrashlytics? _crashlytics;
  bool _isEnabled = false;

  /// Get or create the singleton instance
  static CrashlyticsWrapper get instance {
    _instance ??= CrashlyticsWrapper._();
    return _instance!;
  }

  /// Initialize Crashlytics wrapper
  ///
  /// [enabled] - Whether crash reporting is enabled
  /// Returns false if Crashlytics is not available on this platform
  Future<bool> initialize({required bool enabled}) async {
    if (!enabled) {
      _isEnabled = false;
      return false;
    }

    try {
      _crashlytics = FirebaseCrashlytics.instance;
      await _crashlytics!.setCrashlyticsCollectionEnabled(!kDebugMode);
      _isEnabled = !kDebugMode;
      return _isEnabled;
    } catch (e) {
      // Platform not supported (e.g., web)
      debugPrint('CrashlyticsWrapper: Failed to initialize - $e');
      _isEnabled = false;
      return false;
    }
  }

  /// Whether Crashlytics is initialized and enabled
  bool get isEnabled => _isEnabled && _crashlytics != null;

  /// Record a non-fatal error
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!isEnabled) return;

    try {
      await _crashlytics!.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('CrashlyticsWrapper: Failed to record error - $e');
    }
  }

  /// Set user identifier for crash reports
  Future<void> setUserId(String? userId) async {
    if (!isEnabled) return;

    try {
      await _crashlytics!.setUserIdentifier(userId ?? '');
    } catch (e) {
      debugPrint('CrashlyticsWrapper: Failed to set user ID - $e');
    }
  }

  /// Log a message to Crashlytics (breadcrumb)
  Future<void> log(String message) async {
    if (!isEnabled) return;

    try {
      await _crashlytics!.log(message);
    } catch (e) {
      debugPrint('CrashlyticsWrapper: Failed to log message - $e');
    }
  }

  /// Set a custom key-value pair for crash reports
  Future<void> setCustomKey(String key, Object value) async {
    if (!isEnabled) return;

    try {
      await _crashlytics!.setCustomKey(key, value);
    } catch (e) {
      debugPrint('CrashlyticsWrapper: Failed to set custom key - $e');
    }
  }

  /// Get the Flutter error handler for FlutterError.onError
  FlutterExceptionHandler? get flutterErrorHandler {
    if (!isEnabled) return null;
    return _crashlytics!.recordFlutterError;
  }
}
