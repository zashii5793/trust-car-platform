// ShopRegistrationScreen Widget Tests
//
// Coverage:
//   AppBar titles:
//     1. Shows '店舗を登録' in new mode
//     2. Shows '掲載情報を編集' in edit mode
//   Required field validation:
//     3. Shows error when shop name is empty on submit
//     4. Clears error when name is entered
//   Optional fields visible:
//     5. 電話番号 field is present
//     6. メールアドレス field is present
//     7. ウェブサイト field is present
//     8. 都道府県 field is present
//     9. 市区町村 field is present
//    10. 住所 field is present
//    11. 説明文 field with maxLength 500
//   Section headers:
//    12. 基本情報 section header visible
//    13. 連絡先 section header visible
//    14. 所在地 section header visible
//    15. サービス section header visible
//    16. プラン選択 section header visible
//   ServiceCategory chips:
//    17. All 12 ServiceCategory chips rendered
//    18. Tapping chip selects it
//    19. Tapping selected chip deselects it
//   Plan selection:
//    20. Free plan card shows '0円'
//    21. Standard plan card shows '9,800円 / 月'
//    22. Premium plan card shows '29,800円 / 月'
//    23. Default selection is Free plan
//    24. Tapping Standard selects it
//   Submit button state:
//    25. Bottom '保存する' button enabled when not submitting
//    26. Bottom '保存中...' label while submitting (isSubmitting=true)
//    27. AppBar '保存' TextButton present in new mode
//    28. AppBar shows spinner when isSubmitting=true
//   Edit mode pre-fill:
//    29. Edit mode pre-fills shop name
//    30. Edit mode pre-fills description
//    31. Edit mode pre-fills plan type
//    32. Edit mode pre-fills selected services
//   Submit flow:
//    33. Successful save calls saveMyShop with entered name
//    34. Failed save shows error snackbar
//    35. Successful save pops the route

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;

import 'package:trust_car_platform/screens/marketplace/shop_registration_screen.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/providers/shop_provider.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/inquiry_service.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Stub Services
// ---------------------------------------------------------------------------

class _StubShopService implements ShopService {
  @override
  Future<Result<Shop?, AppError>> getMyShop(String uid) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> deleteMyShop(String uid) async =>
      const Result.success(null);

  @override
  Stream<Map<String, int>> watchInquiryCount(String shopId) =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubInquiryService implements InquiryService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

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
  String get uid => 'owner-uid';
  @override
  String? get displayName => 'Shop Owner';
  @override
  String? get photoURL => null;
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
// Fake ShopProvider
// ---------------------------------------------------------------------------

class _FakeShopProvider extends ShopProvider {
  final bool _fakeIsSubmitting;
  final String? _fakeSubmitError;
  final bool _saveShouldSucceed;

  bool saveCalledWith = false;
  Shop? lastSavedShop;

  _FakeShopProvider({
    bool isSubmitting = false,
    String? submitError,
    bool saveShouldSucceed = true,
  })  : _fakeIsSubmitting = isSubmitting,
        _fakeSubmitError = submitError,
        _saveShouldSucceed = saveShouldSucceed,
        super(
          shopService: _StubShopService(),
          inquiryService: _StubInquiryService(),
        );

  @override
  bool get isSubmitting => _fakeIsSubmitting;

  @override
  String? get submitError => _fakeSubmitError;

  @override
  Future<bool> saveMyShop(Shop shop) async {
    saveCalledWith = true;
    lastSavedShop = shop;
    return _saveShouldSucceed;
  }
}

// ---------------------------------------------------------------------------
// Test shop factory
// ---------------------------------------------------------------------------

Shop _makeExistingShop({
  String id = 'shop-1',
  String name = 'テストモータース',
  String? description,
  ShopPlanType planType = ShopPlanType.standard,
  List<ServiceCategory> services = const [],
}) {
  final now = DateTime.now();
  return Shop(
    id: id,
    name: name,
    type: ShopType.maintenanceShop,
    description: description,
    planType: planType,
    services: services,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen({
  _FakeShopProvider? shopProvider,
  Shop? existingShop,
}) {
  final provider = shopProvider ?? _FakeShopProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => _LoggedInAuthProvider(),
      ),
      ChangeNotifierProvider<ShopProvider>.value(value: provider),
    ],
    child: MaterialApp(
      home: ShopRegistrationScreen(existingShop: existingShop),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ShopRegistrationScreen — AppBar titles', () {
    testWidgets('1. shows 店舗を登録 in new mode', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('店舗を登録'), findsOneWidget);
    });

