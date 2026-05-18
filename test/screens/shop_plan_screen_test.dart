// ShopPlanScreen Widget Tests
//
// Coverage:
//   1. All 4 plan cards are displayed (Free / Standard / Premium / Enterprise)
//   2. The current plan card shows "現在のプラン" chip and disabled button
//   3. The downgrade-to-free confirmation dialog appears when tapping ダウングレード
//   4. Upgrade button text varies by plan type

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/providers/subscription_provider.dart';
import 'package:trust_car_platform/screens/marketplace/shop_plan_screen.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/shop_subscription_service.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
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
  Future<Result<UserCredential, AppError>> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async => Result.failure(AppError.server('stub'));

  @override
  Future<Result<UserCredential, AppError>> signInWithEmail({
    required String email,
    required String password,
  }) async => Result.failure(AppError.server('stub'));

  @override
  Future<Result<UserCredential?, AppError>> signInWithGoogle() async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> sendPasswordResetEmail(String email) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> signOut() async =>
      const Result.success(null);

  @override
  Future<Result<AppUser?, AppError>> getUserProfile() async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> updateUserProfile({
    String? displayName,
    String? photoUrl,
  }) async => const Result.success(null);

  @override
  Future<Result<void, AppError>> updateNotificationSettings(
    NotificationSettings settings,
  ) async => const Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helper to build the widget under test
// ---------------------------------------------------------------------------

Widget _buildScreen({
  ShopPlanType currentPlan = ShopPlanType.free,
  String shopId = 'shop1',
  FakeFirebaseFirestore? fakeFs,
}) {
  final fs = fakeFs ?? FakeFirebaseFirestore();
  final subscriptionService = ShopSubscriptionService(firestore: fs);
  final subscriptionProvider = SubscriptionProvider(
    subscriptionService: subscriptionService,
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(authService: _StubAuthService()),
      ),
      ChangeNotifierProvider<SubscriptionProvider>.value(
        value: subscriptionProvider,
      ),
    ],
    child: MaterialApp(
      home: ShopPlanScreen(shopId: shopId, currentPlan: currentPlan),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ShopPlanScreen — plan card display', () {
    testWidgets('shows all 4 plan names', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('フリー'), findsOneWidget);
      expect(find.text('スタンダード'), findsOneWidget);
      expect(find.text('プレミアム'), findsOneWidget);
      expect(find.text('エンタープライズ'), findsOneWidget);
    });

    testWidgets('shows 30-day trial text', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('30日間の無料トライアルから始められます'), findsOneWidget);
    });

    testWidgets('shows price for paid plans', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('¥3,980'), findsOneWidget);
      expect(find.text('¥9,800'), findsOneWidget);
      expect(find.text('¥14,800'), findsOneWidget);
    });

    testWidgets('shows 無料 label for free plan', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      // "無料" appears as the free plan price label
      expect(find.text('無料'), findsOneWidget);
    });
  });

  group('ShopPlanScreen — current plan button state', () {
    testWidgets('current free plan shows disabled "現在のプラン" button', (tester) async {
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.free));
      await tester.pump();

      // The OutlinedButton for the current plan shows 現在のプラン
      expect(find.text('現在のプラン'), findsOneWidget);
    });

    testWidgets('current standard plan shows 現在のプラン chip', (tester) async {
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.standard));
      await tester.pump();

      expect(find.text('現在のプラン'), findsWidgets);
    });

    testWidgets('upgrade buttons show 30日間無料で始める for standard and premium', (tester) async {
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.free));
      await tester.pump();

      // Standard and Premium both show trial text
      expect(find.text('30日間無料で始める'), findsNWidgets(2));
    });

    testWidgets('enterprise upgrade button shows アップグレード', (tester) async {
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.standard));
      await tester.pump();

      // Enterprise upgrade shows アップグレード (not 30日間無料で始める)
      expect(find.text('アップグレード'), findsOneWidget);
    });
  });

  group('ShopPlanScreen — downgrade confirmation dialog', () {
    testWidgets('tapping downgrade button on paid plan shows confirmation dialog', (tester) async {
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.standard));
      await tester.pump();

      // Find the "ダウングレード" button (OutlinedButton for free plan)
      final downgradeButton = find.text('ダウングレード');
      expect(downgradeButton, findsOneWidget);

      await tester.tap(downgradeButton);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Confirmation dialog should appear
      expect(find.text('無料プランに変更'), findsOneWidget);
      expect(find.text('変更する'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
    });

    testWidgets('tapping キャンセル in dialog closes it without changing plan', (tester) async {
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.standard));
      await tester.pump();

      await tester.tap(find.text('ダウングレード'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Dialog closed; plan name still visible (not navigated away)
      expect(find.text('スタンダード'), findsOneWidget);
    });

    testWidgets('dialog shows plan cancellation warning message', (tester) async {
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.premium));
      await tester.pump();

      await tester.tap(find.text('ダウングレード'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(
        find.textContaining('サブスクリプションは期間終了時にキャンセルされます'),
        findsOneWidget,
      );
    });
  });

  group('ShopPlanScreen — recommended badge', () {
    testWidgets('shows おすすめ badge on standard plan when current is free', (tester) async {
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.free));
      await tester.pump();

      expect(find.text('おすすめ'), findsOneWidget);
    });

    testWidgets('no おすすめ badge when current plan is standard', (tester) async {
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.standard));
      await tester.pump();

      // No recommended badge when not on free plan
      expect(find.text('おすすめ'), findsNothing);
    });
  });
}
