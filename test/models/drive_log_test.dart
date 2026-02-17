import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trust_car_platform/models/drive_log.dart';

void main() {
  group('DriveLogStatus', () {
    test('should have correct display names', () {
      expect(DriveLogStatus.recording.displayName, '記録中');
      expect(DriveLogStatus.completed.displayName, '完了');
      expect(DriveLogStatus.paused.displayName, '一時停止');
    });

    test('fromString should return correct enum value', () {
      expect(DriveLogStatus.fromString('recording'), DriveLogStatus.recording);
      expect(DriveLogStatus.fromString('completed'), DriveLogStatus.completed);
      expect(DriveLogStatus.fromString('paused'), DriveLogStatus.paused);
      expect(DriveLogStatus.fromString('invalid'), isNull);
      expect(DriveLogStatus.fromString(null), isNull);
    });
  });

  group('WeatherCondition', () {
    test('should have correct display names', () {
      expect(WeatherCondition.sunny.displayName, '晴れ');
      expect(WeatherCondition.cloudy.displayName, '曇り');
      expect(WeatherCondition.rainy.displayName, '雨');
      expect(WeatherCondition.snowy.displayName, '雪');
      expect(WeatherCondition.foggy.displayName, '霧');
    });

    test('should have correct emojis', () {
      expect(WeatherCondition.sunny.emoji, '☀️');
      expect(WeatherCondition.cloudy.emoji, '☁️');
      expect(WeatherCondition.rainy.emoji, '🌧️');
      expect(WeatherCondition.snowy.emoji, '❄️');
      expect(WeatherCondition.foggy.emoji, '🌫️');
    });

    test('fromString should return correct enum value', () {
      expect(WeatherCondition.fromString('sunny'), WeatherCondition.sunny);
      expect(WeatherCondition.fromString('rainy'), WeatherCondition.rainy);
      expect(WeatherCondition.fromString('invalid'), isNull);
      expect(WeatherCondition.fromString(null), isNull);
    });
  });

  group('RoadType', () {
    test('should have correct display names', () {
      expect(RoadType.highway.displayName, '高速道路');
      expect(RoadType.nationalRoad.displayName, '国道');
      expect(RoadType.prefecturalRoad.displayName, '県道');
      expect(RoadType.cityRoad.displayName, '市道');
      expect(RoadType.mountainRoad.displayName, '山道');
      expect(RoadType.coastalRoad.displayName, '海岸道路');
    });

    test('fromString should return correct enum value', () {
      expect(RoadType.fromString('highway'), RoadType.highway);
      expect(RoadType.fromString('mountainRoad'), RoadType.mountainRoad);
      expect(RoadType.fromString('invalid'), isNull);
      expect(RoadType.fromString(null), isNull);
    });
  });

  group('GeoPoint2D', () {
    test('should create from map', () {
      final map = {'latitude': 35.6762, 'longitude': 139.6503};
      final point = GeoPoint2D.fromMap(map);

      expect(point.latitude, 35.6762);
      expect(point.longitude, 139.6503);
    });

    test('should create from null map with defaults', () {
      final point = GeoPoint2D.fromMap(null);

      expect(point.latitude, 0);
      expect(point.longitude, 0);
    });

    test('should convert to map', () {
      const point = GeoPoint2D(latitude: 35.6762, longitude: 139.6503);
      final map = point.toMap();

      expect(map['latitude'], 35.6762);
      expect(map['longitude'], 139.6503);
    });

    test('should convert to/from GeoPoint', () {
      const original = GeoPoint2D(latitude: 35.6762, longitude: 139.6503);
      final geoPoint = original.toGeoPoint();
      final restored = GeoPoint2D.fromGeoPoint(geoPoint);

      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
    });

    test('should calculate distance between points', () {
      // Tokyo Station to Shibuya Station (approximately 6.5km)
      const tokyo = GeoPoint2D(latitude: 35.6812, longitude: 139.7671);
      const shibuya = GeoPoint2D(latitude: 35.6580, longitude: 139.7016);

      final distance = tokyo.distanceTo(shibuya);

      // Allow some margin for calculation precision
      expect(distance, greaterThan(5000)); // > 5km
      expect(distance, lessThan(8000)); // < 8km
    });

    test('should return 0 distance for same point', () {
      const point = GeoPoint2D(latitude: 35.6762, longitude: 139.6503);

      expect(point.distanceTo(point), 0);
    });

    test('should implement equality correctly', () {
      const point1 = GeoPoint2D(latitude: 35.6762, longitude: 139.6503);
      const point2 = GeoPoint2D(latitude: 35.6762, longitude: 139.6503);
      const point3 = GeoPoint2D(latitude: 35.0, longitude: 139.0);

      expect(point1, equals(point2));
      expect(point1, isNot(equals(point3)));
      expect(point1.hashCode, equals(point2.hashCode));
    });
  });

  group('DriveWaypoint', () {
    test('should create from map', () {
      final now = DateTime.now();
      final map = {
        'location': {'latitude': 35.6762, 'longitude': 139.6503},
        'timestamp': Timestamp.fromDate(now),
        'speed': 60.5,
        'altitude': 15.0,
        'heading': 180.0,
        'accuracy': 5.0,
      };

      final waypoint = DriveWaypoint.fromMap(map);

      expect(waypoint.location.latitude, 35.6762);
      expect(waypoint.location.longitude, 139.6503);
      expect(waypoint.speed, 60.5);
      expect(waypoint.altitude, 15.0);
      expect(waypoint.heading, 180.0);
      expect(waypoint.accuracy, 5.0);
    });

    test('should convert to map', () {
      final now = DateTime.now();
      final waypoint = DriveWaypoint(
        location: const GeoPoint2D(latitude: 35.6762, longitude: 139.6503),
        timestamp: now,
        speed: 60.5,
        altitude: 15.0,
      );

      final map = waypoint.toMap();

      expect(map['location']['latitude'], 35.6762);
      expect(map['speed'], 60.5);
      expect(map['altitude'], 15.0);
      expect(map.containsKey('heading'), isFalse); // null values excluded
    });
  });

  group('DriveStatistics', () {
    test('should create from map', () {
      final map = {
        'totalDistance': 150.5,
        'totalDuration': 7200,
        'averageSpeed': 75.25,
        'maxSpeed': 120.0,
        'fuelConsumed': 12.5,
        'fuelEfficiency': 12.04,
        'elevationGain': 500,
        'elevationLoss': 450,
        'stopCount': 3,
        'totalStopDuration': 900,
      };

      final stats = DriveStatistics.fromMap(map);

      expect(stats.totalDistance, 150.5);
      expect(stats.totalDuration, 7200);
      expect(stats.averageSpeed, 75.25);
      expect(stats.maxSpeed, 120.0);
      expect(stats.fuelConsumed, 12.5);
      expect(stats.fuelEfficiency, 12.04);
      expect(stats.elevationGain, 500);
      expect(stats.elevationLoss, 450);
      expect(stats.stopCount, 3);
      expect(stats.totalStopDuration, 900);
    });

    test('should create from null map with defaults', () {
      final stats = DriveStatistics.fromMap(null);

      expect(stats.totalDistance, 0);
      expect(stats.totalDuration, 0);
      expect(stats.averageSpeed, 0);
      expect(stats.maxSpeed, 0);
    });

    test('should convert to map', () {
      const stats = DriveStatistics(
        totalDistance: 150.5,
        totalDuration: 7200,
        averageSpeed: 75.25,
        maxSpeed: 120.0,
        stopCount: 3,
        totalStopDuration: 900,
      );

      final map = stats.toMap();

      expect(map['totalDistance'], 150.5);
      expect(map['totalDuration'], 7200);
      expect(map['averageSpeed'], 75.25);
      expect(map['maxSpeed'], 120.0);
      expect(map['stopCount'], 3);
      expect(map['totalStopDuration'], 900);
    });

    test('formattedDuration should format correctly', () {
      expect(
        const DriveStatistics(
          totalDistance: 0,
          totalDuration: 3661, // 1h 1m 1s
          averageSpeed: 0,
          maxSpeed: 0,
        ).formattedDuration,
        '1時間1分',
      );

      expect(
        const DriveStatistics(
          totalDistance: 0,
          totalDuration: 125, // 2m 5s
          averageSpeed: 0,
          maxSpeed: 0,
        ).formattedDuration,
        '2分5秒',
      );
    });

    test('formattedDistance should format correctly', () {
      expect(
        const DriveStatistics(
          totalDistance: 150.5,
          totalDuration: 0,
          averageSpeed: 0,
          maxSpeed: 0,
        ).formattedDistance,
        '150.5km',
      );

      expect(
        const DriveStatistics(
          totalDistance: 0.5,
          totalDuration: 0,
          averageSpeed: 0,
          maxSpeed: 0,
        ).formattedDistance,
        '500m',
      );
    });
  });

  group('DriveLog', () {
    late DateTime now;
    late Map<String, dynamic> validMap;

    setUp(() {
      now = DateTime.now();
      validMap = {
        'userId': 'user123',
        'vehicleId': 'vehicle456',
        'status': 'completed',
        'title': 'Weekend Drive',
        'description': 'Fun drive to the mountains',
        'startLocation': {'latitude': 35.6762, 'longitude': 139.6503},
        'endLocation': {'latitude': 35.3606, 'longitude': 138.7274},
        'startAddress': '東京都渋谷区',
        'endAddress': '山梨県富士吉田市',
        'startTime': Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
        'endTime': Timestamp.fromDate(now),
        'statistics': {
          'totalDistance': 100.0,
          'totalDuration': 7200,
          'averageSpeed': 50.0,
          'maxSpeed': 100.0,
        },
        'weather': 'sunny',
        'roadTypes': ['highway', 'mountainRoad'],
        'photoUrls': ['https://example.com/photo1.jpg'],
        'thumbnailUrl': 'https://example.com/thumb.jpg',
        'isPublic': true,
        'likeCount': 10,
        'commentCount': 5,
        'tags': ['富士山', 'ドライブ'],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };
    });

    test('should create from map', () {
      final log = DriveLog.fromMap(validMap, 'log123');

      expect(log.id, 'log123');
      expect(log.userId, 'user123');
      expect(log.vehicleId, 'vehicle456');
      expect(log.status, DriveLogStatus.completed);
      expect(log.title, 'Weekend Drive');
      expect(log.description, 'Fun drive to the mountains');
      expect(log.startLocation?.latitude, 35.6762);
      expect(log.endLocation?.latitude, 35.3606);
      expect(log.startAddress, '東京都渋谷区');
      expect(log.endAddress, '山梨県富士吉田市');
      expect(log.statistics.totalDistance, 100.0);
      expect(log.weather, WeatherCondition.sunny);
      expect(log.roadTypes, contains(RoadType.highway));
      expect(log.roadTypes, contains(RoadType.mountainRoad));
      expect(log.photoUrls.length, 1);
      expect(log.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(log.isPublic, isTrue);
      expect(log.likeCount, 10);
      expect(log.commentCount, 5);
      expect(log.tags, contains('富士山'));
    });

    test('should convert to map', () {
      final log = DriveLog.fromMap(validMap, 'log123');
      final map = log.toMap();

      expect(map['userId'], 'user123');
      expect(map['status'], 'completed');
      expect(map['title'], 'Weekend Drive');
      expect(map['weather'], 'sunny');
      expect(map['roadTypes'], contains('highway'));
      expect(map['isPublic'], isTrue);
      expect(map['likeCount'], 10);
    });

    test('copyWith should work correctly', () {
      final log = DriveLog.fromMap(validMap, 'log123');
      final updated = log.copyWith(
        title: 'Updated Title',
        isPublic: false,
        likeCount: 20,
      );

      expect(updated.id, log.id);
      expect(updated.userId, log.userId);
      expect(updated.title, 'Updated Title');
      expect(updated.isPublic, isFalse);
      expect(updated.likeCount, 20);
      expect(updated.description, log.description); // unchanged
    });

    test('displayTitle should return title if set', () {
      final log = DriveLog.fromMap(validMap, 'log123');
      expect(log.displayTitle, 'Weekend Drive');
    });

    test('displayTitle should generate title from address if not set', () {
      validMap['title'] = null;
      final log = DriveLog.fromMap(validMap, 'log123');
      expect(log.displayTitle, contains('東京都渋谷区'));
      expect(log.displayTitle, contains('からのドライブ'));
    });

    test('displayTitle should generate title from date if no address', () {
      validMap['title'] = null;
      validMap['startAddress'] = null;
      final log = DriveLog.fromMap(validMap, 'log123');
      expect(log.displayTitle, contains('のドライブ'));
    });

    test('isRecording should return correct value', () {
      validMap['status'] = 'recording';
      final recording = DriveLog.fromMap(validMap, 'log123');
      expect(recording.isRecording, isTrue);
      expect(recording.isCompleted, isFalse);

      validMap['status'] = 'completed';
      final completed = DriveLog.fromMap(validMap, 'log123');
      expect(completed.isRecording, isFalse);
      expect(completed.isCompleted, isTrue);
    });

    test('durationMinutes should calculate correctly', () {
      validMap['statistics']['totalDuration'] = 7200; // 2 hours
      final log = DriveLog.fromMap(validMap, 'log123');
      expect(log.durationMinutes, 120);
    });

    test('should implement equality correctly', () {
      final log1 = DriveLog.fromMap(validMap, 'log123');
      final log2 = DriveLog.fromMap(validMap, 'log123');
      final log3 = DriveLog.fromMap(validMap, 'log456');

      expect(log1, equals(log2));
      expect(log1, isNot(equals(log3)));
    });

    test('toString should return formatted string', () {
      final log = DriveLog.fromMap(validMap, 'log123');
      expect(log.toString(), contains('Weekend Drive'));
      expect(log.toString(), contains('km'));
    });
  });

  group('DriveLogLike', () {
    test('should create from map', () {
      final now = DateTime.now();
      final map = {
        'driveLogId': 'log123',
        'userId': 'user456',
        'createdAt': Timestamp.fromDate(now),
      };

      final like = DriveLogLike.fromMap(map, 'like789');

      expect(like.id, 'like789');
      expect(like.driveLogId, 'log123');
      expect(like.userId, 'user456');
    });

    test('should convert to map', () {
      final now = DateTime.now();
      final like = DriveLogLike(
        id: 'like789',
        driveLogId: 'log123',
        userId: 'user456',
        createdAt: now,
      );

      final map = like.toMap();

      expect(map['driveLogId'], 'log123');
      expect(map['userId'], 'user456');
      expect(map.containsKey('id'), isFalse); // id is not in map
    });
  });
}
