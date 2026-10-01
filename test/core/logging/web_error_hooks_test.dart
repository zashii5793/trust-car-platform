// ウェブ版で FlutterError.onError / PlatformDispatcher.onError を差し替える。
//
// 差し替えても、元のハンドラ（コンソールへの出力）は今までどおり呼ぶ。
// 送り先がまだ用意できていない（起動の途中）ときは、何もしないで通す。

import 'dart:ui';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/logging/web_error_hooks.dart';
import 'package:trust_car_platform/core/logging/web_error_reporter.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late WebErrorReporter reporter;
  late FlutterExceptionHandler? savedFlutterHandler;
  late ErrorCallback? savedPlatformHandler;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    reporter = WebErrorReporter(
      firestore: firestore,
      buildId: 'test',
      currentUrl: () => Uri.parse('https://x.example/'),
      userAgent: () => null,
      currentUid: () => null,
    );
    savedFlutterHandler = FlutterError.onError;
    savedPlatformHandler = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = savedFlutterHandler;
    PlatformDispatcher.instance.onError = savedPlatformHandler;
  });

  Future<int> storedCount() async =>
      (await firestore.collection('client_errors').get()).docs.length;

  group('installWebErrorHooks', () {
    test('FlutterError は元のハンドラにも送り先にも渡る', () async {
      final seen = <FlutterErrorDetails>[];
      FlutterError.onError = seen.add;

      installWebErrorHooks(() => reporter);
      final details = FlutterErrorDetails(exception: StateError('x'));
      FlutterError.onError!(details);
      FlutterError.onError = savedFlutterHandler;
      await pumpEventQueue();

      expect(seen, [details]);
      expect(await storedCount(), 1);
    });

    test('PlatformDispatcher.onError は送って true を返す', () async {
      installWebErrorHooks(() => reporter);
      final handled = PlatformDispatcher.instance.onError!(
        'async',
        StackTrace.empty,
      );
      PlatformDispatcher.instance.onError = savedPlatformHandler;
      await pumpEventQueue();

      expect(handled, isTrue);
      expect(await storedCount(), 1);
    });
  });

  group('Edge Cases', () {
    test('送り先が未登録（null）でも例外を投げない', () {
      FlutterError.onError = (_) {};
      installWebErrorHooks(() => null);

      expect(
        () => FlutterError.onError!(FlutterErrorDetails(exception: 'x')),
        returnsNormally,
      );
      expect(
        PlatformDispatcher.instance.onError!('x', StackTrace.empty),
        isTrue,
      );
      FlutterError.onError = savedFlutterHandler;
      PlatformDispatcher.instance.onError = savedPlatformHandler;
    });

    test('送り先の取得そのものが例外を投げても通す', () {
      FlutterError.onError = (_) {};
      installWebErrorHooks(() => throw StateError('locator broken'));

      expect(
        () => FlutterError.onError!(FlutterErrorDetails(exception: 'x')),
        returnsNormally,
      );
      FlutterError.onError = savedFlutterHandler;
    });

    test('元のハンドラが null でも動く', () async {
      FlutterError.onError = null;
      installWebErrorHooks(() => reporter);
      FlutterError.onError!(FlutterErrorDetails(exception: 'x'));
      FlutterError.onError = savedFlutterHandler;
      await pumpEventQueue();

      expect(await storedCount(), 1);
    });

    test('reportZoneError は送り先に zone として渡す', () async {
      reportZoneError(() => reporter, 'zone', StackTrace.empty);
      await pumpEventQueue();

      final doc = (await firestore.collection('client_errors').get()).docs;
      expect(doc.single.data()['source'], 'zone');
    });

    test('reportZoneError も送り先が無ければ何もしない', () {
      expect(
        () => reportZoneError(() => null, 'zone', StackTrace.empty),
        returnsNormally,
      );
    });
  });
}
