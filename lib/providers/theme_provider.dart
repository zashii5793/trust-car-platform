import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's preferred [ThemeMode] and persists it on-device via
/// SharedPreferences.
///
/// Defaults to [ThemeMode.light], NOT [ThemeMode.system]. Following the OS
/// setting meant a first-time visitor on a dark-themed device saw the app in
/// dark without ever asking for it, which is not the brand's intended first
/// impression. Dark is opt-in: it appears only once the user picks it in 設定.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({ThemeMode initialMode = ThemeMode.light})
      : _themeMode = initialMode;

  static const String prefsKey = 'theme_mode';

  ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

  /// Reads the persisted preference. Falls back to light on any error or when
  /// nothing has been saved yet — see the class doc on why not system.
  static Future<ThemeMode> loadSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _decode(prefs.getString(prefsKey));
    } catch (_) {
      return ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, _encode(mode));
    } catch (_) {
      // Persistence is best-effort; the in-memory choice still applies for the
      // current session.
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _decode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
