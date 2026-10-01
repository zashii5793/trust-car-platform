import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/models/inspection_push_request.dart';
import 'package:trust_car_platform/services/inspection_push_service.dart';

/// アプリ利用者への車検案内（プッシュ）の依頼（2026-09-29 プロダクト評価 #2）。
///
/// 送るのはサーバー。ここで確かめたいのは、**ルールが受け付ける形で依頼を
/// 置くこと**と、**サーバーが書いた結果を読めること**。
void main() {
  late FakeFirebaseFirestore firestore;
  late InspectionPushService service;
  const shopId = 'shop-1';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = InspectionPushService(firestore: firestore);
  });

  Future<Map<String, dynamic>> stored(String id) async =>
      (await firestore.doc('shops/$shopId/inspection_notices/$id').get())
          .data()!;

  group('request', () {
    test('ルールと同じ4項目だけで、受付中として置く', () async {
      final r = await service.request(
        shopId: shopId,
        requesterUid: 'staff-1',
        vehicleIds: ['v1', 'v2'],
      );
      final id = r.valueOrNull!;
      final data = await stored(id);
      expect(data.keys.toSet(),
          {'requesterUid', 'vehicleIds', 'status', 'createdAt'});
      expect(data['requesterUid'], 'staff-1');
      expect(data['vehicleIds'], ['v1', 'v2']);
      expect(data['status'], 'pending');
    });

    test('同じ車が重なっていれば1台にまとめ、空の ID は捨てる', () async {
      final id = (await service.request(
        shopId: shopId,
        requesterUid: 'staff-1',
        vehicleIds: ['v1', '', 'v1', 'v2'],
      ))
          .valueOrNull!;
      expect((await stored(id))['vehicleIds'], ['v1', 'v2']);
    });

    group('Edge Cases', () {
      test('車が無ければ置かない', () async {
        final r = await service
            .request(shopId: shopId, requesterUid: 'staff-1', vehicleIds: []);
        expect(r.errorOrNull, isA<ValidationError>());
        final r2 = await service
            .request(shopId: shopId, requesterUid: 'staff-1', vehicleIds: ['']);
        expect(r2.errorOrNull, isA<ValidationError>());
        expect(
            (await firestore
                    .collection('shops/$shopId/inspection_notices')
                    .get())
                .docs,
            isEmpty);
      });

      test('上限ちょうどは置け、1台でも超えたら置かない（ルールと同じ200台）', () async {
        final ok = await service.request(
          shopId: shopId,
          requesterUid: 'staff-1',
          vehicleIds: [
            for (var i = 0; i < InspectionPushService.maxVehicles; i++) 'v$i'
          ],
        );
        expect(ok.isSuccess, isTrue);
        final ng = await service.request(
          shopId: shopId,
          requesterUid: 'staff-1',
          vehicleIds: [
            for (var i = 0; i <= InspectionPushService.maxVehicles; i++) 'v$i'
          ],
        );
        expect(ng.errorOrNull, isA<ValidationError>());
      });

      test('店・依頼する人が分からなければ置かない', () async {
        expect(
            (await service.request(
                    shopId: '', requesterUid: 'staff-1', vehicleIds: ['v1']))
                .errorOrNull,
            isA<ValidationError>());
        expect(
            (await service.request(
                    shopId: shopId, requesterUid: '', vehicleIds: ['v1']))
                .errorOrNull,
            isA<ValidationError>());
      });
    });
  });

  group('watch', () {
    test('サーバーが結果を書くと、終わった状態と台数が流れてくる', () async {
      final id = (await service.request(
              shopId: shopId, requesterUid: 'staff-1', vehicleIds: ['v1']))
          .valueOrNull!;
      final stream = service.watch(shopId: shopId, noticeId: id);
      final finished = stream.firstWhere((r) => r.isFinished);

      await firestore.doc('shops/$shopId/inspection_notices/$id').update({
        'status': 'done',
        'result': {'sent': 3, 'pushOff': 1, 'noDevice': 2},
      });
      final r = await finished;
      expect(r.status, InspectionPushStatus.done);
      expect(r.result!.sent, 3);
      expect(r.result!.pushOff, 1);
      expect(r.result!.skippedNotes, ['通知を切っている1台', '通知を受け取れる端末が無い2台']);
    });

    group('Edge Cases', () {
      test('無い依頼なら何も流さずに閉じる', () async {
        final events =
            await service.watch(shopId: shopId, noticeId: 'nope').toList();
        expect(events, isEmpty);
      });
    });
  });

  group('InspectionPushRequest.fromMap', () {
    test('サーバーの書いた形を読む', () {
      final r = InspectionPushRequest.fromMap('n1', {
        'requesterUid': 'u',
        'vehicleIds': ['a', 'b'],
        'status': 'failed',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
      });
      expect(r.status, InspectionPushStatus.failed);
      expect(r.isFinished, isTrue);
      expect(r.vehicleIds, ['a', 'b']);
      expect(r.result, isNull);
      expect(r.createdAt, DateTime(2026, 10, 1));
    });

    group('Edge Cases', () {
      test('知らない状態・壊れた値は受付中・0台として読む', () {
        final r = InspectionPushRequest.fromMap('n1', {
          'status': 'weird',
          'vehicleIds': ['a', 1, null],
          'result': {'sent': 'x'},
        });
        expect(r.status, InspectionPushStatus.pending);
        expect(r.isFinished, isFalse);
        expect(r.vehicleIds, ['a']);
        expect(r.result!.sent, 0);
        expect(r.result!.skippedNotes, isEmpty);
      });
    });
  });
}
