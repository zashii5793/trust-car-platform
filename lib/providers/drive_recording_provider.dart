import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/drive_log.dart';
import '../services/drive_log_service.dart';
import '../services/analytics_service.dart';
import '../core/error/app_error.dart';

/// GPS drive recording state provider.
///
/// Depends on [DriveLogService] for Firestore persistence.
/// [permissionChecker] and [positionStreamFactory] are injectable for testing.
class DriveRecordingProvider with ChangeNotifier {
  final DriveLogService _service;
  final AnalyticsService? _analytics;
  final Future<bool> Function() _permissionChecker;
  final Stream<Position> Function() _positionStreamFactory;

  // Optional fixed initial position (overrides GPS lookup; used in tests).
  final GeoPoint2D? initialPosition;

  DriveRecordingProvider({
    required DriveLogService driveLogService,
    AnalyticsService? analyticsService,
    Future<bool> Function()? permissionChecker,
    Stream<Position> Function()? positionStreamFactory,
    this.initialPosition,
  })  : _service = driveLogService,
        _analytics = analyticsService,
        _permissionChecker = permissionChecker ?? _defaultPermissionCheck,
        _positionStreamFactory =
            positionStreamFactory ?? _defaultPositionStream;

  // ── State ─────────────────────────────────────────────────────────────────

  bool _isRecording = false;
  bool _isLoading = false;
  AppError? _error;

  String? _currentDriveLogId;
  String? _currentUserId;

  double _distanceKm = 0;
  double _currentSpeedKmh = 0;
  double _maxSpeedKmh = 0;
  int _elapsedSeconds = 0;

  GeoPoint2D? _lastPosition;
  final List<DriveWaypoint> _waypointBuffer = [];

  Timer? _elapsedTimer;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _waypointFlushTimer;

  static const int _waypointIntervalSeconds = 10;

  // ── Getters ───────────────────────────────────────────────────────────────

  bool get isRecording => _isRecording;
  bool get isLoading => _isLoading;
  AppError? get error => _error;
  String? get errorMessage => _error?.userMessage;

  String? get currentDriveLogId => _currentDriveLogId;
  double get distanceKm => _distanceKm;
  double get currentSpeedKmh => _currentSpeedKmh;
  double get maxSpeedKmh => _maxSpeedKmh;
  int get elapsedSeconds => _elapsedSeconds;

