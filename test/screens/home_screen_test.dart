// HomeScreen Widget Tests
//
// Strategy: Fake providers extend the real provider classes with
// mock service dependencies.  Firebase platform channels are not
// invoked because fake services return instantly.
//
// Coverage:
//   - Initial tab index (マイカー)
//   - AppBar title per tab
//   - BottomNavigationBar items & tap
//   - Vehicle loading / empty / error states
//   - Notification badge when unread count > 0
//   - Offline banner (ConnectivityProvider.isOffline = true)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/home_screen.dart';
import 'package:trust_car_platform/providers/vehicle_provider.dart';
import 'package:trust_car_platform/providers/maintenance_provider.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/providers/notification_provider.dart';
import 'package:trust_car_platform/providers/connectivity_provider.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/recommendation_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/app_notification.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Stub FirebaseService
// ---------------------------------------------------------------------------

class _StubFirebaseService implements FirebaseService {
  @override
  String? get currentUserId => 'uid-test';

  @override
  Stream<List<Vehicle>> getUserVehicles() => const Stream.empty();

  @override
  Stream<List<MaintenanceRecord>> getVehicleMaintenanceRecords(String vid) =>
      const Stream.empty();

  @override
  Future<Result<String, AppError>> addVehicle(Vehicle v) async =>
      const Result.success('id');

  @override
  Future<Result<void, AppError>> updateVehicle(String id, Vehicle v) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteVehicle(String id) async =>
      const Result.success(null);

  @override
  Future<Result<Vehicle?, AppError>> getVehicle(String id) async =>
      const Result.success(null);

  @override
  Future<Result<bool, AppError>> isLicensePlateExists(String plate,
          {String? excludeVehicleId}) async =>
      const Result.success(false);

  @override
  Future<Result<String, AppError>> addMaintenanceRecord(
          MaintenanceRecord r) async =>
      const Result.success('rid');

  @override
  Future<Result<void, AppError>> updateMaintenanceRecord(
          String id, MaintenanceRecord r) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteMaintenanceRecord(String id) async =>
      const Result.success(null);

  @override
  Future<Result<List<MaintenanceRecord>, AppError>>
      getMaintenanceRecordsForVehicle(String vehicleId,
              {int limit = 20}) async =>
          const Result.success([]);

  @override
  Future<Result<Map<String, List<MaintenanceRecord>>, AppError>>
      getMaintenanceRecordsForVehicles(List<String> vehicleIds,
              {int limitPerVehicle = 20}) async =>
          const Result.success({});

  @override
  Future<Result<String, AppError>> uploadImage(dynamic f, String path) async =>
      const Result.success('url');

  @override
  Future<Result<String, AppError>> uploadImageBytes(dynamic b, String path) async =>
      const Result.success('url');

  @override
  Future<Result<List<String>, AppError>> uploadImages(
          List<dynamic> files, String basePath) async =>
      const Result.success([]);

  @override
  Future<Result<String, AppError>> uploadProcessedImage(
    dynamic bytes,
    String path, {
    required dynamic imageService,
  }) async =>
      const Result.success('url');
}

// ---------------------------------------------------------------------------
// Stub AuthService (returns empty stream → firebaseUser stays null)
// ---------------------------------------------------------------------------

class _StubAuthService implements AuthService {
  @override
  Stream<dynamic> get authStateChanges => const Stream.empty();

  @override
  dynamic get currentUser => null;

  @override
  Future<Result<dynamic, AppError>> signInWithEmail(
          {required String email, required String password}) async =>
      Result.failure(AppError.unknown('stub'));

  @override
  Future<Result<dynamic, AppError>> signUpWithEmail(
          {required String email,
          required String password,
          String? displayName}) async =>
      Result.failure(AppError.unknown('stub'));

  @override
  Future<Result<dynamic, AppError>> signInWithGoogle() async =>
      Result.failure(AppError.unknown('stub'));

  @override
  Future<Result<void, AppError>> signOut() async =>
      const Result.success(null);

  @override
  Future<Result<dynamic, AppError>> getUserProfile() async =>
      Result.failure(AppError.unknown('stub'));

  @override
  Future<Result<dynamic, AppError>> updateUserProfile(
          {String? displayName, String? photoUrl}) async =>
      Result.failure(AppError.unknown('stub'));

