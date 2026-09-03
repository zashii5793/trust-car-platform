// ご意見・ご要望の送信。
//
// 送れたかどうかがユーザーに伝わることが大事なので、成功・失敗を
// Result で返す。クライアントからは読み取らない（運用側でだけ見る）。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/user_feedback.dart';
import 'package:trust_car_platform/services/feedback_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FeedbackService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = FeedbackService(
      firestore: firestore,
      appVersion: '1.2.3',
      platform: 'android',
    );
  });

  Future<List<Map<String, dynamic>>> storedFeedback() async {
    final snap = await firestore.collection('feedback').get();
    return snap.docs.map((d) => d.data()).toList();
  }

  group('FeedbackService.submit', () {
    test('送信すると feedback に1件保存される', () async {
      final result = await service.submit(
        userId: 'user1',
        type: FeedbackType.request,
        message: '車検の通知をもっと早くほしい',
      );

      expect(result.isSuccess, isTrue);
      expect((await storedFeedback()).length, 1);
    });

    test('種別と本文が保存される', () async {
      await service.submit(
        userId: 'user1',
        type: FeedbackType.bug,
        message: 'フリート管理が開けません',
      );

      final saved = (await storedFeedback()).single;
      expect(saved['type'], 'bug');
      expect(saved['message'], 'フリート管理が開けません');
      expect(saved['userId'], 'user1');
    });

    test('アプリ版とプラットフォームが自動で付く', () async {
      await service.submit(
        userId: 'user1',
        type: FeedbackType.other,
        message: 'ありがとう',
      );

      final saved = (await storedFeedback()).single;
      expect(saved['appVersion'], '1.2.3');
      expect(saved['platform'], 'android');
    });

    test('未対応（status=open）で入る', () async {
      await service.submit(
        userId: 'user1',
        type: FeedbackType.request,
        message: 'x',
      );

      expect((await storedFeedback()).single['status'], 'open');
    });

    test('前後の空白は落として保存する', () async {
      await service.submit(
        userId: 'user1',
        type: FeedbackType.request,
        message: '  余白つきの要望  ',
      );

      expect((await storedFeedback()).single['message'], '余白つきの要望');
    });

    test('画面名と返信先を付けられる', () async {
      await service.submit(
        userId: 'user1',
        type: FeedbackType.bug,
        message: 'x',
        screen: 'フリート管理',
        contactEmail: 'me@example.com',
      );

      final saved = (await storedFeedback()).single;
      expect(saved['screen'], 'フリート管理');
      expect(saved['contactEmail'], 'me@example.com');
    });
  });

  group('FeedbackService.submit — Edge Cases', () {
    test('空の本文は送らず失敗を返す', () async {
      final result = await service.submit(
        userId: 'user1',
        type: FeedbackType.request,
        message: '   ',
      );

      expect(result.isFailure, isTrue);
      expect(await storedFeedback(), isEmpty);
    });

    test('長すぎる本文は送らず失敗を返す', () async {
      final result = await service.submit(
        userId: 'user1',
        type: FeedbackType.request,
        message: 'あ' * (UserFeedback.maxMessageLength + 1),
      );

      expect(result.isFailure, isTrue);
      expect(await storedFeedback(), isEmpty);
    });

    test('未ログイン（userId 空）では送れない', () async {
      final result = await service.submit(
        userId: '',
        type: FeedbackType.request,
        message: '要望です',
      );

      expect(result.isFailure, isTrue);
      expect(await storedFeedback(), isEmpty);
    });

    test('形式の壊れた返信先は送らず失敗を返す', () async {
      final result = await service.submit(
        userId: 'user1',
        type: FeedbackType.request,
        message: '要望です',
        contactEmail: 'not-an-email',
      );

      expect(result.isFailure, isTrue);
      expect(await storedFeedback(), isEmpty);
    });

    test('返信先が空文字なら任意項目として無視される', () async {
      final result = await service.submit(
        userId: 'user1',
        type: FeedbackType.request,
        message: '要望です',
        contactEmail: '   ',
      );

      expect(result.isSuccess, isTrue);
      expect(
          (await storedFeedback()).single.containsKey('contactEmail'), isFalse);
    });

    test('上限ちょうどの本文は送れる', () async {
      final result = await service.submit(
        userId: 'user1',
        type: FeedbackType.request,
        message: 'あ' * UserFeedback.maxMessageLength,
      );

      expect(result.isSuccess, isTrue);
    });

    test('連続で送っても別々に保存される', () async {
      await service.submit(
        userId: 'user1',
        type: FeedbackType.request,
        message: '1件目',
      );
      await service.submit(
        userId: 'user1',
        type: FeedbackType.bug,
        message: '2件目',
      );

      expect((await storedFeedback()).length, 2);
    });
  });
}
