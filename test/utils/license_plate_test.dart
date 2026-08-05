import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/utils/license_plate.dart';

void main() {
  group('normalizeLicensePlate', () {
    test('全角数字を半角に変換する', () {
      expect(normalizeLicensePlate('品川 ３００ あ １２－３４'), '品川 300 あ 12-34');
    });

    test('全角スペースを半角スペースに変換する', () {
      expect(normalizeLicensePlate('品川　300　あ　12-34'), '品川 300 あ 12-34');
    });

    test('全角ハイフンを半角に変換する', () {
      expect(normalizeLicensePlate('品川 300 あ 12－34'), '品川 300 あ 12-34');
    });

    test('連続する空白を1つにまとめ前後を除去する', () {
      expect(normalizeLicensePlate('  品川   300   あ   12-34  '), '品川 300 あ 12-34');
    });

    test('地名のかな・漢字は変換しない', () {
      expect(normalizeLicensePlate('横浜 500 さ 88-88'), '横浜 500 さ 88-88');
    });

    test('全角英字を半角に変換する', () {
      expect(normalizeLicensePlate('ＡＢＣ'), 'ABC');
    });

    group('Edge Cases', () {
      test('空文字はそのまま空文字', () {
        expect(normalizeLicensePlate(''), '');
      });

      test('空白のみは空文字になる', () {
        expect(normalizeLicensePlate('　  　'), '');
      });

      test('既に正規化済みの値は変わらない（冪等）', () {
        const plate = '品川 300 あ 12-34';
        expect(normalizeLicensePlate(plate), plate);
        expect(normalizeLicensePlate(normalizeLicensePlate(plate)), plate);
      });

      test('各種ダッシュはすべて半角ハイフンに寄せる', () {
        for (final dash in ['‐', '–', '—', '―', '−', '－', 'ー']) {
          expect(normalizeLicensePlate('12${dash}34'), '12-34',
              reason: 'dash=$dash');
        }
      });
    });
  });

  group('licensePlateKey', () {
    test('空白の有無を無視して同じキーになる', () {
      expect(licensePlateKey('品川 300 あ 12-34'), licensePlateKey('品川300あ12-34'));
    });

    // これが本来の目的。同じ車が二重登録されていた原因。
    test('全角入力と半角入力が同一車両と判定される', () {
      expect(
        licensePlateKey('品川　３００　あ　１２－３４'),
        licensePlateKey('品川 300 あ 12-34'),
      );
    });

    test('別の車両は別のキーになる', () {
      expect(
        licensePlateKey('品川 300 あ 12-34') == licensePlateKey('品川 300 あ 12-35'),
        isFalse,
      );
    });

    group('Edge Cases', () {
      test('空文字は空キー', () {
        expect(licensePlateKey(''), '');
        expect(licensePlateKey('　 '), '');
      });

      test('地名違いは別キー', () {
        expect(
          licensePlateKey('品川 300 あ 12-34') ==
              licensePlateKey('横浜 300 あ 12-34'),
          isFalse,
        );
      });
    });
  });
}
