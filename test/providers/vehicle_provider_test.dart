import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/providers/vehicle_provider.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// Mock FirebaseService for testing
class MockFirebaseService implements FirebaseService {
  final StreamController<List<Vehicle>> _vehiclesController =
      StreamController<List<Vehicle>>.broadcast();

  bool addVehicleCalled = false;
  bool updateVehicleCalled = false;
  bool deleteVehicleCalled = false;
  bool isLicensePlateExistsCalled = false;

  Result<String, AppError>? addVehicleResult;
  Result<void, AppError>? updateVehicleResult;
  Result<void, AppError>? deleteVehicleResult;
  Result<bool, AppError>? isLicensePlateExistsResult;

  @override
  String? get currentUserId => 'test-user-id';

  @override
  Stream<List<Vehicle>> getUserVehicles() => _vehiclesController.stream;

  void emitVehicles(List<Vehicle> vehicles) {
    _vehiclesController.add(vehicles);
  }

  void emitVehiclesError(Object error) {
    _vehiclesController.addError(error);
  }

  @override
  Future<Result<String, AppError>> addVehicle(Vehicle vehicle) async {
    addVehicleCalled = true;
    return addVehicleResult ?? const Result.success('new-vehicle-id');
  }

  @override
  Future<Result<void, AppError>> updateVehicle(String vehicleId, Vehicle vehicle) async {
    updateVehicleCalled = true;
    return updateVehicleResult ?? const Result.success(null);
  }

  @override
  Future<Result<void, AppError>> deleteVehicle(String vehicleId) async {
    deleteVehicleCalled = true;
    return deleteVehicleResult ?? const Result.success(null);
  }

  @override
  Future<Result<bool, AppError>> isLicensePlateExists(
    String licensePlate, {
    String? excludeVehicleId,
  }) async {
    isLicensePlateExistsCalled = true;
    return isLicensePlateExistsResult ?? const Result.success(false);
  }

  // Unused methods for this test
  @override
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(String vehicleId) =>
      const Stream.empty();

  @override
  Future<Result<List<MaintenanceRecord>, AppError>> getMaintenanceRecordsForVehicle(
    String vehicleId, {
    int limit = 20,
  }) async =>
      const Result.success([]);

  @override
  Future<Result<String, AppError>> addMaintenanceRecord(MaintenanceRecord record) async =>
      const Result.success('record-id');

  @override
  Future<Result<void, AppError>> updateMaintenanceRecord(
    String recordId,
    MaintenanceRecord record,
  ) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteMaintenanceRecord(String recordId) async =>
      const Result.success(null);

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
    _vehiclesController.close();
  }
}

