// ウェブ版の不具合を client_errors に送る。
//
// 大事なのは「送れること」より「暴れないこと」。
// - 1回の起動で送る数に上限がある
// - 同じメッセージは1回だけ
// - 送信の失敗で例外を投げない（投げると onError に戻って無限に回る）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/logging/web_error_reporter.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late WebErrorReporter reporter;
  String? uid;

  WebErrorReporter create({
    FirebaseFirestore? store,
    int maxReportsPerSession = 10,
    String? Function()? currentUid,
    String? Function()? userAgent,
  }) {
    return WebErrorReporter(
      firestore: store ?? firestore,
      buildId: 'a1b2c3d',
      currentUrl: () => Uri.parse('https://trust-car-platform.web.app/'),
      userAgent: userAgent ?? () => 'Mozilla/5.0',
      currentUid: currentUid ?? () => uid,
      maxReportsPerSession: maxReportsPerSession,
    );
  }

  Future<List<Map<String, dynamic>>> stored() async {
    final snap = await firestore.collection('client_errors').get();
    return snap.docs.map((d) => d.data()).toList();
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    // 送れるのはログイン中だけ（2026-10-01）。既定はログイン中にしておく
    uid = 'user1';
    reporter = create();
  });

  group('WebErrorReporter.report', () {
    test('1件送ると client_errors に1件入る', () async {
      final result = await reporter.report(
        StateError('壊れた'),
        StackTrace.fromString('#0 main'),
      );

      expect(result.valueOrNull, isTrue);
      final docs = await stored();
      expect(docs, hasLength(1));
      expect(docs.single['message'], 'Bad state: 壊れた');
      expect(docs.single['stack'], '#0 main');
      expect(docs.single['buildId'], 'a1b2c3d');
      expect(docs.single['path'], '/');
      expect(docs.single['userAgent'], 'Mozilla/5.0');
      expect(docs.single['platform'], 'web');
      expect(docs.single['source'], 'flutter');
    });

    test('ログイン中なら uid が入る', () async {
      uid = 'user1';
      await reporter.report('boom', null);
      expect((await stored()).single['uid'], 'user1');
    });

    // 2026-10-01 オーナー判断: ログイン必須（ルールも同じ）。送っても弾かれるだけなので、
    // 送らず、1回の起動の上限（10件）にも数えない
    test('未ログインなら送らず、上限にも数えない', () async {
      uid = null;
      final result = await reporter.report('boom', null);
      expect(result.valueOrNull, isFalse);
      expect(await stored(), isEmpty);
      expect(reporter.attemptCount, 0);

      uid = 'user1';
      expect((await reporter.report('boom', null)).valueOrNull, isTrue);
    });

    test('発生源を指定できる', () async {
      await reporter.report('boom', null, source: 'zone');
      expect((await stored()).single['source'], 'zone');
    });
  });

  group('洪水を防ぐ', () {
    test('同じメッセージは1回だけ送る', () async {
      await reporter.report('same', null);
      final second = await reporter.report('same', null);

      expect(second.valueOrNull, isFalse);
      expect(await stored(), hasLength(1));
    });

    test('1回の起動で送るのは上限まで', () async {
      reporter = create(maxReportsPerSession: 3);
      for (var i = 0; i < 10; i++) {
        await reporter.report('error $i', null);
      }
      expect(await stored(), hasLength(3));
      expect(reporter.sentCount, 3);
    });

    test('既定の上限は10件', () async {
      for (var i = 0; i < 15; i++) {
        await reporter.report('error $i', null);
      }
      expect(await stored(), hasLength(10));
    });

    test('上限に達したあとは false を返す', () async {
      reporter = create(maxReportsPerSession: 1);
      await reporter.report('a', null);
      final result = await reporter.report('b', null);
      expect(result.valueOrNull, isFalse);
    });
  });

  group('送信の失敗で例外を投げない', () {
    test('Firestore が例外を投げても failure を返すだけ', () async {
      reporter = create(store: _ThrowingFirestore());

      final result = await reporter.report('boom', null);

      expect(result.isFailure, isTrue);
    });

    test('失敗した分も上限に数える（失敗を繰り返して回り続けない）', () async {
      reporter = create(store: _ThrowingFirestore(), maxReportsPerSession: 2);
      for (var i = 0; i < 5; i++) {
        await reporter.report('e$i', null);
      }
      expect(reporter.attemptCount, 2);
    });

    test('uid の取得が例外を投げたら送らない（落ちない）', () async {
      reporter = create(currentUid: () => throw StateError('auth not ready'));
      final result = await reporter.report('boom', null);
      expect(result.valueOrNull, isFalse);
      expect(await stored(), isEmpty);
    });

    test('userAgent の取得が例外を投げても送れる', () async {
      reporter = create(userAgent: () => throw UnsupportedError('no nav'));
      final result = await reporter.report('boom', null);
      expect(result.valueOrNull, isTrue);
      expect((await stored()).single['userAgent'], isNull);
    });
  });

  group('onError から呼ぶ入口', () {
    test('handleFlutterError は FlutterErrorDetails を送る', () async {
      reporter.handleFlutterError(
        FlutterErrorDetails(
          exception: StateError('build failed'),
          stack: StackTrace.fromString('#0 build'),
        ),
      );
      await pumpEventQueue();

      final doc = (await stored()).single;
      expect(doc['message'], 'Bad state: build failed');
      expect(doc['source'], 'flutter');
    });

    test('handlePlatformError は true を返し、platform として送る', () async {
      final handled = reporter.handlePlatformError(
        'async boom',
        StackTrace.fromString('#0 async'),
      );
      await pumpEventQueue();

      expect(handled, isTrue);
      expect((await stored()).single['source'], 'platform');
    });

    test('handleZoneError は zone として送る', () async {
      reporter.handleZoneError('zone boom', StackTrace.fromString('#0 zone'));
      await pumpEventQueue();

      expect((await stored()).single['source'], 'zone');
    });

    test('Firestore が壊れていても入口は例外を投げない', () async {
      reporter = create(store: _ThrowingFirestore());
      expect(
        () => reporter.handleFlutterError(
          FlutterErrorDetails(exception: StateError('x')),
        ),
        returnsNormally,
      );
      expect(
        () => reporter.handlePlatformError('x', StackTrace.empty),
        returnsNormally,
      );
      await pumpEventQueue();
    });
  });

  group('Edge Cases', () {
    test('上限0なら何も送らない', () async {
      reporter = create(maxReportsPerSession: 0);
      final result = await reporter.report('boom', null);
      expect(result.valueOrNull, isFalse);
      expect(await stored(), isEmpty);
    });

    test('負の上限も0扱い', () async {
      reporter = create(maxReportsPerSession: -1);
      await reporter.report('boom', null);
      expect(await stored(), isEmpty);
    });

    test('空のエラーも1件として送る', () async {
      await reporter.report('', null);
      expect((await stored()).single['message'], '(empty)');
    });

    test('伏せたあとで同じになるメッセージは重複として扱う', () async {
      await reporter.report('not found a@b.jp', null);
      await reporter.report('not found c@d.jp', null);
      expect(await stored(), hasLength(1));
    });
  });

  group('isEnabledFor', () {
    test('ウェブのリリース版だけ有効', () {
      expect(
          WebErrorReporter.isEnabledFor(isWeb: true, isRelease: true), isTrue);
      expect(WebErrorReporter.isEnabledFor(isWeb: true, isRelease: false),
          isFalse);
      expect(WebErrorReporter.isEnabledFor(isWeb: false, isRelease: true),
          isFalse);
      expect(WebErrorReporter.isEnabledFor(isWeb: false, isRelease: false),
          isFalse);
    });
  });
}

/// どの操作も例外を投げる Firestore（送信失敗の再現用）。
class _ThrowingFirestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
  }
}
