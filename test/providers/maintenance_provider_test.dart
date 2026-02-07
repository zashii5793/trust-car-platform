import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/providers/maintenance_provider.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// Mock FirebaseService for testing
class MockFirebaseService implements FirebaseService {
  final StreamController<List<MaintenanceRecord>> _recordsController =
      StreamController<List<MaintenanceRecord>>.broadcast();

  bool addRecordCalled = false;
  bool updateRecordCalled = false;
  bool deleteRecordCalled = false;

  Result<String, AppError>? addRecordResult;
  Result<void, AppError>? updateRecordResult;
  Result<void, AppError>? deleteRecordResult;

  @override
  String? get currentUserId => 'test-user-id';

  @override
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(String vehicleId) =>
      _recordsController.stream;

  void emitRecords(List<MaintenanceRecord> records) {
    _recordsController.add(records);
  }

  void emitRecordsError(Object error) {
    _recordsController.addError(error);
  }

  @override
  Future<Result<String, AppError>> addMaintenanceRecord(MaintenanceRecord record) async {
    addRecordCalled = true;
    return addRecordResult ?? const Result.success('new-record-id');
  }

  @override
  Future<Result<void, AppError>> updateMaintenanceRecord(
    String recordId,
    MaintenanceRecord record,
  ) async {
    updateRecordCalled = true;
    return updateRecordResult ?? const Result.success(null);
  }

  @override
  Future<Result<void, AppError>> deleteMaintenanceRecord(String recordId) async {
    deleteRecordCalled = true;
    return deleteRecordResult ?? const Result.success(null);
  }

  // Unused methods for this test
  @override
  Stream<List<Vehicle>> getUserVehicles() => const Stream.empty();

  @override
  Future<Result<String, AppError>> addVehicle(Vehicle vehicle) async =>
      const Result.success('vehicle-id');

  @override
  Future<Result<void, AppError>> updateVehicle(String id, Vehicle vehicle) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteVehicle(String vehicleId) async =>
      const Result.success(null);

  @override
  Future<Result<bool, AppError>> isLicensePlateExists(
    String licensePlate, {
    String? excludeVehicleId,
  }) async =>
      const Result.success(false);

  @override
  Future<Result<List<MaintenanceRecord>, AppError>> getMaintenanceRecordsForVehicle(
    String vehicleId, {
    int limit = 20,
  }) async =>
      const Result.success([]);

  @override
  Future<Result<String, AppError>> uploadImageBytes(
    dynamic bytes,
    String path,
  ) async =>
      const Result.success('http://example.com/image.jpg');

  @override
  Future<Result<Vehicle?, AppError>> getVehicle(String vehicleId) async =>
      const Result.success(null);

  @override
  Future<Result<String, AppError>> uploadImage(dynamic imageFile, String path) async =>
      const Result.success('http://example.com/image.jpg');

  @override
  Future<Result<List<String>, AppError>> uploadImages(
    List<dynamic> imageFiles,
    String basePath,
  ) async =>
      const Result.success([]);

  void dispose() {
    _recordsController.close();
  }
}

MaintenanceRecord _createTestRecord({
  String? id,
  MaintenanceType? type,
  int? cost,
}) =>
    MaintenanceRecord(
      id: id ?? 'test-record-id',
      vehicleId: 'test-vehicle-id',
      userId: 'test-user-id',
      type: type ?? MaintenanceType.oilChange,
      title: 'Test maintenance',
      cost: cost ?? 5000,
      date: DateTime(2024, 1, 15),
      createdAt: DateTime.now(),
    );

