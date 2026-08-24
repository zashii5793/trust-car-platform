import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/constants/app_info.dart';

/// ビルドの識別子まわり。
///
/// テスト配布では、同じ `1.0.0` のまま APK と Web を何度も出し直す。
/// 「不具合が直っていない」と言われたときに、その人が**どのビルドを触って
/// いるのか**が分からないと確かめようがない。バージョンだけでは足りず、
/// ビルドごとに変わる識別子が要る。
///
/// 識別子はビルド時に `--dart-define=APP_BUILD_ID=<コミットの短縮SHA>` で
/// 渡す。渡されなかったとき（手元の `flutter run` や CI のテスト）は空になり、
/// 表示はバージョンだけに落ちる。**無くても壊れない**ことを含めて確かめる。
void main() {
  group('AppInfo', () {
    group('formatVersion', () {
      test('ビルド識別子が無ければバージョンだけを返す', () {
        expect(AppInfo.formatVersion('1.0.0', ''), '1.0.0');
      });

      test('ビルド識別子があれば括弧で添える', () {
        expect(AppInfo.formatVersion('1.0.0', 'a1b2c3d'), '1.0.0 (a1b2c3d)');
      });

      test('前後の空白は落とす', () {
        expect(AppInfo.formatVersion('1.0.0', '  a1b2c3d '), '1.0.0 (a1b2c3d)');
      });

      group('Edge Cases', () {
        test('空白だけの識別子は無いものとして扱う', () {
          expect(AppInfo.formatVersion('1.0.0', '   '), '1.0.0');
        });

        test('長すぎる識別子は切り詰める（画面の1行に収めるため）', () {
          final long = 'x' * 100;
          final result = AppInfo.formatVersion('1.0.0', long);

          expect(result.length, lessThanOrEqualTo('1.0.0'.length + 3 + 40));
          expect(result, startsWith('1.0.0 ('));
          expect(result, endsWith(')'));
        });

        test('バージョンが空でも識別子は落とさない', () {
          expect(AppInfo.formatVersion('', 'a1b2c3d'), '(a1b2c3d)');
        });

        test('改行を含む識別子でも1行に収める', () {
          expect(AppInfo.formatVersion('1.0.0', 'a1b\nc3d'), '1.0.0 (a1b c3d)');
        });
      });
    });

    group('fullVersion', () {
      test('--dart-define 無しでは version と一致する', () {
        // CI のテストは dart-define を渡さない。ここが version と食い違うなら
        // 既定値の扱いが壊れている。
        expect(AppInfo.buildId, isEmpty);
        expect(AppInfo.fullVersion, AppInfo.version);
      });

      test('空にはならない', () {
        expect(AppInfo.fullVersion, isNotEmpty);
      });
    });

    group('platform', () {
      test('テスト環境でも空にならない', () {
        expect(AppInfo.platform, isNotEmpty);
      });
    });
  });
}
