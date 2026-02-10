// Screenshot capture with simulator screenshot commands
// This test navigates through screens and pauses for external screenshot capture

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trust_car_platform/main.dart' as app;

/// Take simulator screenshot using xcrun
Future<void> captureSimulatorScreenshot(String filename) async {
  final screenshotDir = '/Users/zashii/development/trust_car_platform/docs/screenshots';
  final result = await Process.run('xcrun', [
    'simctl', 'io', 'booted', 'screenshot', '$screenshotDir/$filename.png'
  ]);
  if (result.exitCode == 0) {
    print('📸 Captured: $filename.png');
  } else {
    print('❌ Failed to capture $filename: ${result.stderr}');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Screenshots', () {
    testWidgets('Capture all accessible screens', (tester) async {
      // Start app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 1. Login Screen
      await captureSimulatorScreenshot('01_login_screen');
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to Signup
      final signupLink = find.text('新規登録');
      if (signupLink.evaluate().isNotEmpty) {
        await tester.tap(signupLink);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // 2. Signup Screen
        await captureSimulatorScreenshot('02_signup_screen');
        await Future.delayed(const Duration(milliseconds: 500));

        // Go back
        final scaffold = find.byType(Scaffold);
        if (scaffold.evaluate().isNotEmpty) {
          // Press back button
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
      }

      print('✅ Screenshots captured in docs/screenshots/');
    });
  });
}
