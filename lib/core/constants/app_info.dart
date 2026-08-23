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
