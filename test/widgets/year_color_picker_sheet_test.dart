// YearPickerSheet / ColorPickerSheet widget tests
//
// Year sheet (showYearPickerSheet):
//   - formatYearWithWareki: 和暦併記のフォーマット（令和・平成・昭和・境界値）
//   - シートが開き「年式を選択」タイトルと 今年+1 が先頭に表示される
//   - 年をタップすると閉じて選択した年が返る
//   - selected の年にチェックマークが付く
//   - バリアタップで閉じると null が返る
//
// Color sheet (showColorPickerSheet):
//   - 候補チップ（kCommonVehicleColors）が表示される
//   - チップをタップすると閉じてその色が返る
//   - 自由入力 + 決定 で入力した色が返る
//   - current がテキストフィールドにプリフィルされる
//   - Edge Cases: 候補に無い current / 空入力で決定 / 空白のみ入力 /
//     バリアタップで null

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/core/constants/vehicle_colors.dart';
import 'package:trust_car_platform/widgets/vehicle/color_picker_sheet.dart';
import 'package:trust_car_platform/widgets/vehicle/year_picker_sheet.dart';

// ===========================================================================
// Host helpers — open the sheet from a button and capture the result
// ===========================================================================

class _SheetResult<T> {
  T? value;
  bool completed = false;
}

