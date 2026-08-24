// ユーザーからの要望・不具合報告。
//
// これまで問い合わせ先は「support@trustcar.jp までメール」しか無く、
// 気づいたことがあってもメールを書くほどでもない、で消えていた。
// アプリ内から数タップで送れるようにするためのモデル。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/user_feedback.dart';

void main() {
  group('FeedbackType', () {
    test('3種類ある（要望・不具合・その他）', () {
      expect(FeedbackType.values.length, 3);
      expect(FeedbackType.values, contains(FeedbackType.request));
      expect(FeedbackType.values, contains(FeedbackType.bug));
      expect(FeedbackType.values, contains(FeedbackType.other));
    });

    test('表示名が日本語で付いている', () {
      expect(FeedbackType.request.displayName, 'こうしてほしい');
      expect(FeedbackType.bug.displayName, 'うまく動かない');
      expect(FeedbackType.other.displayName, 'その他');
    });

    test('保存名は英語（Firestore に書く値）', () {
      expect(FeedbackType.request.storageName, 'request');
      expect(FeedbackType.bug.storageName, 'bug');
      expect(FeedbackType.other.storageName, 'other');
    });

    test('保存名から復元できる', () {
      expect(FeedbackType.fromStorage('bug'), FeedbackType.bug);
      expect(FeedbackType.fromStorage('request'), FeedbackType.request);
    });

    test('知らない値は other に倒す（将来の種別追加で落ちないように）', () {
      expect(FeedbackType.fromStorage('unknown-type'), FeedbackType.other);
      expect(FeedbackType.fromStorage(''), FeedbackType.other);
      expect(FeedbackType.fromStorage(null), FeedbackType.other);
    });
  });

  group('UserFeedback', () {
    UserFeedback make({
      String message = '車検の通知をもう少し早くほしいです',
      FeedbackType type = FeedbackType.request,
      String? screen,
      String? contactEmail,
    }) {
      return UserFeedback(
        id: 'fb1',
        userId: 'user1',
        type: type,
        message: message,
        appVersion: '1.0.0',
        platform: 'android',
        screen: screen,
        contactEmail: contactEmail,
        createdAt: DateTime(2026, 8, 22, 10, 0),
      );
    }

    test('必須項目を保持する', () {
      final fb = make();

      expect(fb.userId, 'user1');
      expect(fb.type, FeedbackType.request);
      expect(fb.message, '車検の通知をもう少し早くほしいです');
    });

    test('toMap に種別・本文・環境情報が入る', () {
      final map = make().toMap();

      expect(map['userId'], 'user1');
      expect(map['type'], 'request');
      expect(map['message'], '車検の通知をもう少し早くほしいです');
      expect(map['appVersion'], '1.0.0');
      expect(map['platform'], 'android');
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('未対応（status=open）で作られる', () {
      expect(make().toMap()['status'], 'open');
    });

    test('どの画面から送られたかを残せる', () {
      expect(make(screen: '車検アラート').toMap()['screen'], '車検アラート');
    });

    test('画面名がなければキーを書かない', () {
      expect(make().toMap().containsKey('screen'), isFalse);
    });

    test('返信先メールは任意（入れれば残る）', () {
      expect(
        make(contactEmail: 'a@example.com').toMap()['contactEmail'],
        'a@example.com',
      );
      expect(make().toMap().containsKey('contactEmail'), isFalse);
    });

    test('本文の最大長が決まっている', () {
      expect(UserFeedback.maxMessageLength, greaterThan(0));
    });
  });

  group('UserFeedback — 入力の検証', () {
    test('空の本文は送れない', () {
      expect(UserFeedback.validateMessage(''), isNotNull);
      expect(UserFeedback.validateMessage('   '), isNotNull);
    });

    test('本文があれば通る', () {
      expect(UserFeedback.validateMessage('使いやすいです'), isNull);
    });

    test('長すぎる本文は弾く', () {
      final tooLong = 'あ' * (UserFeedback.maxMessageLength + 1);

      expect(UserFeedback.validateMessage(tooLong), isNotNull);
    });

    test('上限ちょうどは通る', () {
      final justFit = 'あ' * UserFeedback.maxMessageLength;

      expect(UserFeedback.validateMessage(justFit), isNull);
    });

    test('メール形式でない返信先は弾く', () {
      expect(UserFeedback.validateContactEmail('not-an-email'), isNotNull);
    });

    test('空の返信先は許す（任意項目）', () {
      expect(UserFeedback.validateContactEmail(''), isNull);
      expect(UserFeedback.validateContactEmail(null), isNull);
    });

    test('正しいメール形式は通る', () {
      expect(UserFeedback.validateContactEmail('user@example.com'), isNull);
    });
  });
}
