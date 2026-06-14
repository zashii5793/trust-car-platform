import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/car_purchase_inquiry.dart';
import 'package:trust_car_platform/services/car_purchase_inquiry_service.dart';

void main() {
  group('CarPurchaseInquiryService', () {
    late FakeFirebaseFirestore firestore;
    late CarPurchaseInquiryService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = CarPurchaseInquiryService(firestore: firestore);
    });

    // -------------------------------------------------------------------------
    // createInquiry
    // -------------------------------------------------------------------------
    group('createInquiry', () {
      test('正常系: 購入問い合わせを作成できる', () async {
        final result = await service.createInquiry(
          userId: 'user-1',
          condition: const CarPurchaseCondition(
            maker: 'Toyota',
            model: 'Alphard',
            minYear: 2020,
            maxPrice: 5000000,
          ),
          message: 'アルファード希望。予算500万。',
        );

        expect(result.isSuccess, isTrue);
        final id = result.valueOrNull!;
        final doc =
            await firestore.collection('car_purchase_inquiries').doc(id).get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['userId'], 'user-1');
        expect(doc.data()!['status'], 'open');
      });

      test('正常系: 特定の店舗に問い合わせできる', () async {
        final result = await service.createInquiry(
          userId: 'user-1',
          condition: const CarPurchaseCondition(maker: 'Honda'),
          message: '相談したい。',
          shopId: 'shop-abc',
        );

        expect(result.isSuccess, isTrue);
        final doc = await firestore
            .collection('car_purchase_inquiries')
            .doc(result.valueOrNull!)
            .get();
        expect(doc.data()!['shopId'], 'shop-abc');
      });

      group('Edge Cases', () {
        test('空のuserIdはバリデーションエラー', () async {
          final result = await service.createInquiry(
            userId: '',
            condition: const CarPurchaseCondition(),
            message: 'テスト',
          );
          expect(result.isFailure, isTrue);
        });

        test('空のmessageはバリデーションエラー', () async {
          final result = await service.createInquiry(
            userId: 'user-1',
            condition: const CarPurchaseCondition(),
            message: '',
          );
          expect(result.isFailure, isTrue);
        });

        test('空白のみのmessageはバリデーションエラー', () async {
          final result = await service.createInquiry(
            userId: 'user-1',
            condition: const CarPurchaseCondition(),
            message: '   ',
          );
          expect(result.isFailure, isTrue);
        });

        test('minPriceがmaxPriceより大きいとバリデーションエラー', () async {
          final result = await service.createInquiry(
            userId: 'user-1',
            condition: const CarPurchaseCondition(
              minPrice: 5000000,
              maxPrice: 2000000,
            ),
            message: '問い合わせ',
          );
          expect(result.isFailure, isTrue);
        });

        test('minYearがmaxYearより大きいとバリデーションエラー', () async {
          final result = await service.createInquiry(
            userId: 'user-1',
            condition: const CarPurchaseCondition(
              minYear: 2024,
              maxYear: 2020,
            ),
            message: '問い合わせ',
          );
          expect(result.isFailure, isTrue);
        });
      });
    });

    // -------------------------------------------------------------------------
    // getMyInquiries
    // -------------------------------------------------------------------------
    group('getMyInquiries', () {
      test('正常系: 自分の問い合わせ一覧を取得できる', () async {
        await service.createInquiry(
          userId: 'user-1',
          condition: const CarPurchaseCondition(maker: 'Toyota'),
          message: '問い合わせ1',
        );
        await service.createInquiry(
          userId: 'user-1',
          condition: const CarPurchaseCondition(maker: 'Honda'),
          message: '問い合わせ2',
        );
        await service.createInquiry(
          userId: 'user-9',
          condition: const CarPurchaseCondition(maker: 'Nissan'),
          message: '別ユーザー',
        );

        final result = await service.getMyInquiries('user-1');
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, hasLength(2));
        expect(result.valueOrNull!.every((i) => i.userId == 'user-1'), isTrue);
      });

      test('正常系: 問い合わせゼロでも空リスト', () async {
        final result = await service.getMyInquiries('no-such-user');
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // generateSearchLinks
    // -------------------------------------------------------------------------
    group('generateSearchLinks', () {
      test('正常系: カーセンサーとGoo-netのリンクが生成される', () {
        final links = service.generateSearchLinks(
          const CarPurchaseCondition(
            maker: 'Toyota',
            model: 'Prius',
            minYear: 2018,
            maxYear: 2022,
            maxPrice: 3000000,
          ),
        );

        expect(links, hasLength(greaterThanOrEqualTo(2)));
        final siteNames = links.map((l) => l.siteName).toList();
        expect(siteNames, contains('カーセンサー'));
        expect(siteNames, contains('Goo-net'));
      });

      test('正常系: 生成されたURLにメーカー・モデル情報が含まれる', () {
        final links = service.generateSearchLinks(
          const CarPurchaseCondition(maker: 'Honda', model: 'Fit'),
        );

        for (final link in links) {
          expect(link.url, isNotEmpty);
          expect(Uri.tryParse(link.url), isNotNull);
        }
      });

      test('正常系: 条件なしでもリンクが生成される（全車検索）', () {
        final links = service.generateSearchLinks(const CarPurchaseCondition());
        expect(links.isNotEmpty, isTrue);
      });

      test('正常系: 価格上限がURLクエリに反映される', () {
        final links = service.generateSearchLinks(
          const CarPurchaseCondition(maxPrice: 2000000),
        );
        final carsensor = links.firstWhere((l) => l.siteName == 'カーセンサー');
        expect(carsensor.url, contains('2000000'));
      });
    });

    // -------------------------------------------------------------------------
    // closeInquiry
    // -------------------------------------------------------------------------
    group('closeInquiry', () {
      test('正常系: 問い合わせを閉じられる', () async {
        final id = (await service.createInquiry(
          userId: 'user-1',
          condition: const CarPurchaseCondition(),
          message: 'クローズテスト',
        ))
            .valueOrNull!;

        final result =
            await service.closeInquiry(inquiryId: id, requesterId: 'user-1');
        expect(result.isSuccess, isTrue);

        final doc =
            await firestore.collection('car_purchase_inquiries').doc(id).get();
        expect(doc.data()!['status'], 'closed');
      });

      test('異常系: 他人の問い合わせを閉じられない', () async {
        final id = (await service.createInquiry(
          userId: 'user-1',
          condition: const CarPurchaseCondition(),
          message: 'クローズテスト',
        ))
            .valueOrNull!;

        final result =
            await service.closeInquiry(inquiryId: id, requesterId: 'intruder');
        expect(result.isFailure, isTrue);
      });
    });
  });
}
