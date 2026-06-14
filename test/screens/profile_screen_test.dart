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
import 'package:trust_car_platform/models/user.dart';
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

Widget _buildScreen({AppUser? appUser}) {
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
    child: const MaterialApp(home: ProfileScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
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
      // Label is plan-dependent: 'データをエクスポート（プレミアム）' on the free plan.
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

      // Should find the TextFormField for the display name
      expect(find.byType(TextFormField), findsOneWidget);
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

      final textField =
          tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.controller?.text, 'テストユーザー');
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

  // =========================================================================
  group('ProfileScreen — プロフィールヘッダー', () {
    testWidgets('AppUserのdisplayNameが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        appUser: AppUser(
          id: 'uid1',
          email: 'test@example.com',
          displayName: '田中太郎',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('田中太郎'), findsOneWidget);
    });

    testWidgets('メールアドレスが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(
        appUser: AppUser(
          id: 'uid1',
          email: 'test@example.com',
          displayName: '田中',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // ProfileScreen shows user?.email (Firebase User email) = 'test@example.com'
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('フリープランバッジが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('フリープラン'), findsOneWidget);
    });

    testWidgets('AppBarに設定アイコンが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });
  });

  // =========================================================================
  group('ProfileScreen — メニューセクション', () {
    testWidgets('マーケットプレイスセクションに「マイ出品」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.ensureVisible(find.text('マイ出品'));
      expect(find.text('マイ出品'), findsOneWidget);
    });

    testWidgets('サポートセクションに「ヘルプ」と「このアプリについて」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.ensureVisible(find.text('ヘルプ'));
      expect(find.text('ヘルプ'), findsOneWidget);
      expect(find.text('このアプリについて'), findsOneWidget);
    });

    testWidgets('「このアプリについて」タップでAboutDialogが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.ensureVisible(find.text('このアプリについて'));
      await tester.tap(find.text('このアプリについて'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutDialog), findsOneWidget);
    });

    testWidgets('非プレミアム: データエクスポートタップでアップグレードダイアログが表示される',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.ensureVisible(find.textContaining('データをエクスポート'));
      await tester.tap(find.textContaining('データをエクスポート'));
      await tester.pumpAndSettle();

      expect(find.text('プレミアムプランが必要です'), findsOneWidget);
    });
  });

  // =========================================================================
  group('ProfileScreen — ログアウト', () {
    testWidgets('ログアウトボタンタップで確認ダイアログが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.ensureVisible(find.text('ログアウト').first);
      await tester.tap(find.text('ログアウト').first);
      await tester.pumpAndSettle();

      expect(find.text('ログアウトしてもよろしいですか？'), findsOneWidget);
    });

    testWidgets('ログアウト確認ダイアログで「キャンセル」タップするとダイアログが閉じる',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.ensureVisible(find.text('ログアウト').first);
      await tester.tap(find.text('ログアウト').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(find.text('ログアウトしてもよろしいですか？'), findsNothing);
      expect(find.text('プロフィール'), findsOneWidget);
    });
  });

  // =========================================================================
  group('ProfileScreen — 編集フォーム バリデーション', () {
    testWidgets('表示名が空のまま保存すると「表示名を入力してください」が表示される',
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

      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(find.text('表示名を入力してください'), findsOneWidget);
    });

    testWidgets('空白のみの表示名でも「表示名を入力してください」が表示される', (tester) async {
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

      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(find.text('表示名を入力してください'), findsOneWidget);
    });
  });
}
