import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_car_platform/screens/auth/onboarding_screen.dart';
import 'package:trust_car_platform/screens/auth/login_screen.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:provider/provider.dart';

// Minimal AuthService stub so LoginScreen can render without Firebase.
// Stream.value(null) makes AuthProvider set isLoading=false immediately.
class _StubAuthService implements AuthService {
  @override
  Stream<User?> get authStateChanges => Stream.value(null);
  @override
  User? get currentUser => null;
  bool get isAuthenticated => false;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

Widget _buildOnboardingApp() {
  return ChangeNotifierProvider<AuthProvider>(
    create: (_) => AuthProvider(authService: _StubAuthService()),
    child: const MaterialApp(home: OnboardingScreen()),
  );
}

void main() {
  setUp(() {
    // Reset SharedPreferences before each test
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingScreen', () {
    testWidgets('4つのページインジケーターが表示される', (tester) async {
      await tester.pumpWidget(_buildOnboardingApp());
      await tester.pump();

      // 4 dot indicators
      expect(find.byKey(const Key('onboarding_dot_0')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_dot_1')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_dot_2')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_dot_3')), findsOneWidget);
    });

    testWidgets('最初のページにブランドビジョンが表示される', (tester) async {
      await tester.pumpWidget(_buildOnboardingApp());
      await tester.pump();

      expect(find.textContaining('クルマのことを'), findsOneWidget);
    });

    testWidgets('スキップボタンが全ページに表示される', (tester) async {
      await tester.pumpWidget(_buildOnboardingApp());
      await tester.pump();

      expect(find.text('スキップ'), findsOneWidget);
    });

    testWidgets('1ページ目には「はじめる」ボタンがない', (tester) async {
      await tester.pumpWidget(_buildOnboardingApp());
      await tester.pump();

      expect(find.text('はじめる'), findsNothing);
    });

    testWidgets('スワイプで2ページ目に移動できる', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildOnboardingApp());
      await tester.pump();

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.textContaining('整備履歴を'), findsOneWidget);
    });

    testWidgets('4ページ目に「はじめる」ボタンが表示される', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildOnboardingApp());
      await tester.pump();

      // Swipe to page 4
      for (int i = 0; i < 3; i++) {
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
      }

      expect(find.text('はじめる'), findsOneWidget);
      expect(find.textContaining('信頼できる整備工場'), findsOneWidget);
    });

    testWidgets('スキップをタップするとLoginScreenに遷移する', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildOnboardingApp());
      await tester.pump();

      await tester.tap(find.text('スキップ'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('スキップするとonboarding_completedフラグが保存される', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildOnboardingApp());
      await tester.pump();

      await tester.tap(find.text('スキップ'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), isTrue);
    });

    testWidgets('「はじめる」をタップするとLoginScreenに遷移する', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildOnboardingApp());
      await tester.pump();

      // Navigate to last page
      for (int i = 0; i < 3; i++) {
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('はじめる'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('「はじめる」後にonboarding_completedフラグが保存される', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildOnboardingApp());
      await tester.pump();

      for (int i = 0; i < 3; i++) {
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('はじめる'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), isTrue);
    });

    // AuthWrapper（main.dart）は OnboardingScreen を home として直接埋め込む。
    // pushReplacement で home ルートを破棄すると認証監視が失われるため、
    // onCompleted コールバック方式で AuthWrapper 側が画面を切り替える。
    testWidgets('onCompleted が渡されたらスキップ時にコールバックが呼ばれ画面遷移しない', (tester) async {
      var completed = false;
      await tester.pumpWidget(MaterialApp(
        home: OnboardingScreen(onCompleted: () => completed = true),
      ));
      await tester.pump();

      await tester.tap(find.text('スキップ'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      // No navigation happened — OnboardingScreen is still in the tree.
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      // Flag is still persisted.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), isTrue);
    });

    testWidgets('onCompleted が渡されたら「はじめる」でもコールバックが呼ばれる', (tester) async {
      var completed = false;
      await tester.pumpWidget(MaterialApp(
        home: OnboardingScreen(onCompleted: () => completed = true),
      ));
      await tester.pump();

      for (int i = 0; i < 3; i++) {
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('はじめる'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });
  });
}
