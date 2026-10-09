// "送った明細" on the shop's customer page (usability test 2026-10-09,
// shop #10): whether each sent detail arrived and was added to the records.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/detail_delivery_service.dart';
import 'package:trust_car_platform/services/inquiry_maintenance_importer.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/services/ledger_link_service.dart';
import 'package:trust_car_platform/services/shop_subscription_service.dart';
import 'package:trust_car_platform/widgets/shop/sent_details_section.dart';

void main() {
  late FakeFirebaseFirestore fs;
  late DetailDeliveryService service;

  setUp(() async {
    fs = FakeFirebaseFirestore();
    service = DetailDeliveryService(
      firestore: fs,
      linkService: LedgerLinkService(firestore: fs),
      inquiryService: InquiryService(
        firestore: fs,
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'o')),
        subscriptionService: ShopSubscriptionService(firestore: fs),
      ),
    );
    await fs.collection('inquiries').doc('inq1').set({
      'userId': 'user1',
      'shopId': 'shop1',
      'shopName': 'タカヤモーター',
      'type': 'general',
      'status': 'replied',
      'subject': '整備明細のお届け',
      'initialMessage': '',
      'openedByShop': true,
      'createdAt': Timestamp.fromDate(DateTime(2026, 10)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 8)),
    });
  });

  Future<void> sent(String id, int cost,
          {bool read = false, bool imported = false}) =>
      fs
          .collection('inquiries')
          .doc('inq1')
          .collection('messages')
          .doc(id)
          .set({
        'senderId': 'o',
        'isFromShop': true,
        'content': maintenanceDetailMessage,
        'sentAt': Timestamp.fromDate(DateTime(2026, 10, 8, 10)),
        'isRead': read,
        if (imported) 'importedAt': Timestamp.fromDate(DateTime(2026, 10, 9)),
        'maintenancePayload': InquiryMaintenancePayload(
          typeKey: 'oilChange',
          title: 'オイル交換',
          date: DateTime(2026, 10, 8),
          cost: cost,
          vehicleLabel: 'トヨタ ハイエース',
        ).toMap(),
      });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          SentDetailsSection(
              shopId: 'shop1', userId: 'user1', service: service),
        ]),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('送った明細ごとに「届いた／開いた／記録に追加済み」が出る', (tester) async {
    await sent('m1', 5500, imported: true, read: true);
    await sent('m2', 2640, read: true);
    await sent('m3', 1100);
    await pump(tester);

    expect(find.text('送った明細（3件）'), findsOneWidget);
    expect(find.text('記録に追加済み（10/9）'), findsOneWidget);
    expect(find.text('お客さんが開きました'), findsOneWidget);
    expect(find.text('届いています（未読）'), findsOneWidget);
    expect(find.text('オイル交換・¥2,640'), findsOneWidget);
  });

  group('Edge Cases', () {
    testWidgets('まだ送っていなければその旨を出す', (tester) async {
      await pump(tester);
      expect(find.text('まだ明細を送っていません。'), findsOneWidget);
    });

    testWidgets('サービスが無ければ何も出さない', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SentDetailsSection(shopId: 'shop1', userId: 'user1'),
        ),
      ));
      expect(find.byKey(const Key('sent_details_section')), findsNothing);
    });
  });
}
