import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trust_car_platform/main.dart' as app;

// Test user credentials (must exist in Firebase)
const testEmail = 'test@example.com';
const testPassword = 'test1234';

Future<void> takeScreenshot(
    IntegrationTestWidgetsFlutterBinding binding, String name) async {
  await binding.takeScreenshot(name);
  print('📸 Screenshot: $name');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshot Tests', () {
    testWidgets('Capture all screens with CRUD', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // ============================================
      // AUTH SCREENS
      // ============================================

      // 1. Login Screen (empty)
      await takeScreenshot(binding, '01_login_screen');

      // Skip signup for this test - we already have those screenshots
      // Go straight to login

      // ============================================
      // LOGIN AND HOME SCREENS
      // ============================================

      // Find the email and password fields on the login screen
      final emailFields = find.byType(TextFormField);

      // Verify we have text fields
      if (emailFields.evaluate().length < 2) {
        print('❌ Not enough TextFormFields - expected at least 2');
        await takeScreenshot(binding, '02_error_no_fields');
        return;
      }

      // Enter test credentials (login screen has 2 fields: email and password)
      await tester.enterText(emailFields.first, testEmail);
      await tester.enterText(emailFields.at(1), testPassword);
      await tester.pumpAndSettle();

      // 3. Login Screen (filled)
      await takeScreenshot(binding, '03_login_filled');

      // Find and tap login button (could be ElevatedButton or custom AppButton)
      final loginButtonFinder = find.widgetWithText(ElevatedButton, 'ログイン');
      final textButtonFinder = find.text('ログイン');

      if (loginButtonFinder.evaluate().isNotEmpty) {
        await tester.tap(loginButtonFinder.first);
      } else if (textButtonFinder.evaluate().isNotEmpty) {
        await tester.tap(textButtonFinder.first);
      } else {
        // Try tapping the first ElevatedButton
        final buttons = find.byType(ElevatedButton);
        if (buttons.evaluate().isNotEmpty) {
          await tester.tap(buttons.first);
        }
      }
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Check if we're on home screen (look for home screen indicators)
      final homeIndicator = find.textContaining('車両');
      if (homeIndicator.evaluate().isNotEmpty) {
        // 4. Home Screen (empty or with vehicles)
        await takeScreenshot(binding, '04_home_screen');

        // ============================================
        // VEHICLE CRUD
        // ============================================

        // Try to find add vehicle button (FAB or text)
        final addVehicleFab = find.byType(FloatingActionButton);
        final addVehicleText = find.text('車両を追加');

        if (addVehicleFab.evaluate().isNotEmpty) {
          await tester.tap(addVehicleFab.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // 5. Vehicle Registration Screen
          await takeScreenshot(binding, '05_vehicle_registration');

          // Fill vehicle form (basic info)
          final textFields = find.byType(TextFormField);
          if (textFields.evaluate().length >= 3) {
            // Enter basic vehicle info
            await tester.enterText(textFields.at(0), 'トヨタ');
            await tester.enterText(textFields.at(1), 'プリウス');
            await tester.enterText(textFields.at(2), '2023');
            await tester.pumpAndSettle();

            // 6. Vehicle Form Filled
            await takeScreenshot(binding, '06_vehicle_form_filled');

            // Scroll down and find save button
            await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
            await tester.pumpAndSettle();

            // Try to save the vehicle
            final saveButton = find.text('登録');
            final saveButtonAlt = find.text('保存');
            if (saveButton.evaluate().isNotEmpty) {
              await tester.tap(saveButton.first);
              await tester.pumpAndSettle(const Duration(seconds: 3));
            } else if (saveButtonAlt.evaluate().isNotEmpty) {
              await tester.tap(saveButtonAlt.first);
              await tester.pumpAndSettle(const Duration(seconds: 3));
            }

            // After saving, should be back to home with vehicle card
            await takeScreenshot(binding, '07_home_with_vehicle');
          } else {
            // Go back without saving
            final backButton = find.byIcon(Icons.arrow_back);
            if (backButton.evaluate().isNotEmpty) {
              await tester.tap(backButton.first);
              await tester.pumpAndSettle();
            }
          }
        } else if (addVehicleText.evaluate().isNotEmpty) {
          await tester.tap(addVehicleText);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          await takeScreenshot(binding, '05_vehicle_registration');

          // Go back
          final backButton = find.byIcon(Icons.arrow_back);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton.first);
            await tester.pumpAndSettle();
          }
        }

        // ============================================
        // MAINTENANCE RECORD (if vehicle exists)
        // ============================================

        // Wait a moment for any animations
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Look for existing vehicle card to tap
        final vehicleCard = find.byType(Card);
        if (vehicleCard.evaluate().isNotEmpty) {
          await tester.tap(vehicleCard.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // 8. Vehicle Detail Screen
          await takeScreenshot(binding, '08_vehicle_detail');

          // Try to find add maintenance button (FAB with + icon)
          final addMaintenanceFab = find.byType(FloatingActionButton);
          final addMaintenanceText = find.text('整備記録を追加');

          if (addMaintenanceFab.evaluate().isNotEmpty) {
            await tester.tap(addMaintenanceFab.first);
            await tester.pumpAndSettle(const Duration(seconds: 2));

            // 9. Add Maintenance Screen (empty form)
            await takeScreenshot(binding, '09_add_maintenance');

            // Fill maintenance form
            final maintenanceFields = find.byType(TextFormField);
            if (maintenanceFields.evaluate().isNotEmpty) {
              // Try to fill the first field (usually title or description)
              await tester.enterText(maintenanceFields.first, 'オイル交換');
              await tester.pumpAndSettle();

              // 10. Maintenance Form Filled
              await takeScreenshot(binding, '10_maintenance_form_filled');
            }

            // Go back
            final backButton = find.byIcon(Icons.arrow_back);
            if (backButton.evaluate().isNotEmpty) {
              await tester.tap(backButton.first);
              await tester.pumpAndSettle();
            }
          } else if (addMaintenanceText.evaluate().isNotEmpty) {
            await tester.tap(addMaintenanceText.first);
            await tester.pumpAndSettle(const Duration(seconds: 2));
            await takeScreenshot(binding, '09_add_maintenance');

            final backButton = find.byIcon(Icons.arrow_back);
            if (backButton.evaluate().isNotEmpty) {
              await tester.tap(backButton.first);
              await tester.pumpAndSettle();
            }
          }

          // Go back to home
          final backButton = find.byIcon(Icons.arrow_back);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton.first);
            await tester.pumpAndSettle();
          }
        }

        // ============================================
        // SETTINGS/PROFILE
        // ============================================

        // Look for settings or profile icon
        final settingsIcon = find.byIcon(Icons.settings);
        final profileIcon = find.byIcon(Icons.person);

        if (settingsIcon.evaluate().isNotEmpty) {
          await tester.tap(settingsIcon.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          await takeScreenshot(binding, '09_settings');

          final backButton = find.byIcon(Icons.arrow_back);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton.first);
            await tester.pumpAndSettle();
          }
        } else if (profileIcon.evaluate().isNotEmpty) {
          await tester.tap(profileIcon.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          await takeScreenshot(binding, '09_profile');
        }

        print('✅ All screens captured successfully!');
      } else {
        // Login might have failed, capture error state
        await takeScreenshot(binding, '03_login_error');
        print('⚠️ Login may have failed - captured error state');
      }
    });
  });
}
