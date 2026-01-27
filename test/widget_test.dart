import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/constants/colors.dart';
import 'package:trust_car_platform/core/constants/spacing.dart';
import 'package:trust_car_platform/widgets/common/app_button.dart';
import 'package:trust_car_platform/widgets/common/app_card.dart';
import 'package:trust_car_platform/widgets/common/loading_indicator.dart';

void main() {
  group('AppColors Tests', () {
    test('Primary color should be correct', () {
      expect(AppColors.primary, const Color(0xFF1A4D8F));
    });

    test('Secondary color should be correct', () {
      expect(AppColors.secondary, const Color(0xFF2D7A5F));
    });

    test('Maintenance colors should be defined', () {
      expect(AppColors.maintenanceRepair, isNotNull);
      expect(AppColors.maintenanceInspection, isNotNull);
      expect(AppColors.maintenanceParts, isNotNull);
      expect(AppColors.maintenanceCarInspection, isNotNull);
    });
  });

  group('AppSpacing Tests', () {
    test('Spacing values should follow 4px grid', () {
      expect(AppSpacing.xxs, 4.0);
      expect(AppSpacing.xs, 8.0);
      expect(AppSpacing.sm, 12.0);
      expect(AppSpacing.md, 16.0);
      expect(AppSpacing.lg, 24.0);
      expect(AppSpacing.xl, 32.0);
      expect(AppSpacing.xxl, 48.0);
    });
  });

  group('AppButton Widget Tests', () {
    testWidgets('Primary button renders correctly', (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Test Button',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      expect(pressed, isTrue);
    });

    testWidgets('Secondary button renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.secondary(
              label: 'Secondary',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Secondary'), findsOneWidget);
    });

    testWidgets('Loading state shows indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Loading',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Disabled button should not respond to tap', (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton.primary(
              label: 'Disabled',
              onPressed: null,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppButton));
      expect(pressed, isFalse);
    });
  });

  group('AppCard Widget Tests', () {
    testWidgets('AppCard renders child correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('AppCard responds to tap', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              onTap: () => tapped = true,
              child: const Text('Tappable Card'),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppCard));
      expect(tapped, isTrue);
    });
  });

  group('Loading Indicator Tests', () {
    testWidgets('AppLoadingIndicator renders', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLoadingIndicator(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AppLoadingCenter renders with message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLoadingCenter(message: 'Loading...'),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('AppEmptyState renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.inbox,
              title: 'No Data',
              description: 'There is no data to display',
            ),
          ),
        ),
      );

      expect(find.text('No Data'), findsOneWidget);
      expect(find.text('There is no data to display'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });

    testWidgets('AppErrorState renders with retry button', (WidgetTester tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorState(
              message: 'Error occurred',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Error occurred'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);

      await tester.tap(find.text('再試行'));
      expect(retried, isTrue);
    });
  });
}
