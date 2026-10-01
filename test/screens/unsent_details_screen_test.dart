// 台帳の「送っていない明細」（2026-09-29 プロダクト評価 #4）。
//
// 画面で確かめたいのは、**率が一覧の上に出ること・選んだものだけが送られる
// こと・送ったものが一覧から消えること・操作の記録に残ること**。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/screens/shop/ledger/customer_ledger_screen.dart';
import 'package:trust_car_platform/screens/shop/ledger/unsent_details_screen.dart';
import 'package:trust_car_platform/services/detail_delivery_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/services/ledger_link_service.dart';
import 'package:trust_car_platform/services/shop_audit_service.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';
import 'package:trust_car_platform/services/shop_subscription_service.dart';

const _shopId = 'owner1';
final _now = DateTime(2026, 9, 28, 10);

class _Audit {
  final ShopAuditAction action;
  final String? targetId;
  final String? detail;
  _Audit(this.action, this.targetId, this.detail);
}

void main() {
  late FakeFirebaseFirestore fs;
  late DetailDeliveryService service;
  late List<_Audit> audits;

  setUp(() {
    fs = FakeFirebaseFirestore();
    audits = [];
    service = DetailDeliveryService(
      firestore: fs,
      linkService: LedgerLinkService(firestore: fs, now: () => _now),
      inquiryService: InquiryService(
        firestore: fs,
        auth:
            MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: _shopId)),
        subscriptionService: ShopSubscriptionService(firestore: fs),
      ),
      now: () => _now,
    );
  });

  Future<void> customer(String id, String name, {String? userId}) =>
      fs.collection('shops').doc(_shopId).collection('customers').doc(id).set({
        'name': name,
        'kind': 'individual',
        'linkedUserId': userId,
        'isLinked': userId != null,
        'createdAt': Timestamp.fromDate(DateTime(2026)),
        'updatedAt': Timestamp.fromDate(DateTime(2026)),
      });

  Future<void> slip(String id, String customerId, DateTime date,
          {String type = '車検', int total = 128000, bool sent = false}) =>
      fs
          .collection('shops')
          .doc(_shopId)
          .collection('service_records')
          .doc(id)
          .set({
        'customerId': customerId,
        'customerVehicleId': 'v_$customerId',
        'date': Timestamp.fromDate(date),
        'type': type,
        'totalCost': total,
        'maker': 'MINI',
        'model': 'クーパー',
        if (sent) 'detailSentAt': Timestamp.fromDate(DateTime(2026, 9, 2)),
      });

  Future<int> messageCount() async {
    var n = 0;
    for (final i in (await fs.collection('inquiries').get()).docs) {
      n += (await i.reference.collection('messages').get()).size;
    }
    return n;
  }

  Widget screen() => MaterialApp(
        home: UnsentDetailsScreen(
          service: service,
          shopId: _shopId,
          shopName: 'タカヤモーター',
          senderUid: _shopId,
          onAudit: (action, {targetId, targetLabel, detail}) =>
              audits.add(_Audit(action, targetId, detail)),
        ),
      );

  testWidgets('明細送付率が一覧の上に出る', (tester) async {
    await customer('c1', '山田太郎', userId: 'app-yamada');
    await customer('c2', '佐藤花子');
    await slip('r1', 'c1', DateTime(2026, 9, 20));
    await slip('r2', 'c1', DateTime(2026, 9, 1), sent: true);
    await slip('r3', 'c2', DateTime(2026, 9, 21));

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail_rate')), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.textContaining('アプリ利用客の入庫 2件のうち 1件'), findsOneWidget);
    // 並ぶのは山田さんの送っていない1件だけ
    expect(find.byKey(const Key('detail_draft_r1')), findsOneWidget);
    expect(find.byKey(const Key('detail_draft_r2')), findsNothing);
    expect(find.byKey(const Key('detail_draft_r3')), findsNothing);
    expect(find.textContaining('山田太郎'), findsOneWidget);
  });

  testWidgets('選んだものだけを送り、送ったものは一覧から消える', (tester) async {
    await customer('c1', '山田太郎', userId: 'app-yamada');
    await customer('c3', '鈴木一郎', userId: 'app-suzuki');
    await slip('r1', 'c1', DateTime(2026, 9, 20));
    await slip('r3', 'c3', DateTime(2026, 9, 21), type: 'オイル交換', total: 8800);

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    // 何も選ばないうちは押せない
    final button = find.byKey(const Key('detail_send_selected'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.byKey(const Key('detail_draft_r1')));
    await tester.pump();
    expect(find.text('まとめて送る（1件）'), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail_send_confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('1件の整備明細を送りました'), findsOneWidget);
    expect(find.byKey(const Key('detail_draft_r1')), findsNothing);
    expect(find.byKey(const Key('detail_draft_r3')), findsOneWidget);
    expect(await messageCount(), 1);

    // 操作の記録（1件ずつの送付と同じ「整備明細を送った」）
    expect(audits, hasLength(1));
    expect(audits.single.action, ShopAuditAction.sendDetail);
    expect(audits.single.targetId, 'c1');
    expect(audits.single.detail, contains('まとめて'));
  });

  testWidgets('すべて選ぶ → まとめて送る', (tester) async {
    await customer('c1', '山田太郎', userId: 'app-yamada');
    await slip('r1', 'c1', DateTime(2026, 9, 20));
    await slip('r2', 'c1', DateTime(2026, 9, 10));

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail_select_all')));
    await tester.pump();
    expect(find.text('まとめて送る（2件）'), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail_send_selected')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1人のお客さん'), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail_send_confirm')));
    await tester.pumpAndSettle();

    expect(await messageCount(), 2);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('送っていない明細はありません'), findsOneWidget);
    // 1人に2件送っても、記録は1人1行
    expect(audits, hasLength(1));
    expect(audits.single.detail, contains('2件'));
  });

  testWidgets('確認でやめたら送らない', (tester) async {
    await customer('c1', '山田太郎', userId: 'app-yamada');
    await slip('r1', 'c1', DateTime(2026, 9, 20));

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail_draft_r1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('detail_send_selected')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('やめる'));
    await tester.pumpAndSettle();

    expect(await messageCount(), 0);
    expect(find.byKey(const Key('detail_draft_r1')), findsOneWidget);
    expect(audits, isEmpty);
  });

  group('Edge Cases', () {
    testWidgets('アプリ利用客の入庫が無ければ、率は「—」で、0% と見せない', (tester) async {
      await customer('c2', '佐藤花子');
      await slip('r3', 'c2', DateTime(2026, 9, 21));

      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      expect(find.text('送っていない明細はありません'), findsOneWidget);
    });

    testWidgets('読み込みに失敗したら、もう一度を出す', (tester) async {
      final broken = DetailDeliveryService(
        firestore: fs,
        linkService: LedgerLinkService(firestore: fs),
        inquiryService: InquiryService(
          firestore: fs,
          auth: MockFirebaseAuth(),
          subscriptionService: ShopSubscriptionService(firestore: fs),
        ),
      );
      await tester.pumpWidget(MaterialApp(
        home: UnsentDetailsScreen(
          service: broken,
          shopId: '', // 店が分からない → 失敗
          shopName: 'タカヤモーター',
          senderUid: _shopId,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('読み込めませんでした'), findsOneWidget);
      expect(find.text('もう一度'), findsOneWidget);
    });
  });

  group('台帳からの入口', () {
    Widget ledger({DetailDeliveryService? delivery, String? uid}) =>
        MaterialApp(
          home: CustomerLedgerScreen(
            service: ShopLedgerService(firestore: fs, now: () => _now),
            deliveryService: delivery,
            currentUid: uid,
            shopId: _shopId,
            shopName: 'タカヤモーター',
            today: _now,
          ),
        );

    testWidgets('送る仕組みを渡したときだけ入口が出て、開ける', (tester) async {
      await tester.pumpWidget(ledger());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ledger_unsent_details')), findsNothing);

      await tester.pumpWidget(ledger(delivery: service, uid: _shopId));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ledger_unsent_details')));
      await tester.pumpAndSettle();
      expect(find.byType(UnsentDetailsScreen), findsOneWidget);
    });
  });
}
