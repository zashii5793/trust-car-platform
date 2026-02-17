import 'package:cloud_firestore/cloud_firestore.dart';

/// Drive log status
enum DriveLogStatus {
  recording,   // 記録中
  completed,   // 完了
  paused,      // 一時停止
  ;

  String get displayName {
    switch (this) {
      case DriveLogStatus.recording:
        return '記録中';
      case DriveLogStatus.completed:
        return '完了';
      case DriveLogStatus.paused:
        return '一時停止';
    }
  }

  static DriveLogStatus? fromString(String? value) {
    if (value == null) return null;
    return DriveLogStatus.values.where((e) => e.name == value).firstOrNull;
  }
}

/// Weather condition during drive
enum WeatherCondition {
  sunny,       // 晴れ
  cloudy,      // 曇り
  rainy,       // 雨
  snowy,       // 雪
  foggy,       // 霧
  ;

  String get displayName {
    switch (this) {
      case WeatherCondition.sunny:
        return '晴れ';
      case WeatherCondition.cloudy:
        return '曇り';
      case WeatherCondition.rainy:
        return '雨';
      case WeatherCondition.snowy:
        return '雪';
      case WeatherCondition.foggy:
        return '霧';
    }
  }

  String get emoji {
    switch (this) {
      case WeatherCondition.sunny:
        return '☀️';
      case WeatherCondition.cloudy:
        return '☁️';
      case WeatherCondition.rainy:
        return '🌧️';
      case WeatherCondition.snowy:
        return '❄️';
      case WeatherCondition.foggy:
        return '🌫️';
    }
  }

  static WeatherCondition? fromString(String? value) {
    if (value == null) return null;
    return WeatherCondition.values.where((e) => e.name == value).firstOrNull;
  }
}

/// Road type for route segments
enum RoadType {
  highway,      // 高速道路
  nationalRoad, // 国道
  prefecturalRoad, // 県道
  cityRoad,     // 市道
  mountainRoad, // 山道
  coastalRoad,  // 海岸道路
  ;

  String get displayName {
    switch (this) {
      case RoadType.highway:
        return '高速道路';
      case RoadType.nationalRoad:
        return '国道';
      case RoadType.prefecturalRoad:
        return '県道';
      case RoadType.cityRoad:
        return '市道';
      case RoadType.mountainRoad:
        return '山道';
      case RoadType.coastalRoad:
        return '海岸道路';
    }
  }

  static RoadType? fromString(String? value) {
    if (value == null) return null;
    return RoadType.values.where((e) => e.name == value).firstOrNull;
  }
}

/// GPS coordinate point
class GeoPoint2D {
  final double latitude;
  final double longitude;

  const GeoPoint2D({
    required this.latitude,
    required this.longitude,
  });

