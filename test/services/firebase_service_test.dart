import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';

// FirebaseService only touches Firestore in the methods under test. Auth and
// Storage are injected as bare mocks so the constructor never reaches the
// uninitialised FirebaseAuth.instance / FirebaseStorage.instance singletons.
class _FakeAuth extends Mock implements FirebaseAuth {}

class _FakeStorage extends Mock implements FirebaseStorage {}

void main() {
  group('FirebaseService Result Pattern Tests', () {
    group('Result Integration', () {
      test('Result.success can hold vehicle ID', () {
        final result = Result<String, AppError>.success('vehicle_123');

        expect(result.isSuccess, true);
        expect(result.valueOrNull, 'vehicle_123');
      });

      test('Result.failure can hold AppError', () {
        final result = Result<String, AppError>.failure(
          const AppError.network('Connection failed'),
        );

        expect(result.isFailure, true);
        expect(result.valueOrNull, null);

        result.when(
          success: (_) => fail('Should not be success'),
          failure: (error) {
            expect(error, isA<NetworkError>());
            expect(error.isRetryable, true);
          },
        );
      });

      test('Result.success can hold void', () {
        final result = const Result<void, AppError>.success(null);

        expect(result.isSuccess, true);
      });

      test('Result can be mapped', () {
        final result = Result<String, AppError>.success('vehicle_123');
        final mapped = result.map((id) => 'Mapped: $id');

        expect(mapped.valueOrNull, 'Mapped: vehicle_123');
      });

      test('Result.failure does not map', () {
        final result = Result<String, AppError>.failure(
          const AppError.network('Error'),
        );
        final mapped = result.map((id) => 'Mapped: $id');

        expect(mapped.isFailure, true);
      });
    });

    group('AppError Firebase Mapping', () {
      test('maps user-not-found to AuthError', () {
        final error = mapFirebaseError(
            Exception('[firebase_auth/user-not-found] User not found'));

        expect(error, isA<AuthError>());
        expect((error as AuthError).type, AuthErrorType.userNotFound);
      });

      test('maps wrong-password to AuthError', () {
        final error = mapFirebaseError(
            Exception('[firebase_auth/wrong-password] Wrong password'));

        expect(error, isA<AuthError>());
        expect((error as AuthError).type, AuthErrorType.invalidCredentials);
      });

      test('maps invalid-credential to AuthError', () {
        final error = mapFirebaseError(
            Exception('[firebase_auth/invalid-credential] Invalid'));

        expect(error, isA<AuthError>());
        expect((error as AuthError).type, AuthErrorType.invalidCredentials);
      });

      test('maps email-already-in-use to AuthError', () {
        final error = mapFirebaseError(
            Exception('[firebase_auth/email-already-in-use] Email in use'));

        expect(error, isA<AuthError>());
        expect((error as AuthError).type, AuthErrorType.emailAlreadyInUse);
      });

      test('maps weak-password to AuthError', () {
        final error = mapFirebaseError(
            Exception('[firebase_auth/weak-password] Too weak'));

        expect(error, isA<AuthError>());
        expect((error as AuthError).type, AuthErrorType.weakPassword);
      });

      test('maps too-many-requests to AuthError', () {
        final error = mapFirebaseError(
            Exception('[firebase_auth/too-many-requests] Rate limited'));

        expect(error, isA<AuthError>());
        expect((error as AuthError).type, AuthErrorType.tooManyRequests);
        expect(error.isRetryable, true);
      });

      test('maps permission-denied to PermissionError', () {
        final error = mapFirebaseError(
            Exception('[cloud_firestore/permission-denied] Access denied'));

        expect(error, isA<PermissionError>());
        expect(error.isRetryable, false);
      });

      test('maps not-found to NotFoundError', () {
        final error = mapFirebaseError(
            Exception('[cloud_firestore/not-found] Document not found'));

        expect(error, isA<NotFoundError>());
        expect(error.isRetryable, false);
      });

      test('maps unavailable to NetworkError', () {
        final error = mapFirebaseError(
            Exception('[cloud_firestore/unavailable] Service unavailable'));

        expect(error, isA<NetworkError>());
        expect(error.isRetryable, true);
      });

      test('maps network error to NetworkError', () {
        final error = mapFirebaseError(Exception('Network connection failed'));

        expect(error, isA<NetworkError>());
        expect(error.isRetryable, true);
      });

      test('maps unknown error to UnknownError', () {
        final error = mapFirebaseError(Exception('Some unexpected error'));

        expect(error, isA<UnknownError>());
        expect(error.isRetryable, false);
      });
    });

    group('Vehicle Model', () {
      test('can create Vehicle instance', () {
        final vehicle = Vehicle(
          id: 'v1',
          userId: 'u1',
          maker: 'Toyota',
          model: 'Prius',
          year: 2023,
          grade: 'S',
          mileage: 10000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(vehicle.id, 'v1');
        expect(vehicle.maker, 'Toyota');
        expect(vehicle.model, 'Prius');
      });

      test('can convert Vehicle to Map', () {
        final now = DateTime.now();
        final vehicle = Vehicle(
          id: 'v1',
          userId: 'u1',
          maker: 'Toyota',
          model: 'Prius',
          year: 2023,
          grade: 'S',
          mileage: 10000,
          createdAt: now,
          updatedAt: now,
          licensePlate: '品川 500 あ 1234',
        );

        final map = vehicle.toMap();

        expect(map['userId'], 'u1');
        expect(map['maker'], 'Toyota');
        expect(map['model'], 'Prius');
        expect(map['year'], 2023);
        expect(map['licensePlate'], '品川 500 あ 1234');
      });

      test('Vehicle.copyWith works correctly', () {
        final vehicle = Vehicle(
          id: 'v1',
          userId: 'u1',
          maker: 'Toyota',
          model: 'Prius',
          year: 2023,
          grade: 'S',
          mileage: 10000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updated = vehicle.copyWith(mileage: 15000);

        expect(updated.mileage, 15000);
        expect(updated.maker, 'Toyota'); // unchanged
      });
    });

    group('MaintenanceRecord Model', () {
      test('can create MaintenanceRecord instance', () {
        final record = MaintenanceRecord(
          id: 'r1',
          vehicleId: 'v1',
          userId: 'u1',
          type: MaintenanceType.oilChange,
          title: 'オイル交換',
          cost: 5000,
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(record.id, 'r1');
        expect(record.type, MaintenanceType.oilChange);
        expect(record.cost, 5000);
      });

      test('MaintenanceType has correct display names', () {
        expect(MaintenanceType.oilChange.displayName, 'オイル交換');
        expect(MaintenanceType.carInspection.displayName, '車検');
        expect(MaintenanceType.tireChange.displayName, 'タイヤ交換');
      });

      test('MaintenanceType has icons', () {
        expect(MaintenanceType.oilChange.icon, isNotNull);
        expect(MaintenanceType.carInspection.icon, isNotNull);
      });

      test('can convert MaintenanceRecord to Map', () {
        final now = DateTime.now();
        final record = MaintenanceRecord(
          id: 'r1',
          vehicleId: 'v1',
          userId: 'u1',
          type: MaintenanceType.oilChange,
          title: 'オイル交換',
          cost: 5000,
          date: now,
          createdAt: now,
          shopName: 'テストショップ',
        );

        final map = record.toMap();

        expect(map['vehicleId'], 'v1');
        expect(map['type'], 'oilChange');
        expect(map['title'], 'オイル交換');
        expect(map['cost'], 5000);
        expect(map['shopName'], 'テストショップ');
      });
    });

    group('Result Pattern Usage Scenarios', () {
      test('can chain operations with flatMap', () async {
        Future<Result<String, AppError>> fetchVehicleId() async {
          return const Result.success('v123');
        }

        Future<Result<Vehicle, AppError>> fetchVehicle(String id) async {
          return Result.success(Vehicle(
            id: id,
            userId: 'u1',
            maker: 'Toyota',
            model: 'Prius',
            year: 2023,
            grade: 'S',
            mileage: 10000,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }

        final idResult = await fetchVehicleId();

        final vehicleResult = await idResult.when(
          success: (id) => fetchVehicle(id),
          failure: (error) async => Result<Vehicle, AppError>.failure(error),
        );

        expect(vehicleResult.isSuccess, true);
        vehicleResult.when(
          success: (vehicle) {
            expect(vehicle.id, 'v123');
            expect(vehicle.maker, 'Toyota');
          },
          failure: (_) => fail('Should be success'),
        );
      });

      test('error propagates through chain', () async {
        Future<Result<String, AppError>> fetchVehicleIdWithError() async {
          return const Result.failure(AppError.network('Connection failed'));
        }

        Future<Result<Vehicle, AppError>> fetchVehicle(String id) async {
          return Result.success(Vehicle(
            id: id,
            userId: 'u1',
            maker: 'Toyota',
            model: 'Prius',
            year: 2023,
            grade: 'S',
            mileage: 10000,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }

        final idResult = await fetchVehicleIdWithError();

        final vehicleResult = await idResult.when(
          success: (id) => fetchVehicle(id),
          failure: (error) async => Result<Vehicle, AppError>.failure(error),
        );

        expect(vehicleResult.isFailure, true);
        vehicleResult.when(
          success: (_) => fail('Should be failure'),
          failure: (error) {
            expect(error, isA<NetworkError>());
          },
        );
      });
    });

    group('Provider Error Handling Scenarios', () {
      test('AppError provides user-friendly messages', () {
        const errors = <AppError>[
          AppError.network('Connection timeout'),
          AppError.auth('Invalid', type: AuthErrorType.invalidCredentials),
          AppError.validation('Invalid input', field: 'email'),
          AppError.notFound('Not found', resourceType: '車両'),
          AppError.permission('Access denied'),
          AppError.server('Internal error', statusCode: 500),
          AppError.cache('Cache miss'),
          AppError.unknown('Something went wrong'),
        ];

        for (final error in errors) {
          expect(error.userMessage.isNotEmpty, true);
          expect(error.message.isNotEmpty, true);
        }
      });

      test('AppError retryable flag is correct', () {
        expect(const NetworkError('test').isRetryable, true);
        expect(const ServerError('test').isRetryable, true);
        expect(const CacheError('test').isRetryable, true);
        expect(
            const AuthError('test', type: AuthErrorType.tooManyRequests)
                .isRetryable,
            true);

        expect(const ValidationError('test').isRetryable, false);
        expect(const NotFoundError('test').isRetryable, false);
        expect(const PermissionError('test').isRetryable, false);
        expect(const UnknownError('test').isRetryable, false);
        expect(
            const AuthError('test', type: AuthErrorType.invalidCredentials)
                .isRetryable,
            false);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // 大量データ検証: getMaintenanceRecordsForVehicle の limit ページング境界
  //
  // maintenance_records は車両ごとに無制限に蓄積するため、limit で1ページ分に
  // 制限されること・境界値を検証する。
  // ---------------------------------------------------------------------------
  group('FirebaseService.getMaintenanceRecordsForVehicle — pagination', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirebaseService service;

    // date を1日ずつずらして 25 件投入（新しいものが先頭になる desc 順）
    Future<void> seedRecords(String vehicleId, int count) async {
      for (var i = 0; i < count; i++) {
        await fakeFirestore.collection('maintenance_records').add({
          'vehicleId': vehicleId,
          'userId': 'owner-uid',
          'type': 'oilChange',
          'title': 'record-$i',
          'cost': 1000,
          'date':
              Timestamp.fromDate(DateTime(2024, 1, 1).add(Duration(days: i))),
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        });
      }
    }

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = FirebaseService(
        firestore: fakeFirestore,
        auth: _FakeAuth(),
        storage: _FakeStorage(),
      );
    });

    test('limit を超える件数があるとき limit 件で打ち切る', () async {
      await seedRecords('v1', 25);

      final result =
          await service.getMaintenanceRecordsForVehicle('v1', limit: 10);

      result.when(
        success: (records) => expect(records.length, 10),
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    group('Edge Cases', () {
      test('レコードが存在しない車両は空リストを返す（0件境界）', () async {
        final result =
            await service.getMaintenanceRecordsForVehicle('no-such-vehicle');

        result.when(
          success: (records) => expect(records, isEmpty),
          failure: (e) => fail('Expected success, got: $e'),
        );
      });

      test('件数が limit 未満のときは全件を返す', () async {
        await seedRecords('v1', 3);

        final result =
            await service.getMaintenanceRecordsForVehicle('v1', limit: 10);

        result.when(
          success: (records) => expect(records.length, 3),
          failure: (e) => fail('Expected success, got: $e'),
        );
      });

      test('他車両のレコードは混入しない', () async {
        await seedRecords('v1', 5);
        await seedRecords('v2', 5);

        final result =
            await service.getMaintenanceRecordsForVehicle('v1', limit: 50);

        result.when(
          success: (records) {
            expect(records.length, 5);
            expect(records.every((r) => r.vehicleId == 'v1'), isTrue);
          },
          failure: (e) => fail('Expected success, got: $e'),
        );
      });
    });
  });
}
