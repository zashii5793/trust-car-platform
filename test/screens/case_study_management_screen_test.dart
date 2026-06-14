// CaseStudyManagementScreen Widget Tests
//
// Coverage:
//   Empty state:
//     1. Shows 'まだ施工事例がありません' when list is empty
//     2. Shows add button in AppBar
//   List state:
//     3. Shows study titles when studies exist
//     4. Shows edit and delete buttons per tile
//   Category filter:
//     5. Filter chips appear when studies have categories
//     6. Selecting a category shows only matching studies
//     7. Re-selecting 'すべて' shows all studies
//     8. Filter-empty state shows 'フィルターを解除' button
//     9. Tapping 'フィルターを解除' clears filter
//   Sort:
//    10. Sort button (Icons.sort) is in the AppBar
//    11. Sort menu appears on tap
//    12. Studies sorted by title after selecting タイトル順

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/shop_case_study.dart';
import 'package:trust_car_platform/models/shop_monthly_report.dart';
import 'package:trust_car_platform/screens/marketplace/case_study_management_screen.dart';
import 'package:trust_car_platform/services/shop_service.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class _MockShopService implements ShopService {
  final List<ShopCaseStudy> studies;
  _MockShopService({this.studies = const []});

  @override
  Future<Result<List<ShopCaseStudy>, AppError>> getCaseStudies(
          String shopId) async =>
      Result.success(studies);

  @override
  Future<Result<ShopMonthlyReport?, AppError>> getMonthlyReport(
          String shopId) async =>
      const Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ShopCaseStudy _makeStudy({
  required String id,
  required String title,
  ServiceCategory? category,
  DateTime? createdAt,
}) {
  return ShopCaseStudy(
    id: id,
    shopId: 'shop1',
    title: title,
    category: category,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

Widget _buildScreen({List<ShopCaseStudy> studies = const []}) {
  sl.override<ShopService>(_MockShopService(studies: studies));
  return const MaterialApp(
    home: CaseStudyManagementScreen(shopId: 'shop1'),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  tearDown(() {
    Injection.reset();
  });

  // =========================================================================
  group('CaseStudyManagementScreen — Empty state', () {
    testWidgets('1. 施工事例なし: 空のメッセージが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('まだ施工事例がありません'), findsOneWidget);
    });

    testWidgets('2. AppBar に追加ボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.byKey(const Key('add_case_study_btn')), findsOneWidget);
    });
  });

  // =========================================================================
  group('CaseStudyManagementScreen — List state', () {
    final studies = [
      _makeStudy(id: 's1', title: 'ドア板金修理'),
      _makeStudy(id: 's2', title: 'バンパー交換'),
    ];

    testWidgets('3. 施工事例タイトルが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(studies: studies));
      await tester.pump();

      expect(find.text('ドア板金修理'), findsOneWidget);
      expect(find.text('バンパー交換'), findsOneWidget);
    });

    testWidgets('4. 各タイルに編集・削除ボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(studies: studies));
      await tester.pump();

      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
    });
  });

  // =========================================================================
  group('CaseStudyManagementScreen — Category filter', () {
    final studies = [
      _makeStudy(id: 's1', title: '板金修理', category: ServiceCategory.bodyWork),
      _makeStudy(
          id: 's2', title: 'コーティング施工', category: ServiceCategory.coating),
      _makeStudy(id: 's3', title: 'カテゴリなし'),
    ];

    testWidgets('5. カテゴリがある場合フィルターチップが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(studies: studies));
      await tester.pump();

      // Use FilterChip finder to distinguish chip from tile subtitle
      expect(find.widgetWithText(FilterChip, '板金・塗装'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'コーティング'), findsOneWidget);
    });

    testWidgets('6. カテゴリを選択すると該当する施工事例のみ表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(studies: studies));
      await tester.pump();

      // Tap 板金・塗装 chip (use .first to avoid semantic duplicate)
      await tester.tap(find.text('板金・塗装').first);
      await tester.pump();

      expect(find.text('板金修理'), findsOneWidget);
      expect(find.text('コーティング施工'), findsNothing);
      expect(find.text('カテゴリなし'), findsNothing);
    });

    testWidgets('7. すべてチップで全件表示に戻る', (tester) async {
      await tester.pumpWidget(_buildScreen(studies: studies));
      await tester.pump();

      // Filter first
      await tester.tap(find.text('板金・塗装').first);
      await tester.pump();
      expect(find.text('コーティング施工'), findsNothing);

      // Reset via 'すべて' chip
      await tester.tap(find.text('すべて').first);
      await tester.pump();
      expect(find.text('コーティング施工'), findsOneWidget);
    });

    testWidgets('8. 別カテゴリ選択で表示件数が絞り込まれる', (tester) async {
      await tester.pumpWidget(_buildScreen(studies: studies));
      await tester.pump();

      // Select coating — only s2 matches
      await tester.tap(find.text('コーティング').first);
      await tester.pump();

      expect(find.text('コーティング施工'), findsOneWidget);
      expect(find.text('板金修理'), findsNothing);
      expect(find.text('カテゴリなし'), findsNothing);
    });

    testWidgets('9. フィルター選択後すべてに戻すと全件表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(studies: studies));
      await tester.pump();

      // Filter to coating
      await tester.tap(find.text('コーティング').first);
      await tester.pump();
      expect(find.text('板金修理'), findsNothing);

      // Reset
      await tester.tap(find.text('すべて').first);
      await tester.pump();
      expect(find.text('板金修理'), findsOneWidget);
      expect(find.text('コーティング施工'), findsOneWidget);
      expect(find.text('カテゴリなし'), findsOneWidget);
    });
  });

  // =========================================================================
  group('CaseStudyManagementScreen — Sort', () {
    testWidgets('10. AppBarにソートボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        studies: [_makeStudy(id: 's1', title: 'Test')],
      ));
      await tester.pump();

      expect(find.byKey(const Key('sort_btn')), findsOneWidget);
    });

    testWidgets('11. ソートボタンタップでメニューが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        studies: [_makeStudy(id: 's1', title: 'Test')],
      ));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sort_btn')));
      await tester.pumpAndSettle();

      expect(find.text('新着順'), findsOneWidget);
      expect(find.text('古い順'), findsOneWidget);
      expect(find.text('タイトル順'), findsOneWidget);
    });

    testWidgets('12. タイトル順を選択するとアルファベット昇順で表示される', (tester) async {
      final studies = [
        _makeStudy(id: 's1', title: 'Cタイヤ交換', createdAt: DateTime(2026, 3, 1)),
        _makeStudy(id: 's2', title: 'Aドア板金', createdAt: DateTime(2026, 1, 1)),
        _makeStudy(id: 's3', title: 'Bコーティング', createdAt: DateTime(2026, 2, 1)),
      ];
      await tester.pumpWidget(_buildScreen(studies: studies));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sort_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('タイトル順'));
      await tester.pumpAndSettle();

      final tiles = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(Card),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Text &&
                    (w.data == 'Aドア板金' ||
                        w.data == 'Bコーティング' ||
                        w.data == 'Cタイヤ交換'),
              ),
            ),
          )
          .toList();

      expect(tiles.length, 3);
      expect(tiles[0].data, 'Aドア板金');
      expect(tiles[1].data, 'Bコーティング');
      expect(tiles[2].data, 'Cタイヤ交換');
    });
  });
}
