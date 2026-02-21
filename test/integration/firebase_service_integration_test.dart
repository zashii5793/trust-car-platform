/// Firebase Service Integration Tests
///
/// These tests verify CRUD operations against Firebase Emulators.
///
/// Prerequisites:
/// 1. Start Firebase Emulators: `firebase emulators:start`
/// 2. Run tests: `flutter test test/integration/firebase_service_integration_test.dart`
///
/// Note: These tests require running Firebase Emulators.
/// Skip with: `flutter test --exclude-tags=emulator`

@Tags(['emulator'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';

import '../helpers/firebase_emulator_helper.dart';

void main() {
  late FirebaseService firebaseService;
  late FirebaseFirestore firestore;
  late String testUserId;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase Emulator connection
    await FirebaseEmulatorHelper.initialize();

    firestore = FirebaseFirestore.instance;
    firebaseService = FirebaseService();
  });

  setUp(() async {
    // Clear data before each test
    await FirebaseEmulatorHelper.clearFirestore();

    // Create a test user
    final credential = await FirebaseEmulatorHelper.createTestUser(
      email: 'vehicle-test@example.com',
      password: 'testpass123',
    );
    testUserId = credential.user!.uid;

    // Create user profile
    await firestore.collection('users').doc(testUserId).set(
          TestDataGenerator.userProfileData(email: 'vehicle-test@example.com'),
        );
  });

  tearDown(() async {
    await FirebaseEmulatorHelper.signOut();
  });

  group('Vehicle CRUD Operations', () {
    test('Create: addVehicle creates a new vehicle document', () async {
      // Arrange
      final vehicle = Vehicle(
        id: '', // Will be assigned by Firestore
        userId: testUserId,
        maker: 'Toyota',
        model: 'Prius',
        year: 2023,
        grade: 'S',
        mileage: 10000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      final result = await firebaseService.addVehicle(vehicle);

      // Assert
      expect(result.isSuccess, true);
      final vehicleId = result.valueOrNull;
      expect(vehicleId, isNotNull);
      expect(vehicleId, isNotEmpty);

      // Verify in Firestore
      final doc = await firestore.collection('vehicles').doc(vehicleId).get();
      expect(doc.exists, true);
      expect(doc.data()?['maker'], 'Toyota');
      expect(doc.data()?['model'], 'Prius');
      expect(doc.data()?['userId'], testUserId);
    });

    test('Read: getVehicle retrieves an existing vehicle', () async {
      // Arrange: Create vehicle directly in Firestore
      final docRef = await firestore.collection('vehicles').add(
            TestDataGenerator.vehicleData(
              userId: testUserId,
              maker: 'Honda',
              model: 'Civic',
              year: 2022,
            ),
          );

      // Act
      final result = await firebaseService.getVehicle(docRef.id);

      // Assert
      expect(result.isSuccess, true);
      final vehicle = result.valueOrNull;
      expect(vehicle, isNotNull);
      expect(vehicle?.id, docRef.id);
      expect(vehicle?.maker, 'Honda');
      expect(vehicle?.model, 'Civic');
      expect(vehicle?.year, 2022);
    });

    test('Read: getVehicle returns error for non-existent vehicle', () async {
      // Act
      final result = await firebaseService.getVehicle('non-existent-id');

      // Assert
      expect(result.isFailure, true);
    });

    test('Read: getUserVehicles stream retrieves all vehicles for a user',
        () async {
      // Arrange: Create multiple vehicles
      await firestore.collection('vehicles').add(
            TestDataGenerator.vehicleData(
              userId: testUserId,
              maker: 'Toyota',
              model: 'Prius',
            ),
          );
      await firestore.collection('vehicles').add(
            TestDataGenerator.vehicleData(
              userId: testUserId,
              maker: 'Honda',
              model: 'Fit',
            ),
          );
      // Add vehicle for different user (should not be returned)
      await firestore.collection('vehicles').add(
            TestDataGenerator.vehicleData(
              userId: 'other-user-id',
              maker: 'Mazda',
              model: 'CX-5',
            ),
          );

      // Act - getUserVehicles returns a Stream
      final stream = firebaseService.getUserVehicles();
      final vehicles = await stream.first;

      // Assert
      expect(vehicles.length, 2);
      expect(vehicles.every((v) => v.userId == testUserId), true);
    });

    test('Update: updateVehicle modifies vehicle data', () async {
      // Arrange: Create vehicle
      final docRef = await firestore.collection('vehicles').add(
            TestDataGenerator.vehicleData(
              userId: testUserId,
              maker: 'Toyota',
              model: 'Prius',
            ),
          );

      // Wait for document to be created
      await Future.delayed(const Duration(milliseconds: 100));

      // Get the vehicle
      final getResult = await firebaseService.getVehicle(docRef.id);
      expect(getResult.isSuccess, true);
      final originalVehicle = getResult.valueOrNull!;

      // Act: Update mileage
      final updatedVehicle = originalVehicle.copyWith(
        mileage: 15000,
        color: 'Red',
      );
      final updateResult = await firebaseService.updateVehicle(
        docRef.id,
        updatedVehicle,
      );

      // Assert
      expect(updateResult.isSuccess, true);

      // Verify in Firestore
      final doc = await firestore.collection('vehicles').doc(docRef.id).get();
      expect(doc.data()?['mileage'], 15000);
      expect(doc.data()?['color'], 'Red');
    });

    test('Delete: deleteVehicle removes vehicle document', () async {
      // Arrange: Create vehicle
      final docRef = await firestore.collection('vehicles').add(
            TestDataGenerator.vehicleData(userId: testUserId),
          );

      // Verify it exists
      var doc = await firestore.collection('vehicles').doc(docRef.id).get();
      expect(doc.exists, true);

      // Act
      final result = await firebaseService.deleteVehicle(docRef.id);

      // Assert
      expect(result.isSuccess, true);

      // Verify deletion
      doc = await firestore.collection('vehicles').doc(docRef.id).get();
      expect(doc.exists, false);
    });

    test('Validation: isLicensePlateExists checks for duplicate plates',
        () async {
      // Arrange: Create vehicle with license plate
      await firestore.collection('vehicles').add({
        ...TestDataGenerator.vehicleData(userId: testUserId),
        'licensePlate': '品川 500 あ 1234',
      });

      // Act & Assert: Check existing plate
      final existsResult =
          await firebaseService.isLicensePlateExists('品川 500 あ 1234');
      expect(existsResult.isSuccess, true);
      expect(existsResult.valueOrNull, true);

      // Act & Assert: Check non-existing plate
      final notExistsResult =
          await firebaseService.isLicensePlateExists('横浜 300 い 5678');
      expect(notExistsResult.isSuccess, true);
      expect(notExistsResult.valueOrNull, false);
    });
  });

  group('MaintenanceRecord CRUD Operations', () {
    late String testVehicleId;

    setUp(() async {
      // Create a test vehicle for maintenance records
      final docRef = await firestore.collection('vehicles').add(
            TestDataGenerator.vehicleData(userId: testUserId),
          );
      testVehicleId = docRef.id;
    });

    test('Create: addMaintenanceRecord creates a new record', () async {
      // Arrange
      final record = MaintenanceRecord(
        id: '',
        vehicleId: testVehicleId,
        userId: testUserId,
        type: MaintenanceType.oilChange,
        title: 'オイル交換',
        cost: 5000,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // Act
      final result = await firebaseService.addMaintenanceRecord(record);

      // Assert
      expect(result.isSuccess, true);
      final recordId = result.valueOrNull;
      expect(recordId, isNotNull);

      // Verify in Firestore
      final doc =
          await firestore.collection('maintenance_records').doc(recordId).get();
      expect(doc.exists, true);
      expect(doc.data()?['type'], 'oilChange');
      expect(doc.data()?['cost'], 5000);
      expect(doc.data()?['vehicleId'], testVehicleId);
    });

    test('Read: getVehicleMaintenanceRecords stream retrieves records',
        () async {
      // Arrange: Create multiple records
      await firestore.collection('maintenance_records').add(
            TestDataGenerator.maintenanceRecordData(
              vehicleId: testVehicleId,
              userId: testUserId,
              type: 'oilChange',
              cost: 5000,
            ),
          );
      await firestore.collection('maintenance_records').add(
            TestDataGenerator.maintenanceRecordData(
              vehicleId: testVehicleId,
              userId: testUserId,
              type: 'tireRotation',
              cost: 3000,
            ),
          );

      // Act - getVehicleMaintenanceRecords returns a Stream
      final stream =
          firebaseService.getVehicleMaintenanceRecords(testVehicleId);
      final records = await stream.first;

      // Assert
      expect(records.length, 2);
      expect(records.every((r) => r.vehicleId == testVehicleId), true);
    });

    test('Update: updateMaintenanceRecord modifies record data', () async {
      // Arrange: Create record
      final docRef = await firestore.collection('maintenance_records').add(
            TestDataGenerator.maintenanceRecordData(
              vehicleId: testVehicleId,
              userId: testUserId,
              cost: 5000,
            ),
          );

      // Wait and get the record
      await Future.delayed(const Duration(milliseconds: 100));
      final doc = await firestore
          .collection('maintenance_records')
          .doc(docRef.id)
          .get();
      final original = MaintenanceRecord.fromFirestore(doc);

      // Act: Update cost
      final updated = original.copyWith(cost: 6000, shopName: 'New Shop');
      final result = await firebaseService.updateMaintenanceRecord(
        docRef.id,
        updated,
      );

      // Assert
      expect(result.isSuccess, true);

      // Verify in Firestore
      final updatedDoc = await firestore
          .collection('maintenance_records')
          .doc(docRef.id)
          .get();
      expect(updatedDoc.data()?['cost'], 6000);
      expect(updatedDoc.data()?['shopName'], 'New Shop');
    });

    test('Delete: deleteMaintenanceRecord removes record', () async {
      // Arrange: Create record
      final docRef = await firestore.collection('maintenance_records').add(
            TestDataGenerator.maintenanceRecordData(
              vehicleId: testVehicleId,
              userId: testUserId,
            ),
          );

      // Verify it exists
      var doc = await firestore
          .collection('maintenance_records')
          .doc(docRef.id)
          .get();
      expect(doc.exists, true);

      // Act
      final result = await firebaseService.deleteMaintenanceRecord(docRef.id);

      // Assert
      expect(result.isSuccess, true);

      // Verify deletion
      doc = await firestore
          .collection('maintenance_records')
          .doc(docRef.id)
          .get();
      expect(doc.exists, false);
    });

    test(
        'Read: getMaintenanceRecordsForVehicles retrieves records for multiple vehicles',
        () async {
      // Arrange: Create another vehicle
      final docRef2 = await firestore.collection('vehicles').add(
            TestDataGenerator.vehicleData(userId: testUserId),
          );
      final vehicleId2 = docRef2.id;

      // Create records for both vehicles
      await firestore.collection('maintenance_records').add(
            TestDataGenerator.maintenanceRecordData(
              vehicleId: testVehicleId,
              userId: testUserId,
            ),
          );
      await firestore.collection('maintenance_records').add(
            TestDataGenerator.maintenanceRecordData(
              vehicleId: vehicleId2,
              userId: testUserId,
            ),
          );

      // Act
      final result = await firebaseService.getMaintenanceRecordsForVehicles(
        [testVehicleId, vehicleId2],
      );

      // Assert
      expect(result.isSuccess, true);
      final recordsMap = result.valueOrNull;
      expect(recordsMap, isNotNull);
      expect(recordsMap?.containsKey(testVehicleId), true);
      expect(recordsMap?.containsKey(vehicleId2), true);
    });
  });

  group('Error Handling', () {
    test('Operations with no user logged in returns empty list', () async {
      // Sign out first
      await FirebaseEmulatorHelper.signOut();

      // Try to get vehicles - Stream version
      final stream = firebaseService.getUserVehicles();
      final vehicles = await stream.first;

      // Should return empty list when no user
      expect(vehicles, isEmpty);
    });
  });
}
