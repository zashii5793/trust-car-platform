import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/shop_invite_service.dart';

/// 招待コードの発行・照合・引き換え。
///
/// **間違うと「別の店の顧客になる」という、後から気づけない壊れ方をする。**
/// ここは実際に Firestore（fake）へ書いて確かめる。
void main() {
  late FakeFirebaseFirestore firestore;
  late ShopInviteService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ShopInviteService(firestore: firestore);
  });

  Future<String> createInvite({
    String shopId = 'shop-1',
    String shopName = 'タカヤモーター',
    String ownerId = 'owner-1',
    int? maxUses,
    DateTime? expiresAt,
  }) async {
    final result = await service.createInvite(
      shopId: shopId,
      shopName: shopName,
      shopOwnerId: ownerId,
      maxUses: maxUses,
      expiresAt: expiresAt,
    );
    return result.valueOrNull!.code;
  }

  group('createInvite', () {
    test('コードが発行され、読み戻せる', () async {
      final code = await createInvite();

      final found = await service.findByCode(code);
      expect(found.valueOrNull?.shopId, 'shop-1');
      expect(found.valueOrNull?.shopName, 'タカヤモーター');
      expect(found.valueOrNull?.isActive, isTrue);
    });

    test('発行したてのコードは使える', () async {
      final code = await createInvite();
      final invite = (await service.findByCode(code)).valueOrNull!;

      expect(invite.canBeUsedBy('user-1', now: DateTime.now()), isNull);
    });

    test('連続で発行してもコードがぶつからない', () async {
      final codes = <String>{};
      for (var i = 0; i < 20; i++) {
        codes.add(await createInvite(shopId: 'shop-$i'));
      }

      expect(codes.length, 20);
    });

    group('Edge Cases', () {
      test('店舗IDが空なら断る', () async {
        final result = await service.createInvite(
          shopId: '',
          shopName: 'タカヤモーター',
          shopOwnerId: 'owner-1',
        );

        expect(result.isFailure, isTrue);
      });

      test('店主IDが空なら断る', () async {
        // 誰の招待か分からないコードを配ると、自分で自分の顧客になれてしまう。
        final result = await service.createInvite(
          shopId: 'shop-1',
          shopName: 'タカヤモーター',
          shopOwnerId: '',
        );

        expect(result.isFailure, isTrue);
      });

      test('上限を0以下で作ろうとしたら断る', () async {
        final result = await service.createInvite(
          shopId: 'shop-1',
          shopName: 'タカヤモーター',
          shopOwnerId: 'owner-1',
          maxUses: 0,
        );

        expect(result.isFailure, isTrue);
      });
    });
  });

  group('findByCode', () {
    test('入力のゆれを吸収して見つける', () async {
      final code = await createInvite();

      // 紙に「ABC-234」と書いて渡された想定
      final messy = '  ${code.substring(0, 3)}-${code.substring(3)}  ';
      final found = await service.findByCode(messy);

      expect(found.valueOrNull?.code, code);
    });

    group('Edge Cases', () {
      test('無いコードは見つからない', () async {
        final found = await service.findByCode('ZZZZZZ');

        expect(found.valueOrNull, isNull);
      });

      test('空文字は見つからない', () async {
        expect((await service.findByCode('')).valueOrNull, isNull);
      });
    });
  });

  group('redeem — 引き換え', () {
    test('顧客が店に紐づく', () async {
      final code = await createInvite();

      final result = await service.redeem(code: code, userId: 'user-1');

      expect(result.isSuccess, isTrue);
      final link = await service.linkedShopFor('user-1');
      expect(link.valueOrNull?.shopId, 'shop-1');
      expect(link.valueOrNull?.shopName, 'タカヤモーター');
    });

    test('使った回数が増える', () async {
      final code = await createInvite();

      await service.redeem(code: code, userId: 'user-1');
      await service.redeem(code: code, userId: 'user-2');

      final invite = (await service.findByCode(code)).valueOrNull!;
      expect(invite.usedCount, 2);
    });

    test('店側から顧客の一覧が引ける', () async {
      final code = await createInvite();
      await service.redeem(code: code, userId: 'user-1');
      await service.redeem(code: code, userId: 'user-2');

      final customers = await service.customersOf('shop-1');
      expect(customers.valueOrNull?.length, 2);
    });

    group('Edge Cases', () {
      test('無いコードは断る', () async {
        final result = await service.redeem(code: 'ZZZZZZ', userId: 'user-1');

        expect(result.isFailure, isTrue);
      });

      test('止められた招待は断る', () async {
        final code = await createInvite();
        await service.deactivate(code);

        final result = await service.redeem(code: code, userId: 'user-1');

        expect(result.isFailure, isTrue);
      });

      test('期限切れは断る', () async {
        final code = await createInvite(
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        final result = await service.redeem(code: code, userId: 'user-1');

        expect(result.isFailure, isTrue);
      });

      test('上限に達したら断る', () async {
        final code = await createInvite(maxUses: 1);
        await service.redeem(code: code, userId: 'user-1');

        final result = await service.redeem(code: code, userId: 'user-2');

        expect(result.isFailure, isTrue);
      });

      test('店主が自分の招待を使おうとしたら断る', () async {
        final code = await createInvite(ownerId: 'owner-1');

        final result = await service.redeem(code: code, userId: 'owner-1');

        expect(result.isFailure, isTrue);
      });

      test('同じ人が2回使っても、顧客が二重にならない', () async {
        final code = await createInvite();

        await service.redeem(code: code, userId: 'user-1');
        await service.redeem(code: code, userId: 'user-1');

        final customers = await service.customersOf('shop-1');
        expect(customers.valueOrNull?.length, 1);
      });

      test('同じ人が2回使っても、使用回数は増やさない', () async {
        // 増やすと上限が意味をなさなくなる。
        final code = await createInvite();

        await service.redeem(code: code, userId: 'user-1');
        await service.redeem(code: code, userId: 'user-1');

        final invite = (await service.findByCode(code)).valueOrNull!;
        expect(invite.usedCount, 1);
      });

      test('別の店のコードを使うと、かかりつけが乗り換わる', () async {
        final first = await createInvite(shopId: 'shop-1', shopName: 'A整備');
        final second = await createInvite(
          shopId: 'shop-2',
          shopName: 'B整備',
          ownerId: 'owner-2',
        );

        await service.redeem(code: first, userId: 'user-1');
        await service.redeem(code: second, userId: 'user-1');

        final link = await service.linkedShopFor('user-1');
        expect(link.valueOrNull?.shopId, 'shop-2');
      });

      test('利用者IDが空なら断る', () async {
        final code = await createInvite();

        final result = await service.redeem(code: code, userId: '');

        expect(result.isFailure, isTrue);
      });
    });
  });

  group('linkedShopFor', () {
    test('紐づいていなければ null', () async {
      final link = await service.linkedShopFor('user-x');

      expect(link.valueOrNull, isNull);
    });
  });

  group('deactivate', () {
    test('止めた招待は使えなくなる', () async {
      final code = await createInvite();

      await service.deactivate(code);

      final invite = (await service.findByCode(code)).valueOrNull!;
      expect(invite.isActive, isFalse);
    });

    test('止めても、すでに紐づいた顧客は外れない', () async {
      final code = await createInvite();
      await service.redeem(code: code, userId: 'user-1');

      await service.deactivate(code);

      final link = await service.linkedShopFor('user-1');
      expect(link.valueOrNull?.shopId, 'shop-1');
    });
  });
}
