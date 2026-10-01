// ShopPlanScreen Widget Tests
//
// 2026-09-29: 店舗プランは当面、請求書払い（銀行振込）。既定の画面は
// アプリ内課金ではなく「請求書払いで申し込む」流れ（shops/{id}/plan_requests）。
// アプリ内課金（RevenueCat）は FeatureFlag.shopInAppPurchase を開けたときだけ。
//
// Coverage:
//   1. All 4 plan cards are displayed (Free / Standard / Premium / Enterprise)
//   2. The current plan card shows "現在のプラン" chip and disabled button
//   3. 請求書払いの申し込み（フォーム・受付の表示・Firestore への記録）
//   4. エンタープライズは見積もりの相談として受ける
//   5. 無料トライアル・App Store の表記が無い
//   6. フラグを開けたときは、これまでのアプリ内課金の画面に戻る

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/core/config/app_config.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/providers/shop_plan_request_provider.dart';
import 'package:trust_car_platform/providers/subscription_provider.dart';
import 'package:trust_car_platform/screens/marketplace/shop_plan_screen.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/shop_plan_request_service.dart';
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
  Future<Result<AppUser?, AppError>> getUserProfile() async =>
      const Result.success(null);

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

// ---------------------------------------------------------------------------
// Logged-in auth stub（申し込みには店主の uid が要る）
// ---------------------------------------------------------------------------

class _FakeUser implements User {
  @override
  String get uid => 'owner1';
  @override
  String? get email => 'owner@example.com';
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
// Helper to build the widget under test
// ---------------------------------------------------------------------------

Widget _buildScreen({
  ShopPlanType currentPlan = ShopPlanType.free,
  String shopId = 'shop1',
  String? shopName,
  FakeFirebaseFirestore? fakeFs,
  bool loggedIn = true,
}) {
  final fs = fakeFs ?? FakeFirebaseFirestore();
  final subscriptionService = ShopSubscriptionService(firestore: fs);
  final subscriptionProvider = SubscriptionProvider(
    subscriptionService: subscriptionService,
  );
  final requestProvider = ShopPlanRequestProvider(
    service: ShopPlanRequestService(firestore: fs),
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => loggedIn
            ? _LoggedInAuthProvider()
            : AuthProvider(authService: _StubAuthService()),
      ),
      ChangeNotifierProvider<SubscriptionProvider>.value(
        value: subscriptionProvider,
      ),
      ChangeNotifierProvider<ShopPlanRequestProvider>.value(
        value: requestProvider,
      ),
    ],
    child: MaterialApp(
      home: ShopPlanScreen(
        shopId: shopId,
        currentPlan: currentPlan,
        shopName: shopName,
      ),
    ),
  );
}