Widget _buildYearHost(_SheetResult<int> result, {int? selected}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              result.value =
                  await showYearPickerSheet(context, selected: selected);
              result.completed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Widget _buildColorHost(_SheetResult<String> result, {String? current}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              result.value =
                  await showColorPickerSheet(context, current: current);
              result.completed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  // =========================================================================
  group('formatYearWithWareki — 和暦併記フォーマット', () {
    test('令和: 2023 → 2023年（令和5年）', () {
      expect(formatYearWithWareki(2023), '2023年（令和5年）');
    });

    test('令和元年境界: 2019 → 令和1年', () {
      expect(formatYearWithWareki(2019), '2019年（令和1年）');
    });

    test('平成末境界: 2018 → 平成30年', () {
      expect(formatYearWithWareki(2018), '2018年（平成30年）');
    });

    test('平成元年境界: 1989 → 平成1年', () {
      expect(formatYearWithWareki(1989), '1989年（平成1年）');
    });

    test('昭和末境界: 1988 → 昭和63年', () {
      expect(formatYearWithWareki(1988), '1988年（昭和63年）');
    });

    test('選択下限: 1955 → 昭和30年', () {
      expect(formatYearWithWareki(1955), '1955年（昭和30年）');
    });

    group('Edge Cases', () {
      test('和暦範囲外（1925以前）は西暦のみ', () {
        expect(formatYearWithWareki(1925), '1925年');
      });

      test('未来年（今年+1）も令和で表記される', () {
        final next = DateTime.now().year + 1;
        expect(
          formatYearWithWareki(next),
          '$next年（令和${next - 2018}年）',
        );
      });
    });
  });

  // =========================================================================
  group('YearPickerSheet — 表示と選択', () {
    testWidgets('シートが開きタイトルと 今年+1（先頭）が表示される', (tester) async {
      final result = _SheetResult<int>();
      await tester.pumpWidget(_buildYearHost(result));
      await _openSheet(tester);

      expect(find.text('年式を選択'), findsOneWidget);
      // 新しい順 — 先頭は 今年+1（和暦併記）
      expect(
        find.text(formatYearWithWareki(DateTime.now().year + 1)),
        findsOneWidget,
      );
    });

    testWidgets('年をタップするとシートが閉じて選択した年が返る', (tester) async {
      final result = _SheetResult<int>();
      await tester.pumpWidget(_buildYearHost(result));
      await _openSheet(tester);

      final year = DateTime.now().year;
      await tester.tap(find.text(formatYearWithWareki(year)));
      await tester.pumpAndSettle();

      expect(result.completed, isTrue);
      expect(result.value, year);
      expect(find.text('年式を選択'), findsNothing);
    });

    testWidgets('selected の年にチェックマークが付く', (tester) async {
      final year = DateTime.now().year;
      final result = _SheetResult<int>();
      await tester.pumpWidget(_buildYearHost(result, selected: year));
      await _openSheet(tester);

      final selectedTile = find.widgetWithText(
        ListTile,
        formatYearWithWareki(year),
      );
      expect(
        find.descendant(
          of: selectedTile,
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      // 他の年（今年+1）にはチェックが無い
      final otherTile = find.widgetWithText(
        ListTile,
        formatYearWithWareki(year + 1),
      );
      expect(
        find.descendant(of: otherTile, matching: find.byIcon(Icons.check)),
        findsNothing,
      );
    });

    group('Edge Cases', () {
      testWidgets('バリアタップで閉じると null が返る', (tester) async {
        final result = _SheetResult<int>();
        await tester.pumpWidget(_buildYearHost(result));
        await _openSheet(tester);

        // シート外（画面上部）をタップして閉じる
        await tester.tapAt(const Offset(400, 20));
        await tester.pumpAndSettle();

        expect(result.completed, isTrue);
        expect(result.value, isNull);
      });

      testWidgets('selected が候補範囲外（1900）でもクラッシュしない', (tester) async {
        final result = _SheetResult<int>();
        await tester.pumpWidget(_buildYearHost(result, selected: 1900));
        await _openSheet(tester);

        expect(find.text('年式を選択'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });

  // =========================================================================
  group('ColorPickerSheet — 候補チップと自由入力', () {
    testWidgets('シートが開き候補チップが表示される', (tester) async {
      final result = _SheetResult<String>();
      await tester.pumpWidget(_buildColorHost(result));
      await _openSheet(tester);

      expect(find.text('車体色を選択'), findsOneWidget);
      // 先頭候補と自由入力欄の両方が見える
      expect(find.text(kCommonVehicleColors.first), findsOneWidget);
      expect(find.text('一覧に無い色を入力'), findsOneWidget);
    });

    testWidgets('チップをタップするとシートが閉じてその色が返る', (tester) async {
      final result = _SheetResult<String>();
      await tester.pumpWidget(_buildColorHost(result));
      await _openSheet(tester);

      await tester.tap(find.text('パールホワイト'));
      await tester.pumpAndSettle();

      expect(result.completed, isTrue);
      expect(result.value, 'パールホワイト');
      expect(find.text('車体色を選択'), findsNothing);
    });

    testWidgets('自由入力 + 決定 で入力した色が返る', (tester) async {
      final result = _SheetResult<String>();
      await tester.pumpWidget(_buildColorHost(result));
      await _openSheet(tester);

      await tester.enterText(
        find.byType(TextField),
        'クリスタルホワイトパールマイカ',
      );
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(result.completed, isTrue);
      expect(result.value, 'クリスタルホワイトパールマイカ');
    });

    testWidgets('current が候補にある色でもテキストフィールドにプリフィルされる', (tester) async {
      final result = _SheetResult<String>();
      await tester.pumpWidget(_buildColorHost(result, current: 'ブラック'));
      await _openSheet(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'ブラック');
    });

    group('Edge Cases', () {
      testWidgets('候補に無い current（マルーン）がプリフィルされ 決定 でそのまま返る', (tester) async {
        final result = _SheetResult<String>();
        await tester.pumpWidget(_buildColorHost(result, current: 'マルーン'));
        await _openSheet(tester);

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller?.text, 'マルーン');

        await tester.tap(find.text('決定'));
        await tester.pumpAndSettle();

        expect(result.completed, isTrue);
        expect(result.value, 'マルーン');
      });

      testWidgets('空入力で決定を押してもシートは閉じない', (tester) async {
        final result = _SheetResult<String>();
        await tester.pumpWidget(_buildColorHost(result));
        await _openSheet(tester);

        await tester.tap(find.text('決定'));
        await tester.pumpAndSettle();

        // 何も起きない — シートは開いたまま、結果も未確定
        expect(find.text('車体色を選択'), findsOneWidget);
        expect(result.completed, isFalse);
      });

      testWidgets('空白のみの入力で決定を押してもシートは閉じない（trim）', (tester) async {
        final result = _SheetResult<String>();
        await tester.pumpWidget(_buildColorHost(result));
        await _openSheet(tester);

        await tester.enterText(find.byType(TextField), '   ');
        await tester.tap(find.text('決定'));
        await tester.pumpAndSettle();

        expect(find.text('車体色を選択'), findsOneWidget);
        expect(result.completed, isFalse);
      });

      testWidgets('入力の前後空白は trim されて返る', (tester) async {
        final result = _SheetResult<String>();
        await tester.pumpWidget(_buildColorHost(result));
        await _openSheet(tester);

        await tester.enterText(find.byType(TextField), '  マルーン  ');
        await tester.tap(find.text('決定'));
        await tester.pumpAndSettle();

        expect(result.value, 'マルーン');
      });

      testWidgets('バリアタップで閉じると null が返る', (tester) async {
        final result = _SheetResult<String>();
        await tester.pumpWidget(_buildColorHost(result));
        await _openSheet(tester);

        await tester.tapAt(const Offset(400, 20));
        await tester.pumpAndSettle();

        expect(result.completed, isTrue);
        expect(result.value, isNull);
      });
    });
  });
}
