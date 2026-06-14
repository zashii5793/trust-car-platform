// RetiredVehiclesScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows '過去の車両' title
//   Empty state:
//     2. Shows '過去の車両はありません' when list is empty
//   List state:
//     3. Shows maker and model name per card
//     4. Shows status badge per card
//     5. Shows '復元' button per card
//   Restore flow:
//     6. Tapping 復元 shows confirmation dialog
//     7. Tapping キャンセル dismisses dialog
//     8. Tapping 復元する calls restoreVehicle
//   Error state:
//     9. Shows error message and reload button

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;

import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/screens/vehicle/retired_vehicles_screen.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/vehicle_retirement_service.dart';

// ---------------------------------------------------------------------------
// Stubs
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

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider() : super(authService: _StubAuthService());

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;

  @override
  AppUser? get appUser => AppUser(
        id: 'user1',
        email: 'user@example.com',
        displayName: 'Test User',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
}

class _MockRetirementService implements VehicleRetirementService {
  final List<Vehicle> vehicles;
  final AppError? loadError;
  bool restoreCalled = false;
  String? restoredVehicleId;

  _MockRetirementService({this.vehicles = const [], this.loadError});

  @override
  Future<Result<List<Vehicle>, AppError>> getRetiredVehicles(
      String userId) async {
    if (loadError != null) return Result.failure(loadError!);
    return Result.success(vehicles);
  }

  @override
  Future<Result<void, AppError>> restoreVehicle({
    required String vehicleId,
    required String ownerId,
  }) async {
    restoreCalled = true;
    restoredVehicleId = vehicleId;
    return const Result.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Vehicle _makeRetiredVehicle({
  String id = 'v1',
  String maker = 'トヨタ',
  String model = 'プリウス',
  VehicleStatus status = VehicleStatus.sold,
  DateTime? retiredAt,
}) {
  final now = DateTime(2026, 3, 15);
  return Vehicle(
    id: id,
    userId: 'user1',
    maker: maker,
    model: model,
    year: 2022,
    grade: 'Z',
    mileage: 20000,
    createdAt: now,
    updatedAt: now,
    status: status,
    retiredAt: retiredAt ?? now,
  );
}

Widget _buildScreen(_MockRetirementService mock) {
  sl.override<VehicleRetirementService>(mock);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => _FakeAuthProvider(),
      ),
    ],
    child: const MaterialApp(home: RetiredVehiclesScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  tearDown(() {
    Injection.reset();
  });

  // =========================================================================
  group('RetiredVehiclesScreen — AppBar', () {
    testWidgets('1. タイトル「過去の車両」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockRetirementService()));
      await tester.pump();
      await tester.pump();

      expect(find.text('過去の車両'), findsOneWidget);
    });
  });

  // =========================================================================
  group('RetiredVehiclesScreen — Empty state', () {
    testWidgets('2. 車両なし時は空メッセージが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockRetirementService()));
      await tester.pump();
      await tester.pump();

      expect(find.text('過去の車両はありません'), findsOneWidget);
    });
  });

  // =========================================================================
  group('RetiredVehiclesScreen — List state', () {
    final vehicles = [
      _makeRetiredVehicle(
          id: 'v1', maker: 'トヨタ', model: 'プリウス', status: VehicleStatus.sold),
      _makeRetiredVehicle(
          id: 'v2',
          maker: 'ホンダ',
          model: 'フィット',
          status: VehicleStatus.scrapped),
    ];

    testWidgets('3. 車両名（メーカー・モデル）が表示される', (tester) async {
      await tester
          .pumpWidget(_buildScreen(_MockRetirementService(vehicles: vehicles)));
      await tester.pump();
      await tester.pump();

      expect(find.text('トヨタ プリウス'), findsOneWidget);
      expect(find.text('ホンダ フィット'), findsOneWidget);
    });

    testWidgets('4. ステータスバッジが表示される', (tester) async {
      await tester
          .pumpWidget(_buildScreen(_MockRetirementService(vehicles: vehicles)));
      await tester.pump();
      await tester.pump();

      expect(find.text('売却済み'), findsOneWidget);
      expect(find.text('廃車済み'), findsOneWidget);
    });

    testWidgets('5. 各カードに復元ボタンが表示される', (tester) async {
      await tester
          .pumpWidget(_buildScreen(_MockRetirementService(vehicles: vehicles)));
      await tester.pump();
      await tester.pump();

      expect(find.text('復元'), findsNWidgets(2));
    });
  });

  // =========================================================================
  group('RetiredVehiclesScreen — Restore flow', () {
    final vehicles = [
      _makeRetiredVehicle(id: 'v1', maker: 'スズキ', model: 'スイフト'),
    ];

    testWidgets('6. 復元ボタンタップで確認ダイアログが表示される', (tester) async {
      await tester
          .pumpWidget(_buildScreen(_MockRetirementService(vehicles: vehicles)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('復元').first);
      await tester.pumpAndSettle();

      expect(find.text('車両を復元しますか？'), findsOneWidget);
    });

    testWidgets('7. キャンセルでダイアログが閉じる', (tester) async {
      await tester
          .pumpWidget(_buildScreen(_MockRetirementService(vehicles: vehicles)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('復元').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(find.text('車両を復元しますか？'), findsNothing);
    });

    testWidgets('8. 復元するタップでrestoreVehicleが呼ばれる', (tester) async {
      final mock = _MockRetirementService(vehicles: vehicles);
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('復元').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('復元する'));
      await tester.pumpAndSettle();

      expect(mock.restoreCalled, isTrue);
      expect(mock.restoredVehicleId, 'v1');
    });
  });

  // =========================================================================
  group('RetiredVehiclesScreen — Error state', () {
    testWidgets('9. エラー時はエラーメッセージと再読み込みボタンが表示される', (tester) async {
      final mock = _MockRetirementService(
        loadError: AppError.server('load failed'),
      );
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      expect(find.text('再読み込み'), findsOneWidget);
    });
  });
}