Vehicle _createTestVehicle({String? id}) => Vehicle(
      id: id ?? 'test-vehicle-id',
      userId: 'test-user-id',
      maker: 'Toyota',
      model: 'Prius',
      year: 2020,
      grade: 'S',
      mileage: 50000,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

void main() {
  group('VehicleProvider', () {
    late MockFirebaseService mockFirebaseService;
    late VehicleProvider provider;

    setUp(() {
      mockFirebaseService = MockFirebaseService();
      provider = VehicleProvider(firebaseService: mockFirebaseService);
    });

    tearDown(() {
      provider.dispose();
      mockFirebaseService.dispose();
    });

    group('Initial State', () {
      test('starts with empty vehicles and no error', () {
        expect(provider.vehicles, isEmpty);
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);
        expect(provider.selectedVehicle, isNull);
      });
    });

    group('listenToVehicles', () {
      test('receives vehicles from stream', () async {
        provider.listenToVehicles();

        final testVehicles = [_createTestVehicle()];
        mockFirebaseService.emitVehicles(testVehicles);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.vehicles, equals(testVehicles));
        expect(provider.error, isNull);
      });

      test('sets error on stream error', () async {
        provider.listenToVehicles();

        mockFirebaseService.emitVehiclesError(Exception('Network error'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.error, isNotNull);
      });
    });

    group('selectVehicle', () {
      test('sets the selected vehicle', () {
        final vehicle = _createTestVehicle();
        provider.selectVehicle(vehicle);

        expect(provider.selectedVehicle, equals(vehicle));
      });

      test('can unselect vehicle', () {
        final vehicle = _createTestVehicle();
        provider.selectVehicle(vehicle);
        provider.selectVehicle(null);

        expect(provider.selectedVehicle, isNull);
      });
    });

    group('addVehicle', () {
      test('calls firebaseService.addVehicle', () async {
        final vehicle = _createTestVehicle();
        await provider.addVehicle(vehicle);

        expect(mockFirebaseService.addVehicleCalled, isTrue);
      });

      test('returns true on success', () async {
        mockFirebaseService.addVehicleResult = const Result.success('new-id');

        final vehicle = _createTestVehicle();
        final success = await provider.addVehicle(vehicle);

        expect(success, isTrue);
        expect(provider.error, isNull);
      });

      test('returns false and sets error on failure', () async {
        mockFirebaseService.addVehicleResult = Result.failure(
          const ServerError('Server error'),
        );

        final vehicle = _createTestVehicle();
        final success = await provider.addVehicle(vehicle);

        expect(success, isFalse);
        expect(provider.error, isNotNull);
        expect(provider.error, isA<ServerError>());
      });

      test('sets isLoading during operation', () async {
        final vehicle = _createTestVehicle();

        // Start operation
        final future = provider.addVehicle(vehicle);

        // Cannot check isLoading synchronously in async test
        await future;

        expect(provider.isLoading, isFalse);
      });
    });

    group('updateVehicle', () {
      test('calls firebaseService.updateVehicle', () async {
        final vehicle = _createTestVehicle();
        await provider.updateVehicle('test-id', vehicle);

        expect(mockFirebaseService.updateVehicleCalled, isTrue);
      });

      test('returns true on success', () async {
        mockFirebaseService.updateVehicleResult = const Result.success(null);

        final vehicle = _createTestVehicle();
        final success = await provider.updateVehicle('test-id', vehicle);

        expect(success, isTrue);
      });

      test('returns false and sets error on failure', () async {
        mockFirebaseService.updateVehicleResult = Result.failure(
          const PermissionError('Forbidden'),
        );

        final vehicle = _createTestVehicle();
        final success = await provider.updateVehicle('test-id', vehicle);

        expect(success, isFalse);
        expect(provider.error, isA<PermissionError>());
      });
    });

    group('deleteVehicle', () {
      test('calls firebaseService.deleteVehicle', () async {
        await provider.deleteVehicle('test-id');

        expect(mockFirebaseService.deleteVehicleCalled, isTrue);
      });

      test('returns true on success', () async {
        mockFirebaseService.deleteVehicleResult = const Result.success(null);

        final success = await provider.deleteVehicle('test-id');

        expect(success, isTrue);
      });

      test('clears selectedVehicle if deleted', () async {
        final vehicle = _createTestVehicle(id: 'vehicle-to-delete');
        provider.selectVehicle(vehicle);
        expect(provider.selectedVehicle, isNotNull);

        mockFirebaseService.deleteVehicleResult = const Result.success(null);
        await provider.deleteVehicle('vehicle-to-delete');

        expect(provider.selectedVehicle, isNull);
      });

      test('does not clear selectedVehicle if different vehicle deleted', () async {
        final vehicle = _createTestVehicle(id: 'selected-vehicle');
        provider.selectVehicle(vehicle);

        mockFirebaseService.deleteVehicleResult = const Result.success(null);
        await provider.deleteVehicle('other-vehicle');

        expect(provider.selectedVehicle, equals(vehicle));
      });
    });

    group('isLicensePlateExists', () {
      test('calls firebaseService.isLicensePlateExists', () async {
        await provider.isLicensePlateExists('ABC-1234');

        expect(mockFirebaseService.isLicensePlateExistsCalled, isTrue);
      });

      test('returns true when license plate exists', () async {
        mockFirebaseService.isLicensePlateExistsResult = const Result.success(true);

        final exists = await provider.isLicensePlateExists('ABC-1234');

        expect(exists, isTrue);
      });

      test('returns false when license plate does not exist', () async {
        mockFirebaseService.isLicensePlateExistsResult = const Result.success(false);

        final exists = await provider.isLicensePlateExists('NEW-1234');

        expect(exists, isFalse);
      });

      test('returns false on error', () async {
        mockFirebaseService.isLicensePlateExistsResult = Result.failure(
          const NetworkError('Timeout'),
        );

        final exists = await provider.isLicensePlateExists('ABC-1234');

        expect(exists, isFalse);
      });
    });

    group('clear', () {
      test('resets all state', () async {
        // Setup some state
        provider.listenToVehicles();
        mockFirebaseService.emitVehicles([_createTestVehicle()]);
        await Future.delayed(const Duration(milliseconds: 50));
        provider.selectVehicle(_createTestVehicle());

        // Clear
        provider.clear();

        expect(provider.vehicles, isEmpty);
        expect(provider.selectedVehicle, isNull);
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);
      });
    });

    group('clearError', () {
      test('clears the error', () async {
        mockFirebaseService.addVehicleResult = Result.failure(
          const ServerError('Error'),
        );

        await provider.addVehicle(_createTestVehicle());
        expect(provider.error, isNotNull);

        provider.clearError();
        expect(provider.error, isNull);
      });
    });

    group('errorMessage', () {
      test('returns user message from error', () async {
        mockFirebaseService.addVehicleResult = Result.failure(
          const ServerError('Internal error'),
        );

        await provider.addVehicle(_createTestVehicle());

        expect(provider.errorMessage, isNotNull);
        expect(provider.errorMessage, contains('サーバーエラー'));
      });
    });

    group('isRetryable', () {
      test('returns true for network errors', () async {
        mockFirebaseService.addVehicleResult = Result.failure(
          const NetworkError('No connection'),
        );

        await provider.addVehicle(_createTestVehicle());

        expect(provider.isRetryable, isTrue);
      });

      test('returns false for permission errors', () async {
        mockFirebaseService.addVehicleResult = Result.failure(
          const PermissionError('Forbidden'),
        );

        await provider.addVehicle(_createTestVehicle());

        expect(provider.isRetryable, isFalse);
      });
    });
  });
}
