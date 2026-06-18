import 'package:firebase_remote_config/firebase_remote_config.dart';

import 'feature_flag_service.dart';

/// [RemoteFlagSource] backed by Firebase Remote Config.
///
/// Reads the remotely controllable keys (see [FeatureFlagService.remoteKeys])
/// and returns their boolean values so [FeatureFlagService] can apply them
/// onto `AppConfig`. This is what lets ops re-enable the frozen C2C parts
/// marketplace without an app release.
///
/// Defaults mirror the local (frozen) defaults, so a missing/unfetched remote
/// value never accidentally enables a frozen feature. Errors propagate to
/// [FeatureFlagService.sync], which fails safe and keeps local defaults.
class FirebaseRemoteFlagSource implements RemoteFlagSource {
  /// Optional injected instance (for tests). Resolved lazily in [fetch] so the
  /// constructor never touches Firebase — important because the DI container
  /// builds this during `Injection.init()`, including in test environments
  /// where no Firebase app exists. Any failure is handled by
  /// [FeatureFlagService.sync], which fails safe to local defaults.
  final FirebaseRemoteConfig? _override;

  FirebaseRemoteFlagSource({FirebaseRemoteConfig? remoteConfig})
      : _override = remoteConfig;

  @override
  Future<Map<String, dynamic>> fetch() async {
    final remoteConfig = _override ?? FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await remoteConfig.setDefaults(
      {for (final key in FeatureFlagService.remoteKeys.keys) key: false},
    );
    await remoteConfig.fetchAndActivate();
    return {
      for (final key in FeatureFlagService.remoteKeys.keys)
        key: remoteConfig.getBool(key),
    };
  }
}
