/// DriveLog Service Integration Tests
///
/// These tests verify CRUD operations for DriveLog and DriveSpot
/// against Firebase Emulators.
///
/// Prerequisites:
/// 1. Start Firebase Emulators: `firebase emulators:start`
/// 2. Run tests: `flutter test test/integration/drive_log_service_integration_test.dart`

@Tags(['emulator'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/drive_log_service.dart';
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/models/drive_spot.dart';

import '../helpers/firebase_emulator_helper.dart';

void main() {
  late DriveLogService driveLogService;
  late FirebaseFirestore firestore;
  late String testUserId;
  late String testVehicleId;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    await FirebaseEmulatorHelper.initialize();

    firestore = FirebaseFirestore.instance;
    driveLogService = DriveLogService();
  });

  setUp(() async {
    await FirebaseEmulatorHelper.clearFirestore();

    // Create test user
    final credential = await FirebaseEmulatorHelper.createTestUser(
      email: 'drivelog-test@example.com',
      password: 'testpass123',
    );
    testUserId = credential.user!.uid;

    // Create user profile
    await firestore.collection('users').doc(testUserId).set(
          TestDataGenerator.userProfileData(email: 'drivelog-test@example.com'),
        );

    // Create test vehicle
    final vehicleRef = await firestore.collection('vehicles').add(
          TestDataGenerator.vehicleData(userId: testUserId),
        );
    testVehicleId = vehicleRef.id;
  });

  tearDown(() async {
    await FirebaseEmulatorHelper.signOut();
  });

  group('DriveLog CRUD Operations', () {
    test('Create: startDrive creates a new drive log', () async {
      // Act
      final result = await driveLogService.startDrive(
        userId: testUserId,
        vehicleId: testVehicleId,
        startLocation: const GeoPoint2D(latitude: 35.6762, longitude: 139.6503),
        startAddress: '東京都渋谷区',
      );

      // Assert
      expect(result.isSuccess, true);
      final driveLog = result.valueOrNull;
      expect(driveLog, isNotNull);
      // startDrive returns DriveLog, not String
      final driveLogId = driveLog!.id;

      // Verify in Firestore
      final doc =
          await firestore.collection('drive_logs').doc(driveLogId).get();
      expect(doc.exists, true);
      expect(doc.data()?['userId'], testUserId);
      expect(doc.data()?['vehicleId'], testVehicleId);
      expect(doc.data()?['status'], 'recording');
    });

    test('Read: getDriveLog retrieves an existing drive log', () async {
      // Arrange: Create drive log directly
      final docRef = await firestore.collection('drive_logs').add(
            TestDataGenerator.driveLogData(
              userId: testUserId,
              vehicleId: testVehicleId,
            ),
          );

      // Act
      final result = await driveLogService.getDriveLog(docRef.id);

      // Assert
      expect(result.isSuccess, true);
      final driveLog = result.valueOrNull;
      expect(driveLog, isNotNull);
      expect(driveLog?.id, docRef.id);
      expect(driveLog?.userId, testUserId);
    });

    test('Read: getUserDriveLogs retrieves all drive logs for a user',
        () async {
      // Arrange: Create multiple drive logs
      await firestore.collection('drive_logs').add(
            TestDataGenerator.driveLogData(
              userId: testUserId,
              vehicleId: testVehicleId,
            ),
          );
      await firestore.collection('drive_logs').add(
            TestDataGenerator.driveLogData(
              userId: testUserId,
              vehicleId: testVehicleId,
              status: 'completed',
            ),
          );

      // Act — uses named parameter
      final result = await driveLogService.getUserDriveLogs(userId: testUserId);

      // Assert
      expect(result.isSuccess, true);
      final driveLogs = result.valueOrNull;
      expect(driveLogs, isNotNull);
      expect(driveLogs?.length, 2);
    });

    test('Update: endDrive updates drive log status to completed', () async {
      // Arrange: Create drive log
      final docRef = await firestore.collection('drive_logs').add(
            TestDataGenerator.driveLogData(
              userId: testUserId,
              vehicleId: testVehicleId,
              status: 'recording',
            ),
          );

      // Act
      final result = await driveLogService.endDrive(
        driveLogId: docRef.id,
        userId: testUserId,
        endLocation: const GeoPoint2D(latitude: 35.6895, longitude: 139.6917),
        endAddress: '東京都新宿区',
        statistics: DriveStatistics(
          totalDistance: 15.5,
          totalDuration: 1800,
          averageSpeed: 31.0,
          maxSpeed: 60.0,
        ),
      );

      // Assert
      expect(result.isSuccess, true);

      // Verify in Firestore
      final doc =
          await firestore.collection('drive_logs').doc(docRef.id).get();
      expect(doc.data()?['status'], 'completed');
      expect(doc.data()?['statistics']['totalDistance'], 15.5);
    });

    test('Update: updateDriveLog modifies drive log data', () async {
      // Arrange
      final docRef = await firestore.collection('drive_logs').add(
            TestDataGenerator.driveLogData(
              userId: testUserId,
              vehicleId: testVehicleId,
            ),
          );

      await Future.delayed(const Duration(milliseconds: 100));

      // Act — uses named parameters, not DriveLog object
      final result = await driveLogService.updateDriveLog(
        driveLogId: docRef.id,
        userId: testUserId,
        title: 'Weekend Drive',
        description: 'A nice drive through the countryside',
        isPublic: true,
      );

      // Assert
      expect(result.isSuccess, true);

      final doc =
          await firestore.collection('drive_logs').doc(docRef.id).get();
      expect(doc.data()?['title'], 'Weekend Drive');
      expect(doc.data()?['isPublic'], true);
    });

    test('Delete: deleteDriveLog removes drive log', () async {
      // Arrange
      final docRef = await firestore.collection('drive_logs').add(
            TestDataGenerator.driveLogData(
              userId: testUserId,
              vehicleId: testVehicleId,
            ),
          );

      // Act — uses named parameters
      final result = await driveLogService.deleteDriveLog(
        driveLogId: docRef.id,
        userId: testUserId,
      );

      // Assert
      expect(result.isSuccess, true);

      final doc =
          await firestore.collection('drive_logs').doc(docRef.id).get();
      expect(doc.exists, false);
    });

    test('Read: getPublicDriveLogs retrieves only public drive logs',
        () async {
      // Arrange: Create public and private drive logs
      await firestore.collection('drive_logs').add({
        ...TestDataGenerator.driveLogData(userId: testUserId),
        'isPublic': true,
        'status': 'completed',
      });
      await firestore.collection('drive_logs').add({
        ...TestDataGenerator.driveLogData(userId: testUserId),
        'isPublic': false,
        'status': 'completed',
      });

      // Act
      final result = await driveLogService.getPublicDriveLogs();

      // Assert
      expect(result.isSuccess, true);
      final driveLogs = result.valueOrNull;
      expect(driveLogs?.every((d) => d.isPublic), true);
    });
  });

  group('DriveWaypoint Operations', () {
    late String testDriveLogId;

    setUp(() async {
      // Create a test drive log
      final docRef = await firestore.collection('drive_logs').add(
            TestDataGenerator.driveLogData(
              userId: testUserId,
              vehicleId: testVehicleId,
            ),
          );
      testDriveLogId = docRef.id;
    });

    test('Create: addWaypoint adds a waypoint to drive log', () async {
      // Act
      final result = await driveLogService.addWaypoint(
        driveLogId: testDriveLogId,
        waypoint: DriveWaypoint(
          location: const GeoPoint2D(latitude: 35.6762, longitude: 139.6503),
          timestamp: DateTime.now(),
          speed: 50.0,
          altitude: 30.0,
        ),
      );

      // Assert
      expect(result.isSuccess, true);

      // Verify in Firestore — waypoints are stored in top-level 'drive_waypoints' collection
      final waypointsSnapshot = await firestore
          .collection('drive_waypoints')
          .where('driveLogId', isEqualTo: testDriveLogId)
          .get();
      expect(waypointsSnapshot.docs.length, 1);
      expect(waypointsSnapshot.docs.first.data()['speed'], 50.0);
    });

    test('Read: getWaypoints retrieves all waypoints for a drive log',
        () async {
      // Arrange: Add multiple waypoints directly to top-level collection
      await firestore.collection('drive_waypoints').add({
        'driveLogId': testDriveLogId,
        'location': {'latitude': 35.6762, 'longitude': 139.6503},
        'timestamp': Timestamp.now(),
        'speed': 50.0,
      });
      await firestore.collection('drive_waypoints').add({
        'driveLogId': testDriveLogId,
        'location': {'latitude': 35.6800, 'longitude': 139.6600},
        'timestamp': Timestamp.now(),
        'speed': 55.0,
      });

      // Act
      final result = await driveLogService.getWaypoints(testDriveLogId);

      // Assert
      expect(result.isSuccess, true);
      final waypoints = result.valueOrNull;
      expect(waypoints?.length, 2);
    });
  });

  group('DriveLog Like Operations', () {
    late String testDriveLogId;

    setUp(() async {
      final docRef = await firestore.collection('drive_logs').add({
        ...TestDataGenerator.driveLogData(userId: testUserId),
        'isPublic': true,
        'likeCount': 0,
      });
      testDriveLogId = docRef.id;
    });

    test('Like: likeDriveLog adds a like', () async {
      // Act — uses named parameters
      final result = await driveLogService.likeDriveLog(
        driveLogId: testDriveLogId,
        userId: testUserId,
      );

      // Assert
      expect(result.isSuccess, true);

      // Verify like document exists in top-level 'drive_log_likes' collection
      final likeSnapshot = await firestore
          .collection('drive_log_likes')
          .where('driveLogId', isEqualTo: testDriveLogId)
          .where('userId', isEqualTo: testUserId)
          .get();
      expect(likeSnapshot.docs.isNotEmpty, true);
    });

    test('Unlike: unlikeDriveLog removes a like', () async {
      // Arrange: Add like first
      await firestore.collection('drive_log_likes').add({
        'driveLogId': testDriveLogId,
        'userId': testUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Act — uses named parameters
      final result = await driveLogService.unlikeDriveLog(
        driveLogId: testDriveLogId,
        userId: testUserId,
      );

      // Assert
      expect(result.isSuccess, true);

      final likeSnapshot = await firestore
          .collection('drive_log_likes')
          .where('driveLogId', isEqualTo: testDriveLogId)
          .where('userId', isEqualTo: testUserId)
          .get();
      expect(likeSnapshot.docs.isEmpty, true);
    });

    test('Check: isLikedByUser correctly identifies liked status', () async {
      // Initially not liked — uses named parameters
      var result = await driveLogService.isLikedByUser(
        driveLogId: testDriveLogId,
        userId: testUserId,
      );
      expect(result.valueOrNull, false);

      // Add like
      await firestore.collection('drive_log_likes').add({
        'driveLogId': testDriveLogId,
        'userId': testUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Now should be liked
      result = await driveLogService.isLikedByUser(
        driveLogId: testDriveLogId,
        userId: testUserId,
      );
      expect(result.valueOrNull, true);
    });
  });

  group('DriveSpot CRUD Operations', () {
    test('Create: createSpot creates a new spot', () async {
      // Act
      final result = await driveLogService.createSpot(
        userId: testUserId,
        name: 'Beautiful View Point',
        description: 'Amazing sunset views',
        category: SpotCategory.scenicView,
        location: const GeoPoint2D(latitude: 35.6762, longitude: 139.6503),
        address: '東京都渋谷区',
      );

      // Assert
      expect(result.isSuccess, true);
      final spot = result.valueOrNull;
      expect(spot, isNotNull);
      // createSpot returns DriveSpot object
      final spotId = spot!.id;

      // Verify in Firestore
      final doc = await firestore.collection('spots').doc(spotId).get();
      expect(doc.exists, true);
      expect(doc.data()?['name'], 'Beautiful View Point');
      expect(doc.data()?['category'], 'scenicView');
    });

    test('Read: getSpot retrieves an existing spot', () async {
      // Arrange
      final docRef = await firestore.collection('spots').add(
            TestDataGenerator.driveSpotData(
              userId: testUserId,
              name: 'Test Cafe',
              category: 'cafe',
            ),
          );

      // Act
      final result = await driveLogService.getSpot(docRef.id);

      // Assert
      expect(result.isSuccess, true);
      final spot = result.valueOrNull;
      expect(spot?.name, 'Test Cafe');
      expect(spot?.category, SpotCategory.cafe);
    });

    test('Read: searchSpotsByLocation finds nearby spots', () async {
      // Arrange: Create spots at different locations
      await firestore.collection('spots').add(
            TestDataGenerator.driveSpotData(
              userId: testUserId,
              name: 'Tokyo Spot',
              latitude: 35.6762,
              longitude: 139.6503,
            ),
          );
      await firestore.collection('spots').add(
            TestDataGenerator.driveSpotData(
              userId: testUserId,
              name: 'Far Away Spot',
              latitude: 34.6937, // Osaka
              longitude: 135.5023,
            ),
          );

      // Act: Search near Tokyo
      final result = await driveLogService.searchSpotsByLocation(
        center: const GeoPoint2D(latitude: 35.6762, longitude: 139.6503),
        radiusKm: 10,
      );

      // Assert
      expect(result.isSuccess, true);
      final spots = result.valueOrNull;
      // Should find Tokyo spot, not Osaka spot
      expect(spots?.any((s) => s.name == 'Tokyo Spot'), true);
    });

    test('Read: searchSpotsByText finds spots by name', () async {
      // Arrange
      await firestore.collection('spots').add(
            TestDataGenerator.driveSpotData(
              userId: testUserId,
              name: 'Mountain View Cafe',
            ),
          );
      await firestore.collection('spots').add(
            TestDataGenerator.driveSpotData(
              userId: testUserId,
              name: 'Beach Restaurant',
            ),
          );

      // Act — uses named parameter 'query:'
      final result = await driveLogService.searchSpotsByText(query: 'Cafe');

      // Assert
      expect(result.isSuccess, true);
      final spots = result.valueOrNull;
      expect(spots?.any((s) => s.name.contains('Cafe')), true);
    });

    test('Update: updateSpot modifies spot data', () async {
      // Arrange
      final docRef = await firestore.collection('spots').add(
            TestDataGenerator.driveSpotData(
              userId: testUserId,
              name: 'Original Name',
            ),
          );

      await Future.delayed(const Duration(milliseconds: 100));

      // Act — uses named parameters, not DriveSpot object
      final result = await driveLogService.updateSpot(
        spotId: docRef.id,
        userId: testUserId,
        name: 'Updated Name',
        description: 'New description',
      );

      // Assert
      expect(result.isSuccess, true);

      final doc = await firestore.collection('spots').doc(docRef.id).get();
      expect(doc.data()?['name'], 'Updated Name');
    });

    test('Delete: deleteSpot removes spot', () async {
      // Arrange
      final docRef = await firestore.collection('spots').add(
            TestDataGenerator.driveSpotData(userId: testUserId),
          );

      // Act — uses named parameters
      final result = await driveLogService.deleteSpot(
        spotId: docRef.id,
        userId: testUserId,
      );

      // Assert
      expect(result.isSuccess, true);

      final doc = await firestore.collection('spots').doc(docRef.id).get();
      expect(doc.exists, false);
    });
  });

  group('SpotRating Operations', () {
    late String testSpotId;

    setUp(() async {
      final docRef = await firestore.collection('spots').add(
            TestDataGenerator.driveSpotData(userId: testUserId),
          );
      testSpotId = docRef.id;
    });

    test('Create: addSpotRating adds a rating', () async {
      // Act — rating must be int (1-5), not double
      final result = await driveLogService.addSpotRating(
        spotId: testSpotId,
        userId: testUserId,
        rating: 4, // int, not 4.5
        comment: 'Great spot!',
      );

      // Assert
      expect(result.isSuccess, true);

      // Verify rating exists in top-level 'spot_ratings' collection
      final ratingsSnapshot = await firestore
          .collection('spot_ratings')
          .where('spotId', isEqualTo: testSpotId)
          .get();
      expect(ratingsSnapshot.docs.isNotEmpty, true);
    });

    test('Read: getSpotRatings retrieves all ratings', () async {
      // Arrange
      await firestore.collection('spot_ratings').add({
        'spotId': testSpotId,
        'userId': testUserId,
        'rating': 4,
        'comment': 'Great!',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Act — uses named parameter 'spotId:'
      final result = await driveLogService.getSpotRatings(spotId: testSpotId);

      // Assert
      expect(result.isSuccess, true);
      final ratings = result.valueOrNull;
      expect(ratings?.isNotEmpty, true);
    });

    group('Edge Cases', () {
      test('addSpotRating: rating 0 returns validation error', () async {
        final result = await driveLogService.addSpotRating(
          spotId: testSpotId,
          userId: testUserId,
          rating: 0,
        );
        expect(result.isFailure, true);
      });

      test('addSpotRating: rating 6 returns validation error', () async {
        final result = await driveLogService.addSpotRating(
          spotId: testSpotId,
          userId: testUserId,
          rating: 6,
        );
        expect(result.isFailure, true);
      });

      test('addSpotRating: negative rating returns validation error', () async {
        final result = await driveLogService.addSpotRating(
          spotId: testSpotId,
          userId: testUserId,
          rating: -1,
        );
        expect(result.isFailure, true);
      });
    });
  });

  group('SpotFavorite Operations', () {
    late String testSpotId;

    setUp(() async {
      final docRef = await firestore.collection('spots').add({
        ...TestDataGenerator.driveSpotData(userId: testUserId),
        'favoriteCount': 0,
      });
      testSpotId = docRef.id;
    });

    test('Add/Remove favorite works correctly', () async {
      // Add favorite — uses named parameters
      var result = await driveLogService.addSpotFavorite(
        spotId: testSpotId,
        userId: testUserId,
      );
      expect(result.isSuccess, true);

      // Verify favorite exists in top-level 'spot_favorites' collection
      var favSnapshot = await firestore
          .collection('spot_favorites')
          .where('spotId', isEqualTo: testSpotId)
          .where('userId', isEqualTo: testUserId)
          .get();
      expect(favSnapshot.docs.isNotEmpty, true);

      // Remove favorite — uses named parameters
      result = await driveLogService.removeSpotFavorite(
        spotId: testSpotId,
        userId: testUserId,
      );
      expect(result.isSuccess, true);

      // Verify favorite removed
      favSnapshot = await firestore
          .collection('spot_favorites')
          .where('spotId', isEqualTo: testSpotId)
          .where('userId', isEqualTo: testUserId)
          .get();
      expect(favSnapshot.docs.isEmpty, true);
    });

    test('getUserFavoriteSpots retrieves favorite spots', () async {
      // Arrange: Add favorite
      await firestore.collection('spot_favorites').add({
        'spotId': testSpotId,
        'userId': testUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Act — uses named parameter
      final result = await driveLogService.getUserFavoriteSpots(
        userId: testUserId,
      );

      // Assert
      expect(result.isSuccess, true);
    });
  });

  group('SpotVisit Operations', () {
    late String testSpotId;

    setUp(() async {
      final docRef = await firestore.collection('spots').add({
        ...TestDataGenerator.driveSpotData(userId: testUserId),
        'visitCount': 0,
      });
      testSpotId = docRef.id;
    });

    test('recordSpotVisit records a visit', () async {
      // Act
      final result = await driveLogService.recordSpotVisit(
        spotId: testSpotId,
        userId: testUserId,
      );

      // Assert
      expect(result.isSuccess, true);

      // Verify visit recorded in top-level 'spot_visits' collection
      final visitsSnapshot = await firestore
          .collection('spot_visits')
          .where('userId', isEqualTo: testUserId)
          .get();
      expect(visitsSnapshot.docs.isNotEmpty, true);
    });

    test('getUserSpotVisits retrieves user visits', () async {
      // Arrange: Record a visit
      await firestore.collection('spot_visits').add({
        'spotId': testSpotId,
        'userId': testUserId,
        'visitedAt': FieldValue.serverTimestamp(),
      });

      // Act — uses named parameter
      final result = await driveLogService.getUserSpotVisits(userId: testUserId);

      // Assert
      expect(result.isSuccess, true);
    });
  });

  group('User Statistics', () {
    test('getUserDriveStatistics calculates correct statistics', () async {
      // Arrange: Create completed drive logs
      await firestore.collection('drive_logs').add({
        ...TestDataGenerator.driveLogData(userId: testUserId),
        'status': 'completed',
        'statistics': {
          'totalDistance': 100.0,
          'totalDuration': 3600,
          'averageSpeed': 50.0,
          'maxSpeed': 80.0,
        },
      });
      await firestore.collection('drive_logs').add({
        ...TestDataGenerator.driveLogData(userId: testUserId),
        'status': 'completed',
        'statistics': {
          'totalDistance': 50.0,
          'totalDuration': 1800,
          'averageSpeed': 40.0,
          'maxSpeed': 60.0,
        },
      });

      // Act
      final result = await driveLogService.getUserDriveStatistics(testUserId);

      // Assert
      expect(result.isSuccess, true);
      final stats = result.valueOrNull;
      expect(stats, isNotNull);
      // Total distance should be 150.0
      expect(stats?['totalDistance'], 150.0);
      // Key is 'driveCount' (not 'totalDrives')
      expect(stats?['driveCount'], 2);
    });

    group('Edge Cases', () {
      test('getUserDriveStatistics: non-existent user returns empty stats',
          () async {
        final result =
            await driveLogService.getUserDriveStatistics('non-existent-user');
        expect(result.isSuccess, true);
        final stats = result.valueOrNull;
        expect(stats?['driveCount'], 0);
        expect(stats?['totalDistance'], 0.0);
      });
    });
  });
}
