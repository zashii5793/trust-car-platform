// Breakpoints unit tests
//
// Strategy: 判定ロジックは BuildContext 非依存の純粋関数なので、
// 幅の数値を直接渡して境界値を検証する。

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/constants/breakpoints.dart';

void main() {
  group('Breakpoints.sizeForWidth', () {
    test('mobile widths return DeviceSize.mobile', () {
      expect(Breakpoints.sizeForWidth(320), DeviceSize.mobile);
      expect(Breakpoints.sizeForWidth(599.99), DeviceSize.mobile);
    });

    test('tablet widths return DeviceSize.tablet', () {
      expect(Breakpoints.sizeForWidth(600), DeviceSize.tablet);
      expect(Breakpoints.sizeForWidth(900), DeviceSize.tablet);
      expect(Breakpoints.sizeForWidth(1199.99), DeviceSize.tablet);
    });

    test('desktop widths return DeviceSize.desktop', () {
      expect(Breakpoints.sizeForWidth(1200), DeviceSize.desktop);
      expect(Breakpoints.sizeForWidth(1920), DeviceSize.desktop);
    });

    group('Edge Cases', () {
      test('exact tablet boundary (600) is tablet, not mobile', () {
        expect(Breakpoints.sizeForWidth(Breakpoints.tablet), DeviceSize.tablet);
      });

      test('exact desktop boundary (1200) is desktop, not tablet', () {
        expect(
          Breakpoints.sizeForWidth(Breakpoints.desktop),
          DeviceSize.desktop,
        );
      });

      test('zero width is mobile', () {
        expect(Breakpoints.sizeForWidth(0), DeviceSize.mobile);
      });

      test('negative width is treated as mobile (defensive)', () {
        expect(Breakpoints.sizeForWidth(-100), DeviceSize.mobile);
      });

      test('very large width is desktop', () {
        expect(Breakpoints.sizeForWidth(100000), DeviceSize.desktop);
      });
    });
  });

  group('Breakpoints.useWideLayout', () {
    test('false below the wide-layout breakpoint (840)', () {
      expect(Breakpoints.useWideLayout(599.99), isFalse);
      // 800 は Flutter テストのデフォルト幅。compact 扱いを保証する。
      expect(Breakpoints.useWideLayout(800), isFalse);
      expect(Breakpoints.useWideLayout(839.99), isFalse);
    });

    test('true at and above the wide-layout breakpoint (840)', () {
      expect(Breakpoints.useWideLayout(Breakpoints.wideLayout), isTrue);
      expect(Breakpoints.useWideLayout(1000), isTrue);
      expect(Breakpoints.useWideLayout(1920), isTrue);
    });
  });

  group('Breakpoints.useExtendedRail', () {
    test('false below desktop breakpoint', () {
      expect(Breakpoints.useExtendedRail(1199.99), isFalse);
      expect(Breakpoints.useExtendedRail(840), isFalse);
    });

    test('true at and above desktop breakpoint', () {
      expect(Breakpoints.useExtendedRail(1200), isTrue);
      expect(Breakpoints.useExtendedRail(2560), isTrue);
    });
  });
}
