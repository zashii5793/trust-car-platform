import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_car_platform/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider', () {
    test('defaults to system when nothing is saved', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ThemeProvider.loadSavedMode(), ThemeMode.system);
    });

    test('loads the persisted mode', () async {
      SharedPreferences.setMockInitialValues({
        ThemeProvider.prefsKey: 'dark',
      });
      expect(await ThemeProvider.loadSavedMode(), ThemeMode.dark);
    });

    test('setThemeMode persists and notifies listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.setThemeMode(ThemeMode.light);

      expect(provider.themeMode, ThemeMode.light);
      expect(notified, 1);
      expect(await ThemeProvider.loadSavedMode(), ThemeMode.light);
    });

    group('Edge Cases', () {
      test('setting the same mode does not notify', () async {
        SharedPreferences.setMockInitialValues({});
        final provider = ThemeProvider(initialMode: ThemeMode.system);
        var notified = 0;
        provider.addListener(() => notified++);

        await provider.setThemeMode(ThemeMode.system);

        expect(notified, 0);
      });

      test('unknown persisted value falls back to system', () async {
        SharedPreferences.setMockInitialValues({
          ThemeProvider.prefsKey: 'sepia',
        });
        expect(await ThemeProvider.loadSavedMode(), ThemeMode.system);
      });
    });
  });
}
