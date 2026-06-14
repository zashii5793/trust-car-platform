import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/faq.dart';
import 'package:trust_car_platform/services/faq_service.dart';

void main() {
  group('FaqService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FaqService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = FaqService(firestore: fakeFirestore);
    });

    group('createFaq', () {
      test('正常系: FAQを作成できる', () async {
        final result = await service.createFaq(
          question: 'プリウスのオイル交換は何kmごとにするべきですか？',
          category: FaqCategory.maintenance,
          authorId: 'user1',
          allowShopResponse: false,
        );

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, isNotEmpty);
      });

      test('正常系: 作成されたFAQをFirestoreから取得できる', () async {
        final createResult = await service.createFaq(
          question: 'タイヤ交換の目安を教えてください',
          category: FaqCategory.maintenance,
          authorId: 'user1',
          allowShopResponse: true,
          vehicleMaker: 'Toyota',
          vehicleModel: 'Prius',
          tags: ['タイヤ', '交換時期'],
        );

        final faqId = createResult.valueOrNull!;
        final getResult = await service.getFaq(faqId);

        expect(getResult.isSuccess, isTrue);
        final faq = getResult.valueOrNull!;
        expect(faq.question, equals('タイヤ交換の目安を教えてください'));
        expect(faq.category, equals(FaqCategory.maintenance));
        expect(faq.allowShopResponse, isTrue);
        expect(faq.vehicleMaker, equals('Toyota'));
        expect(faq.tags, contains('タイヤ'));
      });

      group('Edge Cases', () {
        test('空の質問文はバリデーションエラー', () async {
          final result = await service.createFaq(
            question: '',
            category: FaqCategory.general,
            authorId: 'user1',
            allowShopResponse: false,
          );
          expect(result.isFailure, isTrue);
        });

        test('空のauthorIdはバリデーションエラー', () async {
          final result = await service.createFaq(
            question: '質問内容',
            category: FaqCategory.general,
            authorId: '',
            allowShopResponse: false,
          );
          expect(result.isFailure, isTrue);
        });

        test('長い質問文（500文字）は作成できる', () async {
          final longQuestion = 'あ' * 500;
          final result = await service.createFaq(
            question: longQuestion,
            category: FaqCategory.general,
            authorId: 'user1',
            allowShopResponse: false,
          );
          expect(result.isSuccess, isTrue);
        });
      });
    });

    group('getFaqs', () {
      setUp(() async {
        await service.createFaq(
          question: 'オイル交換の頻度は？',
          category: FaqCategory.maintenance,
          authorId: 'user1',
          allowShopResponse: false,
        );
        await service.createFaq(
          question: '車検の費用は？',
          category: FaqCategory.inspection,
          authorId: 'user2',
          allowShopResponse: true,
        );
        await service.createFaq(
          question: 'タイヤの寿命は？',
          category: FaqCategory.maintenance,
          authorId: 'user3',
          allowShopResponse: false,
        );
      });

      test('正常系: カテゴリでフィルタできる', () async {
        final result = await service.getFaqs(
          category: FaqCategory.maintenance,
        );

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.length, equals(2));
        expect(
          result.valueOrNull!
              .every((f) => f.category == FaqCategory.maintenance),
          isTrue,
        );
      });

      test('正常系: 全FAQを取得できる（カテゴリなし）', () async {
        final result = await service.getFaqs();

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.length, equals(3));
      });

      test('正常系: キーワード検索ができる', () async {
        final result = await service.getFaqs(keyword: 'オイル');

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.length, equals(1));
        expect(result.valueOrNull!.first.question, contains('オイル'));
      });

      test('正常系: 空データは空リストを返す', () async {
        final emptyFirestore = FakeFirebaseFirestore();
        final emptyService = FaqService(firestore: emptyFirestore);

        final result = await emptyService.getFaqs();
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, isEmpty);
      });
    });

    group('addAnswer', () {
      late String faqId;

      setUp(() async {
        final result = await service.createFaq(
          question: 'オイル交換の頻度は？',
          category: FaqCategory.maintenance,
          authorId: 'user1',
          allowShopResponse: false,
        );
        faqId = result.valueOrNull!;
      });

      test('正常系: ユーザーが回答を追加できる', () async {
        final result = await service.addAnswer(
          faqId: faqId,
          content: '一般的には5,000kmまたは6ヶ月ごとです。',
          authorId: 'user2',
          isShopResponse: false,
        );

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, isNotEmpty);
      });

      test('正常系: 追加した回答をFirestoreから取得できる', () async {
        await service.addAnswer(
          faqId: faqId,
          content: '5,000kmごとが目安です。',
          authorId: 'user2',
          isShopResponse: false,
        );

        final answersResult = await service.getAnswers(faqId);
        expect(answersResult.isSuccess, isTrue);
        expect(answersResult.valueOrNull!.length, equals(1));
        expect(answersResult.valueOrNull!.first.content, contains('5,000km'));
        expect(answersResult.valueOrNull!.first.isShopResponse, isFalse);
      });

      test('正常系: 回答数カウントが増加する', () async {
        await service.addAnswer(
          faqId: faqId,
          content: '回答1',
          authorId: 'user2',
          isShopResponse: false,
        );
        await service.addAnswer(
          faqId: faqId,
          content: '回答2',
          authorId: 'user3',
          isShopResponse: false,
        );

        final faqResult = await service.getFaq(faqId);
        expect(faqResult.valueOrNull!.answerCount, equals(2));
      });

      test('異常系: allowShopResponse=false のFAQに店舗は回答できない', () async {
        final result = await service.addAnswer(
          faqId: faqId,
          content: '当店では5,000kmをお勧めしています。',
          authorId: 'shop1',
          isShopResponse: true,
          shopId: 'shop1',
        );

        expect(result.isFailure, isTrue);
        expect(result.errorOrNull!.message, contains('permission'));
      });

      test('正常系: allowShopResponse=true のFAQに店舗が回答できる', () async {
        final faqWithShopResult = await service.createFaq(
          question: '車検費用は？',
          category: FaqCategory.inspection,
          authorId: 'user1',
          allowShopResponse: true,
        );
        final shopFaqId = faqWithShopResult.valueOrNull!;

        final result = await service.addAnswer(
          faqId: shopFaqId,
          content: '普通車で約70,000〜100,000円が相場です。',
          authorId: 'shop1',
          isShopResponse: true,
          shopId: 'shop1',
        );

        expect(result.isSuccess, isTrue);
      });

      group('Edge Cases', () {
        test('空の回答内容はバリデーションエラー', () async {
          final result = await service.addAnswer(
            faqId: faqId,
            content: '',
            authorId: 'user2',
            isShopResponse: false,
          );
          expect(result.isFailure, isTrue);
        });

        test('存在しないFAQ IDはエラーを返す', () async {
          final result = await service.addAnswer(
            faqId: 'nonexistent',
            content: '回答内容',
            authorId: 'user2',
            isShopResponse: false,
          );
          expect(result.isFailure, isTrue);
        });
      });
    });

    group('markHelpful', () {
      late String faqId;
      late String answerId;

      setUp(() async {
        final faqResult = await service.createFaq(
          question: 'テスト質問',
          category: FaqCategory.general,
          authorId: 'user1',
          allowShopResponse: false,
        );
        faqId = faqResult.valueOrNull!;

        final answerResult = await service.addAnswer(
          faqId: faqId,
          content: 'テスト回答',
          authorId: 'user2',
          isShopResponse: false,
        );
        answerId = answerResult.valueOrNull!;
      });

      test('正常系: 役に立ったボタンを押せる', () async {
        final result = await service.markHelpful(
          faqId: faqId,
          answerId: answerId,
          userId: 'user3',
        );
        expect(result.isSuccess, isTrue);

        final answersResult = await service.getAnswers(faqId);
        expect(answersResult.valueOrNull!.first.helpfulCount, equals(1));
      });

      test('正常系: 同ユーザーは1回のみ', () async {
        await service.markHelpful(
          faqId: faqId,
          answerId: answerId,
          userId: 'user3',
        );
        await service.markHelpful(
          faqId: faqId,
          answerId: answerId,
          userId: 'user3',
        );

        final answersResult = await service.getAnswers(faqId);
        expect(answersResult.valueOrNull!.first.helpfulCount, equals(1));
      });
    });

    group('markBestAnswer', () {
      late String faqId;
      late String answerId;

      setUp(() async {
        final faqResult = await service.createFaq(
          question: 'テスト質問',
          category: FaqCategory.general,
          authorId: 'user1',
          allowShopResponse: false,
        );
        faqId = faqResult.valueOrNull!;

        final answerResult = await service.addAnswer(
          faqId: faqId,
          content: 'ベストな回答',
          authorId: 'user2',
          isShopResponse: false,
        );
        answerId = answerResult.valueOrNull!;
      });

      test('正常系: 質問作成者がベスト回答を設定できる', () async {
        final result = await service.markBestAnswer(
          faqId: faqId,
          answerId: answerId,
          requesterId: 'user1',
        );
        expect(result.isSuccess, isTrue);

        final answersResult = await service.getAnswers(faqId);
        expect(answersResult.valueOrNull!.first.isBestAnswer, isTrue);
      });

      test('異常系: 他のユーザーはベスト回答を設定できない', () async {
        final result = await service.markBestAnswer(
          faqId: faqId,
          answerId: answerId,
          requesterId: 'user2',
        );
        expect(result.isFailure, isTrue);
      });
    });

    group('incrementViewCount', () {
      test('正常系: 閲覧回数が増加する', () async {
        final faqResult = await service.createFaq(
          question: 'テスト質問',
          category: FaqCategory.general,
          authorId: 'user1',
          allowShopResponse: false,
        );
        final faqId = faqResult.valueOrNull!;

        await service.incrementViewCount(faqId);
        await service.incrementViewCount(faqId);

        final getResult = await service.getFaq(faqId);
        expect(getResult.valueOrNull!.viewCount, equals(2));
      });
    });
  });
}
