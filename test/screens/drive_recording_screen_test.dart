// DriveRecordingScreen Widget Tests
//
// Coverage:
//   1. AppBar title: default ('ドライブ記録中') and with vehicleName
//   2. Stat cards: 経過時間 / 走行距離 / 現在速度 / 最高速度
//   3. GPS indicator visible
//   4. Loading state shows CircularProgressIndicator
//   5. Stop button exists and is enabled/disabled based on loading
//   6. Stop button opens confirmation dialog
//   7. Confirmation '続ける' → dialog dismissed, recording continues
//   8. Confirmation '終了' → stopRecording called, screen popped
//   9. Permission denied → error snackbar shown
//  10. Distance formatting: < 1 km → metres, >= 1 km → kilometres

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;

import 'package:trust_car_platform/screens/drive/drive_recording_screen.dart';
import 'package:trust_car_platform/providers/drive_recording_provider.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/drive_log_service.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Stub DriveLogService
// ---------------------------------------------------------------------------

class _StubDriveLogService implements DriveLogService {
  @override
  Future<Result<DriveLog, AppError>> startDrive({
    required String userId,
    String? vehicleId,
    GeoPoint2D? startLocation,
    String? startAddress,
  }) async =>
      Result.success(_makeLog());

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
  }) async =>
      Result.success(_makeLog());

  @override
  Future<Result<void, AppError>> addWaypoint({
    required String driveLogId,
    required DriveWaypoint waypoint,
  }) async =>
      const Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

