// 整備明細の一括送付（2026-09-29 プロダクト評価 #4）。
//
// 取り込んだ整備履歴（伝票）のうち、アプリとつながっている客の分を
// 「送っていない明細」として並べ、まとめて送る。送り方は1件ずつの送付と
// 同じ（店から開いたスレッドに、整備明細付きのメッセージを置く）。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/detail_delivery_service.dart';
import 'package:trust_car_platform/services/inquiry_maintenance_importer.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/services/ledger_link_service.dart';
import 'package:trust_car_platform/services/shop_subscription_service.dart';

const _shopId = 'owner1';
const _shopName = 'タカヤモーター';
final _now = DateTime(2026, 9, 28, 10);

void main() {
  late FakeFirebaseFirestore fs;
  late DetailDeliveryService service;

  DetailDeliveryService build(String uid) {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid),
    );
    return DetailDeliveryService(
      firestore: fs,
      linkService: LedgerLinkService(firestore: fs, now: () => _now),
      inquiryService: InquiryService(
        firestore: fs,
        auth: auth,
        subscriptionService: ShopSubscriptionService(firestore: fs),
      ),
      now: () => _now,
    );
  }

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = build(_shopId);
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

  Future<void> slip(
    String id, {
    required String customerId,
    required DateTime date,
    String type = '車検',
    int total = 128000,
    int? mileage,
    String? slipNumber,
    DateTime? sentAt,
  }) =>
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
        'mileage': mileage,
        'maker': 'MINI',
        'model': 'クーパー',
        'externalId': slipNumber,
        'source': 'csv',
        'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 27)),
        if (sentAt != null) 'detailSentAt': Timestamp.fromDate(sentAt),
      });

  Future<List<Map<String, dynamic>>> messagesTo(String userId) async {
    final inquiries = await fs
        .collection('inquiries')
        .where('userId', isEqualTo: userId)
        .get();
    final out = <Map<String, dynamic>>[];
    for (final i in inquiries.docs) {
      final m = await i.reference.collection('messages').get();
      out.addAll(m.docs.map((d) => d.data()));
    }
    return out;
  }

  group('pending（送っていない明細）', () {
    test('アプリとつながっている客の、まだ送っていない伝票だけが並ぶ', () async {
      await customer('c1', '山田太郎', userId: 'app-yamada');
      await customer('c2', '佐藤花子'); // アプリを使っていない
      await slip('r1', customerId: 'c1', date: DateTime(2026, 9, 20));
      await slip('r2', customerId: 'c2', date: DateTime(2026, 9, 21));
      await slip('r3',
          customerId: 'c1',
          date: DateTime(2026, 9, 1),
          sentAt: DateTime(2026, 9, 2));

      final list = (await service.pending(shopId: _shopId)).valueOrNull!;
      expect(list.drafts.map((d) => d.recordId), ['r1']);
      final d = list.drafts.single;
      expect(d.customerName, '山田太郎');
      expect(d.userId, 'app-yamada');
      expect(d.vehicleLabel, 'MINI クーパー');
    });

    test('送付率は「送った入庫 ÷ アプリ利用客の入庫」', () async {
      await customer('c1', '山田太郎', userId: 'app-yamada');
      await customer('c2', '佐藤花子');
      await slip('r1', customerId: 'c1', date: DateTime(2026, 9, 20));
      await slip('r2', customerId: 'c2', date: DateTime(2026, 9, 21));
      await slip('r3',
          customerId: 'c1',
          date: DateTime(2026, 9, 1),
          sentAt: DateTime(2026, 9, 2));

      final list = (await service.pending(shopId: _shopId)).valueOrNull!;
      // 分母は山田さんの2件（佐藤さんはアプリを使っていないので入らない）
      expect(list.linkedRecords, 2);
      expect(list.sentRecords, 1);
      expect(list.rate, 0.5);
    });

    test('新しい入庫から順に並ぶ', () async {
      await customer('c1', '山田太郎', userId: 'app-yamada');
      await slip('old', customerId: 'c1', date: DateTime(2026, 8, 1));
      await slip('new', customerId: 'c1', date: DateTime(2026, 9, 25));
      await slip('mid', customerId: 'c1', date: DateTime(2026, 9, 1));

      final list = (await service.pending(shopId: _shopId)).valueOrNull!;
      expect(list.drafts.map((d) => d.recordId), ['new', 'mid', 'old']);
    });

    test('明細の中身は伝票から組み立てる（種類・金額・走行距離・店名）', () async {
      await customer('c1', '山田太郎', userId: 'app-yamada');
      await slip('r1',
          customerId: 'c1',
          date: DateTime(2026, 9, 20),
          type: 'オイル交換',
          total: 8800,
          mileage: 45500,
          slipNumber: 'S-100');

      final d =
          (await service.pending(shopId: _shopId)).valueOrNull!.drafts.single;
      final p = d.payload(shopName: _shopName);
      expect(p.typeKey, 'oilChange');
      expect(p.title, 'オイル交換');
      expect(p.cost, 8800);
      expect(p.mileageAtService, 45500);
      expect(p.shopName, _shopName);
      expect(p.date, DateTime(2026, 9, 20));
      expect(p.description, '伝票番号 S-100');
    });

    group('Edge Cases', () {
      test('伝票が1件も無ければ空で、率は出さない（null）', () async {
        await customer('c1', '山田太郎', userId: 'app-yamada');
        final list = (await service.pending(shopId: _shopId)).valueOrNull!;
        expect(list.drafts, isEmpty);
        expect(list.linkedRecords, 0);
        expect(list.rate, isNull);
      });

      test('アプリ利用客がいなければ空', () async {
        await customer('c2', '佐藤花子');
        await slip('r2', customerId: 'c2', date: DateTime(2026, 9, 21));
        final list = (await service.pending(shopId: _shopId)).valueOrNull!;
        expect(list.drafts, isEmpty);
        expect(list.rate, isNull);
      });

      test('期間（既定90日）より前の伝票は並べず、率にも入れない', () async {
        await customer('c1', '山田太郎', userId: 'app-yamada');
        await slip('r_old', customerId: 'c1', date: DateTime(2026, 6, 1));
        await slip('r_new', customerId: 'c1', date: DateTime(2026, 9, 1));
        final list = (await service.pending(shopId: _shopId)).valueOrNull!;
        expect(list.drafts.map((d) => d.recordId), ['r_new']);
        expect(list.linkedRecords, 1);
      });

      test('期間0日以下は入力の誤りとして断る', () async {
        final r = await service.pending(shopId: _shopId, days: 0);
        expect(r.isFailure, isTrue);
      });

      test('店IDが空なら断る', () async {
        expect((await service.pending(shopId: '')).isFailure, isTrue);
      });

      test('他の店の伝票は混ざらない', () async {
        await customer('c1', '山田太郎', userId: 'app-yamada');
        await fs
            .collection('shops')
            .doc('other_shop')
            .collection('service_records')
            .doc('rx')
            .set({
          'customerId': 'c1',
          'customerVehicleId': 'v',
          'date': Timestamp.fromDate(DateTime(2026, 9, 20)),
          'type': '車検',
          'totalCost': 1,
        });
        final list = (await service.pending(shopId: _shopId)).valueOrNull!;
        expect(list.drafts, isEmpty);
      });

      test('金額が負・種類が空の壊れた伝票でも落ちない（0円・その他として出す）', () async {
        await customer('c1', '山田太郎', userId: 'app-yamada');
        await fs
            .collection('shops')
            .doc(_shopId)
            .collection('service_records')
            .doc('broken')
            .set({
          'customerId': 'c1',
          'date': Timestamp.fromDate(DateTime(2026, 9, 20)),
        });
        final d =
            (await service.pending(shopId: _shopId)).valueOrNull!.drafts.single;
        final p = d.payload(shopName: _shopName);
        expect(p.cost, 0);
        expect(p.typeKey, 'other');
        expect(p.title, '整備');
      });
    });
  });

  group('sendAll（まとめて送る）', () {
    test('1件ずつの送付と同じスレッド・同じ形のメッセージで届き、送った印が付く', () async {
      await customer('c1', '山田太郎', userId: 'app-yamada');
      await slip('r1', customerId: 'c1', date: DateTime(2026, 9, 20));
      await slip('r2',
          customerId: 'c1', date: DateTime(2026, 9, 1), type: 'オイル交換');
      final drafts =
          (await service.pending(shopId: _shopId)).valueOrNull!.drafts;

      final r = (await service.sendAll(
        shopId: _shopId,
        shopName: _shopName,
        senderId: _shopId,
        drafts: drafts,
      ))
          .valueOrNull!;
      expect(r.sent, 2);
      expect(r.failures, isEmpty);

      // スレッドは1本（店から開いたもの）。同じ人への2件は同じスレッドに入る
      final inquiries = await fs
          .collection('inquiries')
          .where('userId', isEqualTo: 'app-yamada')
          .get();
      expect(inquiries.docs, hasLength(1));
      expect(inquiries.docs.single.data()['openedByShop'], isTrue);

      final msgs = await messagesTo('app-yamada');
      expect(msgs, hasLength(2));
      for (final m in msgs) {
        expect(m['isFromShop'], isTrue);
        expect(m['senderId'], _shopId);
        expect(m['content'], maintenanceDetailMessage);
        expect(m['maintenancePayload'], isA<Map>());
      }

      // 送った印（台帳の取込の印 updatedAt は動かさない）
      final rec = await fs
          .collection('shops')
          .doc(_shopId)
          .collection('service_records')
          .doc('r1')
          .get();
      expect(rec.data()!['detailSentAt'], isA<Timestamp>());
      expect(rec.data()!['detailInquiryId'], inquiries.docs.single.id);
      expect((rec.data()!['updatedAt'] as Timestamp).toDate(),
          DateTime(2026, 9, 27));

      // 一覧から消え、率は 100%
      final after = (await service.pending(shopId: _shopId)).valueOrNull!;
      expect(after.drafts, isEmpty);
      expect(after.rate, 1.0);
    });

    test('前に店から開いたスレッドがあれば、そこに送る（スレッドを増やさない）', () async {
      await customer('c1', '山田太郎', userId: 'app-yamada');
      final existing = (await LedgerLinkService(firestore: fs, now: () => _now)
              .openThread(
                  shopId: _shopId, shopName: _shopName, userId: 'app-yamada'))
          .valueOrNull!;
      await slip('r1', customerId: 'c1', date: DateTime(2026, 9, 20));
      final drafts =
          (await service.pending(shopId: _shopId)).valueOrNull!.drafts;
      await service.sendAll(
          shopId: _shopId,
          shopName: _shopName,
          senderId: _shopId,
          drafts: drafts);

      final inquiries = await fs
          .collection('inquiries')
          .where('userId', isEqualTo: 'app-yamada')
          .get();
      expect(inquiries.docs.single.id, existing.id);
    });

    test('複数の客に、それぞれのスレッドで届く', () async {
      await customer('c1', '山田太郎', userId: 'app-yamada');
      await customer('c3', '鈴木一郎', userId: 'app-suzuki');
      await slip('r1', customerId: 'c1', date: DateTime(2026, 9, 20));
      await slip('r3', customerId: 'c3', date: DateTime(2026, 9, 21));
      final drafts =
          (await service.pending(shopId: _shopId)).valueOrNull!.drafts;
      final r = (await service.sendAll(
              shopId: _shopId,
              shopName: _shopName,
              senderId: _shopId,
              drafts: drafts))
          .valueOrNull!;
      expect(r.sent, 2);
      expect(r.customers, 2);
      expect(await messagesTo('app-yamada'), hasLength(1));
      expect(await messagesTo('app-suzuki'), hasLength(1));
    });

    group('Edge Cases', () {
      test('空のリストなら何もせずに断る', () async {
        final r = await service.sendAll(
            shopId: _shopId,
            shopName: _shopName,
            senderId: _shopId,
            drafts: const []);
        expect(r.isFailure, isTrue);
        expect(await fs.collection('inquiries').get().then((s) => s.size), 0);
      });

      test('送る人が空なら断る', () async {
        await customer('c1', '山田太郎', userId: 'app-yamada');
        await slip('r1', customerId: 'c1', date: DateTime(2026, 9, 20));
        final drafts =
            (await service.pending(shopId: _shopId)).valueOrNull!.drafts;
        final r = await service.sendAll(
            shopId: _shopId, shopName: _shopName, senderId: '', drafts: drafts);
        expect(r.isFailure, isTrue);
      });

      test('一覧を開いたあとに別の人が送った伝票は、二重に送らない', () async {
        await customer('c1', '山田太郎', userId: 'app-yamada');
        await slip('r1', customerId: 'c1', date: DateTime(2026, 9, 20));
        final drafts =
            (await service.pending(shopId: _shopId)).valueOrNull!.drafts;
        // 1回目
        await service.sendAll(
            shopId: _shopId,
            shopName: _shopName,
            senderId: _shopId,
            drafts: drafts);
        // 古い一覧のまま、もう一度
        final r = (await service.sendAll(
                shopId: _shopId,
                shopName: _shopName,
                senderId: _shopId,
                drafts: drafts))
            .valueOrNull!;
        expect(r.sent, 0);
        expect(r.alreadySent, 1);
        expect(await messagesTo('app-yamada'), hasLength(1));
      });

      test('同じ下書きが2回入っていても1回だけ送る', () async {
        await customer('c1', '山田太郎', userId: 'app-yamada');
        await slip('r1', customerId: 'c1', date: DateTime(2026, 9, 20));
        final d =
            (await service.pending(shopId: _shopId)).valueOrNull!.drafts.single;
        final r = (await service.sendAll(
                shopId: _shopId,
                shopName: _shopName,
                senderId: _shopId,
                drafts: [d, d]))
            .valueOrNull!;
        expect(r.sent, 1);
        expect(await messagesTo('app-yamada'), hasLength(1));
      });

      test('スレッドで1件ずつ送った明細と同じ日・同じ金額なら、送らずに送った印だけ付ける', () async {
        await customer('c1', '山田太郎', userId: 'app-yamada');
        await slip('r1',
            customerId: 'c1', date: DateTime(2026, 9, 20), total: 128000);
        // 店がスレッドから手で送っていた
        final thread = (await LedgerLinkService(firestore: fs, now: () => _now)
                .openThread(
                    shopId: _shopId, shopName: _shopName, userId: 'app-yamada'))
            .valueOrNull!;
        await fs
            .collection('inquiries')
            .doc(thread.id)
            .collection('messages')
            .add({
          'senderId': _shopId,
          'isFromShop': true,
          'content': maintenanceDetailMessage,
          'sentAt': Timestamp.fromDate(DateTime(2026, 9, 21)),
          'maintenancePayload': InquiryMaintenancePayload(
            typeKey: 'carInspection',
            title: '24か月点検・車検',
            date: DateTime(2026, 9, 20, 15),
            cost: 128000,
          ).toMap(),
        });

        final drafts =
            (await service.pending(shopId: _shopId)).valueOrNull!.drafts;
        final r = (await service.sendAll(
                shopId: _shopId,
                shopName: _shopName,
                senderId: _shopId,
                drafts: drafts))
            .valueOrNull!;
        expect(r.sent, 0);
        expect(r.alreadySent, 1);
        expect(await messagesTo('app-yamada'), hasLength(1));
        expect((await service.pending(shopId: _shopId)).valueOrNull!.drafts,
            isEmpty);
      });

      test('ログインしている人と送る人が違えば送らず、印も付けない（失敗として返す）', () async {
        await customer('c1', '山田太郎', userId: 'app-yamada');
        await slip('r1', customerId: 'c1', date: DateTime(2026, 9, 20));
        final drafts =
            (await service.pending(shopId: _shopId)).valueOrNull!.drafts;
        final r = (await build('someone_else').sendAll(
                shopId: _shopId,
                shopName: _shopName,
                senderId: _shopId,
                drafts: drafts))
            .valueOrNull!;
        expect(r.sent, 0);
        expect(r.failures, hasLength(1));
        expect(r.failures.single.recordId, 'r1');
        // 一覧に残る（もう一度送れる）
        expect((await service.pending(shopId: _shopId)).valueOrNull!.drafts,
            hasLength(1));
      });

      test('伝票が消されていたら、その分は失敗として返し、他は送る', () async {
        await customer('c1', '山田太郎', userId: 'app-yamada');
        await slip('r1', customerId: 'c1', date: DateTime(2026, 9, 20));
        await slip('r2', customerId: 'c1', date: DateTime(2026, 9, 21));
        final drafts =
            (await service.pending(shopId: _shopId)).valueOrNull!.drafts;
        await fs
            .collection('shops')
            .doc(_shopId)
            .collection('service_records')
            .doc('r1')
            .delete();
        final r = (await service.sendAll(
                shopId: _shopId,
                shopName: _shopName,
                senderId: _shopId,
                drafts: drafts))
            .valueOrNull!;
        expect(r.sent, 1);
        expect(r.failures.map((f) => f.recordId), ['r1']);
      });

      test('進み具合を知らせる', () async {
        await customer('c1', '山田太郎', userId: 'app-yamada');
        await slip('r1', customerId: 'c1', date: DateTime(2026, 9, 20));
        await slip('r2', customerId: 'c1', date: DateTime(2026, 9, 21));
        final drafts =
            (await service.pending(shopId: _shopId)).valueOrNull!.drafts;
        final progress = <(int, int)>[];
        await service.sendAll(
          shopId: _shopId,
          shopName: _shopName,
          senderId: _shopId,
          drafts: drafts,
          onProgress: (done, total) => progress.add((done, total)),
        );
        expect(progress.last, (2, 2));
      });
    });
  });
}
