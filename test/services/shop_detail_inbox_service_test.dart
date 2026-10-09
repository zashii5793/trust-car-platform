// Maintenance details a shop sent to the user (usability test 2026-10-09,
// shop #9, #10, #14, #15).
//
// - Adding a detail to the records is idempotent: the same message never
//   becomes two records, even when the thread is reopened or the button is
//   pressed from two devices.
// - The "added" state is kept on the message (the shop reads it) and on the
//   record (sourceMessageId), so reopening the thread still shows it.
// - Details not yet added are listed for the home card and the notifications.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/services/inquiry_maintenance_importer.dart';
import 'package:trust_car_platform/services/shop_detail_inbox_service.dart';

const _uid = 'user1';
const _shopId = 'shop1';
final _now = DateTime(2026, 10, 9, 10);

void main() {
  late FakeFirebaseFirestore fs;
  late ShopDetailInboxService service;

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = ShopDetailInboxService(firestore: fs, now: () => _now);
  });

  InquiryMaintenancePayload payload({int cost = 16500, String? label}) =>
      InquiryMaintenancePayload(
        typeKey: 'oilChange',
        title: 'オイル交換',
        date: DateTime(2026, 10, 8),
        cost: cost,
        shopName: 'タカヤモーター',
        vehicleLabel: label,
      );

  Future<void> inquiry(
    String id, {
    String userId = _uid,
    bool openedByShop = true,
    int detailCount = 0,
    DateTime? updatedAt,
  }) =>
      fs.collection('inquiries').doc(id).set({
        'userId': userId,
        'shopId': _shopId,
        'shopName': 'タカヤモーター',
        'type': 'general',
        'status': 'replied',
        'subject': '整備明細のお届け',
        'initialMessage': '',
        'openedByShop': openedByShop,
        'detailCount': detailCount,
        'createdAt': Timestamp.fromDate(DateTime(2026, 10)),
        'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime(2026, 10, 8)),
      });

  Future<void> message(
    String inquiryId,
    String id, {
    InquiryMaintenancePayload? detail,
    bool isFromShop = true,
    DateTime? sentAt,
    DateTime? importedAt,
  }) =>
      fs
          .collection('inquiries')
          .doc(inquiryId)
          .collection('messages')
          .doc(id)
          .set({
        'senderId': isFromShop ? 'owner' : _uid,
        'isFromShop': isFromShop,
        'content': maintenanceDetailMessage,
        'sentAt': Timestamp.fromDate(sentAt ?? DateTime(2026, 10, 8, 12)),
        'isRead': false,
        if (detail != null) 'maintenancePayload': detail.toMap(),
        if (importedAt != null) 'importedAt': Timestamp.fromDate(importedAt),
      });

  Future<List<Map<String, dynamic>>> records() async =>
      (await fs.collection('maintenance_records').get())
          .docs
          .map((d) => d.data())
          .toList();

  Future<Map<String, dynamic>> messageData(String inquiryId, String id) async =>
      (await fs
              .collection('inquiries')
              .doc(inquiryId)
              .collection('messages')
              .doc(id)
              .get())
          .data()!;

  group('importDetail', () {
    test('記録を1件作り、メッセージに取り込み済みの印を付ける', () async {
      await inquiry('inq1');
      await message('inq1', 'm1', detail: payload());

      final r = await service.importDetail(
        userId: _uid,
        inquiryId: 'inq1',
        messageId: 'm1',
        payload: payload(),
        vehicleId: 'car4',
      );

      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull!.alreadyImported, isFalse);
      final rs = await records();
      expect(rs, hasLength(1));
      expect(rs.single['userId'], _uid);
      expect(rs.single['vehicleId'], 'car4');
      expect(rs.single['inquiryId'], 'inq1');
      expect(rs.single['sourceMessageId'], 'm1');
      expect(rs.single['cost'], 16500);

      final m = await messageData('inq1', 'm1');
      expect(m['importedAt'], isA<Timestamp>());
      expect(m['importedRecordId'], r.valueOrNull!.recordId);
    });

    test('同じ明細を2回取り込んでも記録は1件（2回目は既存を返す）', () async {
      await inquiry('inq1');
      await message('inq1', 'm1', detail: payload());

      final first = await service.importDetail(
        userId: _uid,
        inquiryId: 'inq1',
        messageId: 'm1',
        payload: payload(),
        vehicleId: 'car4',
      );
      final second = await service.importDetail(
        userId: _uid,
        inquiryId: 'inq1',
        messageId: 'm1',
        payload: payload(),
        vehicleId: 'car1',
      );

      expect(second.isSuccess, isTrue);
      expect(second.valueOrNull!.alreadyImported, isTrue);
      expect(second.valueOrNull!.recordId, first.valueOrNull!.recordId);
      expect(await records(), hasLength(1));
      expect((await records()).single['vehicleId'], 'car4');
    });

    test('同じスレッドの別の明細は別の記録になる', () async {
      await inquiry('inq1');
      await message('inq1', 'm1', detail: payload());
      await message('inq1', 'm2', detail: payload(cost: 2640));

      for (final (id, cost) in [('m1', 16500), ('m2', 2640)]) {
        await service.importDetail(
          userId: _uid,
          inquiryId: 'inq1',
          messageId: id,
          payload: payload(cost: cost),
          vehicleId: 'car4',
        );
      }
      expect(await records(), hasLength(2));
    });

    test('印の無い以前の取り込み（同じ日・金額・作業）も取り込み済みとみなす', () async {
      await inquiry('inq1');
      await message('inq1', 'm1', detail: payload());
      await fs.collection('maintenance_records').add({
        'userId': _uid,
        'vehicleId': 'car4',
        'inquiryId': 'inq1',
        'type': 'oilChange',
        'title': 'オイル交換',
        'cost': 16500,
        'date': Timestamp.fromDate(DateTime(2026, 10, 8)),
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 8)),
      });

      final r = await service.importDetail(
        userId: _uid,
        inquiryId: 'inq1',
        messageId: 'm1',
        payload: payload(),
        vehicleId: 'car4',
      );
      expect(r.valueOrNull!.alreadyImported, isTrue);
      expect(await records(), hasLength(1));
    });

    group('Edge Cases', () {
      test('空の ID は取り込まない', () async {
        for (final args in [
          ('', 'inq1', 'm1', 'car4'),
          (_uid, '', 'm1', 'car4'),
          (_uid, 'inq1', '', 'car4'),
          (_uid, 'inq1', 'm1', ''),
        ]) {
          final r = await service.importDetail(
            userId: args.$1,
            inquiryId: args.$2,
            messageId: args.$3,
            payload: payload(),
            vehicleId: args.$4,
          );
          expect(r.isFailure, isTrue);
          expect(r.errorOrNull, isA<ValidationError>());
        }
        expect(await records(), isEmpty);
      });

      test('存在しないスレッドの明細は取り込まない', () async {
        final r = await service.importDetail(
          userId: _uid,
          inquiryId: 'gone',
          messageId: 'm1',
          payload: payload(),
          vehicleId: 'car4',
        );
        expect(r.errorOrNull, isA<NotFoundError>());
        expect(await records(), isEmpty);
      });

      test('他人宛てのスレッドの明細は取り込まない', () async {
        await inquiry('inq1', userId: 'someone_else');
        await message('inq1', 'm1', detail: payload());
        final r = await service.importDetail(
          userId: _uid,
          inquiryId: 'inq1',
          messageId: 'm1',
          payload: payload(),
          vehicleId: 'car4',
        );
        expect(r.errorOrNull, isA<PermissionError>());
        expect(await records(), isEmpty);
      });

      test('金額0の明細も取り込める', () async {
        await inquiry('inq1');
        await message('inq1', 'm1', detail: payload(cost: 0));
        final r = await service.importDetail(
          userId: _uid,
          inquiryId: 'inq1',
          messageId: 'm1',
          payload: payload(cost: 0),
          vehicleId: 'car4',
        );
        expect(r.isSuccess, isTrue);
      });
    });
  });

  group('importedMessageIds', () {
    test('印のあるメッセージと、記録が指しているメッセージを返す', () async {
      await inquiry('inq1');
      await message('inq1', 'm1', detail: payload(), importedAt: _now);
      await message('inq1', 'm2', detail: payload(cost: 2640));
      await message('inq1', 'm3', detail: payload(cost: 999));
      await fs.collection('maintenance_records').add({
        'userId': _uid,
        'inquiryId': 'inq1',
        'sourceMessageId': 'm2',
        'title': 'オイル交換',
        'cost': 2640,
        'date': Timestamp.fromDate(DateTime(2026, 10, 8)),
      });
      final msgs = (await fs
              .collection('inquiries')
              .doc('inq1')
              .collection('messages')
              .get())
          .docs
          .map((d) => InquiryMessage.fromMap(d.data(), d.id))
          .toList();

      final r = await service.importedMessageIds(
        userId: _uid,
        inquiryId: 'inq1',
        messages: msgs,
      );
      expect(r.valueOrNull, {'m1', 'm2'});
    });

    group('Edge Cases', () {
      test('メッセージが空なら空', () async {
        final r = await service.importedMessageIds(
          userId: _uid,
          inquiryId: 'inq1',
          messages: const [],
        );
        expect(r.valueOrNull, isEmpty);
      });

      test('利用者が空なら失敗', () async {
        final r = await service.importedMessageIds(
          userId: '',
          inquiryId: 'inq1',
          messages: const [],
        );
        expect(r.isFailure, isTrue);
      });
    });
  });

  group('pendingDetails', () {
    test('まだ記録に追加していない明細を、新しい順に返す', () async {
      await inquiry('inq1');
      await message('inq1', 'm1',
          detail: payload(), sentAt: DateTime(2026, 10, 8, 9));
      await message('inq1', 'm2',
          detail: payload(cost: 2640, label: 'トヨタ ハイエース'),
          sentAt: DateTime(2026, 10, 8, 11));
      await message('inq1', 'm3',
          detail: payload(cost: 1), importedAt: _now); // already added
      await message('inq1', 'm4', isFromShop: true); // plain text

      final r = await service.pendingDetails(_uid);
      final list = r.valueOrNull!;
      expect(list.map((d) => d.message.id), ['m2', 'm1']);
      expect(list.first.shopName, 'タカヤモーター');
      expect(list.first.payload.vehicleLabel, 'トヨタ ハイエース');
      expect(list.first.inquiry.id, 'inq1');
    });

    test('利用者が開いた問い合わせでも、店が明細を送っていれば拾う', () async {
      await inquiry('inq2', openedByShop: false, detailCount: 1);
      await message('inq2', 'm1', detail: payload());
      final r = await service.pendingDetails(_uid);
      expect(r.valueOrNull, hasLength(1));
    });

    group('Edge Cases', () {
      test('明細の来ていない問い合わせは読まない（空）', () async {
        await inquiry('inq3', openedByShop: false);
        await message('inq3', 'm1', isFromShop: true);
        final r = await service.pendingDetails(_uid);
        expect(r.valueOrNull, isEmpty);
      });

      test('他人宛ての明細は出ない', () async {
        await inquiry('inq1', userId: 'someone_else');
        await message('inq1', 'm1', detail: payload());
        final r = await service.pendingDetails(_uid);
        expect(r.valueOrNull, isEmpty);
      });

      test('利用者が空なら失敗', () async {
        final r = await service.pendingDetails('');
        expect(r.isFailure, isTrue);
      });
    });
  });

  group('markSeen', () {
    test('店からの未読の明細を既読にする（店側で「届いた」と分かる）', () async {
      await inquiry('inq1');
      await message('inq1', 'm1', detail: payload());
      await message('inq1', 'm2', isFromShop: false, detail: null);
      final msgs = [
        InquiryMessage.fromMap(await messageData('inq1', 'm1'), 'm1'),
        InquiryMessage.fromMap(await messageData('inq1', 'm2'), 'm2'),
      ];

      final r = await service.markSeen(inquiryId: 'inq1', messages: msgs);
      expect(r.isSuccess, isTrue);
      expect((await messageData('inq1', 'm1'))['isRead'], isTrue);
      expect((await messageData('inq1', 'm2'))['isRead'], isFalse);
    });

    group('Edge Cases', () {
      test('空のメッセージなら何もしない', () async {
        final r = await service.markSeen(inquiryId: 'inq1', messages: const []);
        expect(r.isSuccess, isTrue);
      });
    });
  });
}