void main() {
  group('MaintenanceProvider', () {
    late MockFirebaseService mockFirebaseService;
    late MaintenanceProvider provider;

    setUp(() {
      mockFirebaseService = MockFirebaseService();
      provider = MaintenanceProvider(firebaseService: mockFirebaseService);
    });

    tearDown(() {
      provider.dispose();
      mockFirebaseService.dispose();
    });

    group('Initial State', () {
      test('starts with empty records and no error', () {
        expect(provider.records, isEmpty);
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);
      });
    });

    group('listenToMaintenanceRecords', () {
      test('receives records from stream', () async {
        provider.listenToMaintenanceRecords('vehicle-id');

        final testRecords = [_createTestRecord()];
        mockFirebaseService.emitRecords(testRecords);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.records, equals(testRecords));
        expect(provider.error, isNull);
      });

      test('sets error on stream error', () async {
        provider.listenToMaintenanceRecords('vehicle-id');

        mockFirebaseService.emitRecordsError(Exception('Network error'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.error, isNotNull);
      });
    });

    group('addMaintenanceRecord', () {
      test('calls firebaseService.addMaintenanceRecord', () async {
        final record = _createTestRecord();
        await provider.addMaintenanceRecord(record);

        expect(mockFirebaseService.addRecordCalled, isTrue);
      });

      test('returns true on success', () async {
        mockFirebaseService.addRecordResult = const Result.success('new-id');

        final record = _createTestRecord();
        final success = await provider.addMaintenanceRecord(record);

        expect(success, isTrue);
        expect(provider.error, isNull);
      });

      test('returns false and sets error on failure', () async {
        mockFirebaseService.addRecordResult = Result.failure(
          const ServerError('Server error'),
        );

        final record = _createTestRecord();
        final success = await provider.addMaintenanceRecord(record);

        expect(success, isFalse);
        expect(provider.error, isNotNull);
        expect(provider.error, isA<ServerError>());
      });
    });

    group('updateMaintenanceRecord', () {
      test('calls firebaseService.updateMaintenanceRecord', () async {
        final record = _createTestRecord();
        await provider.updateMaintenanceRecord('test-id', record);

        expect(mockFirebaseService.updateRecordCalled, isTrue);
      });

      test('returns true on success', () async {
        mockFirebaseService.updateRecordResult = const Result.success(null);

        final record = _createTestRecord();
        final success = await provider.updateMaintenanceRecord('test-id', record);

        expect(success, isTrue);
      });

      test('returns false and sets error on failure', () async {
        mockFirebaseService.updateRecordResult = Result.failure(
          const PermissionError('Forbidden'),
        );

        final record = _createTestRecord();
        final success = await provider.updateMaintenanceRecord('test-id', record);

        expect(success, isFalse);
        expect(provider.error, isA<PermissionError>());
      });
    });

    group('deleteMaintenanceRecord', () {
      test('calls firebaseService.deleteMaintenanceRecord', () async {
        await provider.deleteMaintenanceRecord('test-id');

        expect(mockFirebaseService.deleteRecordCalled, isTrue);
      });

      test('returns true on success', () async {
        mockFirebaseService.deleteRecordResult = const Result.success(null);

        final success = await provider.deleteMaintenanceRecord('test-id');

        expect(success, isTrue);
      });

      test('returns false and sets error on failure', () async {
        mockFirebaseService.deleteRecordResult = Result.failure(
          const NotFoundError('Not found'),
        );

        final success = await provider.deleteMaintenanceRecord('test-id');

        expect(success, isFalse);
        expect(provider.error, isA<NotFoundError>());
      });
    });

    group('getRecordsByType', () {
      test('filters records by type', () async {
        provider.listenToMaintenanceRecords('vehicle-id');

        final records = [
          _createTestRecord(id: '1', type: MaintenanceType.oilChange),
          _createTestRecord(id: '2', type: MaintenanceType.tireChange),
          _createTestRecord(id: '3', type: MaintenanceType.oilChange),
        ];
        mockFirebaseService.emitRecords(records);
        await Future.delayed(const Duration(milliseconds: 50));

        final oilChangeRecords = provider.getRecordsByType(MaintenanceType.oilChange);

        expect(oilChangeRecords.length, equals(2));
        expect(oilChangeRecords.every((r) => r.type == MaintenanceType.oilChange), isTrue);
      });

      test('returns empty list when no records match', () async {
        provider.listenToMaintenanceRecords('vehicle-id');

        final records = [
          _createTestRecord(id: '1', type: MaintenanceType.oilChange),
        ];
        mockFirebaseService.emitRecords(records);
        await Future.delayed(const Duration(milliseconds: 50));

        final result = provider.getRecordsByType(MaintenanceType.carInspection);

        expect(result, isEmpty);
      });
    });

    group('getLatestRecord', () {
      test('returns first record (most recent)', () async {
        provider.listenToMaintenanceRecords('vehicle-id');

        final records = [
          _createTestRecord(id: '1'),
          _createTestRecord(id: '2'),
        ];
        mockFirebaseService.emitRecords(records);
        await Future.delayed(const Duration(milliseconds: 50));

        final latest = provider.getLatestRecord();

        expect(latest, isNotNull);
        expect(latest!.id, equals('1'));
      });

      test('returns null when no records', () {
        final latest = provider.getLatestRecord();

        expect(latest, isNull);
      });
    });

    group('getTotalCost', () {
      test('sums up all record costs', () async {
        provider.listenToMaintenanceRecords('vehicle-id');

        final records = [
          _createTestRecord(id: '1', cost: 5000),
          _createTestRecord(id: '2', cost: 10000),
          _createTestRecord(id: '3', cost: 3000),
        ];
        mockFirebaseService.emitRecords(records);
        await Future.delayed(const Duration(milliseconds: 50));

        final totalCost = provider.getTotalCost();

        expect(totalCost, equals(18000));
      });

      test('returns zero when no records', () {
        final totalCost = provider.getTotalCost();

        expect(totalCost, equals(0));
      });
    });

    group('clear', () {
      test('resets all state', () async {
        provider.listenToMaintenanceRecords('vehicle-id');
        mockFirebaseService.emitRecords([_createTestRecord()]);
        await Future.delayed(const Duration(milliseconds: 50));

        provider.clear();

        expect(provider.records, isEmpty);
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);
      });
    });

    group('clearError', () {
      test('clears the error', () async {
        mockFirebaseService.addRecordResult = Result.failure(
          const ServerError('Error'),
        );

        await provider.addMaintenanceRecord(_createTestRecord());
        expect(provider.error, isNotNull);

        provider.clearError();
        expect(provider.error, isNull);
      });
    });

    group('errorMessage', () {
      test('returns user message from error', () async {
        mockFirebaseService.addRecordResult = Result.failure(
          const ServerError('Internal error'),
        );

        await provider.addMaintenanceRecord(_createTestRecord());

        expect(provider.errorMessage, isNotNull);
        expect(provider.errorMessage, contains('サーバーエラー'));
      });
    });

    group('isRetryable', () {
      test('returns true for network errors', () async {
        mockFirebaseService.addRecordResult = Result.failure(
          const NetworkError('No connection'),
        );

        await provider.addMaintenanceRecord(_createTestRecord());

        expect(provider.isRetryable, isTrue);
      });

      test('returns true for server errors', () async {
        mockFirebaseService.addRecordResult = Result.failure(
          const ServerError('Server down'),
        );

        await provider.addMaintenanceRecord(_createTestRecord());

        expect(provider.isRetryable, isTrue);
      });
    });
  });
}
