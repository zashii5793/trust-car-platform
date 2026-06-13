import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/vehicle_history_sharing_service.dart';

void main() {
  group('VehicleHistorySharingService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late VehicleHistorySharingService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = VehicleHistorySharingService(firestore: fakeFirestore);
    });

    group('grantPermission', () {
      test('正常系: 許可を付与できる', () async {
        final result = await service.grantPermission(
          vehicleId: 'v1',
          shopId: 'shop1',
          ownerId: 'user1',
        );
        expect(result.isSuccess, isTrue);
      });

      test('正常系: 付与後に hasPermission が true を返す', () async {
        await service.grantPermission(
          vehicleId: 'v1',
          shopId: 'shop1',
          ownerId: 'user1',
        );

        final result = await service.hasPermission(
          vehicleId: 'v1',
          shopId: 'shop1',
        );
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isTrue);
      });

      test('正常系: 有効期限付き許可を付与できる', () async {
        final expiry = DateTime.now().add(const Duration(days: 30));
        final result = await service.grantPermission(
          vehicleId: 'v1',
          shopId: 'shop1',
          ownerId: 'user1',
          expiresAt: expiry,
        );
        expect(result.isSuccess, isTrue);
      });

      test('正常系: 同じ店舗への重複付与は idempotent', () async {
        await service.grantPermission(
          vehicleId: 'v1',
          shopId: 'shop1',
          ownerId: 'user1',
        );
        final result = await service.grantPermission(
          vehicleId: 'v1',
          shopId: 'shop1',
          ownerId: 'user1',
        );
        expect(result.isSuccess, isTrue);
      });

      group('Edge Cases', () {
        test('空の vehicleId はバリデーションエラー', () async {
          final result = await service.grantPermission(
            vehicleId: '',
            shopId: 'shop1',
            ownerId: 'user1',
          );
          expect(result.isFailure, isTrue);
        });

        test('空の shopId はバリデーションエラー', () async {
          final result = await service.grantPermission(
            vehicleId: 'v1',
            shopId: '',
            ownerId: 'user1',
          );
          expect(result.isFailure, isTrue);
        });

        test('空の ownerId はバリデーションエラー', () async {
          final result = await service.grantPermission(
            vehicleId: 'v1',
            shopId: 'shop1',
            ownerId: '',
          );
          expect(result.isFailure, isTrue);
        });

        test('過去の有効期限はバリデーションエラー', () async {
          final past = DateTime.now().subtract(const Duration(days: 1));
          final result = await service.grantPermission(
            vehicleId: 'v1',
            shopId: 'shop1',
            ownerId: 'user1',
            expiresAt: past,
          );
          expect(result.isFailure, isTrue);
        });
      });
    });

    group('revokePermission', () {
      test('正常系: 許可を取り消せる', () async {
        await service.grantPermission(
          vehicleId: 'v1',
          shopId: 'shop1',
          ownerId: 'user1',
        );

        final result = await service.revokePermission(
          vehicleId: 'v1',
          shopId: 'shop1',
          ownerId: 'user1',
        );
        expect(result.isSuccess, isTrue);

        final check = await service.hasPermission(
          vehicleId: 'v1',
          shopId: 'shop1',
        );
        expect(check.valueOrNull, isFalse);
      });

      test('正常系: 存在しない許可の取り消しは成功（idempotent）', () async {
        final result = await service.revokePermission(
          vehicleId: 'v1',
          shopId: 'shop1',
          ownerId: 'user1',
        );
        expect(result.isSuccess, isTrue);
      });

      test('異常系: 他のオーナーは取り消せない', () async {
        await service.grantPermission(
          vehicleId: 'v1',
          shopId: 'shop1',
          ownerId: 'user1',
        );

        final result = await service.revokePermission(
          vehicleId: 'v1',
          shopId: 'shop1',
          ownerId: 'attacker',
        );
        expect(result.isFailure, isTrue);
      });
    });

    group('hasPermission', () {
      test('正常系: 許可なしは false', () async {
        final result = await service.hasPermission(
          vehicleId: 'v1',
          shopId: 'shop1',
        );
        expect(result.valueOrNull, isFalse);
      });

      test('正常系: 有効期限切れは false', () async {
        // Seed expired permission directly
        await fakeFirestore
            .collection('vehicle_sharing_permissions')
            .doc('v1_shop1')
            .set({
          'vehicleId': 'v1',
          'shopId': 'shop1',
          'ownerId': 'user1',
          'isActive': true,
          'expiresAt': DateTime.now()
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          'grantedAt': DateTime.now().millisecondsSinceEpoch,
        });

        final result = await service.hasPermission(
          vehicleId: 'v1',
          shopId: 'shop1',
        );
        expect(result.valueOrNull, isFalse);
      });
    });

    group('getPermittedShops', () {
      test('正常系: 許可を与えた店舗IDリストを返す', () async {
        await service.grantPermission(
          vehicleId: 'v1',
          shopId: 'shop1',
          ownerId: 'user1',
        );
        await service.grantPermission(
          vehicleId: 'v1',
          shopId: 'shop2',
          ownerId: 'user1',
        );

        final result = await service.getPermittedShops(vehicleId: 'v1');
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, containsAll(['shop1', 'shop2']));
      });

      test('正常系: 許可なしは空リスト', () async {
        final result = await service.getPermittedShops(vehicleId: 'v1');
        expect(result.valueOrNull, isEmpty);
      });
    });

    group('getPermittedVehicles', () {
      test('正常系: 許可を受けた車両IDリストを返す（店舗視点）', () async {
        await service.grantPermission(
          vehicleId: 'v1',
          shopId: 'shop1',
          ownerId: 'user1',
        );
        await service.grantPermission(
          vehicleId: 'v2',
          shopId: 'shop1',
          ownerId: 'user2',
        );

        final result = await service.getPermittedVehicles(shopId: 'shop1');
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, containsAll(['v1', 'v2']));
      });
    });
  });
}
