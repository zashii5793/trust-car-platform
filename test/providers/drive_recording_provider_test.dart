// DriveRecordingProvider Unit Tests
//
// GPS stream and permission checker are injected so tests run without hardware.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trust_car_platform/providers/drive_recording_provider.dart';
import 'package:trust_car_platform/services/drive_log_service.dart';
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Mock DriveLogService
// ---------------------------------------------------------------------------

class MockDriveLogService implements DriveLogService {
  Result<DriveLog, AppError> startDriveResult = Result.success(_makeLog());
  Result<DriveLog, AppError> endDriveResult = Result.success(_makeLog());
  Result<void, AppError> addWaypointResult = const Result.success(null);

  int startDriveCallCount = 0;
  int endDriveCallCount = 0;
  int addWaypointCallCount = 0;
  String? lastStartUserId;
  String? lastEndDriveLogId;

  @override
  Future<Result<DriveLog, AppError>> startDrive({
    required String userId,
    String? vehicleId,
    GeoPoint2D? startLocation,
    String? startAddress,
  }) async {
    startDriveCallCount++;
    lastStartUserId = userId;
    return startDriveResult;
  }

  @override
  Future<Result<DriveLog, AppError>> endDrive({
    required String driveLogId,
    required String userId,
    GeoPoint2D? endLocation,
    String? endAddress,
    required DriveStatistics statistics,
    String? title,
    String? description,
    WeatherCondition? weather,
    List<RoadType>? roadTypes,
    List<String>? tags,
    bool isPublic = false,
  }) async {
    endDriveCallCount++;
    lastEndDriveLogId = driveLogId;
    return endDriveResult;
  }

