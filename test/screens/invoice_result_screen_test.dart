// InvoiceResultScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows '読み取り結果の確認' title
//     2. Shows image/form toggle icon button
//   Confidence card:
//     3. Shows confidence percentage
//     4. Shows '多くの項目を読み取れました' for high confidence (>=50%)
//     5. Shows '一部の項目を読み取れました' for medium confidence (30-49%)
//     6. Shows '読み取りが難しい箇所があります' for low confidence (<30%)
//   Maintenance type:
//     7. Shows '整備タイプ' section header
//     8. Shows maintenance type chips
//     9. Tapping chip changes selection
//   Form fields:
//    10. Amount field pre-filled from ocrData
//    11. Shop name field pre-filled from ocrData
//    12. Description pre-filled from items joined by '、'
//    13. Date shows '未設定' when ocrData has no date
//    14. Date shows formatted date when ocrData has date
//   Items section:
//    15. '明細項目' section hidden when items empty
//    16. '明細項目' section shown when items exist
//    17. Item names displayed in list
//   Bottom bar:
//    18. Shows 'キャンセル' button
//    19. Shows '整備記録を登録' button
//   Validation:
//    20. No type selected → shows '整備タイプを選択してください'
//    21. No date → shows '作業日を設定してください'
//   Submit:
//    22. Valid form pops with MaintenanceRegistrationData result
//   Edge Cases:
//    23. Empty items → description field is empty
//    24. Multiple items → description joined by '、'

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/screens/invoice_result_screen.dart';
import 'package:trust_car_platform/services/invoice_ocr_service.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

// Use /dev/null as a stand-in File (never rendered in form-view tests)
final _fakeFile = File('/dev/null');

InvoiceData _makeOcrData({
  DateTime? date,
  int? totalAmount,
  int? taxAmount,
  int? subtotalAmount,
  String? shopName,
  String? shopAddress,
  String? shopPhone,
  String? invoiceNumber,
  int? mileage,
  List<InvoiceItem> items = const [],
}) {
  return InvoiceData(
    date: date,
    totalAmount: totalAmount,
    taxAmount: taxAmount,
    subtotalAmount: subtotalAmount,
    shopName: shopName,
    shopAddress: shopAddress,
    shopPhone: shopPhone,
    invoiceNumber: invoiceNumber,
    mileage: mileage,
    items: items,
  );
}

