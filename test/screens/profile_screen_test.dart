// ProfileScreen Widget Tests
//
// Coverage:
//   1. Tapping "プロフィールを編集" opens a bottom sheet with an edit form
//   2. Bottom sheet contains "プロフィールを編集" title
//   3. Bottom sheet contains a display name text field
//   4. Bottom sheet contains 保存 button
//   5. Main screen renders ユーザー name and menu items

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/core/theme/app_theme.dart';
import 'package:trust_car_platform/models/user.dart';

import '../golden/font_loader.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/providers/maintenance_provider.dart';
import 'package:trust_car_platform/providers/user_subscription_provider.dart';
import 'package:trust_car_platform/providers/vehicle_provider.dart';
import 'package:trust_car_platform/screens/profile/profile_screen.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _FakeUser implements User {
  @override
  String get uid => 'uid1';
  @override
  String? get displayName => null;
  @override
  String? get photoURL => null;
  @override
  String? get email => 'test@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubAuthService implements AuthService {
  final AppUser? _user;

  _StubAuthService({AppUser? user}) : _user = user;

  // Emit a signed-in user when a profile is provided so AuthProvider
  // loads it via getUserProfile().
  @override
  User? get currentUser => _user == null ? null : _FakeUser();

  @override
  Stream<User?> get authStateChanges =>
      Stream.value(_user == null ? null : _FakeUser());

  @override
  Future<Result<AppUser?, AppError>> getUserProfile() async =>
      Result.success(_user);

  @override
  Future<Result<UserCredential, AppError>> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async =>
      Result.failure(AppError.server('stub'));

  @override
  Future<Result<UserCredential, AppError>> signInWithEmail({
    required String email,
    required String password,
  }) async =>
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
  Future<Result<void, AppError>> updateUserProfile({
    String? displayName,
    String? photoUrl,
    String? prefecture,
    String? city,
  }) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> updateNotificationSettings(
    NotificationSettings settings,
  ) async =>
      const Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubFirebaseService implements FirebaseService {
  @override
  Future<Result<MaintenanceSummary, AppError>> maintenanceSummary({
    DateTime? since,
  }) async =>
      const Result.success(MaintenanceSummary.empty);

  @override
  Future<Result<bool, AppError>> hasAnyMaintenanceRecord() async =>
      const Result.success(false);

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
    MaintenanceRecord record,
  ) async =>
      const Result.success('id');

  @override
  Future<Result<void, AppError>> updateMaintenanceRecord(
    String recordId,
    MaintenanceRecord record,
  ) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteMaintenanceRecord(
    String recordId,
  ) async =>
      const Result.success(null);

  @override
  Future<Result<String, AppError>> uploadImageBytes(
    Uint8List bytes,
    String path,
  ) async =>
      const Result.success('url');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