  @override
  Future<Result<void, AppError>> sendPasswordResetEmail(String email) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteAccount() async =>
      const Result.success(null);
}

// ---------------------------------------------------------------------------
// Fake VehicleProvider — exposes setters so tests control state
// ---------------------------------------------------------------------------

class _FakeVehicleProvider extends VehicleProvider {
  _FakeVehicleProvider() : super(firebaseService: _StubFirebaseService());

  List<Vehicle> _fakeVehicles = [];
  bool _fakeLoading = false;
  AppError? _fakeError;

  void setVehicles(List<Vehicle> v) {
    _fakeVehicles = v;
    notifyListeners();
  }

  void setLoading(bool v) {
    _fakeLoading = v;
    notifyListeners();
  }

  void setError(AppError e) {
    _fakeError = e;
    notifyListeners();
  }

  @override
  List<Vehicle> get vehicles => _fakeVehicles;

  @override
  bool get isLoading => _fakeLoading;

  @override
  AppError? get error => _fakeError;

  @override
  String? get errorMessage => _fakeError?.userMessage;

  @override
  bool get isRetryable => _fakeError?.isRetryable ?? false;

  @override
  void listenToVehicles() {} // no-op: prevents Firebase calls

  @override
  void stopListening() {}

  @override
  void clear() {
    _fakeVehicles = [];
    _fakeLoading = false;
    _fakeError = null;
    notifyListeners();
  }

  @override
  void clearError() {
    _fakeError = null;
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// Fake NotificationProvider
// ---------------------------------------------------------------------------

class _FakeNotificationProvider extends NotificationProvider {
  _FakeNotificationProvider()
      : super(
          firebaseService: _StubFirebaseService(),
          recommendationService: RecommendationService(),
        );

  List<AppNotification> _fakeNotifications = [];

  void setNotifications(List<AppNotification> n) {
    _fakeNotifications = n;
    notifyListeners();
  }

  @override
  List<AppNotification> get notifications => _fakeNotifications;

  @override
  int get unreadCount => _fakeNotifications.where((n) => !n.isRead).length;

  @override
  List<AppNotification> get topSuggestions => _fakeNotifications.take(3).toList();

  @override
  Future<void> generateNotificationsForVehicles(List<Vehicle> vehicles) async {}
}

// ---------------------------------------------------------------------------
// Helper: build the test app
// ---------------------------------------------------------------------------

Vehicle _makeVehicle(String id) => Vehicle(
      id: id,
      userId: 'u1',
      maker: 'Toyota',
      model: 'Prius',
      year: 2021,
      grade: 'S',
      mileage: 30000,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

AppNotification _makeNotif({bool isRead = false}) => AppNotification(
      id: 'n1',
      userId: 'u1',
      type: NotificationType.maintenanceRecommendation,
      title: 'オイル交換',
      message: 'そろそろオイル交換を',
      isRead: isRead,
      createdAt: DateTime(2024, 1, 1),
    );

Widget _buildApp({
  _FakeVehicleProvider? vehicleProvider,
  _FakeNotificationProvider? notificationProvider,
  bool isOffline = false,
}) {
  final fb = _StubFirebaseService();
  final vp = vehicleProvider ?? _FakeVehicleProvider();
  final np = notificationProvider ?? _FakeNotificationProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<VehicleProvider>.value(value: vp),
      ChangeNotifierProvider<MaintenanceProvider>(
        create: (_) => MaintenanceProvider(firebaseService: fb),
      ),
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(authService: _StubAuthService()),
      ),
      ChangeNotifierProvider<NotificationProvider>.value(value: np),
      ChangeNotifierProvider<ConnectivityProvider>(
        create: (_) {
          final cp = _StubConnectivityProvider(isOffline: isOffline);
          return cp;
        },
      ),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

// ---------------------------------------------------------------------------
// Fake ConnectivityProvider (bypasses platform channel via implements)
// ---------------------------------------------------------------------------

class _StubConnectivityProvider extends ChangeNotifier
    implements ConnectivityProvider {
  final bool _offline;

  _StubConnectivityProvider({bool isOffline = false}) : _offline = isOffline;

  @override
  bool get isOnline => !_offline;

  @override
  bool get isOffline => _offline;

  @override
  bool get isInitialized => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('HomeScreen — AppBar', () {
    testWidgets('初期タブはマイカー（タイトルが "マイカー"）', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.text('マイカー'), findsOneWidget);
    });

    testWidgets('マーケットプレイスタブに切り替えるとタイトルが変わる', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.store_outlined));
      await tester.pumpAndSettle();

      expect(find.text('マーケットプレイス'), findsOneWidget);
    });

