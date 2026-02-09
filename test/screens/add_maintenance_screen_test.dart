import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/add_maintenance_screen.dart';
import 'package:trust_car_platform/providers/maintenance_provider.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/services/invoice_ocr_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/di/injection.dart';

// Mock FirebaseService
class MockFirebaseService implements FirebaseService {
  @override
  String? get currentUserId => 'test-user-id';

  @override
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(String vehicleId) =>
      const Stream.empty();

  @override
  Future<Result<String, AppError>> addMaintenanceRecord(MaintenanceRecord record) async =>
      const Result.success('new-record-id');

  @override
  Future<Result<void, AppError>> updateMaintenanceRecord(String recordId, MaintenanceRecord record) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteMaintenanceRecord(String recordId) async =>
      const Result.success(null);

  @override
  Stream<List<Vehicle>> getUserVehicles() => const Stream.empty();

  @override
  Future<Result<Map<String, List<MaintenanceRecord>>, AppError>> getMaintenanceRecordsForVehicles(
    List<String> vehicleIds, {
    int limitPerVehicle = 20,
  }) async =>
      const Result.success({});

  @override
  Future<Result<List<MaintenanceRecord>, AppError>> getMaintenanceRecordsForVehicle(
    String vehicleId, {
    int limit = 20,
  }) async =>
      const Result.success([]);

  @override
  Future<Result<String, AppError>> addVehicle(Vehicle vehicle) async =>
      const Result.success('id');

  @override
  Future<Result<void, AppError>> updateVehicle(String id, Vehicle vehicle) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteVehicle(String vehicleId) async =>
      const Result.success(null);

  @override
  Future<Result<bool, AppError>> isLicensePlateExists(String licensePlate, {String? excludeVehicleId}) async =>
      const Result.success(false);

  @override
  Future<Result<String, AppError>> uploadImageBytes(dynamic bytes, String path) async =>
      const Result.success('url');

  @override
  Future<Result<Vehicle?, AppError>> getVehicle(String vehicleId) async =>
      const Result.success(null);

  @override
  Future<Result<String, AppError>> uploadImage(dynamic imageFile, String path) async =>
      const Result.success('url');

  @override
  Future<Result<List<String>, AppError>> uploadImages(List<dynamic> imageFiles, String basePath) async =>
      const Result.success([]);

  @override
  Future<Result<String, AppError>> uploadProcessedImage(
    dynamic imageBytes,
    String path, {
    required dynamic imageService,
  }) async =>
      const Result.success('url');
}

// Mock InvoiceOcrService
class MockInvoiceOcrService implements InvoiceOcrService {
  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget createAddMaintenanceScreen({
  String vehicleId = 'test-vehicle-id',
  int? currentVehicleMileage,
}) {
  final mockFirebaseService = MockFirebaseService();

  return MaterialApp(
    home: ChangeNotifierProvider<MaintenanceProvider>(
      create: (_) => MaintenanceProvider(firebaseService: mockFirebaseService),
      child: AddMaintenanceScreen(
        vehicleId: vehicleId,
        currentVehicleMileage: currentVehicleMileage,
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    // Register mock services in ServiceLocator
    final sl = ServiceLocator.instance;
    sl.registerLazySingleton<FirebaseService>(() => MockFirebaseService());
    sl.registerLazySingleton<InvoiceOcrService>(() => MockInvoiceOcrService());
  });

  tearDownAll(() {
    Injection.reset();
  });

  group('AddMaintenanceScreen', () {
    testWidgets('displays app bar with title', (tester) async {
      await tester.pumpWidget(createAddMaintenanceScreen());
      await tester.pump();

      expect(find.text('メンテナンス履歴を追加'), findsOneWidget);
    });

    testWidgets('displays maintenance type label', (tester) async {
      await tester.pumpWidget(createAddMaintenanceScreen());
      await tester.pump();

      expect(find.text('メンテナンスタイプ'), findsOneWidget);
    });

    testWidgets('displays maintenance type chips', (tester) async {
      await tester.pumpWidget(createAddMaintenanceScreen());
      await tester.pump();

      // Common maintenance types
      expect(find.text('オイル交換'), findsOneWidget);
      expect(find.text('車検'), findsOneWidget);
    });

    testWidgets('displays scan invoice button', (tester) async {
      await tester.pumpWidget(createAddMaintenanceScreen());
      await tester.pump();

      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
    });

  });
}