Widget _buildScreen(InvoiceData ocrData) {
  return MaterialApp(
    home: InvoiceResultScreen(
      imageFile: _fakeFile,
      ocrData: ocrData,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('InvoiceResultScreen — AppBar', () {
    testWidgets('1. shows 読み取り結果の確認 title', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeOcrData()));
      await tester.pump();

      expect(find.text('読み取り結果の確認'), findsOneWidget);
    });

    testWidgets('2. shows image/form toggle icon button', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeOcrData()));
      await tester.pump();

      // Default form-view shows the image icon
      expect(find.byIcon(Icons.image), findsOneWidget);
    });
  });

  group('InvoiceResultScreen — Confidence card', () {
    testWidgets('3. shows confidence percentage', (tester) async {
      // 5 fields filled → 50%
      final data = _makeOcrData(
        date: DateTime(2025, 6, 1),
        totalAmount: 10000,
        taxAmount: 1000,
        subtotalAmount: 9000,
        shopName: 'テストショップ',
      );
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      expect(find.textContaining('50%'), findsOneWidget);
    });

    testWidgets('4. shows 多くの項目を読み取れました for high confidence', (tester) async {
      // 5/10 = 0.5 → green
      final data = _makeOcrData(
        date: DateTime(2025, 6, 1),
        totalAmount: 10000,
        taxAmount: 1000,
        subtotalAmount: 9000,
        shopName: 'テストショップ',
      );
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      expect(find.text('多くの項目を読み取れました'), findsOneWidget);
    });

    testWidgets('5. shows 一部の項目を読み取れました for medium confidence', (tester) async {
      // 3/10 = 0.3 → orange
      final data = _makeOcrData(
        date: DateTime(2025, 6, 1),
        totalAmount: 10000,
        shopName: 'テストショップ',
      );
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      expect(find.text('一部の項目を読み取れました'), findsOneWidget);
    });

    testWidgets('6. shows 読み取りが難しい箇所があります for low confidence', (tester) async {
      // 2/10 = 0.2 → red
      final data = _makeOcrData(
        date: DateTime(2025, 6, 1),
        totalAmount: 10000,
      );
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      expect(find.text('読み取りが難しい箇所があります'), findsOneWidget);
    });
  });

  group('InvoiceResultScreen — Maintenance type', () {
    testWidgets('7. shows 整備タイプ section header', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeOcrData()));
      await tester.pump();

      expect(find.text('整備タイプ'), findsOneWidget);
    });

    testWidgets('8. shows maintenance type chips', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeOcrData()));
      await tester.pump();

      // Screen renders frequentTypes chips
      expect(find.byType(ChoiceChip), findsWidgets);
    });

    testWidgets('9. tapping unselected chip selects it', (tester) async {
      // Use empty items so estimatedMaintenanceType=null → selectedType=other
      final data = _makeOcrData();
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      // Find the tireChange chip and tap it
      await tester.tap(find.text('タイヤ交換'));
      await tester.pump();

      // After tapping タイヤ交換 chip it should be selected (selected=true)
      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      final tireChip = chips.firstWhere(
        (c) => (c.label as Text).data == 'タイヤ交換',
      );
      expect(tireChip.selected, isTrue);
    });
  });

  group('InvoiceResultScreen — Form fields', () {
    testWidgets('10. amount field pre-filled from ocrData', (tester) async {
      final data = _makeOcrData(totalAmount: 15000);
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      // EditableText renders controller text, found by find.text()
      expect(find.text('15000'), findsOneWidget);
    });

    testWidgets('11. shop name field pre-filled from ocrData', (tester) async {
      final data = _makeOcrData(shopName: 'オートサービス山田');
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      expect(find.text('オートサービス山田'), findsOneWidget);
    });

    testWidgets('12. description pre-filled from items', (tester) async {
      final data = _makeOcrData(
        items: [
          InvoiceItem(name: 'オイル交換', amount: 3000),
          InvoiceItem(name: 'オイルフィルター', amount: 1500),
        ],
      );
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      expect(find.text('オイル交換、オイルフィルター'), findsOneWidget);
    });

    testWidgets('13. shows 未設定 when no date in ocrData', (tester) async {
      final data = _makeOcrData(date: null);
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      expect(find.text('未設定（タップして設定）'), findsOneWidget);
    });

    testWidgets('14. shows formatted date when ocrData has date',
        (tester) async {
      final data = _makeOcrData(date: DateTime(2025, 6, 15));
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      expect(find.text('2025年6月15日'), findsOneWidget);
    });
  });

  group('InvoiceResultScreen — Items section', () {
    testWidgets('15. 明細項目 section hidden when items empty', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeOcrData()));
      await tester.pump();

      expect(find.text('明細項目'), findsNothing);
    });

    testWidgets('16. 明細項目 section shown when items exist', (tester) async {
      final data = _makeOcrData(
        items: [InvoiceItem(name: 'エンジンオイル', amount: 4000)],
      );
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      expect(find.text('明細項目'), findsOneWidget);
    });

    testWidgets('17. item names displayed in list', (tester) async {
      final data = _makeOcrData(
        items: [
          InvoiceItem(name: 'エアフィルター', amount: 2000),
          InvoiceItem(name: 'ワイパーブレード', amount: 3000),
        ],
      );
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      expect(find.text('エアフィルター'), findsOneWidget);
      expect(find.text('ワイパーブレード'), findsOneWidget);
    });
  });

  group('InvoiceResultScreen — Bottom bar', () {
    testWidgets('18. shows キャンセル button', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeOcrData()));
      await tester.pump();

      expect(find.text('キャンセル'), findsOneWidget);
    });

    testWidgets('19. shows 整備記録を登録 button', (tester) async {
      await tester.pumpWidget(_buildScreen(_makeOcrData()));
      await tester.pump();

      expect(find.text('整備記録を登録'), findsOneWidget);
    });
  });

  group('InvoiceResultScreen — Validation', () {
    testWidgets('20. no type selected shows 整備タイプを選択してください', (tester) async {
      // Start with a selectedType (other), then tap it to deselect
      final data = _makeOcrData(date: DateTime(2025, 6, 1));
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      // Tap the currently selected chip (other/その他) to deselect
      await tester.tap(find.text('その他'));
      await tester.pump();

      // 低信頼データのため、まず「内容を確認しました」で登録ゲートを解除する
      await tester.tap(find.text('内容を確認しました'));
      await tester.pump();

      // Now submit with no type
      await tester.tap(find.text('整備記録を登録'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('整備タイプを選択してください'), findsOneWidget);
    });

    testWidgets('21. no date shows 作業日を設定してください', (tester) async {
      // No date provided; selectedType defaults to other
      final data = _makeOcrData(date: null);
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      // 低信頼データのため、まず登録ゲートを解除する
      await tester.tap(find.text('内容を確認しました'));
      await tester.pump();

      await tester.tap(find.text('整備記録を登録'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('作業日を設定してください'), findsOneWidget);
    });
  });

  group('InvoiceResultScreen — 信頼度ドリブンゲート', () {
    // ElevatedButton.icon は Flutter のバージョンによりサブクラスを返すため、
    // find.byType（厳密一致）ではなく is 判定で「整備記録を登録」ボタンを取る。
    ElevatedButton submitButton(WidgetTester tester) {
      return tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('整備記録を登録'),
          matching: find.byWidgetPredicate((w) => w is ElevatedButton),
        ),
      );
    }

    testWidgets('低信頼では確認するまで登録ボタンが無効', (tester) async {
      // ほぼ空＝低信頼データ
      final data = _makeOcrData(date: DateTime(2025, 6, 1));
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      expect(find.text('読み取りの確信度が低めです'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull); // 無効

      await tester.tap(find.text('内容を確認しました'));
      await tester.pump();

      expect(submitButton(tester).onPressed, isNotNull); // 確認後は有効
    });

    testWidgets('高信頼ではゲートを表示せず即登録できる', (tester) async {
      final data = _makeOcrData(
        date: DateTime(2025, 6, 1),
        totalAmount: 12000,
        taxAmount: 1090,
        subtotalAmount: 10910,
        shopName: 'テスト工場',
        shopAddress: '東京都',
        shopPhone: '03-0000-0000',
        invoiceNumber: 'INV-1',
        mileage: 30000,
        items: [InvoiceItem(name: 'オイル交換')],
      );
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      expect(find.text('読み取りの確信度が低めです'), findsNothing);
      expect(submitButton(tester).onPressed, isNotNull);
    });
  });

  group('InvoiceResultScreen — Edge Cases', () {
    testWidgets('23. empty items → hint text visible in description',
        (tester) async {
      final data = _makeOcrData(items: []);
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      // When description is empty the hint text is visible
      expect(find.text('作業内容の詳細'), findsOneWidget);
    });

    testWidgets('24. multiple items → description joined by 、', (tester) async {
      final data = _makeOcrData(
        items: [
          InvoiceItem(name: 'A部品'),
          InvoiceItem(name: 'B部品'),
          InvoiceItem(name: 'C部品'),
        ],
      );
      await tester.pumpWidget(_buildScreen(data));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'A部品、B部品、C部品'), findsOneWidget);
    });
  });
}
