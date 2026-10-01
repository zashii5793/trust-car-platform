// 顧客台帳から、アプリを使っているお客さんに車検案内を送る
// （2026-09-29 プロダクト評価 #2 の「アプリ有り」の側）。
//
// 送るのはサーバー（Cloud Functions）。ここで確かめたいのは、
// **アプリとつながっている客の車だけを依頼に入れること・操作の記録に
// 残ること・サーバーの結果を見せること**。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/models/shop_ledger.dart';
import 'package:trust_car_platform/screens/shop/ledger/customer_ledger_screen.dart';
import 'package:trust_car_platform/services/inspection_push_service.dart';
import 'package:trust_car_platform/services/shop_audit_service.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';

const _shopId = 'shop_1';
final _today = DateTime(2026, 9, 27);

void main() {
  late FakeFirebaseFirestore fs;
  late ShopLedgerService service;
  late List<ShopAuditAction> audits;

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = ShopLedgerService(firestore: fs, now: () => _today);
    audits = [];
  });

  Widget build({bool withPush = true, String? uid = 'staff_uid'}) {
    return MaterialApp(
      home: CustomerLedgerScreen(
        service: service,
        pushService: withPush ? InspectionPushService(firestore: fs) : null,
        currentUid: uid,
        shopId: _shopId,
        shopName: 'テスト工場',
        today: _today,
        onAudit: (action, {targetId, targetLabel, detail}) =>
            audits.add(action),
      ),
    );
  }

  Future<LedgerCustomer> add(String name, {String? linkedUid}) async {
    final c = (await service.createCustomer(
      shopId: _shopId,
      kind: LedgerCustomerKind.individual,
      name: name,
    ))
        .valueOrNull!;
    if (linkedUid != null) {
      await fs
          .doc('shops/$_shopId/customers/${c.id}')
          .update({'linkedUserId': linkedUid, 'isLinked': true});
    }
    return c;
  }

  Future<LedgerVehicle> car(
      LedgerCustomer c, String model, DateTime exp) async {
    return (await service.saveVehicle(
      shopId: _shopId,
      customerId: c.id,
      maker: 'トヨタ',
      model: model,
      inspectionExpiry: exp,
    ))
        .valueOrNull!;
  }

  Future<List<Map<String, dynamic>>> notices() async =>
      (await fs.collection('shops/$_shopId/inspection_notices').get())
          .docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

  /// 送信中の進み具合（止まらないアニメーション）が出ている間は
  /// pumpAndSettle が終わらないので、数フレームだけ進める。
  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openSend(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('ledger_more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('アプリに車検案内を送る'));
    await tester.pumpAndSettle();
  }

  testWidgets('アプリとつながっている客の車だけを依頼に入れ、記録に残し、結果を見せる', (tester) async {
    final app = await add('アプリの人', linkedUid: 'u1');
    final near = await car(app, '近い', DateTime(2026, 10, 20));
    await car(app, '遠い', DateTime(2027, 3, 1));
    final paper = await add('はがきの人');
    await car(paper, 'はがき', DateTime(2026, 10, 21));

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    await openSend(tester);
    await tester.tap(find.byKey(const Key('ledger_app_notice_next')));
    await tester.pumpAndSettle();

    // 何台・何人に送るか、除く車を先に見せる
    expect(find.textContaining('1台（1人）'), findsOneWidget);
    expect(find.textContaining('アプリを使っていない1台'), findsOneWidget);
    expect(await notices(), isEmpty);

    await tester.tap(find.byKey(const Key('ledger_app_notice_confirm')));
    await pumpFrames(tester);

    final list = await notices();
    expect(list, hasLength(1));
    expect(list.single['vehicleIds'], [near.id]);
    expect(list.single['requesterUid'], 'staff_uid');
    expect(list.single['status'], 'pending');
    expect(audits, [ShopAuditAction.sendInspectionPush]);
    expect(find.text('送っています。閉じても送信は続きます。'), findsOneWidget);

    // サーバーが結果を書く
    await fs
        .doc('shops/$_shopId/inspection_notices/${list.single['id']}')
        .update({
      'status': 'done',
      'result': {'sent': 0, 'pushOff': 1},
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ledger_app_notice_result')), findsOneWidget);
    expect(find.textContaining('1台のうち0台に案内を送りました'), findsOneWidget);
    expect(find.textContaining('通知を切っている1台'), findsOneWidget);
    // 届かなかった人は、はがきで案内できると知らせる
    expect(find.textContaining('はがきの宛名の書き出し'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ledger_app_notice_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ledger_app_notice_result')), findsNothing);
  });

  testWidgets('期間を3か月にすると、その先の車も入る', (tester) async {
    final app = await add('アプリの人', linkedUid: 'u1');
    await car(app, '近い', DateTime(2026, 10, 20));
    await car(app, '12月', DateTime(2026, 12, 20));

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    await openSend(tester);
    await tester.tap(find.byKey(const Key('ledger_app_notice_months_3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ledger_app_notice_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ledger_app_notice_confirm')));
    await pumpFrames(tester);

    expect((await notices()).single['vehicleIds'], hasLength(2));
  });

  group('Edge Cases', () {
    testWidgets('送る仕組みか、依頼する人が無ければ入口を出さない', (tester) async {
      await tester.pumpWidget(build(withPush: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ledger_more')));
      await tester.pumpAndSettle();
      expect(find.text('アプリに車検案内を送る'), findsNothing);
      // はがきの書き出しは残る
      expect(find.text('車検案内の宛名を書き出す'), findsOneWidget);

      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await tester.pumpWidget(build(uid: null));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ledger_more')));
      await tester.pumpAndSettle();
      expect(find.text('アプリに車検案内を送る'), findsNothing);
    });

    testWidgets('アプリの客の車が無ければ、依頼も記録もしない', (tester) async {
      final paper = await add('はがきの人');
      await car(paper, 'はがき', DateTime(2026, 10, 21));

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      await openSend(tester);
      await tester.tap(find.byKey(const Key('ledger_app_notice_next')));
      await tester.pumpAndSettle();

      expect(find.textContaining('アプリを使っているお客さんの車はありません'), findsOneWidget);
      expect(await notices(), isEmpty);
      expect(audits, isEmpty);
    });

    testWidgets('確かめる画面でやめたら、依頼も記録もしない', (tester) async {
      final app = await add('アプリの人', linkedUid: 'u1');
      await car(app, '近い', DateTime(2026, 10, 20));

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      await openSend(tester);
      await tester.tap(find.byKey(const Key('ledger_app_notice_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('やめる'));
      await tester.pumpAndSettle();

      expect(await notices(), isEmpty);
      expect(audits, isEmpty);
    });

    testWidgets('案内済みの車は入れない（はがきで出した車にも二重に送らない）', (tester) async {
      final app = await add('アプリの人', linkedUid: 'u1');
      final v = await car(app, '近い', DateTime(2026, 10, 20));
      await service.markInspectionNoticed(shopId: _shopId, vehicles: [v]);

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      await openSend(tester);
      await tester.tap(find.byKey(const Key('ledger_app_notice_next')));
      await tester.pumpAndSettle();

      expect(find.textContaining('案内済みの1台'), findsOneWidget);
      expect(await notices(), isEmpty);
    });

    testWidgets('サーバーが失敗を書いたら、そう見せる', (tester) async {
      final app = await add('アプリの人', linkedUid: 'u1');
      await car(app, '近い', DateTime(2026, 10, 20));

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      await openSend(tester);
      await tester.tap(find.byKey(const Key('ledger_app_notice_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ledger_app_notice_confirm')));
      await pumpFrames(tester);

      final id = (await notices()).single['id'];
      await fs
          .doc('shops/$_shopId/inspection_notices/$id')
          .update({'status': 'failed'});
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ledger_app_notice_failed')), findsOneWidget);
    });
  });
}
