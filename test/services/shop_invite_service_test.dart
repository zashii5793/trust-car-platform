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

  /// 車検満了日の共有（案A）。
  ///
  /// `docs/BUSINESS_MODEL_RETHINK_2026-08-27.md` §6-2。
  /// **店に渡るのはここに書いたものが全部。** 増やすと、店が顧客の車を
  /// どこまで見られるかが静かに変わる。
  group('shareInspectionExpiries', () {
    Future<void> link(String userId) async {
      final code = await createInvite();
      await service.redeem(code: code, userId: userId);
    }

    test('かかりつけがある人の満了日が店に渡る', () async {
      await link('user-1');

      await service.shareInspectionExpiries(
        userId: 'user-1',
        expiryDates: [DateTime(2026, 11, 20)],
        vehicleCount: 1,
      );

      final saved = (await service.linkedShopFor('user-1')).valueOrNull!;
      expect(saved.inspectionExpiries.single, DateTime(2026, 11, 20));
      expect(saved.vehicleCount, 1);
      expect(saved.expiryUpdatedAt, isNotNull);
    });

    test('満了日が未入力の車は、台数にだけ数える', () async {
      // 差分が「満了日が分からない台数」になる。ここを詰めると、
      // 店の画面が「全部把握できている」ように見えてしまう。
      await link('user-1');

      await service.shareInspectionExpiries(
        userId: 'user-1',
        expiryDates: [DateTime(2026, 11, 20), null],
        vehicleCount: 2,
      );

      final saved = (await service.linkedShopFor('user-1')).valueOrNull!;
      expect(saved.inspectionExpiries.length, 1);
      expect(saved.vehicleCount, 2);
    });

    test('共有を切っている人には書かない', () async {
      await link('user-1');
      await service.setExpirySharing(userId: 'user-1', enabled: false);

      await service.shareInspectionExpiries(
        userId: 'user-1',
        expiryDates: [DateTime(2026, 11, 20)],
        vehicleCount: 1,
      );

      final saved = (await service.linkedShopFor('user-1')).valueOrNull!;
      expect(saved.inspectionExpiries, isEmpty);
    });

    group('Edge Cases', () {
      test('かかりつけが無ければ、文書を作らない', () async {
        // ここで作ると、店に紐づいていない人の満了日が置き場所を持ってしまう。
        final result = await service.shareInspectionExpiries(
          userId: 'user-no-shop',
          expiryDates: [DateTime(2026, 11, 20)],
          vehicleCount: 1,
        );

        expect(result.isSuccess, isTrue);
        final doc = await firestore
            .collection('shop_customers')
            .doc('user-no-shop')
            .get();
        expect(doc.exists, isFalse);
      });

      test('userId が空でも落ちない', () async {
        final result = await service.shareInspectionExpiries(
          userId: '',
          expiryDates: const [],
          vehicleCount: 0,
        );

        expect(result.isSuccess, isTrue);
      });

      test('車が0台なら、空で渡す', () async {
        await link('user-1');

        await service.shareInspectionExpiries(
          userId: 'user-1',
          expiryDates: const [],
          vehicleCount: 0,
        );

        final saved = (await service.linkedShopFor('user-1')).valueOrNull!;
        expect(saved.inspectionExpiries, isEmpty);
        expect(saved.vehicleCount, 0);
      });

      test('上限を超える満了日は切り捨てる', () async {
        await link('user-1');

        await service.shareInspectionExpiries(
          userId: 'user-1',
          expiryDates: List.generate(30, (i) => DateTime(2026, 11, 1 + i)),
          vehicleCount: 30,
        );

        final saved = (await service.linkedShopFor('user-1')).valueOrNull!;
        expect(
          saved.inspectionExpiries.length,
          ShopInviteService.maxSharedExpiries,
        );
      });

      test('負の台数は0として扱う', () async {
        await link('user-1');

        await service.shareInspectionExpiries(
          userId: 'user-1',
          expiryDates: const [],
          vehicleCount: -3,
        );

        final saved = (await service.linkedShopFor('user-1')).valueOrNull!;
        expect(saved.vehicleCount, 0);
      });

      test('中身が変わらなければ、更新時刻を動かさない', () async {
        // 画面を開くたびに時刻だけ新しくなると、
        // 「いつの満了日か」が読めなくなる。
        await link('user-1');
        await service.shareInspectionExpiries(
          userId: 'user-1',
          expiryDates: [DateTime(2026, 11, 20)],
          vehicleCount: 1,
        );
        final first = (await service.linkedShopFor('user-1'))
            .valueOrNull!
            .expiryUpdatedAt;

        await service.shareInspectionExpiries(
          userId: 'user-1',
          expiryDates: [DateTime(2026, 11, 20)],
          vehicleCount: 1,
        );
        final second = (await service.linkedShopFor('user-1'))
            .valueOrNull!
            .expiryUpdatedAt;

        expect(second, first);
      });
    });
  });

  group('setExpirySharing', () {
    test('切ると、渡していた満了日も消える', () async {
      // 「今後は渡さない」だけで過去の分が店に残るのでは、切った意味がない。
      final code = await createInvite();
      await service.redeem(code: code, userId: 'user-1');
      await service.shareInspectionExpiries(
        userId: 'user-1',
        expiryDates: [DateTime(2026, 11, 20)],
        vehicleCount: 1,
      );

      final updated =
          (await service.setExpirySharing(userId: 'user-1', enabled: false))
              .valueOrNull!;

      expect(updated.sharesInspectionExpiry, isFalse);
      expect(updated.inspectionExpiries, isEmpty);
      expect(updated.vehicleCount, 0);
    });

    test('店を替えても、切ったままにする', () async {
      // 上書きで既定の true に戻ると、切ったはずの共有が黙って復活する。
      final code = await createInvite();
      await service.redeem(code: code, userId: 'user-1');
      await service.setExpirySharing(userId: 'user-1', enabled: false);

      final otherCode =
          await createInvite(shopId: 'shop-2', ownerId: 'owner-2');
      await service.redeem(code: otherCode, userId: 'user-1');

      final link = (await service.linkedShopFor('user-1')).valueOrNull!;
      expect(link.shopId, 'shop-2');
      expect(link.sharesInspectionExpiry, isFalse);
    });

    group('Edge Cases', () {
      test('かかりつけが無ければ何もしない', () async {
        final result =
            await service.setExpirySharing(userId: 'user-x', enabled: true);

        expect(result.valueOrNull, isNull);
        final doc =
            await firestore.collection('shop_customers').doc('user-x').get();
        expect(doc.exists, isFalse);
      });

      test('userId が空でも落ちない', () async {
        final result =
            await service.setExpirySharing(userId: '', enabled: true);

        expect(result.isSuccess, isTrue);
      });
    });
  });

  group('now の注入', () {
    // 画面には「◯月◯日に更新」や車検の集計期間が出る。時計を外から
    // 渡せないと、**日付が変わっただけでゴールデン画像が落ちる**
    // （2026-09-01 に撮った3枚が 09-03 に落ちた）。
    final pinned = DateTime(2026, 9, 1, 10, 30);

    late ShopInviteService pinnedService;

    setUp(() {
      pinnedService = ShopInviteService(
        firestore: firestore,
        now: () => pinned,
      );
    });

    test('引き換えた時刻が、渡した時計になる', () async {
      final created = await pinnedService.createInvite(
        shopId: 'shop-1',
        shopName: 'タカヤモーター',
        shopOwnerId: 'owner-1',
      );

      await pinnedService.redeem(
        code: created.valueOrNull!.code,
        userId: 'user-1',
      );

      final link = (await pinnedService.linkedShopFor('user-1')).valueOrNull!;
      expect(link.linkedAt, pinned);
    });

    test('満了日を渡した時刻が、渡した時計になる', () async {
      final created = await pinnedService.createInvite(
        shopId: 'shop-1',
        shopName: 'タカヤモーター',
        shopOwnerId: 'owner-1',
      );
      await pinnedService.redeem(
        code: created.valueOrNull!.code,
        userId: 'user-1',
      );

      await pinnedService.shareInspectionExpiries(
        userId: 'user-1',
        expiryDates: [DateTime(2026, 11, 20)],
        vehicleCount: 2,
      );

      final link = (await pinnedService.linkedShopFor('user-1')).valueOrNull!;
      expect(link.expiryUpdatedAt, pinned);
    });

    test('共有を切ったときも、渡した時計で記録する', () async {
      final created = await pinnedService.createInvite(
        shopId: 'shop-1',
        shopName: 'タカヤモーター',
        shopOwnerId: 'owner-1',
      );
      await pinnedService.redeem(
        code: created.valueOrNull!.code,
        userId: 'user-1',
      );

      final result = await pinnedService.setExpirySharing(
        userId: 'user-1',
        enabled: false,
      );

      expect(result.valueOrNull!.expiryUpdatedAt, pinned);
    });

    group('Edge Cases', () {
      test('渡さなければ実時刻で動く', () async {
        final before = DateTime.now();
        final created = await service.createInvite(
          shopId: 'shop-1',
          shopName: 'タカヤモーター',
          shopOwnerId: 'owner-1',
        );
        await service.redeem(
          code: created.valueOrNull!.code,
          userId: 'user-2',
        );

        final link = (await service.linkedShopFor('user-2')).valueOrNull!;
        expect(
          link.linkedAt.isBefore(before.subtract(const Duration(seconds: 5))),
          isFalse,
        );
      });
    });
  });
}