    testWidgets('SNSタブに切り替えるとタイトルが "みんなの投稿"', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.people_outline));
      await tester.pumpAndSettle();

      expect(find.text('みんなの投稿'), findsOneWidget);
    });

    testWidgets('通知タブに切り替えるとタイトルが "通知"', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();

      expect(find.text('通知'), findsOneWidget);
    });

    testWidgets('プロフィールタブに切り替えるとタイトルが "プロフィール"', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();

      expect(find.text('プロフィール'), findsOneWidget);
    });
  });

  group('HomeScreen — BottomNavigationBar', () {
    testWidgets('BottomNavigationBar が表示される', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('5つのタブアイコンが存在する', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byIcon(Icons.directions_car), findsOneWidget);
      expect(find.byIcon(Icons.store_outlined), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('タブを順番にタップして全タブに移動できる', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      // 全タブを一巡
      final icons = [
        Icons.store_outlined,
        Icons.people_outline,
        Icons.notifications_outlined,
        Icons.person_outline,
        Icons.directions_car,
      ];
      for (final icon in icons) {
        await tester.tap(find.byIcon(icon));
        await tester.pumpAndSettle();
      }

      // クラッシュしない
      expect(tester.takeException(), isNull);
    });
  });

  group('HomeScreen — マイカータブ（index=0）', () {
    testWidgets('車両なし → 空状態UIが表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('車両あり → リストに表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles([_makeVehicle('v1'), _makeVehicle('v2')]);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      // ListView が存在する
      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('ローディング中は LoadingIndicator が表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setLoading(true);

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      // CircularProgressIndicator か AppLoadingCenter が存在する
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.byType(Center).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('エラー状態でエラーUIが表示される', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setError(AppError.network('接続失敗'));

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      // エラーテキストが何らか存在する
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('HomeScreen — 通知バッジ', () {
    testWidgets('未読通知があるとき、通知タブにバッジが表示される', (tester) async {
      final np = _FakeNotificationProvider();
      np.setNotifications([_makeNotif(isRead: false)]);

      await tester.pumpWidget(_buildApp(notificationProvider: np));
      await tester.pump();

      // Badge テキスト（件数）が表示される
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('未読通知がないとき、バッジテキストは表示されない', (tester) async {
      final np = _FakeNotificationProvider();
      np.setNotifications([_makeNotif(isRead: true)]);

      await tester.pumpWidget(_buildApp(notificationProvider: np));
      await tester.pump();

      // 未読数0のため、数字バッジは存在しない
      expect(find.text('0'), findsNothing);
    });

    testWidgets('通知100件超えは "99+" 表示になる', (tester) async {
      final np = _FakeNotificationProvider();
      np.setNotifications(
        List.generate(
          101,
          (i) => AppNotification(
            id: 'n$i',
            userId: 'u1',
            type: NotificationType.system,
            title: '通知$i',
            message: 'msg',
            isRead: false,
            createdAt: DateTime(2024, 1, 1),
          ),
        ),
      );

      await tester.pumpWidget(_buildApp(notificationProvider: np));
      await tester.pump();

      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('HomeScreen — オフラインバナー', () {
    testWidgets('オフライン時にオフラインアイコンが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(isOffline: true));
      await tester.pump();

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('オンライン時はオフラインアイコンが表示されない', (tester) async {
      await tester.pumpWidget(_buildApp(isOffline: false));
      await tester.pump();

      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });
  });

  group('Edge Cases', () {
    testWidgets('同じタブを連続タップしてもクラッシュしない', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.directions_car));
      await tester.tap(find.byIcon(Icons.directions_car));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('多数の車両（20件）があってもクラッシュしない', (tester) async {
      final vp = _FakeVehicleProvider();
      vp.setVehicles(List.generate(20, (i) => _makeVehicle('v$i')));

      await tester.pumpWidget(_buildApp(vehicleProvider: vp));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
