import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/license_plate_detection_service.dart';

void main() {
  group('LicensePlateDetectionService.findPlateRegions', () {
    const service = LicensePlateDetectionService();

    RecognizedTextLine line(
      String text, {
      int left = 100,
      int top = 200,
      int width = 120,
      int height = 40,
    }) =>
        RecognizedTextLine(
          text: text,
          left: left,
          top: top,
          width: width,
          height: height,
        );

    test('正常系: 1行に収まったナンバー全体を検出する', () {
      final regions = service.findPlateRegions([line('品川 300 あ 12-34')]);
      expect(regions, hasLength(1));
    });

    test('正常系: 地名+分類番号の行を検出する', () {
      final regions = service.findPlateRegions([line('横浜 500')]);
      expect(regions, hasLength(1));
    });

    test('正常系: かな+一連番号の行を検出する', () {
      final regions = service.findPlateRegions([line('さ 12-34')]);
      expect(regions, hasLength(1));
    });

    test('正常系: 一連指定番号（下段の大きな数字）を検出する', () {
      final regions = service.findPlateRegions([line('12-34')]);
      expect(regions, hasLength(1));
    });

    test('正常系: 複数のナンバー行をすべて検出する', () {
      final regions = service.findPlateRegions([
        line('品川 300 あ', top: 200),
        line('12-34', top: 240),
      ]);
      expect(regions, hasLength(2));
    });

    test('検出領域は元のボックスより大きい（マージンが付く）', () {
      final regions = service.findPlateRegions([
        line('12-34', left: 100, top: 200, width: 120, height: 40),
      ]);
      expect(regions, hasLength(1));
      final r = regions.first;
      // Margin expands width/height and shifts the origin towards 0.
      expect(r.width, greaterThan(120));
      expect(r.height, greaterThan(40));
      expect(r.left, lessThan(100));
      expect(r.top, lessThan(200));
    });

    group('Edge Cases', () {
      test('空リストは空の結果を返す', () {
        expect(service.findPlateRegions([]), isEmpty);
      });

      test('プレートに見えない一般的なテキストは検出しない', () {
        final regions = service.findPlateRegions([
          line('ガソリンスタンド'),
          line('TOYOTA'),
          line('こんにちは'),
        ]);
        expect(regions, isEmpty);
      });

      test('住所のような長い行はプレート断片を含んでも除外する', () {
        final regions = service.findPlateRegions([line('東京都品川区北品川5丁目300番地')]);
        expect(regions, isEmpty);
      });

      test('幅または高さが0以下の行は無視する', () {
        final regions = service.findPlateRegions([
          line('12-34', width: 0),
          line('品川 300', height: -5),
        ]);
        expect(regions, isEmpty);
      });

      test('空文字・空白のみの行は無視する', () {
        final regions = service.findPlateRegions([line(''), line('   ')]);
        expect(regions, isEmpty);
      });

      test('マージンを付けても left/top は負にならない', () {
        final regions = service.findPlateRegions([
          line('12-34', left: 1, top: 1, width: 120, height: 40),
        ]);
        expect(regions, hasLength(1));
        expect(regions.first.left, greaterThanOrEqualTo(0));
        expect(regions.first.top, greaterThanOrEqualTo(0));
      });
    });
  });
}
