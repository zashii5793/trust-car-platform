import '../core/config/app_config.dart';

/// A source of remote feature-flag overrides.
///
/// Implement this with Firebase Remote Config (or any backend) to control
/// flags such as [FeatureFlag.c2cPartsMarketplace] without shipping an app
/// release. See `docs/HUMAN_TASKS.md` for the Remote Config wiring steps.
abstract class RemoteFlagSource {
  /// Returns a map of remote flag keys to values. Keys use snake_case
  /// (e.g. `c2c_parts_marketplace`); values may be bool/String/num.
  Future<Map<String, dynamic>> fetch();
}

/// Default source that returns no overrides — flags keep their local defaults.
///
/// Swap this for a Remote Config-backed source to enable remote control.
class NoopRemoteFlagSource implements RemoteFlagSource {
  const NoopRemoteFlagSource();

  @override
  Future<Map<String, dynamic>> fetch() async => const {};
}

/// Applies remote feature-flag overrides onto [AppConfig].
///
/// This is the seam that lets ops re-enable the frozen C2C parts marketplace
/// (or any controllable flag) remotely. The mapping in [remoteKeys] is the
/// allow-list: only these flags can be overridden from the remote source.
class FeatureFlagService {
  final AppConfig _config;
  final RemoteFlagSource _source;

  FeatureFlagService({
    AppConfig? config,
    RemoteFlagSource source = const NoopRemoteFlagSource(),
  })  : _config = config ?? AppConfig.instance,
        _source = source;

  /// Remote key → [FeatureFlag] allow-list. Only remotely controllable flags
  /// are listed here; unknown keys from the source are ignored.
  static const Map<String, FeatureFlag> remoteKeys = {
    'c2c_parts_marketplace': FeatureFlag.c2cPartsMarketplace,
  };

  /// Fetches remote overrides and applies them onto [AppConfig].
  ///
  /// Fails safe: any error from the source leaves local defaults untouched.
  /// Returns the flags that were actually applied.
  Future<Map<FeatureFlag, bool>> sync() async {
    Map<String, dynamic> remote;
    try {
      remote = await _source.fetch();
    } catch (_) {
      return const {};
    }
    return applyOverrides(remote);
  }

  /// Maps a raw remote [overrides] map onto [AppConfig] flags and returns the
  /// applied subset. Unknown keys and uncoercible values are skipped.
  Map<FeatureFlag, bool> applyOverrides(Map<String, dynamic> overrides) {
    final applied = <FeatureFlag, bool>{};
    overrides.forEach((key, value) {
      final flag = remoteKeys[key];
      if (flag == null) return;
      final boolValue = _coerceBool(value);
      if (boolValue == null) return;
      applied[flag] = boolValue;
    });
    if (applied.isNotEmpty) {
      _config.setFeatureFlags(applied);
    }
    return applied;
  }

  bool? _coerceBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final s = value.trim().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return null;
  }
}
