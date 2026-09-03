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

  /// `Vehicle.maker` は makerId ではなく**和名**（"トヨタ"）で保存されている。
  /// 保存済み車両のカードにバッジを出すには、そこから id を引き直すしかない。
  group('MakerBrand.idFromName', () {
    test('マスタの全メーカーが和名から引ける', () {
      for (final maker in VehicleMasterData.makers) {
        final id = maker['id'] as String;
        final name = maker['name'] as String;

        expect(MakerBrand.idFromName(name), id, reason: '$name を引けない');
      }
    });

    test('マスタの全メーカーが英名から引ける', () {
      for (final maker in VehicleMasterData.makers) {
        final id = maker['id'] as String;
        final nameEn = maker['nameEn'] as String;

        expect(MakerBrand.idFromName(nameEn), id, reason: '$nameEn を引けない');
      }
    });

    test('英名の大文字小文字と前後の空白は無視する', () {
      expect(MakerBrand.idFromName('  TOYOTA '), 'toyota');
      expect(MakerBrand.idFromName('nissan'), 'nissan');
    });

    test('makerId をそのまま渡しても通る', () {
      expect(MakerBrand.idFromName('toyota'), 'toyota');
    });

    group('Edge Cases', () {
      /// 自由入力メーカーは名前しか無い。id が引けなくても
      /// **バッジは必ず出す**（ここで落ちるとカードごと壊れる）。
      test('知らないメーカー名は名前をそのまま返す', () {
        expect(MakerBrand.idFromName('ポルシェ'), 'ポルシェ');
      });

      test('知らないメーカー名でも同じ名前なら毎回同じ色になる', () {
        final a = MakerBrand.of(MakerBrand.idFromName('ポルシェ'));
        final b = MakerBrand.of(MakerBrand.idFromName('ポルシェ'));

        expect(a.color, b.color);
      });

      test('空文字でも落ちない', () {
        expect(
            MakerBrand.of(MakerBrand.idFromName('')).mark.isNotEmpty, isTrue);
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

    /// 自由入力のメーカーは id が `custom_<タイムスタンプ>` になる。
    /// id をそのまま使うと登録のたびに色が変わり、マークは全部「C」になる。
    testWidgets('カタログに無いidでも名前が分かれば名前で色を決める', (tester) async {
      await tester.pumpWidget(
        wrap(
          const Column(
            children: [
              MakerBadge(makerId: 'custom_1000', makerName: 'ポルシェ'),
              MakerBadge(makerId: 'custom_2000', makerName: 'ポルシェ'),
            ],
          ),
        ),
      );

      final marks = tester
          .widgetList<Text>(find.descendant(
            of: find.byType(MakerBadge),
            matching: find.byType(Text),
          ))
          .map((t) => t.data)
          .toList();

      expect(marks.first, isNot('C'));
      expect(marks.first, marks.last, reason: 'id が違っても同じメーカーなら同じマーク');
    });

    /// 名前が既知メーカーなら、自由入力でも正規のマークに寄せる。
    testWidgets('自由入力でも名前がカタログにあれば正規のマークになる', (tester) async {
      await tester.pumpWidget(
        wrap(const MakerBadge(makerId: 'custom_1000', makerName: 'トヨタ')),
      );

      expect(find.text(MakerBrand.of('toyota').mark), findsOneWidget);
    });

    /// 保存済み車両は makerId を持たず和名しか無い。
    testWidgets('メーカー名からでも組み立てられる', (tester) async {
      await tester.pumpWidget(wrap(MakerBadge.fromName('トヨタ')));

      expect(find.text(MakerBrand.of('toyota').mark), findsOneWidget);
      expect(find.bySemanticsLabel('トヨタ'), findsOneWidget);
    });

    testWidgets('カタログに無いメーカー名でも表示できる', (tester) async {
      await tester.pumpWidget(wrap(MakerBadge.fromName('ポルシェ')));

      expect(find.byType(MakerBadge), findsOneWidget);
      expect(find.bySemanticsLabel('ポルシェ'), findsOneWidget);
    });

    /// 選択中は枠を出す。枠のぶんだけ大きくなると、一覧の行が
    /// 選択のたびにガタつく。**外形は変えない。**
    testWidgets('選択しても外形の大きさが変わらない', (tester) async {
      await tester.pumpWidget(
        wrap(
          const Row(
            children: [
              MakerBadge(makerId: 'toyota', size: 40),
              MakerBadge(makerId: 'honda', size: 40, isSelected: true),
            ],
          ),
        ),
      );

      final sizes =
          tester.widgetList<MakerBadge>(find.byType(MakerBadge)).map((w) {
        return tester.getSize(find.byWidget(w));
      }).toList();

      expect(sizes[0], sizes[1]);
      expect(sizes[0], const Size(40, 40));
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
