import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/screens/settings/privacy_policy_screen.dart';
import 'package:trust_car_platform/screens/settings/terms_of_service_screen.dart';

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(home: child);
}

void main() {
  group('PrivacyPolicyScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(const PrivacyPolicyScreen()));
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    });

    testWidgets('shows AppBar with correct title', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(const PrivacyPolicyScreen()));
      expect(find.text('プライバシーポリシー'), findsWidgets);
    });

    testWidgets('shows last-updated date', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(const PrivacyPolicyScreen()));
      expect(find.textContaining('最終更新日'), findsOneWidget);
    });

    testWidgets('shows all required sections', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(const PrivacyPolicyScreen()));
      await tester.pump();

      expect(find.textContaining('はじめに'), findsAtLeastNWidgets(1));
      expect(find.textContaining('収集する情報'), findsAtLeastNWidgets(1));
      expect(find.textContaining('情報の利用目的'), findsAtLeastNWidgets(1));
      expect(find.textContaining('情報の第三者提供'), findsAtLeastNWidgets(1));
      expect(find.textContaining('位置情報'), findsAtLeastNWidgets(1));
      expect(find.textContaining('お問い合わせ'), findsAtLeastNWidgets(1));
    });

    testWidgets('is scrollable', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(const PrivacyPolicyScreen()));
      final scrollable = find.byType(SingleChildScrollView);
      expect(scrollable, findsOneWidget);
    });

    testWidgets('shows copyright footer', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(const PrivacyPolicyScreen()));
      await tester.pump();
      expect(find.textContaining('TrustCar'), findsWidgets);
    });
  });

  group('TermsOfServiceScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(const TermsOfServiceScreen()));
      expect(find.byType(TermsOfServiceScreen), findsOneWidget);
    });

    testWidgets('shows AppBar with correct title', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(const TermsOfServiceScreen()));
      expect(find.text('利用規約'), findsWidgets);
    });

    testWidgets('shows last-updated date', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(const TermsOfServiceScreen()));
      expect(find.textContaining('最終更新日'), findsOneWidget);
    });

    testWidgets('shows all required articles', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(const TermsOfServiceScreen()));
      await tester.pump();

      expect(find.textContaining('適用'), findsAtLeastNWidgets(1));
      expect(find.textContaining('利用登録'), findsAtLeastNWidgets(1));
      expect(find.textContaining('アカウント管理'), findsAtLeastNWidgets(1));
      expect(find.textContaining('禁止事項'), findsAtLeastNWidgets(1));
      expect(find.textContaining('投稿コンテンツ'), findsAtLeastNWidgets(1));
      expect(find.textContaining('免責事項'), findsAtLeastNWidgets(1));
      expect(find.textContaining('準拠法'), findsAtLeastNWidgets(1));
    });

    testWidgets('is scrollable', (tester) async {
      await tester.pumpWidget(_wrapWithMaterial(const TermsOfServiceScreen()));
      final scrollable = find.byType(SingleChildScrollView);
      expect(scrollable, findsOneWidget);
    });
  });

  group('Edge Cases', () {
    testWidgets('PrivacyPolicyScreen - back navigation works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);

      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pumpAndSettle();
        expect(find.byType(PrivacyPolicyScreen), findsNothing);
      }
    });

    testWidgets('TermsOfServiceScreen - back navigation works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => const TermsOfServiceScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(TermsOfServiceScreen), findsOneWidget);

      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pumpAndSettle();
        expect(find.byType(TermsOfServiceScreen), findsNothing);
      }
    });

    testWidgets('PrivacyPolicyScreen - supports dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData.dark(),
          home: const PrivacyPolicyScreen(),
        ),
      );
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    });

    testWidgets('TermsOfServiceScreen - supports dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData.dark(),
          home: const TermsOfServiceScreen(),
        ),
      );
      expect(find.byType(TermsOfServiceScreen), findsOneWidget);
    });
  });
}
