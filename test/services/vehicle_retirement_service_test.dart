import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/vehicle_retirement_service.dart';

void main() {
  group('VehicleRetirementService', () {
    late FakeFirebaseFirestore firestore;
    late VehicleRetirementService service;
    final now = DateTime(2026, 1, 1);

    Vehicle activeVehicle({
      String id = 'v1',
      String userId = 'owner-1',
      String maker = 'Toyota',
      String model = 'Prius',
    }) =>
        Vehicle(
          id: id,
          userId: userId,
          maker: maker,
          model: model,
          year: 2020,
          grade: 'S',
          mileage: 50000,
          status: VehicleStatus.active,
          isDataRetained: true,
          createdAt: now,
          updatedAt: now,
        );

    Future<void> seed(Vehicle v) async {
      await firestore.collection('vehicles').doc(v.id).set(v.toMap());
    }

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = VehicleRetirementService(firestore: firestore);
    });

    // -------------------------------------------------------------------------
    // retireVehicle — 売却
    // -------------------------------------------------------------------------
    group('retireVehicle (売却)', () {
      test('正常系: 売却ステータスに変更される', () async {
        await seed(activeVehicle());

        final result = await service.retireVehicle(
          vehicleId: 'v1',
          ownerId: 'owner-1',
          reason: VehicleStatus.sold,
          retainData: true,
          note: 'カーセンサー経由で売却、50万円',
        );

        expect(result.isSuccess, isTrue);
        final doc = await firestore.collection('vehicles').doc('v1').get();
        expect(doc.data()!['status'], 'sold');
        expect(doc.data()!['retirementNote'], 'カーセンサー経由で売却、50万円');
        expect(doc.data()!['isDataRetained'], isTrue);
        expect(doc.data()!['retiredAt'], isNotNull);
      });

      test('正常系: 廃車ステータスに変更される', () async {
        await seed(activeVehicle());

        final result = await service.retireVehicle(
          vehicleId: 'v1',
          ownerId: 'owner-1',
          reason: VehicleStatus.scrapped,
          retainData: false,
        );

        expect(result.isSuccess, isTrue);
        final doc = await firestore.collection('vehicles').doc('v1').get();
        expect(doc.data()!['status'], 'scrapped');
        expect(doc.data()!['isDataRetained'], isFalse);
      });

      test('正常系: リース返却ステータスに変更される', () async {
        await seed(activeVehicle());

        final result = await service.retireVehicle(
          vehicleId: 'v1',
          ownerId: 'owner-1',
          reason: VehicleStatus.leaseReturned,
          retainData: true,
        );

        expect(result.isSuccess, isTrue);
        final doc = await firestore.collection('vehicles').doc('v1').get();
        expect(doc.data()!['status'], 'leaseReturned');
      });

      test('正常系: 譲渡ステータスに変更される', () async {
        await seed(activeVehicle());

        final result = await service.retireVehicle(
          vehicleId: 'v1',
          ownerId: 'owner-1',
          reason: VehicleStatus.transferred,
          retainData: true,
          note: '家族に譲渡',
        );

        expect(result.isSuccess, isTrue);
        final doc = await firestore.collection('vehicles').doc('v1').get();
        expect(doc.data()!['status'], 'transferred');
      });

      group('異常系', () {
        test('他人の車両は退役できない', () async {
          await seed(activeVehicle(userId: 'owner-1'));

          final result = await service.retireVehicle(
            vehicleId: 'v1',
            ownerId: 'intruder',
            reason: VehicleStatus.sold,
            retainData: true,
          );

          expect(result.isFailure, isTrue);
        });

        test('既に退役済みの車両は再度退役できない', () async {
          final retired = activeVehicle().copyWith(
            status: VehicleStatus.sold,
          );
          await seed(retired);

          final result = await service.retireVehicle(
            vehicleId: 'v1',
            ownerId: 'owner-1',
            reason: VehicleStatus.scrapped,
            retainData: false,
          );

          expect(result.isFailure, isTrue);
        });

        test('active以外のreasonはバリデーションエラー', () async {
          await seed(activeVehicle());

          final result = await service.retireVehicle(
            vehicleId: 'v1',
            ownerId: 'owner-1',
            reason: VehicleStatus.active, // invalid
            retainData: true,
          );

          expect(result.isFailure, isTrue);
        });
      });

      group('Edge Cases', () {
        test('空のvehicleIdはバリデーションエラー', () async {
          final result = await service.retireVehicle(
            vehicleId: '',
            ownerId: 'owner-1',
            reason: VehicleStatus.sold,
            retainData: true,
          );
          expect(result.isFailure, isTrue);
        });

        test('存在しない車両IDはnotFoundエラー', () async {
          final result = await service.retireVehicle(
            vehicleId: 'ghost',
            ownerId: 'owner-1',
            reason: VehicleStatus.sold,
            retainData: true,
          );
          expect(result.isFailure, isTrue);
        });
      });
    });

    // -------------------------------------------------------------------------
    // restoreVehicle — 誤操作取り消し
    // -------------------------------------------------------------------------
    group('restoreVehicle', () {
      test('正常系: 退役車両を使用中に戻せる', () async {
        final retired = activeVehicle().copyWith(status: VehicleStatus.sold);
        await seed(retired);

        final result = await service.restoreVehicle(
          vehicleId: 'v1',
          ownerId: 'owner-1',
        );

        expect(result.isSuccess, isTrue);
        final doc = await firestore.collection('vehicles').doc('v1').get();
        expect(doc.data()!['status'], 'active');
        expect(doc.data()!['retiredAt'], isNull);
      });

      test('異常系: 使用中の車両を復元しようとするとエラー', () async {
        await seed(activeVehicle());

        final result = await service.restoreVehicle(
          vehicleId: 'v1',
          ownerId: 'owner-1',
        );

        expect(result.isFailure, isTrue);
      });

      test('異常系: 他人の退役車両は復元できない', () async {
        final retired = activeVehicle(userId: 'owner-1')
            .copyWith(status: VehicleStatus.sold);
        await seed(retired);

        final result = await service.restoreVehicle(
          vehicleId: 'v1',
          ownerId: 'intruder',
        );

        expect(result.isFailure, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // getRetiredVehicles
    // -------------------------------------------------------------------------
    group('getRetiredVehicles', () {
      test('正常系: 退役済み車両のみ取得できる', () async {
        await seed(activeVehicle(id: 'active-1'));
        await seed(activeVehicle(id: 'active-2'));
        await seed(
            activeVehicle(id: 'sold-1').copyWith(status: VehicleStatus.sold));
        await seed(activeVehicle(id: 'scrapped-1')
            .copyWith(status: VehicleStatus.scrapped));

        final result = await service.getRetiredVehicles('owner-1');

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, hasLength(2));
        expect(
          result.valueOrNull!.every((v) => v.status != VehicleStatus.active),
          isTrue,
        );
      });

      test('正常系: 退役車両ゼロでも空リスト', () async {
        await seed(activeVehicle());
        final result = await service.getRetiredVehicles('owner-1');
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // getActiveVehicles
    // -------------------------------------------------------------------------
    group('getActiveVehicles', () {
      test('正常系: アクティブ車両のみ取得できる', () async {
        await seed(activeVehicle(id: 'active-1'));
        await seed(activeVehicle(id: 'active-2'));
        await seed(
            activeVehicle(id: 'sold-1').copyWith(status: VehicleStatus.sold));

        final result = await service.getActiveVehicles('owner-1');

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, hasLength(2));
        expect(
          result.valueOrNull!.every((v) => v.status == VehicleStatus.active),
          isTrue,
        );
      });
    });

    // -------------------------------------------------------------------------
    // データ保持の確認
    // -------------------------------------------------------------------------
    group('データ保持設定', () {
      test('retainData=true: 整備記録関連フラグが保持に設定される', () async {
        await seed(activeVehicle());

        await service.retireVehicle(
          vehicleId: 'v1',
          ownerId: 'owner-1',
          reason: VehicleStatus.sold,
          retainData: true,
        );

        final doc = await firestore.collection('vehicles').doc('v1').get();
        expect(doc.data()!['isDataRetained'], isTrue);
      });

      test('retainData=false: データ削除フラグが設定される', () async {
        await seed(activeVehicle());

        await service.retireVehicle(
          vehicleId: 'v1',
          ownerId: 'owner-1',
          reason: VehicleStatus.scrapped,
          retainData: false,
        );

        final doc = await firestore.collection('vehicles').doc('v1').get();
        expect(doc.data()!['isDataRetained'], isFalse);
      });
    });
  });
}
