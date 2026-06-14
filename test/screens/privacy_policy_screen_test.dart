// PrivacyPolicyScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows 'プライバシーポリシー' title
//   Content:
//     2. Shows headlne text
//     3. Shows last-update date
//     4. Shows section '1. はじめに'
//     5. Shows section '2. 収集する情報'
//     6. Shows copyright footer

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/screens/settings/privacy_policy_screen.dart';

Widget _buildScreen() {
  return const MaterialApp(home: PrivacyPolicyScreen());
}

void main() {
  group('PrivacyPolicyScreen — AppBar', () {
    testWidgets('1. タイトル「プライバシーポリシー」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('プライバシーポリシー'), findsWidgets);
    });
  });

  group('PrivacyPolicyScreen — Content', () {
    testWidgets('2. 見出しテキストが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('プライバシーポリシー'), findsWidgets);
    });

    testWidgets('3. 最終更新日が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.textContaining('2026年4月1日'), findsOneWidget);
    });

    testWidgets('4. セクション「1. はじめに」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('1. はじめに'), findsOneWidget);
    });

    testWidgets('5. セクション「2. 収集する情報」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('2. 収集する情報'), findsOneWidget);
    });

    testWidgets('6. コピーライトフッターが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.textContaining('© 2026 TrustCar'), findsOneWidget);
    });
  });
}
