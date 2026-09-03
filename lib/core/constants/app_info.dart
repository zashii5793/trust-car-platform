import 'package:flutter/foundation.dart';

/// Build identity used when reporting problems.
///
/// A bug report without a version and platform is hard to act on — "the fleet
/// screen is broken" reads differently on 1.0.0 Web and 1.2.0 iOS.
///
/// [version] is kept in step with pubspec.yaml by hand. It is only used for
/// labelling feedback, so a stale value degrades the report, not the app.
class AppInfo {
  AppInfo._();

  static const String version = '1.0.0';

  /// Identifies one build of the same [version].
  ///
  /// During a test rollout the version stays at 1.0.0 while the APK and the
  /// Web build are re-cut many times. Without this, "it still happens" cannot
  /// be tied to the build the reporter actually ran.
  ///
  /// Supplied at build time:
  ///
  ///   flutter build apk --dart-define=APP_BUILD_ID=$(git rev-parse --short HEAD)
  ///
  /// Empty for `flutter run` and for CI test runs — the app must work without
  /// it, so every display path falls back to [version] alone.
  static const String buildId = String.fromEnvironment('APP_BUILD_ID');

  /// What to show on screen and record on feedback: `1.0.0 (a1b2c3d)`.
  static String get fullVersion => formatVersion(version, buildId);

  /// Longest build id we render. A commit SHA is 7-40 characters; anything
  /// beyond that is truncated so the label stays on one line.
  static const int maxBuildIdLength = 40;

  /// Pure formatter so the empty/長すぎる cases are testable — [buildId] itself
  /// is fixed at compile time and cannot be varied from a test.
  @visibleForTesting
  static String formatVersion(String version, String buildId) {
    final id = buildId.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (id.isEmpty) return version;

    final shown =
        id.length > maxBuildIdLength ? id.substring(0, maxBuildIdLength) : id;
    return version.isEmpty ? '($shown)' : '$version ($shown)';
  }

  /// 'web' / 'android' / 'ios' / 'macos' / 'windows' / 'linux' / 'unknown'
  static String get platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