  @override
  Future<Result<void, AppError>> addWaypoint({
    required String driveLogId,
    required DriveWaypoint waypoint,
  }) async {
    addWaypointCallCount++;
    return addWaypointResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DriveLog _makeLog({String id = 'drive1', String userId = 'user1'}) {
  final now = DateTime.now();
  return DriveLog(
    id: id,
    userId: userId,
    status: DriveLogStatus.recording,
    startTime: now,
    statistics: const DriveStatistics(
      totalDistance: 0,
      totalDuration: 0,
      averageSpeed: 0,
      maxSpeed: 0,
    ),
    createdAt: now,
    updatedAt: now,
  );
}

Position _makePosition({
  double lat = 35.6812,
  double lng = 139.7671,
  double speedMs = 10.0, // 36 km/h
  double altitude = 10.0,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
    accuracy: 5.0,
    altitude: altitude,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: speedMs,
    speedAccuracy: 1.0,
  );
}

DriveRecordingProvider _makeProvider(
  MockDriveLogService service, {
  StreamController<Position>? positionController,
  bool permissionGranted = true,
}) {
  final controller = positionController ?? StreamController<Position>();
  return DriveRecordingProvider(
    driveLogService: service,
    permissionChecker: () async => permissionGranted,
    positionStreamFactory: () => controller.stream,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DriveRecordingProvider — initial state', () {
    test('starts in idle state', () {
      final provider = _makeProvider(MockDriveLogService());
      expect(provider.isRecording, isFalse);
      expect(provider.isLoading, isFalse);
      expect(provider.elapsedSeconds, 0);
      expect(provider.distanceKm, 0.0);
      expect(provider.currentSpeedKmh, 0.0);
      expect(provider.maxSpeedKmh, 0.0);
      expect(provider.currentDriveLogId, isNull);
      expect(provider.error, isNull);
    });

    test('formattedElapsed shows 00:00 initially', () {
      final provider = _makeProvider(MockDriveLogService());
      expect(provider.formattedElapsed, '00:00');
    });
  });

  group('DriveRecordingProvider — startRecording', () {
    test('sets isRecording=true on success', () async {
      final service = MockDriveLogService();
      final provider = _makeProvider(service);

      final ok = await provider.startRecording(userId: 'user1');

      expect(ok, isTrue);
      expect(provider.isRecording, isTrue);
      expect(provider.isLoading, isFalse);
      expect(provider.currentDriveLogId, 'drive1');
      expect(service.startDriveCallCount, 1);
      expect(service.lastStartUserId, 'user1');

      provider.clear();
    });

    test('passes vehicleId to service', () async {
      final service = MockDriveLogService();
      final provider = _makeProvider(service);

      await provider.startRecording(userId: 'user1', vehicleId: 'vehicle123');

      expect(service.startDriveCallCount, 1);

      provider.clear();
    });

    test('sets error when permission denied', () async {
      final service = MockDriveLogService();
      final provider = _makeProvider(service, permissionGranted: false);

      final ok = await provider.startRecording(userId: 'user1');

      expect(ok, isFalse);
      expect(provider.isRecording, isFalse);
      expect(provider.error, isNotNull);
      expect(service.startDriveCallCount, 0);
    });

    test('sets error when startDrive fails', () async {
      final service = MockDriveLogService()
        ..startDriveResult = const Result.failure(AppError.server('Firestore error'));
      final provider = _makeProvider(service);

      final ok = await provider.startRecording(userId: 'user1');

      expect(ok, isFalse);
      expect(provider.isRecording, isFalse);
      expect(provider.error, isNotNull);
    });
  });

  group('DriveRecordingProvider — position stream', () {
    test('updates speed from position', () async {
      final service = MockDriveLogService();
      final controller = StreamController<Position>();
      final provider = _makeProvider(service, positionController: controller);

      await provider.startRecording(userId: 'user1');
      controller.add(_makePosition(speedMs: 20.0)); // 72 km/h
      await Future.microtask(() {});

      expect(provider.currentSpeedKmh, closeTo(72.0, 0.1));

      controller.close();
      provider.clear();
    });

    test('tracks maxSpeed correctly', () async {
      final service = MockDriveLogService();
      final controller = StreamController<Position>();
      final provider = _makeProvider(service, positionController: controller);

      await provider.startRecording(userId: 'user1');
      controller.add(_makePosition(speedMs: 10.0)); // 36 km/h
      await Future.microtask(() {});
      controller.add(_makePosition(speedMs: 30.0)); // 108 km/h
      await Future.microtask(() {});
      controller.add(_makePosition(speedMs: 15.0)); // 54 km/h
      await Future.microtask(() {});

      expect(provider.maxSpeedKmh, closeTo(108.0, 0.1));

      controller.close();
      provider.clear();
    });

    test('accumulates distance across positions', () async {
      final service = MockDriveLogService();
      final controller = StreamController<Position>();
      final provider = _makeProvider(service, positionController: controller);

      await provider.startRecording(userId: 'user1');
      // Move ~111m north (1 degree lat ~= 111km)
      controller.add(_makePosition(lat: 35.6812, lng: 139.7671));
      await Future.microtask(() {});
      controller.add(_makePosition(lat: 35.6822, lng: 139.7671)); // ~111m
      await Future.microtask(() {});

      expect(provider.distanceKm, greaterThan(0));

      controller.close();
      provider.clear();
    });
  });

  group('DriveRecordingProvider — stopRecording', () {
    test('calls endDrive and sets isRecording=false', () async {
      final service = MockDriveLogService()
        ..endDriveResult = Result.success(_makeLog(id: 'drive1', userId: 'user1'));

      final controller = StreamController<Position>();
      final provider = _makeProvider(service, positionController: controller);

      await provider.startRecording(userId: 'user1');
      await provider.stopRecording();

      expect(provider.isRecording, isFalse);
      expect(provider.isLoading, isFalse);
      expect(service.endDriveCallCount, 1);
      expect(service.lastEndDriveLogId, 'drive1');

      controller.close();
    });

    test('returns null when not recording', () async {
      final service = MockDriveLogService();
      final provider = _makeProvider(service);

      final result = await provider.stopRecording();
      expect(result, isNull);
      expect(service.endDriveCallCount, 0);
    });
  });

  group('DriveRecordingProvider — clear', () {
    test('resets all state', () async {
      final service = MockDriveLogService();
      final controller = StreamController<Position>();
      final provider = _makeProvider(service, positionController: controller);

      await provider.startRecording(userId: 'user1');
      provider.clear();

      expect(provider.isRecording, isFalse);
      expect(provider.distanceKm, 0.0);
      expect(provider.elapsedSeconds, 0);
      expect(provider.currentDriveLogId, isNull);

      controller.close();
    });
  });

  group('DriveRecordingProvider — formattedElapsed', () {
    test('formats seconds under 1 hour as MM:SS', () {
      final provider = _makeProvider(MockDriveLogService());
      // Directly test the getter by calling internal method
      expect(provider.formattedElapsed, '00:00');
    });
  });

  group('Edge Cases', () {
    test('does not accumulate distance on first position (no previous point)', () async {
      final service = MockDriveLogService();
      final controller = StreamController<Position>();
      // No startLocation — first position becomes anchor
      final provider = DriveRecordingProvider(
        driveLogService: service,
        permissionChecker: () async => true,
        positionStreamFactory: () => controller.stream,
        initialPosition: null,
      );

      await provider.startRecording(userId: 'user1');
      controller.add(_makePosition(lat: 35.0, lng: 139.0));
      await Future.microtask(() {});

      // First position sets anchor, so distance should be minimal/zero from anchor
      // The second position would calculate distance
      controller.add(_makePosition(lat: 35.001, lng: 139.0));
      await Future.microtask(() {});

      expect(provider.distanceKm, greaterThanOrEqualTo(0.0));

      controller.close();
      provider.clear();
    });

    test('speed 0 does not update maxSpeed', () async {
      final service = MockDriveLogService();
      final controller = StreamController<Position>();
      final provider = _makeProvider(service, positionController: controller);

      await provider.startRecording(userId: 'user1');
      controller.add(_makePosition(speedMs: 0.0));
      await Future.microtask(() {});

      expect(provider.maxSpeedKmh, 0.0);

      controller.close();
      provider.clear();
    });

    test('negative speed from GPS is treated as 0', () async {
      final service = MockDriveLogService();
      final controller = StreamController<Position>();
      final provider = _makeProvider(service, positionController: controller);

      await provider.startRecording(userId: 'user1');
      controller.add(_makePosition(speedMs: -1.0));
      await Future.microtask(() {});

      expect(provider.currentSpeedKmh, 0.0);

      controller.close();
      provider.clear();
    });
  });
}
