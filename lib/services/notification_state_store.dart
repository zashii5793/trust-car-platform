import 'package:shared_preferences/shared_preferences.dart';

/// Persists which AI-suggestion notifications the user has read or dismissed.
///
/// Notifications themselves are regenerated from [RecommendationService] on each
/// launch (they are not stored), so without this the user's "既読/削除" actions
/// were lost on restart and suppressed suggestions reappeared as unread.
/// Persisting only the lightweight read/dismissed id-sets keeps that state.
abstract class NotificationStateStore {
  Future<Set<String>> loadReadIds();
  Future<void> saveReadIds(Set<String> ids);
  Future<Set<String>> loadDismissedIds();
  Future<void> saveDismissedIds(Set<String> ids);
}

/// SharedPreferences-backed implementation.
class SharedPrefsNotificationStateStore implements NotificationStateStore {
  static const _readKey = 'notif_read_ids';
  static const _dismissedKey = 'notif_dismissed_ids';

  /// Upper bound to keep the persisted sets from growing without limit over the
  /// app's lifetime. Oldest entries are dropped first (insertion order).
  static const _maxIds = 500;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<Set<String>> loadReadIds() async =>
      (await _prefs).getStringList(_readKey)?.toSet() ?? <String>{};

  @override
  Future<void> saveReadIds(Set<String> ids) async =>
      (await _prefs).setStringList(_readKey, _capped(ids));

  @override
  Future<Set<String>> loadDismissedIds() async =>
      (await _prefs).getStringList(_dismissedKey)?.toSet() ?? <String>{};

  @override
  Future<void> saveDismissedIds(Set<String> ids) async =>
      (await _prefs).setStringList(_dismissedKey, _capped(ids));

  List<String> _capped(Set<String> ids) {
    final list = ids.toList();
    if (list.length <= _maxIds) return list;
    return list.sublist(list.length - _maxIds);
  }
}
