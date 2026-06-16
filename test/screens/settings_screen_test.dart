// SettingsScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows '設定' title
//     2. Shows '保存' TextButton in AppBar
//     3. Shows spinner instead of 保存 while saving
//   Notification section:
//     4. Shows '通知設定' section header
//     5. Shows プッシュ通知 switch
//     6. Shows 点検リマインダー switch
//     7. Shows オイル交換リマインダー switch
//     8. Shows タイヤ交換リマインダー switch
//     9. Shows 車検リマインダー switch
//    10. Reminder switches disabled when push disabled (no appUser)
//   App info section:
//    11. Shows 'アプリ情報' section header
//    12. Shows バージョン '1.0.0'
//    13. Shows 利用規約 ListTile
//    14. Shows プライバシーポリシー ListTile
//   Save flow:
//    15. Tapping 保存 calls updateNotificationSettings
//    16. Success shows '設定を保存しました' snackbar
//    17. Failure shows '設定の保存に失敗しました' snackbar
//   Edge Cases:
//    18. Toggle a switch state changes locally
//    19. appUser null — default NotificationSettings applied

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;

import 'package:trust_car_platform/screens/profile/settings_screen.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/push_notification_service.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';

// ---------------------------------------------------------------------------
// Stub services
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

class _StubPushNotificationService implements PushNotificationService {
  @override
  Future<Result<bool, AppError>> requestPermission() async =>
      const Result.success(true);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Fake AuthProvider
// ---------------------------------------------------------------------------

class _FakeAuthProvider extends AuthProvider {
  final AppUser? _fakeAppUser;
  final bool _saveShouldSucceed;

  bool saveSettingsCalled = false;

  _FakeAuthProvider({
    AppUser? appUser,
    bool saveShouldSucceed = true,
  })  : _fakeAppUser = appUser,
        _saveShouldSucceed = saveShouldSucceed,
        super(authService: _StubAuthService());

  @override
  AppUser? get appUser => _fakeAppUser;

  @override
  bool get isLoading => false;

