// Home card for shop-sent details (usability test 2026-10-09, shop #14).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/providers/notification_provider.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/services/inquiry_maintenance_importer.dart';
import 'package:trust_car_platform/services/recommendation_service.dart';
import 'package:trust_car_platform/services/shop_detail_inbox_service.dart';
import 'package:trust_car_platform/widgets/home/shop_detail_inbox_card.dart';

class _Firebase implements FirebaseService {
  @override
  String? get currentUserId => 'user1';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late FakeFirebaseFirestore fs;

  setUp(() async {
    fs = FakeFirebaseFirestore();
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

  Future<void> detail(String id, int cost, DateTime sentAt) => fs
          .collection('inquiries')
          .doc('inq1')
          .collection('messages')
          .doc(id)
          .set({
        'senderId': 'owner',
        'isFromShop': true,
        'content': maintenanceDetailMessage,
        'sentAt': Timestamp.fromDate(sentAt),
        'isRead': false,
        'maintenancePayload': InquiryMaintenancePayload(
          typeKey: 'oilChange',
          title: 'ワイパー交換',
          date: DateTime(2026, 10, 8),
          cost: cost,
          vehicleLabel: 'トヨタ ハイエース',
        ).toMap(),
      });

  Future<List<String>> pump(WidgetTester tester) async {
    final opened = <String>[];
    final provider = NotificationProvider(
      firebaseService: _Firebase(),
      recommendationService: const RecommendationService(),
      detailInbox: ShopDetailInboxService(firestore: fs),
    );
    await tester.pumpWidget(ChangeNotifierProvider<NotificationProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(
          body: ShopDetailInboxCard(
            onOpenDetail: (_, d) => opened.add(d.message.id),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    return opened;
  }

  testWidgets('未取り込みの件数と、店の名前・車名・金額が出る', (tester) async {
    await detail('m1', 2640, DateTime(2026, 10, 8, 9));
    await detail('m2', 5500, DateTime(2026, 10, 8, 11));
    await pump(tester);

    expect(find.text('店から届いた明細（未取り込み 2件）'), findsOneWidget);
    expect(find.text('タカヤモーター：トヨタ ハイエース・ワイパー交換・¥5,500'), findsOneWidget);
  });

  testWidgets('1件なら押すとその明細を開く', (tester) async {
    await detail('m1', 2640, DateTime(2026, 10, 8, 9));
    final opened = await pump(tester);

    await tester.tap(find.byKey(const Key('home_shop_detail_card')));
    await tester.pumpAndSettle();
    expect(opened, ['m1']);
  });

  testWidgets('2件以上なら一覧から選んで開く', (tester) async {
    await detail('m1', 2640, DateTime(2026, 10, 8, 9));
    await detail('m2', 5500, DateTime(2026, 10, 8, 11));
    final opened = await pump(tester);

    await tester.tap(find.byKey(const Key('home_shop_detail_card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_shop_detail_m1')));
    await tester.pumpAndSettle();
    expect(opened, ['m1']);
  });

  group('Edge Cases', () {
    testWidgets('明細が無ければ何も出さない', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('home_shop_detail_card')), findsNothing);
    });

    testWidgets('記録に追加済みの明細は数えない', (tester) async {
      await detail('m1', 2640, DateTime(2026, 10, 8, 9));
      await fs
          .collection('inquiries')
          .doc('inq1')
          .collection('messages')
          .doc('m1')
          .update({'importedAt': Timestamp.fromDate(DateTime(2026, 10, 9))});
      await pump(tester);
      expect(find.byKey(const Key('home_shop_detail_card')), findsNothing);
    });
  });
}
