// ウェイポイント（走行の経路）が、自分のものとして書かれ・読まれるかのテスト。
//
// なぜ要るか:
//   `firestore.rules` の `drive_waypoints` は、書き込みに
//   `request.resource.data.userId == request.auth.uid` を、読み取りに
//   `resource.data.userId == request.auth.uid` を要求する。
//
//   ところが `addWaypoint` は userId を書いておらず、`getWaypoints` は
//   driveLogId だけで引いていた。**本番では経路が1点も保存されず、
//   保存されていても読めない。** ドライブログの詳細画面に地図が出ない
//   （2026-09-08 に発見）。
//
//   fake_cloud_firestore はルールを評価しないので、この壊れ方は
//   「userId が書かれているか」「クエリが userId で絞っているか」を
//   直接確かめるしかない。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/services/drive_log_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late DriveLogService service;

  DriveWaypoint waypoint(DateTime at) => DriveWaypoint(
        location: const GeoPoint2D(latitude: 35.6, longitude: 139.6),
        timestamp: at,
        speed: 40,
      );

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = DriveLogService(firestore: firestore);
  });

  group('addWaypoint', () {
    test('userId を書く（これが無いとルールに弾かれる）', () async {
      await service.addWaypoint(
        driveLogId: 'log-1',
        userId: 'u1',
        waypoint: waypoint(DateTime(2026, 9, 1, 10)),
      );

      final docs = await firestore.collection('drive_waypoints').get();

      expect(docs.docs.single.data()['userId'], 'u1');
      expect(docs.docs.single.data()['driveLogId'], 'log-1');
    });

    group('Edge Cases', () {
      test('userId が空なら書かずに断る', () async {
        final result = await service.addWaypoint(
          driveLogId: 'log-1',
          userId: '',
          waypoint: waypoint(DateTime(2026, 9, 1, 10)),
        );

        expect(result.isFailure, isTrue);
        expect((await firestore.collection('drive_waypoints').get()).size, 0);
      });
    });
  });

  group('getWaypoints', () {
    test('自分の経路だけを、時刻の順で返す', () async {
      await service.addWaypoint(
        driveLogId: 'log-1',
        userId: 'u1',
        waypoint: waypoint(DateTime(2026, 9, 1, 10, 5)),
      );
      await service.addWaypoint(
        driveLogId: 'log-1',
        userId: 'u1',
        waypoint: waypoint(DateTime(2026, 9, 1, 10)),
      );
      // 同じ driveLogId でも、別のユーザーのものは返さない。
      await service.addWaypoint(
        driveLogId: 'log-1',
        userId: 'u2',
        waypoint: waypoint(DateTime(2026, 9, 1, 10, 1)),
      );

      final points =
          (await service.getWaypoints('log-1', userId: 'u1')).valueOrNull!;

      expect(points.length, 2);
      expect(points.first.timestamp, DateTime(2026, 9, 1, 10));
      expect(points.last.timestamp, DateTime(2026, 9, 1, 10, 5));
    });

    group('Edge Cases', () {
      test('userId が空なら空で返す（ルールで弾かれるクエリを投げない）', () async {
        await service.addWaypoint(
          driveLogId: 'log-1',
          userId: 'u1',
          waypoint: waypoint(DateTime(2026, 9, 1, 10)),
        );

        expect(
          (await service.getWaypoints('log-1', userId: '')).valueOrNull,
          isEmpty,
        );
      });

      test('経路が無ければ空で返す', () async {
        expect(
          (await service.getWaypoints('log-none', userId: 'u1')).valueOrNull,
          isEmpty,
        );
      });
    });
  });
}
