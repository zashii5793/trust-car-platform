import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/app_scroll_behavior.dart';

void main() {
  group('AppScrollBehavior.dragDevices', () {
    const behavior = AppScrollBehavior();

    test('mouse でのドラッグスクロールを許可する（Web/デスクトップ回帰対策）', () {
      expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
    });

    test('trackpad でのドラッグスクロールを許可する', () {
      expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
    });

    test('タッチ操作は引き続き許可する（モバイル非回帰）', () {
      expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
    });
  });
}
