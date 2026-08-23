// ご意見・ご要望の送信画面。
//
// 「support@trustcar.jp までメール」しか窓口が無く、気づいたことが
// 届かないままだった。数タップで送れて、送れたことが分かるようにする。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/user_feedback.dart';
import 'package:trust_car_platform/screens/settings/feedback_screen.dart';
import 'package:trust_car_platform/services/feedback_service.dart';

class _RecordingFeedbackService extends FeedbackService {
  _RecordingFeedbackService({this.shouldFail = false})
      : super(
          firestore: FakeFirebaseFirestore(),
          appVersion: '1.0.0',
          platform: 'test',
        );

  final bool shouldFail;

  int submitCount = 0;
  FeedbackType? lastType;
  String? lastMessage;
  String? lastScreen;
  String? lastContactEmail;

  @override
  Future<Result<void, AppError>> submit({
    required String userId,
    required FeedbackType type,
    required String message,
    String? screen,
    String? contactEmail,
  }) async {
    submitCount++;
    lastType = type;
    lastMessage = message;
    lastScreen = screen;
    lastContactEmail = contactEmail;
    if (shouldFail) {
      return super.submit(
        userId: '',
        type: type,
        message: message,
      );
    }
    return super.submit(
      userId: userId,
      type: type,
      message: message,
      screen: screen,
      contactEmail: contactEmail,
    );
  }
}

Widget _wrap(FeedbackService service, {String userId = 'user1'}) {
  return MaterialApp(
    home: FeedbackScreen(service: service, userId: userId),
  );
}

Future<void> _enterMessage(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('feedback_message')), text);
  await tester.pump();
}

void main() {
  group('FeedbackScreen — 表示', () {
    testWidgets('種別を3つから選べる', (tester) async {
      await tester.pumpWidget(_wrap(_RecordingFeedbackService()));

      for (final type in FeedbackType.values) {
        expect(
          find.byKey(Key('feedback_type_${type.storageName}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('既定は「こうしてほしい」', (tester) async {
      final service = _RecordingFeedbackService();
      await tester.pumpWidget(_wrap(service));

      await _enterMessage(tester, '要望です');
      await tester.tap(find.byKey(const Key('feedback_submit')));
      await tester.pumpAndSettle();

      expect(service.lastType, FeedbackType.request);
    });

    testWidgets('本文の入力欄がある', (tester) async {
      await tester.pumpWidget(_wrap(_RecordingFeedbackService()));

      expect(find.byKey(const Key('feedback_message')), findsOneWidget);
    });

    testWidgets('返信先メールは任意と分かる', (tester) async {
      await tester.pumpWidget(_wrap(_RecordingFeedbackService()));

      expect(find.byKey(const Key('feedback_email')), findsOneWidget);
      expect(find.textContaining('任意'), findsWidgets);
    });
  });

  group('FeedbackScreen — 送信', () {
    testWidgets('本文が空のままでは送信されない', (tester) async {
      final service = _RecordingFeedbackService();
      await tester.pumpWidget(_wrap(service));

      await tester.tap(find.byKey(const Key('feedback_submit')));
      await tester.pumpAndSettle();

      expect(service.submitCount, 0);
      expect(find.text('内容を入力してください'), findsOneWidget);
    });

    testWidgets('本文を入れると送信される', (tester) async {
      final service = _RecordingFeedbackService();
      await tester.pumpWidget(_wrap(service));

      await _enterMessage(tester, '車検の通知をもっと早くほしい');
      await tester.tap(find.byKey(const Key('feedback_submit')));
      await tester.pumpAndSettle();

      expect(service.submitCount, 1);
      expect(service.lastMessage, '車検の通知をもっと早くほしい');
    });

    testWidgets('選んだ種別が渡る', (tester) async {
      final service = _RecordingFeedbackService();
      await tester.pumpWidget(_wrap(service));

      await tester.tap(
          find.byKey(Key('feedback_type_${FeedbackType.bug.storageName}')));
      await tester.pump();
      await _enterMessage(tester, 'フリート管理が開けません');
      await tester.tap(find.byKey(const Key('feedback_submit')));
      await tester.pumpAndSettle();

      expect(service.lastType, FeedbackType.bug);
    });

    testWidgets('送信できたら礼を伝えて閉じられる状態になる', (tester) async {
      final service = _RecordingFeedbackService();
      await tester.pumpWidget(_wrap(service));

      await _enterMessage(tester, 'ありがとう');
      await tester.tap(find.byKey(const Key('feedback_submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feedback_thanks')), findsOneWidget);
    });

    testWidgets('送信後は入力欄が消える（二重送信させない）', (tester) async {
      final service = _RecordingFeedbackService();
      await tester.pumpWidget(_wrap(service));

      await _enterMessage(tester, 'ありがとう');
      await tester.tap(find.byKey(const Key('feedback_submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feedback_submit')), findsNothing);
    });

    testWidgets('どの画面から送ったかが渡る', (tester) async {
      final service = _RecordingFeedbackService();
      await tester.pumpWidget(MaterialApp(
        home: FeedbackScreen(
          service: service,
          userId: 'user1',
          fromScreen: 'フリート管理',
        ),
      ));

      await _enterMessage(tester, 'x');
      await tester.tap(find.byKey(const Key('feedback_submit')));
      await tester.pumpAndSettle();

      expect(service.lastScreen, 'フリート管理');
    });

    testWidgets('失敗したら理由を出して入力を残す', (tester) async {
      final service = _RecordingFeedbackService(shouldFail: true);
      await tester.pumpWidget(_wrap(service));

      await _enterMessage(tester, '送信に失敗する要望');
      await tester.tap(find.byKey(const Key('feedback_submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feedback_thanks')), findsNothing);
      expect(find.byKey(const Key('feedback_submit')), findsOneWidget);
      expect(find.textContaining('ログイン'), findsWidgets);
    });
  });

  group('FeedbackScreen — Edge Cases', () {
    testWidgets('空白だけの本文は送信されない', (tester) async {
      final service = _RecordingFeedbackService();
      await tester.pumpWidget(_wrap(service));

      await _enterMessage(tester, '     ');
      await tester.tap(find.byKey(const Key('feedback_submit')));
      await tester.pumpAndSettle();

      expect(service.submitCount, 0);
    });

    // 入力欄には maxLength も掛けてあるが、貼り付けなどで超えた場合に備えて
    // 送信前にも止める。
    testWidgets('上限を超える本文は送信されない', (tester) async {
      final service = _RecordingFeedbackService();
      await tester.pumpWidget(_wrap(service));

      await _enterMessage(tester, 'あ' * (UserFeedback.maxMessageLength + 100));
      await tester.tap(find.byKey(const Key('feedback_submit')));
      await tester.pumpAndSettle();

      expect(service.submitCount, 0);
    });

    testWidgets('形式の壊れたメールはエラーを出す', (tester) async {
      final service = _RecordingFeedbackService();
      await tester.pumpWidget(_wrap(service));

      await _enterMessage(tester, '要望です');
      await tester.enterText(
          find.byKey(const Key('feedback_email')), 'not-an-email');
      await tester.tap(find.byKey(const Key('feedback_submit')));
      await tester.pumpAndSettle();

      expect(service.submitCount, 0);
      expect(find.textContaining('メールアドレスの形式'), findsWidgets);
    });

    testWidgets('未ログインでは入力させず案内を出す', (tester) async {
      await tester.pumpWidget(
        _wrap(_RecordingFeedbackService(), userId: ''),
      );

      expect(find.byKey(const Key('feedback_message')), findsNothing);
      expect(find.textContaining('ログイン'), findsWidgets);
    });
  });
}
