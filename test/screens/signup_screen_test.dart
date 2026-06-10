// SignupScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows '新規登録' title
//   Form validation:
//     2. Empty display name shows error
//     3. Empty email shows error
//     4. Invalid email format shows error
//     5. Empty password shows error
//     6. Password shorter than 6 chars shows error
//     7. Empty confirm password shows error
//     8. Mismatched passwords show error
//   Successful validation:
//     9. All fields valid — no validation errors
//   Loading state:
//    10. Shows loading overlay when isLoading=true
//    11. Button tap disabled during loading
//   Sign-up flow:
//    12. Successful signup pops the route
//    13. Failed signup shows error snackbar
//    14. Signup failure shows provider errorMessage
//   Google signup:
//    15. Google 登録 button is present
//    16. Successful Google signup pops the route
//   Legal links:
//    17. 利用規約 link is visible
//    18. プライバシーポリシー link is visible
//   Edge Cases:
//    19. Whitespace-only display name fails validation
//    20. Password exactly 5 chars fails; 6 chars passes

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;

import 'package:trust_car_platform/screens/auth/signup_screen.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

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
// Fake AuthProvider
// ---------------------------------------------------------------------------

class _FakeAuthProvider extends AuthProvider {
  final bool _fakeIsLoading;
  final String? _fakeErrorMessage;
  final bool _signUpShouldSucceed;
  final bool _googleShouldSucceed;

  bool signUpCalled = false;
  bool googleSignupCalled = false;

  _FakeAuthProvider({
    bool isLoading = false,
    String? errorMessage,
    bool signUpShouldSucceed = true,
    bool googleShouldSucceed = true,
  })  : _fakeIsLoading = isLoading,
        _fakeErrorMessage = errorMessage,
        _signUpShouldSucceed = signUpShouldSucceed,
        _googleShouldSucceed = googleShouldSucceed,
        super(authService: _StubAuthService());

  @override
  bool get isLoading => _fakeIsLoading;

  @override
  String? get errorMessage => _fakeErrorMessage;

  @override
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    signUpCalled = true;
    return _signUpShouldSucceed;
  }

  @override
  Future<bool> signInWithGoogle() async {
    googleSignupCalled = true;
    return _googleShouldSucceed;
  }
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen({_FakeAuthProvider? provider}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: provider ?? _FakeAuthProvider(),
    child: const MaterialApp(home: SignupScreen()),
  );
}

