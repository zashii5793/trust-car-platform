import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/drive_log_service.dart';
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/core/constants/firestore_collections.dart';

void main() {
  group('DriveLogService.createManualDriveLog', () {
    late FakeFirebaseFirestore firestore;
    late DriveLogService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = DriveLogService(firestore: firestore);
    });

    Future<DriveLog> onlyLog() async {
      final snap =
          await firestore.collection(FirestoreCollections.driveLogs).get();
      expect(snap.docs.length, 1);
      return DriveLog.fromMap(snap.docs.first.data(), snap.docs.first.id);
    }

    test('完了済みログとして保存し統計を設定する', () async {
      final result = await service.createManualDriveLog(
        userId: 'u1',
        vehicleId: 'v1',
        startTime: DateTime(2026, 8, 1, 9),
        title: '箱根ドライブ',
        distanceKm: 42.0,
        durationSeconds: 3600,
      );

      expect(result.isFailure, isFalse);
      final log = await onlyLog();
      expect(log.status, DriveLogStatus.completed);
      expect(log.userId, 'u1');
      expect(log.vehicleId, 'v1');
      expect(log.title, '箱根ドライブ');
      expect(log.statistics.totalDistance, 42.0);
      expect(log.statistics.totalDuration, 3600);
      // 42km を 1時間 → 平均 42 km/h
      expect(log.statistics.averageSpeed, closeTo(42.0, 0.001));
    });

    group('Edge Cases', () {
      test('所要時間0のとき平均速度は0・車両未指定はnull', () async {
        await service.createManualDriveLog(
          userId: 'u1',
          startTime: DateTime(2026, 8, 1),
          distanceKm: 10.0,
        );

        final log = await onlyLog();
        expect(log.statistics.averageSpeed, 0);
        expect(log.statistics.totalDuration, 0);
        expect(log.vehicleId, isNull);
      });

      test('任意項目が空でも保存できる', () async {
        final result = await service.createManualDriveLog(
          userId: 'u1',
          startTime: DateTime(2026, 8, 1),
          distanceKm: 1.0,
        );
        expect(result.isFailure, isFalse);
      });
    });
  });
}