  factory GeoPoint2D.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const GeoPoint2D(latitude: 0, longitude: 0);
    }
    return GeoPoint2D(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
    );
  }

  factory GeoPoint2D.fromGeoPoint(GeoPoint geoPoint) {
    return GeoPoint2D(
      latitude: geoPoint.latitude,
      longitude: geoPoint.longitude,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  GeoPoint toGeoPoint() {
    return GeoPoint(latitude, longitude);
  }

  /// Calculate distance to another point in meters (Haversine formula)
  double distanceTo(GeoPoint2D other) {
    const earthRadius = 6371000.0; // meters
    final lat1 = latitude * 3.141592653589793 / 180;
    final lat2 = other.latitude * 3.141592653589793 / 180;
    final dLat = (other.latitude - latitude) * 3.141592653589793 / 180;
    final dLon = (other.longitude - longitude) * 3.141592653589793 / 180;

    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(lat1) * _cos(lat2) * _sin(dLon / 2) * _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  // Simple math functions to avoid dart:math import issues
  double _sin(double x) => _taylor(x, true);
  double _cos(double x) => _taylor(x, false);
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }
  double _atan(double x) {
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * (3.141592653589793 / 2 - _atan(1 / x.abs()));
    }
    double result = 0;
    double term = x;
    for (int i = 1; i <= 15; i += 2) {
      result += term / i;
      term *= -x * x;
    }
    return result;
  }
  double _taylor(double x, bool isSin) {
    // Normalize x to [-pi, pi]
    const pi = 3.141592653589793;
    while (x > pi) x -= 2 * pi;
    while (x < -pi) x += 2 * pi;

    double result = isSin ? x : 1;
    double term = isSin ? x : 1;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((isSin ? 2 * i : 2 * i - 1) * (isSin ? 2 * i + 1 : 2 * i));
      result += term;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint2D &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

/// Waypoint in a drive log
class DriveWaypoint {
  final GeoPoint2D location;
  final DateTime timestamp;
  final double? speed;       // km/h
  final double? altitude;    // meters
  final double? heading;     // degrees (0-360)
  final double? accuracy;    // GPS accuracy in meters

  const DriveWaypoint({
    required this.location,
    required this.timestamp,
    this.speed,
    this.altitude,
    this.heading,
    this.accuracy,
  });

  factory DriveWaypoint.fromMap(Map<String, dynamic> map) {
    return DriveWaypoint(
      location: GeoPoint2D.fromMap(map['location'] as Map<String, dynamic>?),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      speed: (map['speed'] as num?)?.toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'location': location.toMap(),
      'timestamp': Timestamp.fromDate(timestamp),
      if (speed != null) 'speed': speed,
      if (altitude != null) 'altitude': altitude,
      if (heading != null) 'heading': heading,
      if (accuracy != null) 'accuracy': accuracy,
    };
  }
}

/// Statistics for a drive
class DriveStatistics {
  final double totalDistance;     // km
  final int totalDuration;        // seconds
  final double averageSpeed;      // km/h
  final double maxSpeed;          // km/h
  final double? fuelConsumed;     // liters
  final double? fuelEfficiency;   // km/L
  final int? elevationGain;       // meters
  final int? elevationLoss;       // meters
  final int stopCount;            // number of stops
  final int totalStopDuration;    // seconds

  const DriveStatistics({
    required this.totalDistance,
    required this.totalDuration,
    required this.averageSpeed,
    required this.maxSpeed,
    this.fuelConsumed,
    this.fuelEfficiency,
    this.elevationGain,
    this.elevationLoss,
    this.stopCount = 0,
    this.totalStopDuration = 0,
  });

  factory DriveStatistics.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const DriveStatistics(
        totalDistance: 0,
        totalDuration: 0,
        averageSpeed: 0,
        maxSpeed: 0,
      );
    }
    return DriveStatistics(
      totalDistance: (map['totalDistance'] as num?)?.toDouble() ?? 0,
      totalDuration: (map['totalDuration'] as num?)?.toInt() ?? 0,
      averageSpeed: (map['averageSpeed'] as num?)?.toDouble() ?? 0,
      maxSpeed: (map['maxSpeed'] as num?)?.toDouble() ?? 0,
      fuelConsumed: (map['fuelConsumed'] as num?)?.toDouble(),
      fuelEfficiency: (map['fuelEfficiency'] as num?)?.toDouble(),
      elevationGain: (map['elevationGain'] as num?)?.toInt(),
      elevationLoss: (map['elevationLoss'] as num?)?.toInt(),
      stopCount: (map['stopCount'] as num?)?.toInt() ?? 0,
      totalStopDuration: (map['totalStopDuration'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      if (fuelConsumed != null) 'fuelConsumed': fuelConsumed,
      if (fuelEfficiency != null) 'fuelEfficiency': fuelEfficiency,
      if (elevationGain != null) 'elevationGain': elevationGain,
      if (elevationLoss != null) 'elevationLoss': elevationLoss,
      'stopCount': stopCount,
      'totalStopDuration': totalStopDuration,
    };
  }

  /// Format duration as HH:MM:SS
  String get formattedDuration {
    final hours = totalDuration ~/ 3600;
    final minutes = (totalDuration % 3600) ~/ 60;
    final seconds = totalDuration % 60;
    if (hours > 0) {
      return '$hours時間${minutes}分';
    }
    return '$minutes分${seconds}秒';
  }

  /// Format distance
  String get formattedDistance {
    if (totalDistance >= 1) {
      return '${totalDistance.toStringAsFixed(1)}km';
    }
    return '${(totalDistance * 1000).toInt()}m';
  }
}

/// Drive log entry
class DriveLog {
  final String id;
  final String userId;
  final String? vehicleId;        // Associated vehicle
  final DriveLogStatus status;

  // Route info
  final String? title;
  final String? description;
  final GeoPoint2D? startLocation;
  final GeoPoint2D? endLocation;
  final String? startAddress;
  final String? endAddress;

  // Time
  final DateTime startTime;
  final DateTime? endTime;

  // Statistics
  final DriveStatistics statistics;

  // Conditions
  final WeatherCondition? weather;
  final List<RoadType> roadTypes;

  // Media
  final List<String> photoUrls;
  final String? thumbnailUrl;

  // Social
  final bool isPublic;
  final int likeCount;
  final int commentCount;
  final List<String> tags;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  const DriveLog({
    required this.id,
    required this.userId,
    this.vehicleId,
    required this.status,
    this.title,
    this.description,
    this.startLocation,
    this.endLocation,
    this.startAddress,
    this.endAddress,
    required this.startTime,
    this.endTime,
    required this.statistics,
    this.weather,
    this.roadTypes = const [],
    this.photoUrls = const [],
    this.thumbnailUrl,
    this.isPublic = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriveLog.fromMap(Map<String, dynamic> map, String id) {
    return DriveLog(
      id: id,
      userId: map['userId'] as String,
      vehicleId: map['vehicleId'] as String?,
      status: DriveLogStatus.fromString(map['status'] as String?) ?? DriveLogStatus.completed,
      title: map['title'] as String?,
      description: map['description'] as String?,
      startLocation: map['startLocation'] != null
          ? GeoPoint2D.fromMap(map['startLocation'] as Map<String, dynamic>)
          : null,
      endLocation: map['endLocation'] != null
          ? GeoPoint2D.fromMap(map['endLocation'] as Map<String, dynamic>)
          : null,
      startAddress: map['startAddress'] as String?,
      endAddress: map['endAddress'] as String?,
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: map['endTime'] != null
          ? (map['endTime'] as Timestamp).toDate()
          : null,
      statistics: DriveStatistics.fromMap(map['statistics'] as Map<String, dynamic>?),
      weather: WeatherCondition.fromString(map['weather'] as String?),
      roadTypes: (map['roadTypes'] as List<dynamic>?)
              ?.map((e) => RoadType.fromString(e as String))
              .whereType<RoadType>()
              .toList() ??
          [],
      photoUrls: (map['photoUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      thumbnailUrl: map['thumbnailUrl'] as String?,
      isPublic: map['isPublic'] as bool? ?? false,
      likeCount: (map['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (map['commentCount'] as num?)?.toInt() ?? 0,
      tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      if (vehicleId != null) 'vehicleId': vehicleId,
      'status': status.name,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (startLocation != null) 'startLocation': startLocation!.toMap(),
      if (endLocation != null) 'endLocation': endLocation!.toMap(),
      if (startAddress != null) 'startAddress': startAddress,
      if (endAddress != null) 'endAddress': endAddress,
      'startTime': Timestamp.fromDate(startTime),
      if (endTime != null) 'endTime': Timestamp.fromDate(endTime!),
      'statistics': statistics.toMap(),
      if (weather != null) 'weather': weather!.name,
      'roadTypes': roadTypes.map((e) => e.name).toList(),
      'photoUrls': photoUrls,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'isPublic': isPublic,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  DriveLog copyWith({
    String? id,
    String? userId,
    String? vehicleId,
    DriveLogStatus? status,
    String? title,
    String? description,
    GeoPoint2D? startLocation,
    GeoPoint2D? endLocation,
    String? startAddress,
    String? endAddress,
    DateTime? startTime,
    DateTime? endTime,
    DriveStatistics? statistics,
    WeatherCondition? weather,
    List<RoadType>? roadTypes,
    List<String>? photoUrls,
    String? thumbnailUrl,
    bool? isPublic,
    int? likeCount,
    int? commentCount,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriveLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vehicleId: vehicleId ?? this.vehicleId,
      status: status ?? this.status,
      title: title ?? this.title,
      description: description ?? this.description,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      statistics: statistics ?? this.statistics,
      weather: weather ?? this.weather,
      roadTypes: roadTypes ?? this.roadTypes,
      photoUrls: photoUrls ?? this.photoUrls,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isPublic: isPublic ?? this.isPublic,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Display title (auto-generated if not set)
  String get displayTitle {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    final dateStr = '${startTime.month}/${startTime.day}';
    if (startAddress != null) {
      return '$dateStr $startAddressからのドライブ';
    }
    return '$dateStr のドライブ';
  }

  /// Check if drive is in progress
  bool get isRecording => status == DriveLogStatus.recording;

  /// Check if drive is completed
  bool get isCompleted => status == DriveLogStatus.completed;

  /// Get drive duration in minutes
  int get durationMinutes => statistics.totalDuration ~/ 60;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DriveLog && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DriveLog($displayTitle, ${statistics.formattedDistance})';
}

/// Like for drive log
class DriveLogLike {
  final String id;
  final String driveLogId;
  final String userId;
  final DateTime createdAt;

  const DriveLogLike({
    required this.id,
    required this.driveLogId,
    required this.userId,
    required this.createdAt,
  });

  factory DriveLogLike.fromMap(Map<String, dynamic> map, String id) {
    return DriveLogLike(
      id: id,
      driveLogId: map['driveLogId'] as String,
      userId: map['userId'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driveLogId': driveLogId,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
