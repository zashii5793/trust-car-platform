import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/shop_chain.dart';
import 'package:trust_car_platform/services/shop_chain_service.dart';

void main() {
  group('ShopChainService', () {
    late FakeFirebaseFirestore firestore;
    late ShopChainService service;
    final now = DateTime(2026, 1, 1);

    ShopChain _chain({
      String id = 'chain-kobac',
      String name = 'コバック',
      String? nationalPhone = '0120-000-111',
      String? website = 'https://kobac.co.jp',
      int shopCount = 5,
    }) =>
        ShopChain(
          id: id,
          name: name,
          nationalPhone: nationalPhone,
          website: website,
          shopCount: shopCount,
          createdAt: now,
          updatedAt: now,
        );

    Shop _shop({
      required String id,
      required String name,
      String? chainId,
      String? chainName,
    }) =>
        Shop(
          id: id,
          name: name,
          type: ShopType.maintenanceShop,
          chainId: chainId,
          chainName: chainName,
          prefecture: '東京都',
          createdAt: now,
          updatedAt: now,
        );

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ShopChainService(firestore: firestore);
    });

    // -------------------------------------------------------------------------
    // getChain
    // -------------------------------------------------------------------------
    group('getChain', () {
      test('正常系: チェーン情報を取得できる', () async {
        final chain = _chain();
        await firestore
            .collection('shop_chains')
            .doc(chain.id)
            .set(chain.toMap());

        final result = await service.getChain(chain.id);

        expect(result.isSuccess, isTrue);
        final fetched = result.valueOrNull!;
        expect(fetched.name, 'コバック');
        expect(fetched.nationalPhone, '0120-000-111');
        expect(fetched.shopCount, 5);
      });

      test('異常系: 存在しないIDはnotFoundエラー', () async {
        final result = await service.getChain('does-not-exist');
        expect(result.isFailure, isTrue);
      });

      group('Edge Cases', () {
        test('空文字IDはバリデーションエラー', () async {
          final result = await service.getChain('');
          expect(result.isFailure, isTrue);
        });
      });
    });

    // -------------------------------------------------------------------------
    // getShopsInChain
    // -------------------------------------------------------------------------
    group('getShopsInChain', () {
      test('正常系: チェーンに属する複数店舗を取得できる', () async {
        final chain = _chain(id: 'kobac', name: 'コバック', shopCount: 3);
        await firestore
            .collection('shop_chains')
            .doc(chain.id)
            .set(chain.toMap());

        // Seed 3 shops with chainId + 1 independent shop
        for (var i = 1; i <= 3; i++) {
          final shop = _shop(
            id: 'kobac-$i',
            name: 'コバック 店舗$i',
            chainId: 'kobac',
            chainName: 'コバック',
          );
          await firestore.collection('shops').doc(shop.id).set(shop.toMap());
        }
        final independent = _shop(id: 'solo-1', name: '独立整備工場');
        await firestore
            .collection('shops')
            .doc(independent.id)
            .set(independent.toMap());

        final result = await service.getShopsInChain('kobac');

        expect(result.isSuccess, isTrue);
        final shops = result.valueOrNull!;
        expect(shops, hasLength(3));
        expect(shops.every((s) => s.chainId == 'kobac'), isTrue);
      });

      test('正常系: チェーンに店舗がなければ空リスト', () async {
        final result = await service.getShopsInChain('empty-chain');
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, isEmpty);
      });

      group('Edge Cases', () {
        test('空文字チェーンIDはバリデーションエラー', () async {
          final result = await service.getShopsInChain('');
          expect(result.isFailure, isTrue);
        });
      });
    });

    // -------------------------------------------------------------------------
    // createChain
    // -------------------------------------------------------------------------
    group('createChain', () {
      test('正常系: チェーンを新規作成できる', () async {
        final result = await service.createChain(
          name: 'ジェームス',
          website: 'https://james.co.jp',
          nationalPhone: '0120-123-456',
        );

        expect(result.isSuccess, isTrue);
        final id = result.valueOrNull!;
        expect(id.isNotEmpty, isTrue);

        final doc = await firestore.collection('shop_chains').doc(id).get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['name'], 'ジェームス');
      });

      group('Edge Cases', () {
        test('空文字nameはバリデーションエラー', () async {
          final result = await service.createChain(name: '');
          expect(result.isFailure, isTrue);
        });

        test('空白のみのnameはバリデーションエラー', () async {
          final result = await service.createChain(name: '   ');
          expect(result.isFailure, isTrue);
        });
      });
    });

    // -------------------------------------------------------------------------
    // linkShopToChain
    // -------------------------------------------------------------------------
    group('linkShopToChain', () {
      test('正常系: 店舗をチェーンに紐付けられる', () async {
        // Create chain
        final chainId = (await service.createChain(name: 'コバック')).valueOrNull!;

        // Create shop with owner
        final shop =
            _shop(id: 'shop-x', name: 'テスト工場').copyWith(ownerId: 'owner-1');
        await firestore.collection('shops').doc(shop.id).set(shop.toMap());

        final result = await service.linkShopToChain(
          shopId: 'shop-x',
          chainId: chainId,
          requesterId: 'owner-1',
        );

        expect(result.isSuccess, isTrue);

        // Verify shop has chainId set
        final doc = await firestore.collection('shops').doc('shop-x').get();
        expect(doc.data()!['chainId'], chainId);
      });

      test('異常系: 非オーナーはリンクできない', () async {
        final chainId = (await service.createChain(name: 'コバック')).valueOrNull!;
        final shop =
            _shop(id: 'shop-y', name: 'テスト工場').copyWith(ownerId: 'owner-1');
        await firestore.collection('shops').doc(shop.id).set(shop.toMap());

        final result = await service.linkShopToChain(
          shopId: 'shop-y',
          chainId: chainId,
          requesterId: 'intruder',
        );

        expect(result.isFailure, isTrue);
      });

      test('異常系: 存在しない店舗IDはエラー', () async {
        final chainId = (await service.createChain(name: 'コバック')).valueOrNull!;
        final result = await service.linkShopToChain(
          shopId: 'ghost-shop',
          chainId: chainId,
          requesterId: 'owner-1',
        );
        expect(result.isFailure, isTrue);
      });

      group('Edge Cases', () {
        test('空文字shopIdはバリデーションエラー', () async {
          final result = await service.linkShopToChain(
            shopId: '',
            chainId: 'chain-1',
            requesterId: 'owner-1',
          );
          expect(result.isFailure, isTrue);
        });

        test('空文字chainIdはバリデーションエラー', () async {
          final result = await service.linkShopToChain(
            shopId: 'shop-1',
            chainId: '',
            requesterId: 'owner-1',
          );
          expect(result.isFailure, isTrue);
        });
      });
    });

    // -------------------------------------------------------------------------
    // unlinkShopFromChain
    // -------------------------------------------------------------------------
    group('unlinkShopFromChain', () {
      test('正常系: チェーンから店舗を切り離せる', () async {
        final chainId = (await service.createChain(name: 'コバック')).valueOrNull!;
        final shop = _shop(
          id: 'shop-z',
          name: 'テスト工場',
          chainId: chainId,
          chainName: 'コバック',
        ).copyWith(ownerId: 'owner-1');
        await firestore.collection('shops').doc(shop.id).set(shop.toMap());

        final result = await service.unlinkShopFromChain(
          shopId: 'shop-z',
          requesterId: 'owner-1',
        );

        expect(result.isSuccess, isTrue);
        final doc = await firestore.collection('shops').doc('shop-z').get();
        expect(doc.data()!.containsKey('chainId'), isFalse);
      });

      test('異常系: 非オーナーは切り離しできない', () async {
        final shop = _shop(
          id: 'shop-locked',
          name: 'テスト工場',
          chainId: 'some-chain',
        ).copyWith(ownerId: 'owner-1');
        await firestore.collection('shops').doc(shop.id).set(shop.toMap());

        final result = await service.unlinkShopFromChain(
          shopId: 'shop-locked',
          requesterId: 'intruder',
        );

        expect(result.isFailure, isTrue);
      });
    });
  });
}