/// 背の高い画面にして、4枚のカードと注意書きをすべて描かせる。
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _openRequestSheet(WidgetTester tester, String buttonText,
    {int index = 0}) async {
  final button = find.text(buttonText).at(index);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<int> _requestCount(FakeFirebaseFirestore fs) async =>
    (await fs.collection('shops/shop1/plan_requests').get()).docs.length;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ShopPlanScreen — plan card display', () {
    testWidgets('shows all 4 plan names', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('フリー'), findsOneWidget);
      expect(find.text('スタンダード'), findsOneWidget);
      expect(find.text('プレミアム'), findsOneWidget);
      expect(find.text('エンタープライズ'), findsOneWidget);
    });

    testWidgets('shows price for paid plans', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('¥9,800'), findsOneWidget);
      expect(find.text('¥29,800'), findsOneWidget);
      // 掲載管理の画面・特商法と食い違っていた旧価格が残っていない
      expect(find.text('¥3,980'), findsNothing);
      expect(find.text('¥14,800'), findsNothing);
    });

    testWidgets('エンタープライズは個別見積もりと表示する', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('個別見積もり'), findsOneWidget);
    });

    testWidgets('shows 無料 label for free plan', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      // "無料" appears as the free plan price label
      expect(find.text('無料'), findsOneWidget);
    });
  });

  group('ShopPlanScreen — 請求書払いの表記', () {
    testWidgets('支払いは請求書払い（銀行振込）と書く', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('お支払いは請求書払い（銀行振込）です'), findsOneWidget);
      expect(find.textContaining('請求書による銀行振込'), findsOneWidget);
    });

    // 2026-10-01 オーナー判断: 初回の申し込みは30日間無料（規約 第11条・特商法と同じ文言）
    testWidgets('初回の申し込みは30日間無料と出す', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text(ShopPlanScreen.trialNotice), findsOneWidget);
      expect(ShopPlanScreen.trialNotice, contains('30日間'));
    });

    testWidgets('アプリ内課金の表記は出さない', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      // 特商法・利用規約（請求書払い）と矛盾する表記
      expect(find.textContaining('App Store'), findsNothing);
      expect(find.text('購入を復元'), findsNothing);
    });
  });

  group('ShopPlanScreen — current plan button state', () {
    testWidgets('current free plan shows disabled "現在のプラン" button',
        (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.free));
      await tester.pump();

      // The chip and the OutlinedButton for the current plan both show 現在のプラン
      expect(find.text('現在のプラン'), findsWidgets);
    });

    testWidgets('current standard plan shows 現在のプラン chip', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.standard));
      await tester.pump();

      expect(find.text('現在のプラン'), findsWidgets);
    });

    testWidgets('スタンダード・プレミアムは「請求書払いで申し込む」', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.free));
      await tester.pump();

      expect(find.text('請求書払いで申し込む'), findsNWidgets(2));
    });

    testWidgets('エンタープライズは「見積もりを相談する」', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.standard));
      await tester.pump();

      expect(find.text('見積もりを相談する'), findsOneWidget);
      expect(find.text('アップグレード'), findsNothing);
    });
  });

  group('ShopPlanScreen — 請求書払いの申し込み', () {
    testWidgets('有料プランを選ぶと申し込みのフォームが開く', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen(shopName: 'タカヤモーター'));
      await tester.pump();

      await _openRequestSheet(tester, '請求書払いで申し込む');

      expect(find.text('スタンダードを請求書払いで申し込む'), findsOneWidget);
      expect(find.textContaining('月額 ¥9,800（税込）'), findsOneWidget);
      // 宛名は店名、連絡先はログイン中のメールアドレスを最初から入れておく
      expect(find.text('タカヤモーター'), findsOneWidget);
      expect(find.text('owner@example.com'), findsOneWidget);
    });

    testWidgets('申し込むと Firestore に pending で記録し、受付を知らせる', (tester) async {
      _useTallSurface(tester);
      final fs = FakeFirebaseFirestore();
      await fs.collection('shops').doc('shop1').set({
        'name': 'タカヤモーター',
        'planType': 'free',
        'subscriptionStatus': 'free',
      });
      await tester.pumpWidget(_buildScreen(fakeFs: fs));
      await tester.pump();

      // プレミアム（2つ目の「請求書払いで申し込む」）
      await _openRequestSheet(tester, '請求書払いで申し込む', index: 1);
      await tester.enterText(
          find.byKey(const Key('plan_request_billing_name')), '株式会社タカヤ');
      await tester.enterText(
          find.byKey(const Key('plan_request_note')), '10月から');
      await tester.tap(find.byKey(const Key('plan_request_submit')));
      await tester.pumpAndSettle();

      expect(find.text('申し込みを受け付けました'), findsOneWidget);
      expect(find.textContaining('担当から請求書をお送りします'), findsWidgets);

      final docs = await fs.collection('shops/shop1/plan_requests').get();
      expect(docs.docs, hasLength(1));
      final d = docs.docs.single.data();
      expect(d['plan'], 'premium');
      expect(d['currentPlan'], 'free');
      expect(d['requesterUid'], 'owner1');
      expect(d['contactEmail'], 'owner@example.com');
      expect(d['billingName'], '株式会社タカヤ');
      expect(d['note'], '10月から');
      expect(d['status'], 'pending');

      // プランそのものはアプリから変えない（運営者が入金確認後に切り替える）
      final shop = await fs.collection('shops').doc('shop1').get();
      expect(shop.data()!['planType'], 'free');
      expect(shop.data()!['subscriptionStatus'], 'free');

      // ダイアログを閉じると、受付中の表示が残る
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan_request_pending')), findsOneWidget);
      expect(find.text('プレミアムの申し込みを受け付けています'), findsOneWidget);
    });

    testWidgets('エンタープライズは見積もりの相談として受ける', (tester) async {
      _useTallSurface(tester);
      final fs = FakeFirebaseFirestore();
      await tester.pumpWidget(_buildScreen(fakeFs: fs, shopName: '店'));
      await tester.pump();

      await _openRequestSheet(tester, '見積もりを相談する');
      expect(find.text('エンタープライズの見積もりを相談する'), findsOneWidget);
      expect(find.textContaining('個別にお見積もり'), findsWidgets);

      await tester.tap(find.byKey(const Key('plan_request_submit')));
      await tester.pumpAndSettle();

      expect(find.text('ご相談を受け付けました'), findsOneWidget);
      final d = (await fs.collection('shops/shop1/plan_requests').get())
          .docs
          .single
          .data();
      expect(d['plan'], 'enterprise');
    });

    testWidgets('すでに受付中の申し込みがあれば、開いたときに表示する', (tester) async {
      _useTallSurface(tester);
      final fs = FakeFirebaseFirestore();
      await ShopPlanRequestService(firestore: fs).submit(
        shopId: 'shop1',
        requesterUid: 'owner1',
        plan: ShopPlanType.standard,
        currentPlan: ShopPlanType.free,
        contactEmail: 'owner@example.com',
        billingName: '店',
      );
      await tester.pumpWidget(_buildScreen(fakeFs: fs));
      await tester.pumpAndSettle();

      expect(find.text('スタンダードの申し込みを受け付けています'), findsOneWidget);
    });

    group('Edge Cases', () {
      testWidgets('宛名が空なら送らない', (tester) async {
        _useTallSurface(tester);
        final fs = FakeFirebaseFirestore();
        await tester.pumpWidget(_buildScreen(fakeFs: fs));
        await tester.pump();

        await _openRequestSheet(tester, '請求書払いで申し込む');
        await tester.tap(find.byKey(const Key('plan_request_submit')));
        await tester.pumpAndSettle();

        expect(find.text('請求書の宛名を入力してください'), findsOneWidget);
        expect(await _requestCount(fs), 0);
      });

      testWidgets('メールアドレスの形が違えば送らない', (tester) async {
        _useTallSurface(tester);
        final fs = FakeFirebaseFirestore();
        await tester.pumpWidget(_buildScreen(fakeFs: fs, shopName: '店'));
        await tester.pump();

        await _openRequestSheet(tester, '請求書払いで申し込む');
        await tester.enterText(
            find.byKey(const Key('plan_request_email')), 'owner');
        await tester.tap(find.byKey(const Key('plan_request_submit')));
        await tester.pumpAndSettle();

        expect(find.text('メールアドレスを確認してください'), findsOneWidget);
        expect(await _requestCount(fs), 0);
      });

      testWidgets('ログインしていなければ送らない', (tester) async {
        _useTallSurface(tester);
        final fs = FakeFirebaseFirestore();
        await tester.pumpWidget(
            _buildScreen(fakeFs: fs, shopName: '店', loggedIn: false));
        await tester.pump();

        await _openRequestSheet(tester, '請求書払いで申し込む');
        await tester.enterText(
            find.byKey(const Key('plan_request_email')), 'a@example.com');
        await tester.tap(find.byKey(const Key('plan_request_submit')));
        await tester.pumpAndSettle();

        expect(find.text('ログインしてください'), findsOneWidget);
        expect(await _requestCount(fs), 0);
      });
    });
  });

  group('ShopPlanScreen — ダウングレード', () {
    testWidgets('ダウングレードも申し込みとして受け、プランはその場で変えない', (tester) async {
      _useTallSurface(tester);
      final fs = FakeFirebaseFirestore();
      await fs.collection('shops').doc('shop1').set({
        'planType': 'standard',
        'subscriptionStatus': 'active',
      });
      await tester.pumpWidget(_buildScreen(
        currentPlan: ShopPlanType.standard,
        fakeFs: fs,
        shopName: '店',
      ));
      await tester.pump();

      expect(find.text('ダウングレード'), findsOneWidget);
      await _openRequestSheet(tester, 'ダウングレード');

      expect(find.text('フリーへの変更を申し込む'), findsOneWidget);
      // 利用規約 第11条6: 満了日までは今のプランを使える
      expect(find.textContaining('契約期間の満了日まで'), findsOneWidget);

      await tester.tap(find.byKey(const Key('plan_request_submit')));
      await tester.pumpAndSettle();

      expect(find.text('申し込みを受け付けました'), findsOneWidget);
      final d = (await fs.collection('shops/shop1/plan_requests').get())
          .docs
          .single
          .data();
      expect(d['plan'], 'free');
      expect(d['currentPlan'], 'standard');
      final shop = await fs.collection('shops').doc('shop1').get();
      expect(shop.data()!['planType'], 'standard');
      expect(shop.data()!['subscriptionStatus'], 'active');
    });

    testWidgets('フォームを閉じれば何も送らない', (tester) async {
      _useTallSurface(tester);
      final fs = FakeFirebaseFirestore();
      await tester.pumpWidget(_buildScreen(
        currentPlan: ShopPlanType.premium,
        fakeFs: fs,
      ));
      await tester.pump();

      // プレミアムからは Free / Standard の2つにダウングレードできる。先頭（フリー）
      await _openRequestSheet(tester, 'ダウングレード');
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(find.text('フリーへの変更を申し込む'), findsNothing);
      expect(find.text('スタンダード'), findsOneWidget);
      expect(await _requestCount(fs), 0);
    });
  });

  group('ShopPlanScreen — recommended badge', () {
    testWidgets('shows おすすめ badge on standard plan when current is free',
        (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.free));
      await tester.pump();

      expect(find.text('おすすめ'), findsOneWidget);
    });

    testWidgets('no おすすめ badge when current plan is standard', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.standard));
      await tester.pump();

      // No recommended badge when not on free plan
      expect(find.text('おすすめ'), findsNothing);
    });
  });

  group('ShopPlanScreen — アプリ内課金（フラグを開けたとき）', () {
    setUp(() {
      AppConfig.instance.setFeatureFlag(FeatureFlag.shopInAppPurchase, true);
    });
    tearDown(() {
      AppConfig.instance.setFeatureFlag(FeatureFlag.shopInAppPurchase, false);
    });

    testWidgets('これまでの購入ボタン・購入の復元に戻る', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('購入を復元'), findsOneWidget);
      expect(find.textContaining('App Store / Google Play'), findsOneWidget);
      expect(find.text('アップグレード'), findsNWidgets(3));
      expect(find.text('請求書払いで申し込む'), findsNothing);
      // アプリ内課金でも無料トライアルは約束しない
      expect(find.textContaining('無料トライアル'), findsNothing);
    });

    testWidgets('ダウングレードはこれまでの確認ダイアログ', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_buildScreen(currentPlan: ShopPlanType.standard));
      await tester.pump();

      await tester.tap(find.text('ダウングレード'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('無料プランに変更'), findsOneWidget);
      expect(find.text('変更する'), findsOneWidget);
    });
  });
}
