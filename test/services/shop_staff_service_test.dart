import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/screens/shop/ledger/staff_screens.dart';
import 'package:trust_car_platform/services/shop_staff_service.dart';

/// 店のスタッフ。コードは1回限り・7日間。
void main() {
  late FakeFirebaseFirestore fs;
  late ShopStaffService service;
  final now = DateTime(2026, 9, 28, 10);

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = ShopStaffService(firestore: fs, now: () => now);
  });

  Future<String> issue() async => (await service.issue(
        shopId: 'owner1',
        shopName: 'タカヤモーター',
        issuedBy: 'owner1',
      ))
          .valueOrNull!
          .code;

  group('issue / redeem', () {
    test('コードで入ると、名簿と札ができ、自分の店が引ける', () async {
      final code = await issue();
      final link = (await service.redeem(
        code: code.toLowerCase(), // 入力の揺れは吸収する
        uid: 's1',
        displayName: '佐藤',
      ))
          .valueOrNull!;
      expect(link.shopId, 'owner1');

      final members = (await service.members('owner1')).valueOrNull!;
      expect(members.single.displayName, '佐藤');
      expect(members.single.role, 'staff');
      expect((await service.myShop('s1')).valueOrNull!.shopName, 'タカヤモーター');
    });

    test('有効期限は7日', () async {
      final r = (await service.issue(
        shopId: 'owner1',
        shopName: 'x',
        issuedBy: 'owner1',
      ))
          .valueOrNull!;
      expect(r.expiresAt, now.add(const Duration(days: 7)));
    });

    group('Edge Cases', () {
      test('同じコードは2回使えない', () async {
        final code = await issue();
        await service.redeem(code: code, uid: 's1', displayName: 'a');
        final second =
            await service.redeem(code: code, uid: 's2', displayName: 'b');
        expect(second.errorOrNull, isA<ValidationError>());
        expect(second.errorOrNull!.message, contains('使用済み'));
      });

      test('期限が切れたコードでは入れない', () async {
        final code = await issue();
        final later = ShopStaffService(
          firestore: fs,
          now: () => now.add(const Duration(days: 8)),
        );
        final r = await later.redeem(code: code, uid: 's1', displayName: 'a');
        expect(r.errorOrNull!.message, contains('期限'));
      });

      test('無いコード・桁の違うコード', () async {
        expect(
          (await service.redeem(code: 'ZZZZZZ', uid: 's', displayName: 'a'))
              .errorOrNull,
          isA<NotFoundError>(),
        );
        expect(
          (await service.redeem(code: 'AB', uid: 's', displayName: 'a'))
              .errorOrNull,
          isA<ValidationError>(),
        );
      });

      test('店が特定できなければ発行しない', () async {
        final r = await service.issue(shopId: '', shopName: '', issuedBy: 'x');
        expect(r.isFailure, isTrue);
      });

      test('どの店のスタッフでもなければ null', () async {
        expect((await service.myShop('nobody')).valueOrNull, isNull);
      });
    });
  });

  group('remove', () {
    test('外すと、名簿からも札からも消える', () async {
      final code = await issue();
      await service.redeem(code: code, uid: 's1', displayName: '佐藤');
      await service.remove(shopId: 'owner1', uid: 's1');
      expect((await service.members('owner1')).valueOrNull, isEmpty);
      expect((await service.myShop('s1')).valueOrNull, isNull);
    });
  });

  group('画面', () {
    testWidgets('店主がコードを発行し、スタッフが入れると名簿に並ぶ', (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: StaffManageScreen(
          service: service,
          shopId: 'owner1',
          shopName: 'タカヤモーター',
          ownerUid: 'owner1',
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('まだスタッフはいません'), findsOneWidget);

      await tester.tap(find.byKey(const Key('staff_issue')));
      await tester.pumpAndSettle();
      final code = tester
          .widget<SelectableText>(find.byKey(const Key('staff_invite_code')))
          .data!;
      expect(code, hasLength(6));

      // スタッフ側
      StaffShopLinkHolder.value = null;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              StaffShopLinkHolder.value = await Navigator.push<StaffShopLink>(
                context,
                MaterialPageRoute(
                  builder: (_) => StaffJoinScreen(
                    service: service,
                    uid: 's1',
                    displayName: '佐藤',
                  ),
                ),
              );
            },
            child: const Text('開く'),
          ),
        ),
      ));
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('staff_join_code')), code);
      await tester.tap(find.byKey(const Key('staff_join_submit')));
      await tester.pumpAndSettle();
      expect(StaffShopLinkHolder.value!.shopName, 'タカヤモーター');
    });

    testWidgets('間違ったコードなら理由を出す', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: StaffJoinScreen(service: service, uid: 's1', displayName: 'a'),
      ));
      await tester.enterText(
          find.byKey(const Key('staff_join_code')), 'ZZZZZZ');
      await tester.tap(find.byKey(const Key('staff_join_submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('staff_join_error')), findsOneWidget);
    });
  });
}

/// 画面から返った値を、テストの外側に持ち出すための入れ物。
class StaffShopLinkHolder {
  static StaffShopLink? value;
}
