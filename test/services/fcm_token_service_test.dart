import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/services/fcm_token_service.dart';

/// この端末のプッシュの宛先を users/{uid}.fcmTokens に登録する。
/// 店からの車検案内（Cloud Functions）はここに送る。
void main() {
  late FakeFirebaseFirestore firestore;
  late StreamController<String> refresh;
  String? token;
  late FcmTokenService service;
  const uid = 'user-1';

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    refresh = StreamController<String>.broadcast();
    token = 'tok-a';
    service = FcmTokenService(
      firestore: firestore,
      getToken: () async => token,
      onTokenRefresh: () => refresh.stream,
      now: () => DateTime(2026, 10, 1),
    );
    await firestore.doc('users/$uid').set({'email': 'a@example.com'});
  });

  tearDown(() async {
    service.dispose();
    await refresh.close();
  });

  Future<List<dynamic>?> tokens([String id = uid]) async =>
      (await firestore.doc('users/$id').get()).data()?['fcmTokens']
          as List<dynamic>?;

  group('register', () {
    test('この端末のトークンを利用者に足す（ほかの項目は消さない）', () async {
      final r = await service.register(uid);
      expect(r.isSuccess, isTrue);
      expect(await tokens(), ['tok-a']);
      final data = (await firestore.doc('users/$uid').get()).data()!;
      expect(data['email'], 'a@example.com');
      expect(data['fcmTokenUpdatedAt'], isNotNull);
    });

    test('ほかの端末のトークンは残し、同じものは重ねない', () async {
      await firestore.doc('users/$uid').update({
        'fcmTokens': ['tok-other', 'tok-a'],
      });
      await service.register(uid);
      expect(await tokens(), ['tok-other', 'tok-a']);
    });

    test('トークンが替わったら、古いものと付け替える', () async {
      await service.register(uid);
      refresh.add('tok-b');
      await pumpEventQueue();
      expect(await tokens(), ['tok-b']);
    });

    group('Edge Cases', () {
      test('上限を超えたら古いものから落とす', () async {
        await firestore.doc('users/$uid').update({
          'fcmTokens': [
            for (var i = 0; i < FcmTokenService.maxTokens; i++) 'old$i'
          ],
        });
        await service.register(uid);
        final list = (await tokens())!;
        expect(list, hasLength(FcmTokenService.maxTokens));
        expect(list.first, 'old1');
        expect(list.last, 'tok-a');
      });

      test('トークンが取れない（通知を許可していない等）なら何も書かない', () async {
        token = null;
        final r = await service.register(uid);
        expect(r.isSuccess, isTrue);
        expect(await tokens(), isNull);
      });

      test('プロフィールがまだ無ければ作らない（中身の無い users を作らない）', () async {
        await service.register('no-profile');
        expect((await firestore.doc('users/no-profile').get()).exists, isFalse);
      });

      test('uid が空なら失敗', () async {
        expect(
            (await service.register('')).errorOrNull, isA<ValidationError>());
      });

      test('トークンの取得が例外を投げたら失敗として返す（ログインは止めない）', () async {
        final broken = FcmTokenService(
          firestore: firestore,
          getToken: () async => throw Exception('APNs token not set'),
          onTokenRefresh: () => const Stream.empty(),
        );
        final r = await broken.register(uid);
        expect(r.isFailure, isTrue);
        expect(await tokens(), isNull);
      });
    });
  });

  group('unregister', () {
    test('ログアウトの前に、この端末のトークンだけを外す', () async {
      await firestore.doc('users/$uid').update({
        'fcmTokens': ['tok-other'],
      });
      await service.register(uid);
      await service.unregister(uid);
      expect(await tokens(), ['tok-other']);
    });

    test('外したあとはトークンが替わっても書かない', () async {
      await service.register(uid);
      await service.unregister(uid);
      refresh.add('tok-b');
      await pumpEventQueue();
      expect(await tokens(), isEmpty);
    });

    group('Edge Cases', () {
      test('登録していなくても、プロフィールが無くても失敗しない', () async {
        expect((await service.unregister('no-profile')).isSuccess, isTrue);
        expect((await service.unregister('')).isSuccess, isTrue);
      });
    });
  });
}
