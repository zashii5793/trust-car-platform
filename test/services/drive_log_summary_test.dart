// DriveLogService.summaryForUser のテスト
//
// なぜ要るか:
//   ホームの「たびの記録」は、**読み込んだ1ページ分（20件）の合計**を
//   「合計」として出していた。1年使った人は 200 件近く記録するので、
//   画面には実際の 1/10 の距離が出る。
//
//   合計を出すために全件を読むわけにもいかない（ホームを開くたびに
//   200 ドキュメント読む）ので、集計クエリ（count / sum）で数字だけを取る。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/drive_log_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late DriveLogService service;

  /// 1件ぶんのドライブログを作る。summaryForUser が見るのは
  /// userId / startTime / statistics.totalDistance の3つだけ。
  Future<void> addLog({
    required String id,
    required String userId,
    required DateTime startTime,
    required double distance,
  }) async {
    await firestore.collection('drive_logs').doc(id).set({
      'userId': userId,
      'vehicleId': 'v1',
      'status': 'completed',
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(startTime.add(const Duration(hours: 1))),
      'statistics': {
        'totalDistance': distance,
        'totalDuration': 3600,
        'averageSpeed': distance,
        'maxSpeed': distance,
        'stopCount': 0,
        'totalStopDuration': 0,
      },
      'createdAt': Timestamp.fromDate(startTime),
      'updatedAt': Timestamp.fromDate(startTime),
    });
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = DriveLogService(firestore: firestore);
  });

  group('summaryForUser', () {
    test('1ページ分を超えても、全部の回数と距離を返す', () async {
      final now = DateTime.now();
      for (var i = 0; i < 25; i++) {
        await addLog(
          id: 'log-$i',
          userId: 'u1',
          startTime: now.subtract(Duration(days: i)),
          distance: 10.0,
        );
      }

      final result = await service.summaryForUser(userId: 'u1');
      final summary = result.valueOrNull!;

      // 20件（1ページ）ではなく25件。
      expect(summary.count, 25);
      expect(summary.totalDistanceKm, closeTo(250.0, 0.001));
    });

    test('他人の記録は数えない', () async {
      final now = DateTime.now();
      await addLog(id: 'mine', userId: 'u1', startTime: now, distance: 100);
      await addLog(id: 'theirs', userId: 'u2', startTime: now, distance: 999);

      final summary = (await service.summaryForUser(userId: 'u1')).valueOrNull!;

      expect(summary.count, 1);
      expect(summary.totalDistanceKm, closeTo(100.0, 0.001));
    });

    test('since を渡すと、その日以降だけを数える', () async {
      final now = DateTime.now();
      await addLog(
        id: 'recent',
        userId: 'u1',
        startTime: now.subtract(const Duration(days: 30)),
        distance: 50,
      );
      await addLog(
        id: 'old',
        userId: 'u1',
        startTime: now.subtract(const Duration(days: 400)),
        distance: 500,
      );

      final summary = (await service.summaryForUser(
        userId: 'u1',
        since: now.subtract(const Duration(days: 365)),
      ))
          .valueOrNull!;

      expect(summary.count, 1);
      expect(summary.totalDistanceKm, closeTo(50.0, 0.001));
    });

    group('Edge Cases', () {
      test('userId が空なら 0 件を返す（クエリを投げない）', () async {
        final summary = (await service.summaryForUser(userId: '')).valueOrNull!;

        expect(summary.count, 0);
        expect(summary.totalDistanceKm, 0);
        expect(summary.isEmpty, isTrue);
      });

      test('1件も無ければ 0 件・0km', () async {
        final summary =
            (await service.summaryForUser(userId: 'u-none')).valueOrNull!;

        expect(summary.count, 0);
        expect(summary.totalDistanceKm, 0);
      });
    });
  });
}