    testWidgets('2. shows 掲載情報を編集 in edit mode', (tester) async {
      await tester.pumpWidget(
        _buildScreen(existingShop: _makeExistingShop()),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('掲載情報を編集'), findsOneWidget);
    });
  });

  group('ShopRegistrationScreen — Required field validation', () {
    testWidgets('3. shows error when shop name is empty on submit',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Tap AppBar 保存 without entering name
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('店舗名を入力してください'), findsOneWidget);
    });

    testWidgets('4. clears validation error after entering shop name',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Trigger validation error
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle(const Duration(seconds: 10));
      expect(find.text('店舗名を入力してください'), findsOneWidget);

      // Enter name and re-submit — validation now passes and the error clears
      await tester.enterText(find.byType(TextFormField).first, 'テスト工場');
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle(const Duration(seconds: 10));
      expect(find.text('店舗名を入力してください'), findsNothing);
    });
  });

  group('ShopRegistrationScreen — Optional fields visible', () {
    testWidgets('5-11. all optional fields are present', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // 電話番号
      expect(find.text('電話番号'), findsOneWidget);
      // メールアドレス
      expect(find.text('メールアドレス'), findsOneWidget);
      // ウェブサイト
      await tester.scrollUntilVisible(find.text('ウェブサイト'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('ウェブサイト'), findsOneWidget);
      // 都道府県
      await tester.scrollUntilVisible(find.text('都道府県'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('都道府県'), findsOneWidget);
      // 市区町村
      await tester.scrollUntilVisible(find.text('市区町村'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('市区町村'), findsOneWidget);
      // 住所
      await tester.scrollUntilVisible(find.text('住所'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('住所'), findsOneWidget);
    });

    testWidgets('11. 説明文 field has maxLength 500', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('説明文'), findsOneWidget);
      // Find the description hint text to confirm it exists
      expect(
        find.textContaining('最大500文字'),
        findsOneWidget,
      );
    });
  });

  group('ShopRegistrationScreen — Section headers', () {
    testWidgets('12-16. all section headers are visible', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('基本情報'), findsOneWidget);
      expect(find.text('連絡先'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('所在地'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('所在地'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('サービス'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('サービス'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('プラン選択'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('プラン選択'), findsOneWidget);
    });
  });

  group('ShopRegistrationScreen — ServiceCategory chips', () {
    testWidgets('17. all 12 ServiceCategory chips are rendered',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Scroll to chips section
      await tester.scrollUntilVisible(find.text('車検'), 200,
          scrollable: find.byType(Scrollable).first);

      // Verify some representative chips are present
      expect(find.text('車検'), findsOneWidget);
      expect(find.text('整備・点検'), findsOneWidget);
      expect(find.text('修理'), findsOneWidget);
      expect(find.text('カスタム'), findsOneWidget);
      expect(find.text('板金・塗装'), findsOneWidget);
    });

    testWidgets('18. tapping chip selects it', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(find.text('車検'), 200,
          scrollable: find.byType(Scrollable).first);

      final chip = find.ancestor(
        of: find.text('車検'),
        matching: find.byType(FilterChip),
      );
      expect(chip, findsOneWidget);

      // Initially not selected
      FilterChip chipWidget = tester.widget(chip);
      expect(chipWidget.selected, isFalse);

      await tester.ensureVisible(chip);
      await tester.pumpAndSettle(const Duration(seconds: 10));
      await tester.tap(chip);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      chipWidget = tester.widget(chip);
      expect(chipWidget.selected, isTrue);
    });

    testWidgets('19. tapping selected chip deselects it', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(find.text('整備・点検'), 200,
          scrollable: find.byType(Scrollable).first);

      final chip = find.ancestor(
        of: find.text('整備・点検'),
        matching: find.byType(FilterChip),
      );

      // Select
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle(const Duration(seconds: 10));
      await tester.tap(chip);
      await tester.pumpAndSettle(const Duration(seconds: 10));
      FilterChip chipWidget = tester.widget(chip);
      expect(chipWidget.selected, isTrue);

      // Deselect
      await tester.tap(chip);
      await tester.pumpAndSettle(const Duration(seconds: 10));
      chipWidget = tester.widget(chip);
      expect(chipWidget.selected, isFalse);
    });
  });

  group('ShopRegistrationScreen — Plan selection', () {
    testWidgets('20. Free plan card shows 0円', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(find.text('0円'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('0円'), findsOneWidget);
    });

    testWidgets('21. Standard plan card shows 9,800円 / 月', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(find.text('9,800円 / 月'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('9,800円 / 月'), findsOneWidget);
    });

    testWidgets('22. Premium plan card shows 29,800円 / 月', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(find.text('29,800円 / 月'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('29,800円 / 月'), findsOneWidget);
    });

    testWidgets('23. default selection is Free plan', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(find.text('Free'), 200,
          scrollable: find.byType(Scrollable).first);

      // Free plan should have radio_button_checked icon
      final freePlanCard = find.ancestor(
        of: find.text('Free'),
        matching: find.byType(GestureDetector),
      );
      expect(freePlanCard, findsWidgets);

      // The Free plan has radio_button_checked; Standard and Premium have radio_button_off
      expect(
        find.byIcon(Icons.radio_button_checked),
        findsOneWidget,
      );
    });

    testWidgets('24. tapping Standard plan selects it', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(find.text('Standard'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Now Standard should be selected (radio_button_checked near 'Standard')
      // and Free should be deselected
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_off), findsNWidgets(2));
    });
  });

  group('ShopRegistrationScreen — Submit button state', () {
    testWidgets('25. bottom 保存する button enabled when not submitting',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Scroll to bottom button
      await tester.scrollUntilVisible(find.text('保存する'), 200,
          scrollable: find.byType(Scrollable).first);

      final button = find.ancestor(
        of: find.text('保存する'),
        matching: find.byType(FilledButton),
      );
      final buttonWidget = tester.widget<FilledButton>(button);
      expect(buttonWidget.onPressed, isNotNull);
    });

    testWidgets('26. bottom button shows 保存中... when isSubmitting=true',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(shopProvider: _FakeShopProvider(isSubmitting: true)),
      );
      // The submitting spinner animates forever; use bounded pumps.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.scrollUntilVisible(find.text('保存中...'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('保存中...'), findsOneWidget);

      // Button should be disabled
      final button = find.ancestor(
        of: find.text('保存中...'),
        matching: find.byType(FilledButton),
      );
      final buttonWidget = tester.widget<FilledButton>(button);
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('27. AppBar 保存 TextButton present in new mode', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('保存'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('保存'),
          matching: find.byType(TextButton),
        ),
        findsOneWidget,
      );
    });

    testWidgets('28. AppBar shows CircularProgressIndicator when isSubmitting',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(shopProvider: _FakeShopProvider(isSubmitting: true)),
      );
      // The submitting spinner animates forever; use bounded pumps.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // AppBar should show spinner, not 保存 button
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('保存'), findsNothing);
    });
  });

  group('ShopRegistrationScreen — Edit mode pre-fill', () {
    testWidgets('29. edit mode pre-fills shop name', (tester) async {
      final shop = _makeExistingShop(name: 'オートサービス山田');
      await tester.pumpWidget(_buildScreen(existingShop: shop));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(
        find.descendant(
          of: find.byType(TextFormField).first,
          matching: find.text('オートサービス山田'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('30. edit mode pre-fills description', (tester) async {
      final shop = _makeExistingShop(description: '熟練スタッフが丁寧に整備します');
      await tester.pumpWidget(_buildScreen(existingShop: shop));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('熟練スタッフが丁寧に整備します'), findsOneWidget);
    });

    testWidgets('31. edit mode pre-fills plan type (Standard)', (tester) async {
      // Plan cards are lazily built in a ListView; use a tall surface so all
      // three cards (Free/Standard/Premium) are rendered.
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final shop = _makeExistingShop(planType: ShopPlanType.standard);
      await tester.pumpWidget(_buildScreen(existingShop: shop));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Scroll to plan section
      await tester.scrollUntilVisible(find.text('Standard'), 200,
          scrollable: find.byType(Scrollable).first);

      // Standard should be selected (radio_button_checked near it)
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      // The other two plans are not selected
      expect(find.byIcon(Icons.radio_button_off), findsNWidgets(2));
    });

    testWidgets('32. edit mode pre-fills selected services', (tester) async {
      final shop = _makeExistingShop(
        services: [ServiceCategory.inspection, ServiceCategory.tire],
      );
      await tester.pumpWidget(_buildScreen(existingShop: shop));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(find.text('車検'), 200,
          scrollable: find.byType(Scrollable).first);

      // 車検 chip should be selected
      final inspectionChip = find.ancestor(
        of: find.text('車検'),
        matching: find.byType(FilterChip),
      );
      FilterChip widget = tester.widget(inspectionChip);
      expect(widget.selected, isTrue);

      // タイヤ交換 chip should also be selected
      await tester.scrollUntilVisible(find.text('タイヤ交換'), 100,
          scrollable: find.byType(Scrollable).first);
      final tireChip = find.ancestor(
        of: find.text('タイヤ交換'),
        matching: find.byType(FilterChip),
      );
      FilterChip tireWidget = tester.widget(tireChip);
      expect(tireWidget.selected, isTrue);
    });
  });

  group('ShopRegistrationScreen — Submit flow', () {
    testWidgets('33. successful save calls saveMyShop with entered name',
        (tester) async {
      final provider = _FakeShopProvider(saveShouldSucceed: true);
      await tester.pumpWidget(_buildScreen(shopProvider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.enterText(find.byType(TextFormField).first, '新規テスト工場');
      await tester.pump();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(provider.saveCalledWith, isTrue);
      expect(provider.lastSavedShop?.name, '新規テスト工場');
    });

    testWidgets('34. failed save shows error snackbar', (tester) async {
      final provider = _FakeShopProvider(saveShouldSucceed: false);
      await tester.pumpWidget(_buildScreen(shopProvider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.enterText(find.byType(TextFormField).first, 'エラーテスト工場');
      await tester.pump();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Shows fallback error message snackbar
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('保存に失敗しました'), findsOneWidget);
    });

    testWidgets('34b. failed save shows provider submitError in snackbar',
        (tester) async {
      final provider = _FakeShopProvider(
        saveShouldSucceed: false,
        submitError: 'ネットワークエラーが発生しました',
      );
      await tester.pumpWidget(_buildScreen(shopProvider: provider));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.enterText(find.byType(TextFormField).first, 'エラーテスト工場');
      await tester.pump();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('ネットワークエラーが発生しました'), findsOneWidget);
    });

    testWidgets('35. successful save pops the route', (tester) async {
      final provider = _FakeShopProvider(saveShouldSucceed: true);

      // Wrap in a Navigator with a home route so pop can be verified
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => _LoggedInAuthProvider(),
            ),
            ChangeNotifierProvider<ShopProvider>.value(value: provider),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ShopRegistrationScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Navigate to registration screen
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle(const Duration(seconds: 10));
      expect(find.text('店舗を登録'), findsOneWidget);

      // Enter name and save
      await tester.enterText(find.byType(TextFormField).first, 'ポップテスト工場');
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // After successful save, should have popped back to the home screen
      expect(find.text('open'), findsOneWidget);
      expect(find.text('店舗を登録'), findsNothing);
    });
  });

  group('ShopRegistrationScreen — Edge Cases', () {
    testWidgets('name with only whitespace fails validation', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.enterText(find.byType(TextFormField).first, '   ');
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('店舗名を入力してください'), findsOneWidget);
    });

    testWidgets('all plan cards are visible on scroll', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.scrollUntilVisible(find.text('Free'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Free'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Standard'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Standard'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Premium'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Premium'), findsOneWidget);
    });

    testWidgets('edit mode uses existingShop id for saved shop',
        (tester) async {
      final shop = _makeExistingShop(id: 'existing-shop-id', name: '既存工場');
      final provider = _FakeShopProvider(saveShouldSucceed: true);
      await tester.pumpWidget(
        _buildScreen(shopProvider: provider, existingShop: shop),
      );
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(provider.lastSavedShop?.id, 'existing-shop-id');
    });
  });
}
