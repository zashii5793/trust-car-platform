// 直した画面の見え方を、画像にして残す。
//
// 更新: flutter test --update-goldens test/golden/ux_golden_test.dart
// 画像: test/golden/goldens/ux_*.png
//
// **数値の検査（layout_overflow_test.dart）だけでは、見え方は分からない。**
// はみ出していなくても、詰まっている・沈んでいる・間延びしている、は起きる。
// 目で見るためのものを、直したその日に残しておく。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/theme/app_theme.dart';
import 'package:trust_car_platform/widgets/common/loading_indicator.dart';

import 'font_loader.dart';

void main() {
  // **フォントを読まないと、文字もアイコンも豆腐で写る。**
  // これらは目で見るための画像なので、実際に読める状態で撮る。
  setUpAll(() async {
    await loadMaterialIcons();
    final ok = await loadJapaneseFont();
    if (!ok) {
      // ignore: avoid_print
      print('[注意] 日本語フォントが見つかりません。文字は □ で写ります。');
    }
  });
  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget child, {
    Size size = const Size(390, 844),
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  Widget chipRow({required bool fixedHeight}) {
    const labels = [
      'すべて',
      'エアロパーツ',
      'ホイール',
      'タイヤ',
      'サスペンション',
      'マフラー・排気系',
    ];
    final chips = labels
        .map((l) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: ChoiceChip(
                label: Text(l),
                selected: l == 'すべて',
                onSelected: (_) {},
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 12),
              ),
            ))
        .toList();

    // 直した形（内容で高さが決まる）と、壊れていた形（固定 42）を並べる。
    final row = fixedHeight
        ? SizedBox(
            height: 42,
            child: ListView(scrollDirection: Axis.horizontal, children: chips),
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chips),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(fixedHeight ? '直す前（固定 42）' : '直したあと（内容で決まる）'),
        ),
        ColoredBox(color: const Color(0xFFF3F3F3), child: row),
      ],
    );
  }

  group('見え方 — チップ行', () {
    testWidgets('直す前（潰れている）', (t) async {
      await shoot(t, 'ux_chips_before', chipRow(fixedHeight: true));
    });
    testWidgets('直したあと', (t) async {
      await shoot(t, 'ux_chips_after', chipRow(fixedHeight: false));
    });
    testWidgets('直したあと（ダーク）', (t) async {
      await shoot(t, 'ux_chips_after_dark', chipRow(fixedHeight: false),
          theme: AppTheme.darkTheme);
    });
  });

  group('見え方 — 空表示', () {
    testWidgets('ドライブタブ（次の一手つき）', (t) async {
      await shoot(
        t,
        'ux_empty_drive',
        const AppEmptyState(
          icon: Icons.directions_car_outlined,
          title: 'ドライブログがありません',
          description: 'ドライブログを記録してみましょう',
          buttonLabel: 'ドライブログを記録',
          onButtonPressed: _noop,
        ),
      );
    });

    testWidgets('工場一覧（いちばん長いボタン文言）', (t) async {
      await shoot(
        t,
        'ux_empty_shops',
        const AppEmptyState(
          icon: Icons.store_outlined,
          title: '整備工場・業者が見つかりません',
          description: '絞り込みを外すと、登録されている工場がすべて表示されます',
          buttonLabel: '条件をクリアして再読み込み',
          onButtonPressed: _noop,
        ),
      );
    });

    testWidgets('工場一覧（320 幅・小型端末）', (t) async {
      await shoot(
        t,
        'ux_empty_shops_320',
        const AppEmptyState(
          icon: Icons.store_outlined,
          title: '整備工場・業者が見つかりません',
          description: '絞り込みを外すと、登録されている工場がすべて表示されます',
          buttonLabel: '条件をクリアして再読み込み',
          onButtonPressed: _noop,
        ),
        size: const Size(320, 568),
      );
    });

    testWidgets('ドライブログ一覧（2行の説明）', (t) async {
      await shoot(
        t,
        'ux_empty_drive_list',
        const AppEmptyState(
          icon: Icons.directions_car_outlined,
          title: 'ドライブログがありません',
          description: '「記録開始」でGPS記録を始めるか、\n走った分を手で入力できます',
          buttonLabel: '手動で記録する',
          onButtonPressed: _noop,
        ),
      );
    });

    testWidgets('タブレット幅（間延びしないか）', (t) async {
      await shoot(
        t,
        'ux_empty_shops_tablet',
        const AppEmptyState(
          icon: Icons.store_outlined,
          title: '整備工場・業者が見つかりません',
          description: '絞り込みを外すと、登録されている工場がすべて表示されます',
          buttonLabel: '条件をクリアして再読み込み',
          onButtonPressed: _noop,
        ),
        size: const Size(768, 1024),
      );
    });

    testWidgets('ダークテーマ', (t) async {
      await shoot(
        t,
        'ux_empty_drive_dark',
        const AppEmptyState(
          icon: Icons.directions_car_outlined,
          title: 'ドライブログがありません',
          description: 'ドライブログを記録してみましょう',
          buttonLabel: 'ドライブログを記録',
          onButtonPressed: _noop,
        ),
        theme: AppTheme.darkTheme,
      );
    });
  });
}

void _noop() {}
