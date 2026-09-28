import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/shop_ledger.dart';
import 'package:trust_car_platform/screens/shop/ledger/customer_detail_screen.dart';
import 'package:trust_car_platform/services/ledger_link_service.dart';
import 'package:trust_car_platform/services/shop_invite_service.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';

/// 台帳の顧客とアプリの利用者をつなぎ、整備明細を送る。
void main() {
  late FakeFirebaseFirestore fs;
  late ShopLedgerService ledger;
  late ShopInviteService invites;
  late LedgerLinkService links;
  final now = DateTime(2026, 9, 28);
  const shopId = 'owner1';

  setUp(() {
    fs = FakeFirebaseFirestore();
    ledger = ShopLedgerService(firestore: fs, now: () => now);
    invites = ShopInviteService(firestore: fs, now: () => now);
    links = LedgerLinkService(firestore: fs, now: () => now);
  });

  Future<LedgerCustomer> customer() async => (await ledger.createCustomer(
        shopId: shopId,
        kind: LedgerCustomerKind.individual,
        name: '山田太郎',
      ))
          .valueOrNull!;

  test('専用コードを使ってもらうと、台帳の顧客がアプリの利用者とつながる', () async {
    final c = await customer();
    final invite = (await invites.createInvite(
      shopId: shopId,
      shopName: 'タカヤモーター',
      shopOwnerId: shopId,
      maxUses: 1,
      customerId: c.id,
    ))
        .valueOrNull!;
    // まだ使われていない
    expect((await links.syncLink(shopId: shopId, customerId: c.id)).valueOrNull,
        isNull);

    final link = (await invites.redeem(code: invite.code, userId: 'app-user-1'))
        .valueOrNull!;
    expect(link.customerId, c.id);
    expect(link.inviteCode, invite.code);

    final uid =
        (await links.syncLink(shopId: shopId, customerId: c.id)).valueOrNull;
    expect(uid, 'app-user-1');
    final after = (await ledger.getCustomer(shopId: shopId, customerId: c.id))
        .valueOrNull!;
    expect(after.isLinked, isTrue);
    expect(after.linkedUserId, 'app-user-1');
    expect((await ledger.counts(shopId)).valueOrNull!.linked, 1);
  });

  test('店に置く共通のコード（顧客宛てでない）では、台帳の誰にもつながらない', () async {
    final c = await customer();
    final invite = (await invites.createInvite(
      shopId: shopId,
      shopName: 'タカヤモーター',
      shopOwnerId: shopId,
    ))
        .valueOrNull!;
    final link =
        (await invites.redeem(code: invite.code, userId: 'u9')).valueOrNull!;
    expect(link.customerId, isNull);
    expect((await links.syncLink(shopId: shopId, customerId: c.id)).valueOrNull,
        isNull);
  });

  group('openThread', () {
    test('店から開いたスレッドは、お客さんの側に未読が付く', () async {
      final inquiry = (await links.openThread(
        shopId: shopId,
        shopName: 'タカヤモーター',
        userId: 'app-user-1',
      ))
          .valueOrNull!;
      expect(inquiry.subject, '整備明細のお届け');
      expect(inquiry.unreadCountUser, 1);
      expect(inquiry.unreadCountShop, 0);
      final doc =
          (await fs.collection('inquiries').doc(inquiry.id).get()).data()!;
      expect(doc['openedByShop'], isTrue);
    });

    test('2回目は、前に開いたスレッドを使う（増やさない）', () async {
      final a = (await links.openThread(
        shopId: shopId,
        shopName: 'x',
        userId: 'app-user-1',
      ))
          .valueOrNull!;
      final b = (await links.openThread(
        shopId: shopId,
        shopName: 'x',
        userId: 'app-user-1',
      ))
          .valueOrNull!;
      expect(b.id, a.id);
      expect((await fs.collection('inquiries').get()).docs, hasLength(1));
    });
  });

  group('顧客詳細の画面', () {
    Future<void> pump(WidgetTester tester, String customerId) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: CustomerDetailScreen(
          service: ledger,
          shopId: shopId,
          customerId: customerId,
          today: now,
          linkService: links,
          inviteService: invites,
          shopName: 'タカヤモーター',
          ownerUid: shopId,
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('つながっていなければ、専用コードを出せる', (tester) async {
      final c = await customer();
      await pump(tester, c.id);
      expect(find.byKey(const Key('customer_send_detail')), findsNothing);

      await tester.tap(find.byKey(const Key('customer_issue_invite')));
      await tester.pumpAndSettle();
      final code = tester
          .widget<SelectableText>(find.byKey(const Key('customer_invite_code')))
          .data!;
      final invite = (await invites.findByCode(code)).valueOrNull!;
      expect(invite.customerId, c.id);
      expect(invite.maxUses, 1);
    });

    testWidgets('コードが使われていれば、開いたときにつながり、明細を送れる', (tester) async {
      final c = await customer();
      final invite = (await invites.createInvite(
        shopId: shopId,
        shopName: 'タカヤモーター',
        shopOwnerId: shopId,
        customerId: c.id,
      ))
          .valueOrNull!;
      await invites.redeem(code: invite.code, userId: 'app-user-1');

      await pump(tester, c.id);
      expect(find.text('利用中'), findsOneWidget);
      expect(find.byKey(const Key('customer_send_detail')), findsOneWidget);
    });

    testWidgets('部品を渡さない（スタッフが開いた）ときは、どちらも出さない', (tester) async {
      final c = await customer();
      await tester.pumpWidget(MaterialApp(
        home: CustomerDetailScreen(
          service: ledger,
          shopId: shopId,
          customerId: c.id,
          today: now,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('customer_issue_invite')), findsNothing);
      expect(find.byKey(const Key('customer_send_detail')), findsNothing);
    });
  });
}