  @override
  Future<bool> updateNotificationSettings(NotificationSettings settings) async {
    saveSettingsCalled = true;
    return _saveShouldSucceed;
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

AppUser _makeAppUser({NotificationSettings? notificationSettings}) {
  return AppUser(
    id: 'user-1',
    email: 'test@example.com',
    displayName: 'テストユーザー',
    notificationSettings: notificationSettings ?? NotificationSettings(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

Widget _buildScreen({required _FakeAuthProvider provider}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: provider,
    child: const MaterialApp(home: SettingsScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    ServiceLocator.instance.override<PushNotificationService>(
      _StubPushNotificationService(),
    );
  });

  tearDown(() {
    ServiceLocator.instance.unregister<PushNotificationService>();
  });

  group('SettingsScreen — AppBar', () {
    testWidgets('1. shows 設定 title', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeAuthProvider()),
      );
      await tester.pump();

      expect(find.text('設定'), findsOneWidget);
    });

    testWidgets('2. shows 保存 TextButton in AppBar', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeAuthProvider()),
      );
      await tester.pump();

      expect(find.text('保存'), findsOneWidget);
    });
  });

  group('SettingsScreen — Notification section', () {
    testWidgets('4. shows 通知設定 section header', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeAuthProvider()),
      );
      await tester.pump();

      expect(find.text('通知設定'), findsOneWidget);
    });

    testWidgets('5. shows プッシュ通知 switch', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeAuthProvider()),
      );
      await tester.pump();

      expect(find.text('プッシュ通知'), findsOneWidget);
    });

    testWidgets('6. shows 点検リマインダー switch', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeAuthProvider()),
      );
      await tester.pump();

      expect(find.text('点検リマインダー'), findsOneWidget);
    });

    testWidgets('7. shows オイル交換リマインダー switch', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeAuthProvider()),
      );
      await tester.pump();

      expect(find.text('オイル交換リマインダー'), findsOneWidget);
    });

    testWidgets('8. shows タイヤ交換リマインダー switch', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeAuthProvider()),
      );
      await tester.pump();

      expect(find.text('タイヤ交換リマインダー'), findsOneWidget);
    });

    testWidgets('9. shows 車検リマインダー switch', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeAuthProvider()),
      );
      await tester.pump();

      expect(find.text('車検リマインダー'), findsOneWidget);
    });

    testWidgets('10. reminder switches disabled when pushEnabled=false',
        (tester) async {
      final provider = _FakeAuthProvider(
        appUser: _makeAppUser(
          notificationSettings: NotificationSettings(pushEnabled: false),
        ),
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pump();

      // When pushEnabled is false, reminder switches have null onChanged → disabled
      final switches = tester
          .widgetList<SwitchListTile>(
            find.byType(SwitchListTile),
          )
          .toList();

      // First switch is pushEnabled itself — it should be enabled
      expect(switches[0].onChanged, isNotNull);
      // Remaining reminder switches should be disabled
      for (final sw in switches.skip(1)) {
        expect(sw.onChanged, isNull,
            reason: '${sw.title} should be disabled when push is off');
      }
    });
  });

  group('SettingsScreen — App info section', () {
    testWidgets('11. shows アプリ情報 section header', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeAuthProvider()),
      );
      await tester.pump();

      expect(find.text('アプリ情報'), findsOneWidget);
    });

    testWidgets('12. shows バージョン 1.0.0', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeAuthProvider()),
      );
      await tester.pump();

      expect(find.text('バージョン'), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
    });

    testWidgets('13. shows 利用規約 ListTile', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeAuthProvider()),
      );
      await tester.pump();

      expect(find.text('利用規約'), findsOneWidget);
    });

    testWidgets('14. shows プライバシーポリシー ListTile', (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeAuthProvider()),
      );
      await tester.pump();

      expect(find.text('プライバシーポリシー'), findsOneWidget);
    });
  });

  group('SettingsScreen — Save flow', () {
    testWidgets('15. tapping 保存 calls updateNotificationSettings',
        (tester) async {
      final provider = _FakeAuthProvider(saveShouldSucceed: true);
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pump();

      await tester.tap(find.text('保存'));
      // The newsletter section keeps an indeterminate spinner alive when no
      // user is signed in, so pumpAndSettle would never settle. Bounded pumps
      // are enough for the save future and the snackbar animation.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(provider.saveSettingsCalled, isTrue);
    });

    testWidgets('16. success shows 設定を保存しました snackbar', (tester) async {
      final provider = _FakeAuthProvider(saveShouldSucceed: true);
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pump();

      await tester.tap(find.text('保存'));
      // The newsletter section keeps an indeterminate spinner alive when no
      // user is signed in, so pumpAndSettle would never settle. Bounded pumps
      // are enough for the save future and the snackbar animation.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('設定を保存しました'), findsOneWidget);
    });

    testWidgets('17. failure shows 設定の保存に失敗しました snackbar', (tester) async {
      final provider = _FakeAuthProvider(saveShouldSucceed: false);
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pump();

      await tester.tap(find.text('保存'));
      // The newsletter section keeps an indeterminate spinner alive when no
      // user is signed in, so pumpAndSettle would never settle. Bounded pumps
      // are enough for the save future and the snackbar animation.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('設定の保存に失敗しました'), findsOneWidget);
    });
  });

  group('SettingsScreen — Edge Cases', () {
    testWidgets('18. toggling a switch updates state locally', (tester) async {
      final provider = _FakeAuthProvider(
        appUser: _makeAppUser(
          notificationSettings: NotificationSettings(
            pushEnabled: true,
            oilChangeReminder: false,
          ),
        ),
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pump();

      // オイル交換リマインダー switch starts as off — toggle it on
      final oilSwitch = find.ancestor(
        of: find.text('オイル交換リマインダー'),
        matching: find.byType(SwitchListTile),
      );
      SwitchListTile sw = tester.widget(oilSwitch);
      expect(sw.value, isFalse);

      await tester.tap(oilSwitch);
      await tester.pump();

      sw = tester.widget(oilSwitch);
      expect(sw.value, isTrue);
    });

    testWidgets('19. no appUser → default NotificationSettings applied',
        (tester) async {
      final provider = _FakeAuthProvider(appUser: null);
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pump();

      // Default NotificationSettings has pushEnabled=true
      final pushSwitch = find.ancestor(
        of: find.text('プッシュ通知'),
        matching: find.byType(SwitchListTile),
      );
      final sw = tester.widget<SwitchListTile>(pushSwitch);
      expect(sw.value, isTrue);
    });
  });

  // =========================================================================
  group('SettingsScreen — Switch subtitles', () {
    testWidgets('20. プッシュ通知スイッチのサブタイトルが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(provider: _FakeAuthProvider()));
      await tester.pump();

      expect(find.text('お知らせを受け取る'), findsOneWidget);
    });

    testWidgets('21. 点検リマインダースイッチのサブタイトルが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(provider: _FakeAuthProvider()));
      await tester.pump();

      expect(find.text('定期点検の時期をお知らせ'), findsOneWidget);
    });

    testWidgets('22. 車検リマインダースイッチのサブタイトルが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(provider: _FakeAuthProvider()));
      await tester.pump();

      expect(find.text('車検の時期をお知らせ'), findsOneWidget);
    });
  });

  // =========================================================================
  group('SettingsScreen — Additional sections', () {
    testWidgets('23. 「メールニュースレター」セクションが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(provider: _FakeAuthProvider()));
      await tester.pump();

      expect(find.text('メールニュースレター'), findsOneWidget);
    });

    testWidgets('24. 「法人利用」セクションが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(provider: _FakeAuthProvider()));
      await tester.pump();

      expect(find.text('法人利用'), findsOneWidget);
    });

    testWidgets('25. 法人アカウント登録ListTileが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(provider: _FakeAuthProvider()));
      await tester.pump();

      expect(find.text('法人アカウント登録'), findsOneWidget);
    });
  });

  // =========================================================================
  group('SettingsScreen — Switches with pushEnabled=true', () {
    testWidgets('26. プッシュ通知ONのとき点検リマインダーが有効', (tester) async {
      final provider = _FakeAuthProvider(
        appUser: _makeAppUser(
          notificationSettings: NotificationSettings(pushEnabled: true),
        ),
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pump();

      final inspectionSwitch = find.ancestor(
        of: find.text('点検リマインダー'),
        matching: find.byType(SwitchListTile),
      );
      final sw = tester.widget<SwitchListTile>(inspectionSwitch);
      expect(sw.onChanged, isNotNull);
    });
  });
}
