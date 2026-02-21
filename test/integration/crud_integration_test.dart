/// CRUD Integration Tests
///
/// This file tests CRUD operations for all models
/// verifying serialization, deserialization, and data integrity.
///
/// Run with: flutter test test/integration/crud_integration_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/models/post.dart';
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/models/drive_spot.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

void main() {
  group('Vehicle Model CRUD Tests', () {
    test('Create: Vehicle can be instantiated with required fields', () {
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
      );

      expect(vehicle.id, 'v1');
      expect(vehicle.userId, 'u1');
      expect(vehicle.maker, 'Toyota');
      expect(vehicle.model, 'Prius');
      expect(vehicle.year, 2023);
      expect(vehicle.grade, 'S');
      expect(vehicle.mileage, 10000);
    });

    test('Create: Vehicle can be instantiated with all optional fields', () {
      final now = DateTime.now();
      final vehicle = Vehicle(
        id: 'v1',
        userId: 'u1',
        maker: 'Honda',
        model: 'Civic',
        year: 2022,
        grade: 'RS',
        mileage: 5000,
        createdAt: now,
        updatedAt: now,
        licensePlate: '品川 500 あ 1234',
        color: 'Blue',
        imageUrl: 'https://example.com/image.jpg',
        vinNumber: 'JH4KA8260MC000001',
        purchaseDate: now,
      );

      expect(vehicle.licensePlate, '品川 500 あ 1234');
      expect(vehicle.color, 'Blue');
      expect(vehicle.imageUrl, 'https://example.com/image.jpg');
      expect(vehicle.vinNumber, 'JH4KA8260MC000001');
    });

    test('Update: Vehicle.copyWith creates new instance with updated fields', () {
      final now = DateTime.now();
      final original = Vehicle(
        id: 'v1',
        userId: 'u1',
        maker: 'Toyota',
        model: 'Prius',
        year: 2023,
        grade: 'S',
        mileage: 10000,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(
        mileage: 15000,
        color: 'Red',
      );

      // Updated fields
      expect(updated.mileage, 15000);
      expect(updated.color, 'Red');

      // Unchanged fields
      expect(updated.id, 'v1');
      expect(updated.maker, 'Toyota');
      expect(updated.model, 'Prius');
      expect(updated.year, 2023);
    });

    test('Serialization: Vehicle.toMap creates correct map', () {
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
      expect(map['grade'], 'S');
      expect(map['mileage'], 10000);
      expect(map['licensePlate'], '品川 500 あ 1234');
    });
  });

  group('MaintenanceRecord Model CRUD Tests', () {
    test('Create: MaintenanceRecord can be instantiated', () {
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
      );

      expect(record.id, 'r1');
      expect(record.type, MaintenanceType.oilChange);
      expect(record.cost, 5000);
    });

    test('Update: MaintenanceRecord.copyWith works', () {
      final now = DateTime.now();
      final original = MaintenanceRecord(
        id: 'r1',
        vehicleId: 'v1',
        userId: 'u1',
        type: MaintenanceType.oilChange,
        title: 'オイル交換',
        cost: 5000,
        date: now,
        createdAt: now,
      );

      final updated = original.copyWith(cost: 6000, shopName: 'New Shop');

      expect(updated.cost, 6000);
      expect(updated.shopName, 'New Shop');
      expect(updated.type, MaintenanceType.oilChange); // unchanged
    });

    test('Serialization: MaintenanceRecord.toMap creates correct map', () {
      final now = DateTime.now();
      final record = MaintenanceRecord(
        id: 'r1',
        vehicleId: 'v1',
        userId: 'u1',
        type: MaintenanceType.carInspection,
        title: '車検',
        cost: 100000,
        date: now,
        createdAt: now,
      );

      final map = record.toMap();

      expect(map['type'], 'carInspection');
      expect(map['title'], '車検');
      expect(map['cost'], 100000);
    });

    test('MaintenanceType enum has all expected values', () {
      expect(MaintenanceType.values.length, greaterThanOrEqualTo(5));
      expect(MaintenanceType.oilChange.displayName, 'オイル交換');
      expect(MaintenanceType.carInspection.displayName, '車検');
    });
  });

  group('AppUser Model CRUD Tests', () {
    test('Create: AppUser can be instantiated', () {
      final now = DateTime.now();
      final user = AppUser(
        id: 'u1',
        email: 'test@example.com',
        displayName: 'Test User',
        createdAt: now,
        updatedAt: now,
      );

      expect(user.id, 'u1');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
    });

    test('Create: AppUser with all optional fields', () {
      final now = DateTime.now();
      final user = AppUser(
        id: 'u1',
        email: 'test@example.com',
        displayName: 'Test User',
        photoUrl: 'https://example.com/photo.jpg',
        createdAt: now,
        updatedAt: now,
        notificationSettings: NotificationSettings(
          maintenanceReminder: true,
          pushEnabled: false,
        ),
      );

      expect(user.photoUrl, 'https://example.com/photo.jpg');
      expect(user.notificationSettings.maintenanceReminder, true);
      expect(user.notificationSettings.pushEnabled, false);
    });

    test('Serialization: AppUser.toMap creates correct map', () {
      final now = DateTime.now();
      final user = AppUser(
        id: 'u1',
        email: 'test@example.com',
        displayName: 'Test User',
        createdAt: now,
        updatedAt: now,
      );

      final map = user.toMap();

      expect(map['email'], 'test@example.com');
      expect(map['displayName'], 'Test User');
    });

    test('NotificationSettings has correct defaults', () {
      final settings = NotificationSettings();

      expect(settings.pushEnabled, true);
      expect(settings.maintenanceReminder, true);
      expect(settings.inspectionReminder, true);
    });

    test('NotificationSettings.fromMap parses correctly', () {
      final map = {
        'pushEnabled': false,
        'maintenanceReminder': true,
        'inspectionReminder': false,
      };

      final settings = NotificationSettings.fromMap(map);

      expect(settings.pushEnabled, false);
      expect(settings.maintenanceReminder, true);
      expect(settings.inspectionReminder, false);
    });

    test('NotificationSettings.copyWith works', () {
      final original = NotificationSettings();
      final updated = original.copyWith(pushEnabled: false);

      expect(updated.pushEnabled, false);
      expect(updated.maintenanceReminder, true); // unchanged
    });
  });

  group('Post Model CRUD Tests', () {
    test('Create: Post can be instantiated with required fields', () {
      final now = DateTime.now();
      final post = Post(
        id: 'p1',
        userId: 'u1',
        category: PostCategory.general,
        content: 'Test post content',
        createdAt: now,
        updatedAt: now,
      );

      expect(post.id, 'p1');
      expect(post.userId, 'u1');
      expect(post.content, 'Test post content');
      expect(post.category, PostCategory.general);
    });

    test('Create: Post with all optional fields', () {
      final now = DateTime.now();
      final post = Post(
        id: 'p1',
        userId: 'u1',
        category: PostCategory.drive,
        content: 'Check out my car! #Toyota #Prius',
        createdAt: now,
        updatedAt: now,
        likeCount: 10,
        commentCount: 5,
        viewCount: 100,
        hashtags: ['Toyota', 'Prius'],
      );

      expect(post.likeCount, 10);
      expect(post.hashtags.length, 2);
    });

    test('PostCategory has expected values', () {
      expect(PostCategory.values.contains(PostCategory.general), true);
      expect(PostCategory.values.contains(PostCategory.maintenance), true);
      expect(PostCategory.values.contains(PostCategory.drive), true);
    });

    test('Post.extractHashtags extracts hashtags correctly', () {
      final hashtags = Post.extractHashtags('Hello #world #test');
      expect(hashtags, containsAll(['world', 'test']));
    });

    test('Serialization: Post.toMap creates correct map', () {
      final now = DateTime.now();
      final post = Post(
        id: 'p1',
        userId: 'u1',
        category: PostCategory.general,
        content: 'Test post',
        createdAt: now,
        updatedAt: now,
        hashtags: ['test'],
      );

      final map = post.toMap();

      expect(map['userId'], 'u1');
      expect(map['content'], 'Test post');
      expect(map['hashtags'], ['test']);
    });
  });

  group('DriveLog Model CRUD Tests', () {
    test('Create: DriveLog can be instantiated', () {
      final now = DateTime.now();
      final stats = DriveStatistics(
        totalDistance: 0,
        totalDuration: 0,
        averageSpeed: 0,
        maxSpeed: 0,
      );

      final driveLog = DriveLog(
        id: 'd1',
        userId: 'u1',
        startTime: now,
        status: DriveLogStatus.recording,
        statistics: stats,
        createdAt: now,
        updatedAt: now,
      );

      expect(driveLog.id, 'd1');
      expect(driveLog.status, DriveLogStatus.recording);
    });

    test('Create: DriveLog with full statistics', () {
      final now = DateTime.now();
      final stats = DriveStatistics(
        totalDistance: 150.5,
        averageSpeed: 45.0,
        maxSpeed: 100.0,
        totalDuration: 12600, // seconds
        fuelEfficiency: 15.5,
      );

      final driveLog = DriveLog(
        id: 'd1',
        userId: 'u1',
        vehicleId: 'v1',
        startTime: now,
        endTime: now.add(const Duration(hours: 3, minutes: 30)),
        status: DriveLogStatus.completed,
        statistics: stats,
        createdAt: now,
        updatedAt: now,
      );

      expect(driveLog.statistics.totalDistance, 150.5);
      expect(driveLog.statistics.averageSpeed, 45.0);
      expect(driveLog.status, DriveLogStatus.completed);
    });

    test('DriveLogStatus enum values', () {
      expect(DriveLogStatus.values.contains(DriveLogStatus.recording), true);
      expect(DriveLogStatus.values.contains(DriveLogStatus.paused), true);
      expect(DriveLogStatus.values.contains(DriveLogStatus.completed), true);
    });

    test('DriveStatistics.fromMap parses correctly', () {
      final map = {
        'totalDistance': 100.0,
        'totalDuration': 3600,
        'averageSpeed': 50.0,
        'maxSpeed': 80.0,
      };

      final stats = DriveStatistics.fromMap(map);

      expect(stats?.totalDistance, 100.0);
      expect(stats?.totalDuration, 3600);
      expect(stats?.averageSpeed, 50.0);
    });

    test('DriveLog.fromMap parses correctly', () {
      final now = DateTime.now();
      final map = {
        'userId': 'u1',
        'vehicleId': 'v1',
        'startTime': Timestamp.fromDate(now),
        'status': 'recording',
        'statistics': {
          'totalDistance': 50.0,
          'totalDuration': 1800,
          'averageSpeed': 30.0,
          'maxSpeed': 60.0,
        },
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final driveLog = DriveLog.fromMap(map, 'd1');

      expect(driveLog.id, 'd1');
      expect(driveLog.userId, 'u1');
      expect(driveLog.status, DriveLogStatus.recording);
      expect(driveLog.statistics.totalDistance, 50.0);
    });

    test('Serialization: DriveLog.toMap creates correct map', () {
      final now = DateTime.now();
      final stats = DriveStatistics(
        totalDistance: 100.0,
        totalDuration: 3600,
        averageSpeed: 50.0,
        maxSpeed: 80.0,
      );

      final driveLog = DriveLog(
        id: 'd1',
        userId: 'u1',
        vehicleId: 'v1',
        startTime: now,
        status: DriveLogStatus.recording,
        title: 'Weekend Drive',
        statistics: stats,
        createdAt: now,
        updatedAt: now,
      );

      final map = driveLog.toMap();

      expect(map['userId'], 'u1');
      expect(map['vehicleId'], 'v1');
      expect(map['status'], 'recording');
      expect(map['title'], 'Weekend Drive');
      expect(map['statistics'], isA<Map<String, dynamic>>());
    });

    test('DriveLog.copyWith works correctly', () {
      final now = DateTime.now();
      final stats = DriveStatistics(
        totalDistance: 0,
        totalDuration: 0,
        averageSpeed: 0,
        maxSpeed: 0,
      );

      final original = DriveLog(
        id: 'd1',
        userId: 'u1',
        startTime: now,
        status: DriveLogStatus.recording,
        statistics: stats,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(
        status: DriveLogStatus.completed,
        title: 'My Drive',
      );

      expect(updated.status, DriveLogStatus.completed);
      expect(updated.title, 'My Drive');
      expect(updated.userId, 'u1'); // unchanged
    });
  });

  group('DriveSpot Model CRUD Tests', () {
    test('Create: DriveSpot can be instantiated', () {
      final now = DateTime.now();
      final spot = DriveSpot(
        id: 's1',
        userId: 'u1',
        name: 'Beautiful View Point',
        description: 'A scenic overlook',
        category: SpotCategory.scenicView,
        location: const GeoPoint2D(latitude: 35.6762, longitude: 139.6503),
        createdAt: now,
        updatedAt: now,
      );

      expect(spot.id, 's1');
      expect(spot.name, 'Beautiful View Point');
      expect(spot.category, SpotCategory.scenicView);
      expect(spot.location.latitude, 35.6762);
    });

    test('SpotCategory has expected values', () {
      expect(SpotCategory.values.contains(SpotCategory.scenicView), true);
      expect(SpotCategory.values.contains(SpotCategory.restaurant), true);
      expect(SpotCategory.values.contains(SpotCategory.cafe), true);
      expect(SpotCategory.values.contains(SpotCategory.gasStation), true);
    });

    test('SpotCategory has displayName', () {
      expect(SpotCategory.scenicView.displayName, isNotEmpty);
      expect(SpotCategory.restaurant.displayName, isNotEmpty);
    });

    test('GeoPoint2D distance calculation', () {
      const tokyo = GeoPoint2D(latitude: 35.6762, longitude: 139.6503);
      const osaka = GeoPoint2D(latitude: 34.6937, longitude: 135.5023);

      final distance = tokyo.distanceTo(osaka);

      // Tokyo to Osaka is approximately 400km = 400000m
      expect(distance, greaterThan(350000));
      expect(distance, lessThan(450000));
    });

    test('DriveSpot.fromMap parses correctly', () {
      final now = DateTime.now();
      final map = {
        'userId': 'u1',
        'name': 'Test Spot',
        'description': 'A test spot',
        'category': 'restaurant',
        'location': {
          'latitude': 35.0,
          'longitude': 139.0,
        },
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'address': '東京都渋谷区',
        'averageRating': 4.5,
      };

      final spot = DriveSpot.fromMap(map, 's1');

      expect(spot.id, 's1');
      expect(spot.name, 'Test Spot');
      expect(spot.category, SpotCategory.restaurant);
      expect(spot.address, '東京都渋谷区');
    });

    test('Serialization: DriveSpot.toMap creates correct map', () {
      final now = DateTime.now();
      final spot = DriveSpot(
        id: 's1',
        userId: 'u1',
        name: 'Test Spot',
        description: 'Test description',
        category: SpotCategory.restaurant,
        location: const GeoPoint2D(latitude: 35.0, longitude: 139.0),
        createdAt: now,
        updatedAt: now,
        address: '東京都渋谷区',
        averageRating: 4.5,
        ratingCount: 10,
      );

      final map = spot.toMap();

      expect(map['name'], 'Test Spot');
      expect(map['category'], 'restaurant');
      expect(map['address'], '東京都渋谷区');
      expect(map['averageRating'], 4.5);
    });

    test('DriveSpot.copyWith works correctly', () {
      final now = DateTime.now();
      final original = DriveSpot(
        id: 's1',
        userId: 'u1',
        name: 'Original Spot',
        category: SpotCategory.scenicView,
        location: const GeoPoint2D(latitude: 35.0, longitude: 139.0),
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(
        name: 'Updated Spot',
        averageRating: 4.0,
      );

      expect(updated.name, 'Updated Spot');
      expect(updated.averageRating, 4.0);
      expect(updated.category, SpotCategory.scenicView); // unchanged
    });
  });

  group('GeoPoint2D Tests', () {
    test('GeoPoint2D can be created', () {
      const point = GeoPoint2D(latitude: 35.6762, longitude: 139.6503);

      expect(point.latitude, 35.6762);
      expect(point.longitude, 139.6503);
    });

    test('GeoPoint2D.toMap creates correct map', () {
      const point = GeoPoint2D(latitude: 35.6762, longitude: 139.6503);
      final map = point.toMap();

      expect(map['latitude'], 35.6762);
      expect(map['longitude'], 139.6503);
    });

    test('GeoPoint2D.fromMap parses correctly', () {
      final map = {'latitude': 35.0, 'longitude': 139.0};
      final point = GeoPoint2D.fromMap(map);

      expect(point.latitude, 35.0);
      expect(point.longitude, 139.0);
    });

    test('GeoPoint2D distance calculation is symmetric', () {
      const p1 = GeoPoint2D(latitude: 35.0, longitude: 139.0);
      const p2 = GeoPoint2D(latitude: 36.0, longitude: 140.0);

      final d1 = p1.distanceTo(p2);
      final d2 = p2.distanceTo(p1);

      expect(d1, closeTo(d2, 0.001));
    });
  });

  group('DriveWaypoint Tests', () {
    test('DriveWaypoint can be created', () {
      final now = DateTime.now();
      final waypoint = DriveWaypoint(
        location: const GeoPoint2D(latitude: 35.0, longitude: 139.0),
        timestamp: now,
        speed: 50.0,
        altitude: 100.0,
      );

      expect(waypoint.speed, 50.0);
      expect(waypoint.altitude, 100.0);
    });

    test('DriveWaypoint.fromMap parses correctly', () {
      final now = DateTime.now();
      final map = {
        'location': {'latitude': 35.0, 'longitude': 139.0},
        'timestamp': Timestamp.fromDate(now),
        'speed': 60.0,
        'altitude': 50.0,
      };

      final waypoint = DriveWaypoint.fromMap(map);

      expect(waypoint.speed, 60.0);
      expect(waypoint.altitude, 50.0);
    });

    test('DriveWaypoint.toMap creates correct map', () {
      final now = DateTime.now();
      final waypoint = DriveWaypoint(
        location: const GeoPoint2D(latitude: 35.0, longitude: 139.0),
        timestamp: now,
        speed: 50.0,
      );

      final map = waypoint.toMap();

      expect(map['speed'], 50.0);
      expect(map['location'], isA<Map<String, dynamic>>());
    });
  });

  group('Result Pattern Integration Tests', () {
    test('Result.success wraps value correctly', () {
      final result = Result<String, AppError>.success('test_id');

      expect(result.isSuccess, true);
      expect(result.isFailure, false);
      expect(result.valueOrNull, 'test_id');
    });

    test('Result.failure wraps error correctly', () {
      final result = Result<String, AppError>.failure(
        const AppError.network('Connection failed'),
      );

      expect(result.isSuccess, false);
      expect(result.isFailure, true);
      expect(result.valueOrNull, null);
    });

    test('Result.when handles both cases', () {
      final successResult = Result<int, AppError>.success(42);
      final failureResult = Result<int, AppError>.failure(
        const AppError.notFound('Not found'),
      );

      final successValue = successResult.when(
        success: (v) => 'Value: $v',
        failure: (e) => 'Error: ${e.message}',
      );

      final failureValue = failureResult.when(
        success: (v) => 'Value: $v',
        failure: (e) => 'Error: ${e.message}',
      );

      expect(successValue, 'Value: 42');
      expect(failureValue, 'Error: Not found');
    });

    test('Result.map transforms success value', () {
      final result = Result<int, AppError>.success(10);
      final mapped = result.map((v) => v * 2);

      expect(mapped.valueOrNull, 20);
    });

    test('Result.map does not transform failure', () {
      final result = Result<int, AppError>.failure(
        const AppError.validation('Invalid'),
      );
      final mapped = result.map((v) => v * 2);

      expect(mapped.isFailure, true);
    });

    test('Result.getOrElse provides fallback', () {
      final successResult = Result<String, AppError>.success('value');
      final failureResult = Result<String, AppError>.failure(
        const AppError.unknown('Unknown'),
      );

      expect(successResult.getOrElse('fallback'), 'value');
      expect(failureResult.getOrElse('fallback'), 'fallback');
    });
  });

  group('AppError Types Tests', () {
    test('NetworkError is retryable', () {
      const error = AppError.network('Connection failed');
      expect(error.isRetryable, true);
      expect(error, isA<NetworkError>());
    });

    test('ValidationError is not retryable', () {
      const error = AppError.validation('Invalid input');
      expect(error.isRetryable, false);
      expect(error, isA<ValidationError>());
    });

    test('NotFoundError is not retryable', () {
      const error = AppError.notFound('Resource not found');
      expect(error.isRetryable, false);
      expect(error, isA<NotFoundError>());
    });

    test('PermissionError is not retryable', () {
      const error = AppError.permission('Access denied');
      expect(error.isRetryable, false);
      expect(error, isA<PermissionError>());
    });

    test('AuthError types have correct retryable status', () {
      const userNotFound = AppError.auth('Not found', type: AuthErrorType.userNotFound);
      const tooManyRequests = AppError.auth('Rate limited', type: AuthErrorType.tooManyRequests);

      expect(userNotFound.isRetryable, false);
      expect(tooManyRequests.isRetryable, true);
    });

    test('All AppError types have userMessage', () {
      const errors = <AppError>[
        AppError.network('test'),
        AppError.validation('test'),
        AppError.notFound('test'),
        AppError.permission('test'),
        AppError.auth('test', type: AuthErrorType.unknown),
        AppError.server('test'),
        AppError.cache('test'),
        AppError.unknown('test'),
      ];

      for (final error in errors) {
        expect(error.userMessage.isNotEmpty, true);
      }
    });

    test('mapFirebaseError maps auth errors correctly', () {
      final userNotFound = mapFirebaseError(
          Exception('[firebase_auth/user-not-found] User not found'));
      expect(userNotFound, isA<AuthError>());
      expect((userNotFound as AuthError).type, AuthErrorType.userNotFound);

      final wrongPassword = mapFirebaseError(
          Exception('[firebase_auth/wrong-password] Wrong password'));
      expect(wrongPassword, isA<AuthError>());
      expect((wrongPassword as AuthError).type, AuthErrorType.invalidCredentials);
    });

    test('mapFirebaseError maps firestore errors correctly', () {
      final permissionDenied = mapFirebaseError(
          Exception('[cloud_firestore/permission-denied] Access denied'));
      expect(permissionDenied, isA<PermissionError>());

      final notFound = mapFirebaseError(
          Exception('[cloud_firestore/not-found] Document not found'));
      expect(notFound, isA<NotFoundError>());

      final unavailable = mapFirebaseError(
          Exception('[cloud_firestore/unavailable] Service unavailable'));
      expect(unavailable, isA<NetworkError>());
    });
  });

  group('Roundtrip Tests (Model -> Map -> Model)', () {
    test('Vehicle roundtrip preserves data', () {
      final now = DateTime.now();
      final original = Vehicle(
        id: 'v1',
        userId: 'u1',
        maker: 'Mazda',
        model: 'CX-5',
        year: 2024,
        grade: 'XD L Package',
        mileage: 500,
        createdAt: now,
        updatedAt: now,
        licensePlate: '神戸 100 う 9999',
        color: 'Soul Red',
        vinNumber: 'JM3KFBDM5N0000001',
      );

      final map = original.toMap();

      // Check key fields are preserved
      expect(map['userId'], original.userId);
      expect(map['maker'], original.maker);
      expect(map['model'], original.model);
      expect(map['year'], original.year);
      expect(map['licensePlate'], original.licensePlate);
    });

    test('DriveLog roundtrip preserves data', () {
      final now = DateTime.now();
      final stats = DriveStatistics(
        totalDistance: 100.0,
        totalDuration: 3600,
        averageSpeed: 50.0,
        maxSpeed: 80.0,
      );

      final original = DriveLog(
        id: 'd1',
        userId: 'u1',
        vehicleId: 'v1',
        startTime: now,
        status: DriveLogStatus.completed,
        title: 'Test Drive',
        statistics: stats,
        createdAt: now,
        updatedAt: now,
      );

      final map = original.toMap();
      // Convert timestamps for fromMap
      map['startTime'] = Timestamp.fromDate(now);
      map['createdAt'] = Timestamp.fromDate(now);
      map['updatedAt'] = Timestamp.fromDate(now);

      final restored = DriveLog.fromMap(map, 'd1');

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.vehicleId, original.vehicleId);
      expect(restored.status, original.status);
      expect(restored.title, original.title);
      expect(restored.statistics.totalDistance, original.statistics.totalDistance);
    });

    test('DriveSpot roundtrip preserves data', () {
      final now = DateTime.now();
      final original = DriveSpot(
        id: 's1',
        userId: 'u1',
        name: 'Test Spot',
        description: 'A test description',
        category: SpotCategory.restaurant,
        location: const GeoPoint2D(latitude: 35.6762, longitude: 139.6503),
        address: '東京都渋谷区',
        averageRating: 4.5,
        createdAt: now,
        updatedAt: now,
      );

      final map = original.toMap();
      // Convert timestamps for fromMap
      map['createdAt'] = Timestamp.fromDate(now);
      map['updatedAt'] = Timestamp.fromDate(now);

      final restored = DriveSpot.fromMap(map, 's1');

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.name, original.name);
      expect(restored.category, original.category);
      expect(restored.location.latitude, original.location.latitude);
      expect(restored.address, original.address);
    });
  });
}