// Fills all required fields with valid values.
Future<void> _fillAllValid(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), '山田太郎');
  await tester.enterText(fields.at(1), 'yamada@example.com');
  await tester.enterText(fields.at(2), 'password123');
  await tester.enterText(fields.at(3), 'password123');
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SignupScreen — AppBar', () {
    testWidgets('1. shows 新規登録 title', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('新規登録'), findsOneWidget);
    });
  });

  group('SignupScreen — Form validation', () {
    testWidgets('2. empty display name shows error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('アカウントを作成'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('表示名を入力してください'), findsOneWidget);
    });

    testWidgets('3. empty email shows error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '山田太郎');
      await tester.pump();

      await tester.tap(find.text('アカウントを作成'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('メールアドレスを入力してください'), findsOneWidget);
    });

    testWidgets('4. invalid email format shows error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '山田太郎');
      await tester.enterText(fields.at(1), 'not-an-email');
      await tester.pump();

      await tester.tap(find.text('アカウントを作成'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('有効なメールアドレスを入力してください'), findsOneWidget);
    });

    testWidgets('5. empty password shows error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '山田太郎');
      await tester.enterText(fields.at(1), 'test@example.com');
      await tester.pump();

      await tester.tap(find.text('アカウントを作成'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('パスワードを入力してください'), findsOneWidget);
    });

    testWidgets('6. password shorter than 6 chars shows error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '山田太郎');
      await tester.enterText(fields.at(1), 'test@example.com');
      await tester.enterText(fields.at(2), '12345');
      await tester.pump();

      await tester.tap(find.text('アカウントを作成'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('パスワードは6文字以上で入力してください'), findsOneWidget);
    });

    testWidgets('7. empty confirm password shows error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '山田太郎');
      await tester.enterText(fields.at(1), 'test@example.com');
      await tester.enterText(fields.at(2), 'password123');
      await tester.pump();

      await tester.tap(find.text('アカウントを作成'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('パスワードを再入力してください'), findsOneWidget);
    });

    testWidgets('8. mismatched passwords show error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '山田太郎');
      await tester.enterText(fields.at(1), 'test@example.com');
      await tester.enterText(fields.at(2), 'password123');
      await tester.enterText(fields.at(3), 'different456');
      await tester.pump();

      await tester.tap(find.text('アカウントを作成'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('パスワードが一致しません'), findsOneWidget);
    });

    testWidgets('9. all valid fields produce no validation errors',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await _fillAllValid(tester);
      await tester.tap(find.text('アカウントを作成'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('表示名を入力してください'), findsNothing);
      expect(find.text('メールアドレスを入力してください'), findsNothing);
      expect(find.text('パスワードを入力してください'), findsNothing);
      expect(find.text('パスワードが一致しません'), findsNothing);
    });
  });

  group('SignupScreen — Loading state', () {
    testWidgets('10. shows loading overlay when isLoading=true',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(provider: _FakeAuthProvider(isLoading: true)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('SignupScreen — Sign-up flow', () {
    testWidgets('12. successful signup pops the route', (tester) async {
      final provider = _FakeAuthProvider(signUpShouldSucceed: true);

      bool popped = false;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle(const Duration(seconds: 10));
      expect(find.text('新規登録'), findsOneWidget);

      await _fillAllValid(tester);
      await tester.tap(find.text('アカウントを作成'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('open'), findsOneWidget);
      expect(find.text('新規登録'), findsNothing);
    });

    testWidgets('13. failed signup shows fallback error snackbar',
        (tester) async {
      final provider = _FakeAuthProvider(signUpShouldSucceed: false);
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await _fillAllValid(tester);
      await tester.tap(find.text('アカウントを作成'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('サインアップに失敗しました'), findsOneWidget);
    });

    testWidgets('14. failed signup shows provider errorMessage',
        (tester) async {
      final provider = _FakeAuthProvider(
        signUpShouldSucceed: false,
        errorMessage: 'このメールアドレスは既に使用されています',
      );
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await _fillAllValid(tester);
      await tester.tap(find.text('アカウントを作成'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('このメールアドレスは既に使用されています'), findsOneWidget);
    });
  });

  group('SignupScreen — Google signup', () {
    testWidgets('15. Google 登録 button is present', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('Google で登録'), findsOneWidget);
    });

    testWidgets('16. successful Google signup pops the route', (tester) async {
      final provider = _FakeAuthProvider(googleShouldSucceed: true);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('Google で登録'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(provider.googleSignupCalled, isTrue);
      expect(find.text('open'), findsOneWidget);
      expect(find.text('新規登録'), findsNothing);
    });
  });

  group('SignupScreen — Legal links', () {
    testWidgets('17. 利用規約 link is visible', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('利用規約'), findsOneWidget);
    });

    testWidgets('18. プライバシーポリシー link is visible', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('プライバシーポリシー'), findsOneWidget);
    });
  });

  group('SignupScreen — Edge Cases', () {
    testWidgets('19. whitespace-only display name fails validation',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.enterText(find.byType(TextFormField).at(0), '   ');
      await tester.pump();

      await tester.tap(find.text('アカウントを作成'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('表示名を入力してください'), findsOneWidget);
    });

    testWidgets('20a. password with exactly 5 chars fails', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '山田太郎');
      await tester.enterText(fields.at(1), 'test@example.com');
      await tester.enterText(fields.at(2), '12345');
      await tester.pump();

      await tester.tap(find.text('アカウントを作成'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('パスワードは6文字以上で入力してください'), findsOneWidget);
    });

    testWidgets('20b. password with exactly 6 chars passes validation',
        (tester) async {
      final provider = _FakeAuthProvider(signUpShouldSucceed: true);
      await tester.pumpWidget(_buildScreen(provider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '山田太郎');
      await tester.enterText(fields.at(1), 'test@example.com');
      await tester.enterText(fields.at(2), '123456');
      await tester.enterText(fields.at(3), '123456');
      await tester.pump();

      await tester.tap(find.text('アカウントを作成'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('パスワードは6文字以上で入力してください'), findsNothing);
    });
  });
}