  String get formattedElapsed {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Request GPS permission and start a drive recording.
  /// Returns true if recording started successfully.
  Future<bool> startRecording({
    required String userId,
    String? vehicleId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Permission check
    final granted = await _permissionChecker();
    if (!granted) {
      _error = const AppError.permission('位置情報の権限が必要です。設定から許可してください。');
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Resolve start position
    final startLocation = await _resolveStartPosition();

    // Persist drive start to Firestore
    final result = await _service.startDrive(
      userId: userId,
      vehicleId: vehicleId,
      startLocation: startLocation,
    );

    if (result.isFailure) {
      _error = result.errorOrNull ?? const AppError.unknown('ドライブの開始に失敗しました');
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final driveLog = result.valueOrNull!;
    _currentDriveLogId = driveLog.id;
    _currentUserId = userId;
    _isRecording = true;
    _distanceKm = 0;
    _currentSpeedKmh = 0;
    _maxSpeedKmh = 0;
    _elapsedSeconds = 0;
    _lastPosition = startLocation;
    _isLoading = false;
    notifyListeners();

    _startElapsedTimer();
    _startPositionStream();
    _startWaypointFlushTimer();

    return true;
  }

  /// Stop the current recording and persist statistics.
  /// Returns the completed [DriveLog] or null if not recording.
  Future<DriveLog?> stopRecording() async {
    if (!_isRecording || _currentDriveLogId == null || _currentUserId == null) {
      return null;
    }

    _isLoading = true;
    notifyListeners();

    _elapsedTimer?.cancel();
    _positionSubscription?.cancel();
    _waypointFlushTimer?.cancel();

    // Flush remaining buffered waypoints
    await _flushWaypoints();

    final endLocation = await _resolveCurrentPosition();

    final avgSpeed =
        _elapsedSeconds > 0 ? _distanceKm / (_elapsedSeconds / 3600) : 0.0;

    final stats = DriveStatistics(
      totalDistance: _distanceKm,
      totalDuration: _elapsedSeconds,
      averageSpeed: avgSpeed,
      maxSpeed: _maxSpeedKmh,
    );

    final result = await _service.endDrive(
      driveLogId: _currentDriveLogId!,
      userId: _currentUserId!,
      endLocation: endLocation,
      statistics: stats,
    );

    _isRecording = false;
    _isLoading = false;

    result.when(
      success: (log) {
        _analytics?.trackDriveLogged(log.statistics.totalDistance);
      },
      failure: (err) {
        _error = err;
      },
    );

    notifyListeners();
    return result.valueOrNull;
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _positionSubscription?.cancel();
    _waypointFlushTimer?.cancel();
    super.dispose();
  }

  /// Reset all state (call on logout or after navigating away).
  void clear() {
    _elapsedTimer?.cancel();
    _positionSubscription?.cancel();
    _waypointFlushTimer?.cancel();
    _isRecording = false;
    _isLoading = false;
    _currentDriveLogId = null;
    _currentUserId = null;
    _distanceKm = 0;
    _currentSpeedKmh = 0;
    _maxSpeedKmh = 0;
    _elapsedSeconds = 0;
    _lastPosition = null;
    _waypointBuffer.clear();
    _error = null;
    notifyListeners();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
  }

  void _startPositionStream() {
    _positionSubscription = _positionStreamFactory().listen(
      _onPosition,
      onError: (_) {}, // silently ignore GPS errors during recording
    );
  }

  void _onPosition(Position position) {
    final newPoint = GeoPoint2D(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (_lastPosition != null) {
      final deltaM = _lastPosition!.distanceTo(newPoint);
      _distanceKm += deltaM / 1000;
    }
    _lastPosition = newPoint;

    // geolocator returns speed in m/s; convert to km/h
    final speedKmh = (position.speed > 0 ? position.speed : 0) * 3.6;
    _currentSpeedKmh = speedKmh;
    if (speedKmh > _maxSpeedKmh) {
      _maxSpeedKmh = speedKmh;
    }

    _waypointBuffer.add(DriveWaypoint(
      location: newPoint,
      timestamp: position.timestamp,
      speed: speedKmh,
      altitude: position.altitude,
      heading: position.heading,
      accuracy: position.accuracy,
    ));

    notifyListeners();
  }

  void _startWaypointFlushTimer() {
    _waypointFlushTimer = Timer.periodic(
      const Duration(seconds: _waypointIntervalSeconds),
      (_) => _flushWaypoints(),
    );
  }

  Future<void> _flushWaypoints() async {
    if (_waypointBuffer.isEmpty || _currentDriveLogId == null) return;
    final batch = List<DriveWaypoint>.from(_waypointBuffer);
    _waypointBuffer.clear();
    for (final waypoint in batch) {
      await _service.addWaypoint(
        driveLogId: _currentDriveLogId!,
        waypoint: waypoint,
      );
    }
  }

  Future<GeoPoint2D?> _resolveStartPosition() async {
    if (initialPosition != null) return initialPosition;
    return _resolveCurrentPosition();
  }

  Future<GeoPoint2D?> _resolveCurrentPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return GeoPoint2D(latitude: pos.latitude, longitude: pos.longitude);
    } catch (_) {
      return null;
    }
  }

  // ── Defaults (real device) ────────────────────────────────────────────────

  static Future<bool> _defaultPermissionCheck() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  static Stream<Position> _defaultPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // ignore jitter below 5 m
      ),
    );
  }
}
