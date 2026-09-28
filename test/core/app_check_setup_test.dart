import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/security/app_check_setup.dart';

void main() {
  AppCheckMode decide({
    bool isWeb = false,
    bool isDebug = false,
    bool useEmulator = false,
    String key = '',
  }) =>
      decideAppCheckMode(
        isWeb: isWeb,
        isDebug: isDebug,
        useEmulator: useEmulator,
        webSiteKey: key,
      );

  test('スマートフォンの本番ビルドは本番用', () {
    expect(decide(), AppCheckMode.production);
  });

  test('開発中はデバッグ用', () {
    expect(decide(isDebug: true), AppCheckMode.debug);
  });

  group('Edge Cases', () {
    test('エミュレータにつないでいるときは動かさない', () {
      expect(decide(useEmulator: true), AppCheckMode.off);
      expect(decide(useEmulator: true, isDebug: true), AppCheckMode.off);
    });

    test('Web はサイトキーが無ければ動かさない（有れば動かす）', () {
      expect(decide(isWeb: true), AppCheckMode.off);
      expect(decide(isWeb: true, key: 'abc'), AppCheckMode.production);
    });
  });
}
