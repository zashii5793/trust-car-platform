// PostCreateScreen Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/sns/post_create_screen.dart';
import 'package:trust_car_platform/providers/post_provider.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/providers/vehicle_provider.dart';
import 'package:trust_car_platform/services/post_service.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/models/post.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPostService implements PostService {
  Result<Post, AppError>? createResult;
  int createCallCount = 0;
  String? lastContent;
  PostCategory? lastCategory;
  PostVisibility? lastVisibility;

  @override
  Future<Result<List<Post>, AppError>> getFeed({
    int limit = 20,
    dynamic startAfter,
    PostCategory? category,
    String? makerId,
    String? modelName,
  }) async =>
      const Result.success([]);

  @override
  Future<Result<Post, AppError>> createPost({
    required String userId,
    String? userDisplayName,
    String? userPhotoUrl,
    required PostCategory category,
    PostVisibility visibility = PostVisibility.public,
    required String content,
    List<PostMedia> media = const [],
    dynamic vehicleTag,
  }) async {
    createCallCount++;
    lastContent = content;
    lastCategory = category;
    lastVisibility = visibility;
    return createResult ?? Result.success(_makePost(content: content));
  }

  @override
  Future<Result<void, AppError>> likePost({
    required String postId,
    required String userId,
    String? postAuthorId,
    String? actorDisplayName,
    String? actorPhotoUrl,
  }) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> unlikePost(
          {required String postId, required String userId}) async =>
      const Result.success(null);

  @override
  Future<bool> isPostLiked(
          {required String postId, required String userId}) async =>
      false;

  @override
  Future<Result<void, AppError>> deletePost(
          {required String postId, required String userId}) async =>
      const Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockAuthService implements AuthService {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeUser implements User {
  @override
  String get uid => 'test-uid';

  @override
  String? get displayName => 'Test User';

  @override
  String? get photoURL => null;

  @override
  String? get email => 'test@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _LoggedInAuthProvider extends AuthProvider {
  _LoggedInAuthProvider() : super(authService: MockAuthService());

  @override
  User? get firebaseUser => _FakeUser();

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Post _makePost({String content = 'テスト投稿'}) {
  final now = DateTime.now();
  return Post(
    id: 'new1',
    userId: 'u1',
    category: PostCategory.general,
    content: content,
    createdAt: now,
    updatedAt: now,
  );
}

/// Minimal FirebaseService stub — VehicleProvider only reads its in-memory
/// state in these tests, so no method is actually invoked.
class _StubFirebaseService implements FirebaseService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _buildApp(MockPostService mockPostService) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => PostProvider(postService: mockPostService),
      ),
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => _LoggedInAuthProvider(),
      ),
      ChangeNotifierProvider<VehicleProvider>(
        create: (_) => VehicleProvider(firebaseService: _StubFirebaseService()),
      ),
    ],
    child: const MaterialApp(home: PostCreateScreen()),
  );
}

