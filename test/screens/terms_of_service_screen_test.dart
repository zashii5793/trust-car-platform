// TermsOfServiceScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows '利用規約' title
//   Content:
//     2. Shows headline text
//     3. Shows last-update date
//     4. Shows '第1条（適用）'
//     5. Shows '第4条（禁止事項）'
//     6. Shows copyright footer

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/screens/settings/terms_of_service_screen.dart';

Widget _buildScreen() {
  return const MaterialApp(home: TermsOfServiceScreen());
}

void main() {
  group('TermsOfServiceScreen — AppBar', () {
    testWidgets('1. タイトル「利用規約」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('利用規約'), findsWidgets);
    });
  });

  group('TermsOfServiceScreen — Content', () {
    testWidgets('2. 見出しテキストが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('利用規約'), findsWidgets);
    });

    testWidgets('3. 最終更新日が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.textContaining('2026年4月1日'), findsOneWidget);
    });

    testWidgets('4. セクション「第1条（適用）」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('第1条（適用）'), findsOneWidget);
    });

    testWidgets('5. セクション「第4条（禁止事項）」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('第4条（禁止事項）'), findsOneWidget);
    });

    testWidgets('6. コピーライトフッターが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.textContaining('© 2026 ZAXEL LLC'), findsOneWidget);
    });
  });
}