Widget _buildScreen({AppUser? appUser, ThemeData? theme}) {
  final fb = _StubFirebaseService();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(
          authService: _StubAuthService(user: appUser),
        ),
      ),
      ChangeNotifierProvider<VehicleProvider>(
        create: (_) => VehicleProvider(firebaseService: fb),
      ),
      ChangeNotifierProvider<UserSubscriptionProvider>(
        create: (_) => UserSubscriptionProvider(),
      ),
      ChangeNotifierProvider<MaintenanceProvider>(
        create: (_) => MaintenanceProvider(firebaseService: fb),
      ),
    ],
    child: MaterialApp(
      theme: theme,
      // ゴールデンに右上の赤いリボンが写り込むのを防ぐ。
      debugShowCheckedModeBanner: false,
      home: const ProfileScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // 見え方を画像に残す。**数値の検査では、詰まっている・沈んでいる・
  // 読みにくい、は分からない。** CI では走らない（tags: 'golden'）。
  //
  //   flutter test --update-goldens test/screens/profile_screen_test.dart
  group('ゴールデン', () {
    setUpAll(() async {
      await loadMaterialIcons();
      await loadJapaneseFont();
    });

    Future<void> shoot(WidgetTester tester, String name, ThemeData base) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildScreen(
          appUser: AppUser(
            id: 'uid1',
            email: 'test@example.com',
            displayName: 'テストユーザー',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
          theme: goldenTheme(base),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../golden/goldens/$name.png'),
      );
    }

    testWidgets('プロフィール（ライト）', (tester) async {
      await shoot(tester, 'screen_profile_light', AppTheme.lightTheme);
    }, tags: 'golden');

    testWidgets('プロフィール（ダーク）', (tester) async {
      await shoot(tester, 'screen_profile_dark', AppTheme.darkTheme);
    }, tags: 'golden');
  });

  group('ProfileScreen — initial rendering', () {
    testWidgets('shows プロフィール app bar title', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('プロフィール'), findsOneWidget);
    });

    testWidgets('shows menu items', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('プロフィールを編集'), findsOneWidget);
      expect(find.text('通知設定'), findsOneWidget);
      // ラベルはプランによらず同じ。有料であることは開いたときの案内で伝える。
      expect(find.textContaining('データをエクスポート'), findsOneWidget);
    });

    testWidgets('shows ログアウト button', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('ログアウト'), findsOneWidget);
    });
  });

  group('ProfileScreen — profile edit bottom sheet', () {
    testWidgets('tapping "プロフィールを編集" opens bottom sheet', (tester) async {
      await tester.pumpWidget(_buildScreen(
        appUser: AppUser(
          id: 'uid1',
          email: 'test@example.com',
          displayName: 'テストユーザー',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ));
      await tester.pump();

      // Tap menu item
      await tester.tap(find.text('プロフィールを編集'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Bottom sheet title should appear
      expect(find.text('プロフィールを編集'), findsWidgets);
    });

    testWidgets('bottom sheet contains display name text field',
        (tester) async {
      await tester.pumpWidget(_buildScreen(
        appUser: AppUser(
          id: 'uid1',
          email: 'test@example.com',
          displayName: 'テストユーザー',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('プロフィールを編集'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // 表示名の欄は Key で特定する。シートには市区町村の欄もあるため、
      // byType(TextFormField) では複数一致する。
      expect(
          find.byKey(const Key('profile_display_name_field')), findsOneWidget);
    });

    testWidgets('bottom sheet contains 保存 button', (tester) async {
      await tester.pumpWidget(_buildScreen(
        appUser: AppUser(
          id: 'uid1',
          email: 'test@example.com',
          displayName: 'テストユーザー',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('プロフィールを編集'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('bottom sheet pre-fills current display name', (tester) async {
      await tester.pumpWidget(_buildScreen(
        appUser: AppUser(
          id: 'uid1',
          email: 'test@example.com',
          displayName: 'テストユーザー',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('プロフィールを編集'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final textField = tester.widget<TextFormField>(
          find.byKey(const Key('profile_display_name_field')));
      expect(textField.controller?.text, 'テストユーザー');
    });

    testWidgets('bottom sheet shows the region fields', (tester) async {
      // 近くの整備工場を探すための居住地。都道府県は選択式、
      // 市区町村は網羅した一覧を持てないので自由入力。
      await tester.pumpWidget(_buildScreen(
        appUser: AppUser(
          id: 'uid1',
          email: 'test@example.com',
          displayName: 'テストユーザー',
          prefecture: '東京都',
          city: '世田谷区',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('プロフィールを編集'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(
          find.byKey(const Key('profile_prefecture_dropdown')), findsOneWidget);
      final cityField = tester
          .widget<TextFormField>(find.byKey(const Key('profile_city_field')));
      expect(cityField.controller?.text, '世田谷区');
    });

    testWidgets('bottom sheet shows photo picker area', (tester) async {
      await tester.pumpWidget(_buildScreen(
        appUser: AppUser(
          id: 'uid1',
          email: 'test@example.com',
          displayName: 'テストユーザー',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('プロフィールを編集'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Should find a CircleAvatar for the photo picker
      expect(find.byType(CircleAvatar), findsWidgets);
    });
  });

  group('ProfileScreen — 統計セクション', () {
    testWidgets('統計ラベルが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('登録車両'), findsOneWidget);
      expect(find.text('整備記録'), findsOneWidget);
      expect(find.text('総走行距離(km)'), findsOneWidget);
    });

    testWidgets('初期状態で車両数と整備記録数が 0 と表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      // VehicleProvider と MaintenanceProvider が空なので '0' が複数表示される
      expect(find.text('0'), findsWidgets);
    });
  });
}
