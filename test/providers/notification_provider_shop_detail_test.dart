// Shop-sent maintenance details in the notifications (usability test
// 2026-10-09, shop #14): the bell had 21 items, all inspection suggestions,
// and none said a detail had arrived.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/app_notification.dart';
import 'package:trust_car_platform/providers/notification_provider.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/services/inquiry_maintenance_importer.dart';
import 'package:trust_car_platform/services/notification_state_store.dart';
import 'package:trust_car_platform/services/recommendation_service.dart';
import 'package:trust_car_platform/services/shop_detail_inbox_service.dart';

class _Firebase implements FirebaseService {
  final String? uid;
  _Firebase(this.uid);

  @override
  String? get currentUserId => uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MemoryStore implements NotificationStateStore {
  Set<String> read = {};
  Set<String> dismissed = {};
  @override
  Future<Set<String>> loadReadIds() async => {...read};
  @override
  Future<void> saveReadIds(Set<String> ids) async => read = {...ids};
  @override
  Future<Set<String>> loadDismissedIds() async => {...dismissed};
  @override
  Future<void> saveDismissedIds(Set<String> ids) async => dismissed = {...ids};
}

void main() {
  late FakeFirebaseFirestore fs;
  late _MemoryStore store;

  NotificationProvider build({String? uid = 'user1', bool withInbox = true}) =>
      NotificationProvider(
        firebaseService: _Firebase(uid),
        recommendationService: RecommendationService(),
        stateStore: store,
        detailInbox: withInbox ? ShopDetailInboxService(firestore: fs) : null,
      );

  Future<void> seedDetail(String messageId, {int cost = 16500}) async {
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
    await fs
        .collection('inquiries')
        .doc('inq1')
        .collection('messages')
        .doc(messageId)
        .set({
      'senderId': 'owner',
      'isFromShop': true,
      'content': maintenanceDetailMessage,
      'sentAt': Timestamp.fromDate(DateTime(2026, 10, 8, 12)),
      'isRead': false,
      'maintenancePayload': InquiryMaintenancePayload(
        typeKey: 'oilChange',
        title: 'オイル交換',
        date: DateTime(2026, 10, 8),
        cost: cost,
        vehicleLabel: 'トヨタ ハイエース',
      ).toMap(),
    });
  }

  setUp(() {
    fs = FakeFirebaseFirestore();
    store = _MemoryStore();
  });

  test('届いた明細が通知の先頭に出る（店の名前と車名つき）', () async {
    await seedDetail('m1');
    final p = build();
    await p.refreshShopDetails();

    expect(p.pendingShopDetails, hasLength(1));
    final n = p.notifications.first;
    expect(n.title, 'タカヤモーターから整備明細が届きました');
    expect(n.message, contains('トヨタ ハイエース'));
    expect(n.message, contains('¥16,500'));
    expect(n.metadata?['kind'], 'shopDetail');
    expect(n.metadata?['inquiryId'], 'inq1');
    expect(n.metadata?['messageId'], 'm1');
    expect(p.unreadCount, 1);
  });

  test('通知から元の明細（スレッド）を引ける', () async {
    await seedDetail('m1');
    final p = build();
    await p.refreshShopDetails();
    final d = p.shopDetailFor(p.notifications.first);
    expect(d?.inquiry.id, 'inq1');
    expect(d?.message.id, 'm1');
  });

  test('明細の通知はホームの「提案」には混ざらない', () async {
    await seedDetail('m1');
    final p = build();
    await p.refreshShopDetails();
    expect(p.topSuggestions, isEmpty);
  });

  test('既読は保存され、読み直しても既読のまま', () async {
    await seedDetail('m1');
    final p = build();
    await p.refreshShopDetails();
    await p.markAsRead(p.notifications.first.id);

    final again = build();
    await again.refreshShopDetails();
    expect(again.notifications.first.isRead, isTrue);
  });

  test('記録に追加すると、次に読み直したとき通知から消える', () async {
    await seedDetail('m1');
    final p = build();
    await p.refreshShopDetails();
    await fs
        .collection('inquiries')
        .doc('inq1')
        .collection('messages')
        .doc('m1')
        .update({'importedAt': Timestamp.fromDate(DateTime(2026, 10, 9))});
    await p.refreshShopDetails();
    expect(p.pendingShopDetails, isEmpty);
    expect(p.notifications, isEmpty);
  });

  test('おすすめの再生成で、明細の通知が消えない', () async {
    await seedDetail('m1');
    final p = build();
    await p.refreshShopDetails();
    await p.generateRecommendations(vehicles: const [], maintenanceRecords: {});
    expect(p.notifications.where((n) => n.metadata?['kind'] == 'shopDetail'),
        hasLength(1));
  });

  group('Edge Cases', () {
    test('明細以外の通知からは引けない（null）', () async {
      final p = build();
      final other = AppNotification(
        id: 'x',
        userId: 'user1',
        type: NotificationType.system,
        title: 't',
        message: 'm',
        createdAt: DateTime(2026),
      );
      expect(p.shopDetailFor(other), isNull);
    });

    test('明細の仕組みが無ければ何もしない', () async {
      await seedDetail('m1');
      final p = build(withInbox: false);
      await p.refreshShopDetails();
      expect(p.pendingShopDetails, isEmpty);
    });

    test('ログインしていなければ何もしない', () async {
      await seedDetail('m1');
      final p = build(uid: null);
      await p.refreshShopDetails();
      expect(p.pendingShopDetails, isEmpty);
    });

    test('削除した明細の通知は戻らないが、ホームの件数には残る', () async {
      await seedDetail('m1');
      final p = build();
      await p.refreshShopDetails();
      p.removeNotification(p.notifications.first.id);
      await p.refreshShopDetails();
      expect(p.notifications, isEmpty);
      expect(p.pendingShopDetails, hasLength(1));
    });

    test('ログアウトで明細も消える', () async {
      await seedDetail('m1');
      final p = build();
      await p.refreshShopDetails();
      p.clear();
      expect(p.pendingShopDetails, isEmpty);
      expect(p.notifications, isEmpty);
    });

    test('種類は system（既存の画面の switch を増やさない）', () async {
      await seedDetail('m1');
      final p = build();
      await p.refreshShopDetails();
      expect(p.notifications.first.type, NotificationType.system);
      expect(p.notifications.first.priority, NotificationPriority.high);
    });
  });
}