/// ListView uses 600px default height; expand to 2000px to render all items.
Future<void> pumpApp(WidgetTester tester, MockPostService service) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_buildApp(service));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PostCreateScreen', () {
    late MockPostService mockService;

    setUp(() {
      mockService = MockPostService();
    });

    testWidgets('画面タイトルが「新規投稿」になっている', (tester) async {
      await pumpApp(tester, mockService);
      expect(find.text('新規投稿'), findsOneWidget);
    });

    testWidgets('カテゴリチップが全種表示される', (tester) async {
      await pumpApp(tester, mockService);

      for (final cat in PostCategory.values) {
        expect(find.text(cat.displayName), findsWidgets);
      }
    });

    testWidgets('本文テキストフィールドが表示される', (tester) async {
      await pumpApp(tester, mockService);

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('送信ボタンが表示される', (tester) async {
      await pumpApp(tester, mockService);

      expect(find.text('投稿する'), findsOneWidget);
    });

    testWidgets('本文なしで送信してもcreatePostは呼ばれない', (tester) async {
      await pumpApp(tester, mockService);

      await tester.tap(find.text('投稿する'));
      await tester.pump();

      expect(mockService.createCallCount, 0);
    });

    testWidgets('空白のみで送信するとcreatePostは呼ばれない', (tester) async {
      await pumpApp(tester, mockService);

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump(); // rebuild so the submit button enables
      await tester.tap(find.text('投稿する'));
      await tester.pump();

      expect(mockService.createCallCount, 0);
    });

    testWidgets('本文を入力して送信するとcreatePostが呼ばれる', (tester) async {
      await pumpApp(tester, mockService);

      await tester.enterText(find.byType(TextField).first, 'テスト投稿です');
      await tester.pump(); // rebuild so the submit button enables
      await tester.tap(find.text('投稿する'));
      await tester.pump();

      expect(mockService.createCallCount, 1);
      expect(mockService.lastContent, 'テスト投稿です');
    });

    testWidgets('カテゴリを選択して投稿するとカテゴリが送信される', (tester) async {
      await pumpApp(tester, mockService);

      await tester.tap(
        find.text(PostCategory.maintenance.displayName).first,
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'メンテ記録です');
      await tester.pump(); // rebuild so the submit button enables
      await tester.tap(find.text('投稿する'));
      await tester.pump();

      expect(mockService.lastCategory, PostCategory.maintenance);
    });

    testWidgets('文字数カウンタが表示される', (tester) async {
      await pumpApp(tester, mockService);

      expect(find.textContaining('/ 500'), findsOneWidget);
    });

    testWidgets('文字を入力すると文字数カウンタが更新される', (tester) async {
      await pumpApp(tester, mockService);

      await tester.enterText(find.byType(TextField).first, 'あいう'); // 3文字
      await tester.pump();

      expect(find.text('3 / 500'), findsOneWidget);
    });

    testWidgets('AppBarに投稿ボタンが表示される', (tester) async {
      await pumpApp(tester, mockService);

      expect(find.widgetWithText(TextButton, '投稿'), findsOneWidget);
    });

    testWidgets('AppBarの投稿ボタンからも送信できる', (tester) async {
      await pumpApp(tester, mockService);

      await tester.enterText(find.byType(TextField).first, 'AppBarから投稿テスト');
      await tester.pump(); // rebuild so the submit button enables
      await tester.tap(find.widgetWithText(TextButton, '投稿'));
      await tester.pump();

      expect(mockService.createCallCount, 1);
    });

    testWidgets('サービス失敗時にSnackBarでエラーが表示される', (tester) async {
      mockService.createResult =
          Result.failure(AppError.network('connection failed'));

      await pumpApp(tester, mockService);

      await tester.enterText(find.byType(TextField).first, '失敗する投稿');
      await tester.pump(); // rebuild so the submit button enables
      await tester.tap(find.text('投稿する'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    // ── Edge Cases ──────────────────────────────────────────────────────────

    group('Edge Cases', () {
      testWidgets('499文字の投稿は送信できる', (tester) async {
        await pumpApp(tester, mockService);

        final longContent = 'あ' * 499;
        await tester.enterText(find.byType(TextField).first, longContent);
        await tester.pump(); // rebuild so the submit button enables
        await tester.tap(find.text('投稿する'));
        await tester.pump();

        expect(mockService.createCallCount, 1);
      });

      testWidgets('デフォルトカテゴリは「一般」になっている', (tester) async {
        await pumpApp(tester, mockService);

        await tester.enterText(find.byType(TextField).first, '一般投稿');
        await tester.pump(); // rebuild so the submit button enables
        await tester.tap(find.text('投稿する'));
        await tester.pump();

        expect(mockService.lastCategory, PostCategory.general);
      });

      testWidgets('デフォルト公開設定は「全体公開」になっている', (tester) async {
        await pumpApp(tester, mockService);

        await tester.enterText(find.byType(TextField).first, '公開投稿');
        await tester.pump(); // rebuild so the submit button enables
        await tester.tap(find.text('投稿する'));
        await tester.pump();

        expect(mockService.lastVisibility, PostVisibility.public);
      });

      testWidgets('カテゴリを複数回変更しても最後に選んだものが送信される', (tester) async {
        await pumpApp(tester, mockService);

        await tester.tap(find.text(PostCategory.drive.displayName).first);
        await tester.pump();
        await tester.tap(find.text(PostCategory.review.displayName).first);
        await tester.pump();

        await tester.enterText(find.byType(TextField).first, 'レビュー投稿');
        await tester.pump(); // rebuild so the submit button enables
        await tester.tap(find.text('投稿する'));
        await tester.pump();

        expect(mockService.lastCategory, PostCategory.review);
      });

      testWidgets('本文入力フィールドのヒントテキストが表示される', (tester) async {
        await pumpApp(tester, mockService);

        expect(find.textContaining('投稿しましょう'), findsOneWidget);
      });
    });
  });
}