DriveLog _makeLog() {
  final now = DateTime.now();
  return DriveLog(
    id: 'drive1',
    userId: 'user1',
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

// ---------------------------------------------------------------------------
// Fake DriveRecordingProvider
// ---------------------------------------------------------------------------

class _FakeDriveRecordingProvider extends DriveRecordingProvider {
  final bool _mockIsRecording;
  final bool _mockIsLoading;
  final bool _startShouldFail;
  final String? _mockErrorMessage;
  final double _mockDistanceKm;
  final double _mockCurrentSpeed;
  final double _mockMaxSpeed;

  bool stopCalled = false;
  bool startCalled = false;

  _FakeDriveRecordingProvider({
    bool isRecording = true,
    bool isLoading = false,
    bool startShouldFail = false,
    String? errorMessage,
    double distanceKm = 0.0,
    double currentSpeed = 42.0,
    double maxSpeed = 68.0,
  })  : _mockIsRecording = isRecording,
        _mockIsLoading = isLoading,
        _startShouldFail = startShouldFail,
        _mockErrorMessage = errorMessage,
        _mockDistanceKm = distanceKm,
        _mockCurrentSpeed = currentSpeed,
        _mockMaxSpeed = maxSpeed,
        super(
          driveLogService: _StubDriveLogService(),
          permissionChecker: () async => true,
          positionStreamFactory: Stream.empty,
        );

  @override
  bool get isRecording => _mockIsRecording;

  @override
  bool get isLoading => _mockIsLoading;

  @override
  String? get errorMessage => _mockErrorMessage;

  @override
  String get formattedElapsed => '12:34';

  @override
  double get distanceKm => _mockDistanceKm;

  @override
  double get currentSpeedKmh => _mockCurrentSpeed;

  @override
  double get maxSpeedKmh => _mockMaxSpeed;

  @override
  Future<bool> startRecording({
    required String userId,
    String? vehicleId,
  }) async {
    startCalled = true;
    return !_startShouldFail;
  }

  @override
  Future<DriveLog?> stopRecording() async {
    stopCalled = true;
    return null;
  }
}

// ---------------------------------------------------------------------------
// Stub AuthService
// ---------------------------------------------------------------------------

class _StubAuthService implements AuthService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<Result<UserCredential, AppError>> signUpWithEmail(
          {required String email,
          required String password,
          String? displayName}) async =>
      Result.failure(AppError.server('stub'));

  @override
  Future<Result<UserCredential, AppError>> signInWithEmail(
          {required String email, required String password}) async =>
      Result.failure(AppError.server('stub'));

  @override
  Future<Result<UserCredential?, AppError>> signInWithGoogle() async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> sendPasswordResetEmail(String email) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> signOut() async => const Result.success(null);

  @override
  Future<Result<AppUser?, AppError>> getUserProfile() async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> updateUserProfile(
          {String? displayName, String? photoUrl}) async =>
      const Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Fake Firebase User + LoggedIn AuthProvider
// ---------------------------------------------------------------------------

class _FakeUser implements User {
  @override
  String get uid => 'test-uid';
  @override
  String? get displayName => 'Test User';
  @override
  String? get photoURL => null;
  @override
  String? get email => 'test@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _LoggedInAuthProvider extends AuthProvider {
  _LoggedInAuthProvider() : super(authService: _StubAuthService());
  @override
  User? get firebaseUser => _FakeUser();
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => false;
}

// ---------------------------------------------------------------------------
// Widget builder helpers
// ---------------------------------------------------------------------------

Widget _buildScreen({
  _FakeDriveRecordingProvider? provider,
  String? vehicleId,
  String? vehicleName,
}) {
  final recordingProvider = provider ?? _FakeDriveRecordingProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => _LoggedInAuthProvider(),
      ),
      ChangeNotifierProvider<DriveRecordingProvider>.value(
          value: recordingProvider),
    ],
    child: MaterialApp(
      home: DriveRecordingScreen(
        vehicleId: vehicleId,
        vehicleName: vehicleName,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DriveRecordingScreen — AppBar', () {
    testWidgets('shows default title when no vehicleName', (tester) async {
      await tester.pumpWidget(_buildScreen());
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('ドライブ記録中'), findsOneWidget);
    });

    testWidgets('shows vehicle name in title when provided', (tester) async {
      await tester
          .pumpWidget(_buildScreen(vehicleName: 'GR86', vehicleId: 'v1'));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('GR86 — 記録中'), findsOneWidget);
    });

    testWidgets('no back arrow shown (canPop is false)', (tester) async {
      await tester.pumpWidget(_buildScreen());
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      // automaticallyImplyLeading is false → no back button
      expect(find.byType(BackButton), findsNothing);
    });
  });

  group('DriveRecordingScreen — Stat cards', () {
    testWidgets('shows 経過時間 card with formattedElapsed', (tester) async {
      await tester.pumpWidget(_buildScreen());
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('経過時間'), findsOneWidget);
      expect(find.text('12:34'), findsOneWidget);
    });

    testWidgets('shows 走行距離 card', (tester) async {
      await tester.pumpWidget(
          _buildScreen(provider: _FakeDriveRecordingProvider(distanceKm: 0)));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('走行距離'), findsOneWidget);
    });

    testWidgets('shows 現在速度 card with speed value', (tester) async {
      await tester.pumpWidget(_buildScreen(
          provider: _FakeDriveRecordingProvider(currentSpeed: 42)));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('現在速度'), findsOneWidget);
      expect(find.text('42 km/h'), findsOneWidget);
    });

    testWidgets('shows 最高速度 card with speed value', (tester) async {
      await tester.pumpWidget(
          _buildScreen(provider: _FakeDriveRecordingProvider(maxSpeed: 68)));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('最高速度'), findsOneWidget);
      expect(find.text('68 km/h'), findsOneWidget);
    });

    testWidgets('shows GPS indicator', (tester) async {
      await tester.pumpWidget(_buildScreen());
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('GPS 取得中'), findsOneWidget);
    });
  });

  group('DriveRecordingScreen — Distance formatting', () {
    testWidgets('shows metres when distance < 1 km', (tester) async {
      await tester.pumpWidget(
          _buildScreen(provider: _FakeDriveRecordingProvider(distanceKm: 0.5)));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('500 m'), findsOneWidget);
    });

    testWidgets('shows km when distance >= 1 km', (tester) async {
      await tester.pumpWidget(_buildScreen(
          provider: _FakeDriveRecordingProvider(distanceKm: 12.34)));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('12.34 km'), findsOneWidget);
    });

    testWidgets('shows 0 m when distance is 0', (tester) async {
      await tester.pumpWidget(
          _buildScreen(provider: _FakeDriveRecordingProvider(distanceKm: 0)));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('0 m'), findsOneWidget);
    });
  });

  group('DriveRecordingScreen — Loading state', () {
    testWidgets('shows CircularProgressIndicator when isLoading',
        (tester) async {
      await tester.pumpWidget(
          _buildScreen(provider: _FakeDriveRecordingProvider(isLoading: true)));
      await tester.pump(); // one frame — addPostFrameCallback fires

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Stat cards are not shown during loading
      expect(find.text('経過時間'), findsNothing);
    });

    testWidgets('stop button is disabled when isLoading', (tester) async {
      final provider = _FakeDriveRecordingProvider(isLoading: true);
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pump();

      // The ElevatedButton.icon is disabled when onPressed is null
      // (ElevatedButton.icon builds a private subclass, so match by subtype)
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('記録を終了'),
          matching: find.bySubtype<ElevatedButton>(),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('DriveRecordingScreen — Stop button', () {
    testWidgets('stop button is visible when recording', (tester) async {
      await tester.pumpWidget(_buildScreen());
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('記録を終了'), findsOneWidget);
    });

    testWidgets('stop button opens confirmation dialog', (tester) async {
      await tester.pumpWidget(_buildScreen());
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('記録を終了'));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('記録を終了しますか？'), findsOneWidget);
      expect(find.text('現在のドライブデータを保存して終了します。'), findsOneWidget);
      expect(find.text('続ける'), findsOneWidget);
      expect(find.text('終了'), findsOneWidget);
    });

    testWidgets("tapping '続ける' dismisses dialog without stopping",
        (tester) async {
      final provider = _FakeDriveRecordingProvider();
      await tester.pumpWidget(_buildScreen(provider: provider));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('記録を終了'));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('続ける'));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(provider.stopCalled, isFalse);
      // Dialog is gone
      expect(find.text('記録を終了しますか？'), findsNothing);
      // Screen still shows
      expect(find.text('経過時間'), findsOneWidget);
    });

    testWidgets("tapping '終了' calls stopRecording", (tester) async {
      final provider = _FakeDriveRecordingProvider();
      await tester.pumpWidget(_buildScreen(provider: provider));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('記録を終了'));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('終了'));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(provider.stopCalled, isTrue);
    });
  });

  group('DriveRecordingScreen — Permission denied', () {
    testWidgets('shows error snackbar when startRecording fails',
        (tester) async {
      final provider = _FakeDriveRecordingProvider(
        isRecording: false,
        startShouldFail: true,
        errorMessage: '位置情報の権限が必要です',
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pump(); // triggers postFrameCallback → startRecording
      await tester.pump(const Duration(milliseconds: 200)); // snackbar entrance

      expect(find.text('位置情報の権限が必要です'), findsOneWidget);
    });

    testWidgets('shows fallback snackbar message when errorMessage is null',
        (tester) async {
      final provider = _FakeDriveRecordingProvider(
        isRecording: false,
        startShouldFail: true,
        errorMessage: null,
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pump(); // triggers postFrameCallback → startRecording
      await tester.pump(const Duration(milliseconds: 200)); // snackbar entrance

      expect(find.text('記録を開始できませんでした'), findsOneWidget);
    });
  });

  group('DriveRecordingScreen — Already recording guard', () {
    testWidgets('does NOT call startRecording when already recording',
        (tester) async {
      final provider = _FakeDriveRecordingProvider(isRecording: true);
      await tester.pumpWidget(_buildScreen(provider: provider));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(provider.startCalled, isFalse);
    });
  });

  group('DriveRecordingScreen — Edge cases', () {
    testWidgets('no crash when vehicleId and vehicleName are null',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull);
    });

    testWidgets('speed shows zero correctly', (tester) async {
      await tester.pumpWidget(_buildScreen(
          provider: _FakeDriveRecordingProvider(currentSpeed: 0, maxSpeed: 0)));
      // Bounded pumps: the pulsing GPS indicator animates forever,
      // so pumpAndSettle would always time out on this screen.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      // Both speed cards should show '0 km/h'
      expect(find.text('0 km/h'), findsNWidgets(2));
    });
  });
}
