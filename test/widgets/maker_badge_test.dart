import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/constants/maker_brand.dart';
import 'package:trust_car_platform/data/vehicle_master_data.dart';
import 'package:trust_car_platform/widgets/vehicle/maker_badge.dart';

/// メーカーの識別マーク。
///
/// 2026-08-25 の指摘: **メーカーのロゴが無いのでプアーに感じる。**
/// 実際、メーカー一覧は「灰色の丸に和名の1文字目」だけだった。
/// 「ト」「ホ」「日」「マ」…が灰色で並ぶ。
///
/// 実ロゴは商標なので同梱できない。代わりに、メーカーごとに決まった色と
/// 短いマークを与えて見分けられるようにする。**実ロゴの再現ではない。**
///
/// 色は「隣り合っても見分けられること」を優先して選んである。国産メーカーは
/// 赤を使う会社が多く、ブランド色をそのまま当てると赤が3つ並んで用をなさない。
void main() {
  group('MakerBrand', () {
    test('全メーカーに色とマークが定義されている', () {
      for (final maker in VehicleMasterData.makers) {
        final id = maker['id'] as String;
        final brand = MakerBrand.of(id);

        expect(brand.mark.isNotEmpty, isTrue, reason: '$id にマークが無い');
        expect(brand.mark.length, lessThanOrEqualTo(2), reason: '$id のマークが長い');
      }
    });

    test('色が重複しない（隣り合っても見分けられること）', () {
      final colors = VehicleMasterData.makers
          .map((m) => MakerBrand.of(m['id'] as String).color.toARGB32())
          .toList();

      expect(colors.length, colors.toSet().length, reason: '同じ色のメーカーがある');
    });

    test('マークが重複しない', () {
      final marks = VehicleMasterData.makers
          .map((m) => MakerBrand.of(m['id'] as String).mark)
          .toList();

      expect(marks.length, marks.toSet().length, reason: '同じマークのメーカーがある');
    });

    group('Edge Cases', () {
      test('知らないメーカーIDでも落ちない', () {
        final brand = MakerBrand.of('bmw');

        expect(brand.mark.isNotEmpty, isTrue);
      });

      test('知らないIDでも同じIDなら毎回同じ色になる', () {
        expect(MakerBrand.of('bmw').color, MakerBrand.of('bmw').color);
      });

      test('空文字でも落ちない', () {
        expect(MakerBrand.of('').mark.isNotEmpty, isTrue);
      });

      test('文字の色は背景に対して十分な明度差がある', () {
        for (final maker in VehicleMasterData.makers) {
          final brand = MakerBrand.of(maker['id'] as String);
          final bg = brand.color.computeLuminance();
          final fg = brand.onColor.computeLuminance();

          expect(
            (bg - fg).abs(),
            greaterThan(0.3),
            reason: '${maker['id']} の文字が読みにくい',
          );
        }
      });
    });
  });

  group('MakerBadge', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('マークが表示される', (tester) async {
      await tester.pumpWidget(wrap(const MakerBadge(makerId: 'toyota')));

      expect(find.text(MakerBrand.of('toyota').mark), findsOneWidget);
    });

    testWidgets('読み上げ用にメーカー名を持つ', (tester) async {
      await tester.pumpWidget(
        wrap(const MakerBadge(makerId: 'toyota', makerName: 'トヨタ')),
      );

      expect(
        find.bySemanticsLabel('トヨタ'),
        findsOneWidget,
      );
    });

    testWidgets('大きさを指定できる', (tester) async {
      await tester
          .pumpWidget(wrap(const MakerBadge(makerId: 'honda', size: 56)));

      final box = tester.getSize(find.byType(MakerBadge));
      expect(box.width, 56);
      expect(box.height, 56);
    });

    group('Edge Cases', () {
      testWidgets('知らないメーカーでも表示できる', (tester) async {
        await tester.pumpWidget(wrap(const MakerBadge(makerId: 'porsche')));

        expect(find.byType(MakerBadge), findsOneWidget);
      });

      testWidgets('メーカー名が空でも落ちない', (tester) async {
        await tester.pumpWidget(
          wrap(const MakerBadge(makerId: 'toyota', makerName: '')),
        );

        expect(find.byType(MakerBadge), findsOneWidget);
      });
    });
  });
}
