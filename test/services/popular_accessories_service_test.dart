import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/accessory_showcase.dart';
import 'package:trust_car_platform/services/popular_accessories_service.dart';

void main() {
  group('PopularAccessoriesService', () {
    late FakeFirebaseFirestore firestore;
    late PopularAccessoriesService service;
    final now = DateTime(2026, 1, 1);

    AccessoryShowcase showcase({
      String id = 'sc-1',
      String userId = 'user-1',
      AccessoryCategory category = AccessoryCategory.electronics,
      String itemName = 'Vantrue N2 Pro',
      String? brand = 'Vantrue',
      int rating = 5,
      int? priceApprox = 18000,
    }) =>
        AccessoryShowcase(
          id: id,
          userId: userId,
          category: category,
          itemName: itemName,
          brand: brand,
          priceApprox: priceApprox,
          rating: rating,
          createdAt: now,
        );

    Future<void> seedShowcase(AccessoryShowcase sc) async {
      await firestore
          .collection('accessory_showcases')
          .doc(sc.id)
          .set(sc.toMap());
    }

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = PopularAccessoriesService(firestore: firestore);
    });

    // -------------------------------------------------------------------------
    // submitShowcase
    // -------------------------------------------------------------------------
    group('submitShowcase', () {
      test('正常系: アクセサリーを投稿できる', () async {
        final result = await service.submitShowcase(
          userId: 'user-1',
          category: AccessoryCategory.electronics,
          itemName: 'Vantrue N2 Pro',
          brand: 'Vantrue',
          rating: 5,
          priceApprox: 18000,
          review: '画質が良く駐車監視も完璧。',
        );

        expect(result.isSuccess, isTrue);
        final id = result.valueOrNull!;
        expect(id.isNotEmpty, isTrue);

        final doc =
            await firestore.collection('accessory_showcases').doc(id).get();
        expect(doc.data()!['itemName'], 'Vantrue N2 Pro');
        expect(doc.data()!['category'], 'electronics');
      });

      group('Edge Cases', () {
        test('空のitemNameはバリデーションエラー', () async {
          final result = await service.submitShowcase(
            userId: 'user-1',
            category: AccessoryCategory.electronics,
            itemName: '',
            rating: 5,
          );
          expect(result.isFailure, isTrue);
        });

        test('空白のみのitemNameはバリデーションエラー', () async {
          final result = await service.submitShowcase(
            userId: 'user-1',
            category: AccessoryCategory.electronics,
            itemName: '   ',
            rating: 5,
          );
          expect(result.isFailure, isTrue);
        });

        test('空のuserIdはバリデーションエラー', () async {
          final result = await service.submitShowcase(
            userId: '',
            category: AccessoryCategory.electronics,
            itemName: 'Test Item',
            rating: 5,
          );
          expect(result.isFailure, isTrue);
        });

        test('rating=0はバリデーションエラー', () async {
          final result = await service.submitShowcase(
            userId: 'user-1',
            category: AccessoryCategory.electronics,
            itemName: 'Test Item',
            rating: 0,
          );
          expect(result.isFailure, isTrue);
        });

        test('rating=6はバリデーションエラー', () async {
          final result = await service.submitShowcase(
            userId: 'user-1',
            category: AccessoryCategory.electronics,
            itemName: 'Test Item',
            rating: 6,
          );
          expect(result.isFailure, isTrue);
        });
      });
    });

    // -------------------------------------------------------------------------
    // getShowcasesByCategory
    // -------------------------------------------------------------------------
    group('getShowcasesByCategory', () {
      test('正常系: カテゴリでフィルタされた投稿を取得できる', () async {
        await seedShowcase(
            showcase(id: 'e1', category: AccessoryCategory.electronics));
        await seedShowcase(showcase(
            id: 'e2',
            category: AccessoryCategory.electronics,
            itemName: 'Pioneer carrozzeria'));
        await seedShowcase(showcase(
            id: 'i1',
            category: AccessoryCategory.interior,
            itemName: 'コクピットシートカバー'));

        final result =
            await service.getShowcasesByCategory(AccessoryCategory.electronics);

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, hasLength(2));
        expect(
          result.valueOrNull!
              .every((s) => s.category == AccessoryCategory.electronics),
          isTrue,
        );
      });

      test('正常系: 投稿ゼロでも空リストを返す', () async {
        final result =
            await service.getShowcasesByCategory(AccessoryCategory.safety);
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // getPopularTrends
    // -------------------------------------------------------------------------
    group('getPopularTrends', () {
      test('正常系: 同アイテムを複数ユーザーが投稿するとショーケース数が集計される', () async {
        // 3 users post about the same dash cam
        for (var i = 1; i <= 3; i++) {
          await seedShowcase(showcase(
            id: 'v-$i',
            userId: 'user-$i',
            itemName: 'Vantrue N2 Pro',
            rating: 5,
          ));
        }
        // 1 user posts about a different item
        await seedShowcase(showcase(
          id: 'p-1',
          userId: 'user-4',
          itemName: 'Pioneer carrozzeria',
          rating: 4,
        ));

        final result = await service.getPopularTrends(
            category: AccessoryCategory.electronics);

        expect(result.isSuccess, isTrue);
        final trends = result.valueOrNull!;
        // Vantrue should rank first with count=3
        final vantrue =
            trends.firstWhere((t) => t.itemName == 'Vantrue N2 Pro');
        expect(vantrue.showcaseCount, 3);
        expect(
            trends.indexOf(vantrue),
            lessThan(
                trends.indexWhere((t) => t.itemName == 'Pioneer carrozzeria')));
      });

      test('正常系: 平均評価が計算される', () async {
        await seedShowcase(
            showcase(id: 'r1', userId: 'u1', itemName: 'Item X', rating: 4));
        await seedShowcase(
            showcase(id: 'r2', userId: 'u2', itemName: 'Item X', rating: 2));

        final result = await service.getPopularTrends(
            category: AccessoryCategory.electronics);
        final trend =
            result.valueOrNull!.firstWhere((t) => t.itemName == 'Item X');

        expect(trend.averageRating, closeTo(3.0, 0.01));
      });

      test('正常系: limitで返すアイテム数を制限できる', () async {
        for (var i = 1; i <= 10; i++) {
          await seedShowcase(showcase(
            id: 'item-$i',
            userId: 'user-$i',
            itemName: 'Item $i',
            category: AccessoryCategory.interior,
          ));
        }

        final result = await service.getPopularTrends(
            category: AccessoryCategory.interior, limit: 5);

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, hasLength(5));
      });

      test('正常系: 投稿なしは空トレンドリスト', () async {
        final result =
            await service.getPopularTrends(category: AccessoryCategory.safety);
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // getTopAccessories (cross-category)
    // -------------------------------------------------------------------------
    group('getTopAccessories', () {
      test('正常系: 全カテゴリを横断して人気アイテムを取得できる', () async {
        // electronics: 2 showcases
        await seedShowcase(showcase(id: 'e1', userId: 'u1', itemName: 'ドラレコA'));
        await seedShowcase(showcase(id: 'e2', userId: 'u2', itemName: 'ドラレコA'));
        // interior: 3 showcases
        await seedShowcase(showcase(
          id: 'i1',
          userId: 'u3',
          itemName: 'シートカバーB',
          category: AccessoryCategory.interior,
        ));
        await seedShowcase(showcase(
          id: 'i2',
          userId: 'u4',
          itemName: 'シートカバーB',
          category: AccessoryCategory.interior,
        ));
        await seedShowcase(showcase(
          id: 'i3',
          userId: 'u5',
          itemName: 'シートカバーB',
          category: AccessoryCategory.interior,
        ));

        final result = await service.getTopAccessories(limit: 5);

        expect(result.isSuccess, isTrue);
        final trends = result.valueOrNull!;
        expect(trends.isNotEmpty, isTrue);
        // シートカバーB (3) should rank above ドラレコA (2)
        final seat = trends.firstWhere((t) => t.itemName == 'シートカバーB');
        final cam = trends.firstWhere((t) => t.itemName == 'ドラレコA');
        expect(trends.indexOf(seat), lessThan(trends.indexOf(cam)));
      });

      test('正常系: 全投稿ゼロでも空リスト', () async {
        final result = await service.getTopAccessories();
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, isEmpty);
      });
    });
  });
}
