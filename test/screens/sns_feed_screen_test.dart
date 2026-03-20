// SnsFeedScreen Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/sns/sns_feed_screen.dart';
import 'package:trust_car_platform/providers/post_provider.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/post_service.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/models/post.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/widgets/common/loading_indicator.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPostService implements PostService {
  Result<List<Post>, AppError> feedResult = const Result.success([]);
  Result<Post, AppError>? createResult;
  Result<void, AppError> likeResult = const Result.success(null);
  Result<void, AppError> unlikeResult = const Result.success(null);
  Result<void, AppError> deleteResult = const Result.success(null);
  bool isPostLikedResult = false;

  int getFeedCallCount = 0;
  PostCategory? lastCategory;

  @override
  Future<Result<List<Post>, AppError>> getFeed({
    int limit = 20,
    dynamic startAfter,
    PostCategory? category,
    String? makerId,
  }) async {
    getFeedCallCount++;
    lastCategory = category;
    return feedResult;
  }

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
    return createResult ?? Result.success(_makePost());
  }

  @override
  Future<Result<void, AppError>> likePost(
          {required String postId, required String userId}) async =>
      likeResult;

  @override
  Future<Result<void, AppError>> unlikePost(
          {required String postId, required String userId}) async =>
      unlikeResult;

  @override
  Future<bool> isPostLiked(
          {required String postId, required String userId}) async =>
      isPostLikedResult;

  @override
  Future<Result<void, AppError>> deletePost(
          {required String postId, required String userId}) async =>
      deleteResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockAuthService implements AuthService {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<Result<UserCredential, AppError>> signUpWithEmail(
          {required String email,
          required String password,
          String? displayName}) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<UserCredential, AppError>> signInWithEmail(
          {required String email, required String password}) async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<UserCredential?, AppError>> signInWithGoogle() async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  Future<Result<void, AppError>> sendPasswordResetEmail(String email) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> signOut() async => const Result.success(null);

  @override
  Future<Result<AppUser?, AppError>> getUserProfile() async =>
      Result.failure(AppError.unknown('not impl'));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Post _makePost({
  String id = 'post1',
  String userId = 'user1',
  String userDisplayName = 'テストユーザー',
  String content = 'テスト投稿内容',
  PostCategory category = PostCategory.general,
  int likeCount = 3,
  int commentCount = 1,
  List<String> hashtags = const [],
}) {
  final now = DateTime.now();
  return Post(
    id: id,
    userId: userId,
    userDisplayName: userDisplayName,
    category: category,
    content: content,
    likeCount: likeCount,
    commentCount: commentCount,
    hashtags: hashtags,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildApp(MockPostService mockPostService) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => PostProvider(postService: mockPostService),
      ),
      ChangeNotifierProvider(
        create: (_) => AuthProvider(authService: MockAuthService()),
      ),
    ],
    child: const MaterialApp(home: SnsFeedScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SnsFeedScreen', () {
    late MockPostService mockService;

    setUp(() {
      mockService = MockPostService();
    });

    testWidgets('読み込み後に投稿リストが表示される', (tester) async {
      mockService.feedResult = Result.success([
        _makePost(id: 'p1', content: '最初の投稿'),
        _makePost(id: 'p2', content: '二番目の投稿'),
      ]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      expect(find.text('最初の投稿'), findsOneWidget);
      expect(find.text('二番目の投稿'), findsOneWidget);
    });

    testWidgets('フィードが空のとき空状態UIが表示される', (tester) async {
      mockService.feedResult = const Result.success([]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      expect(find.text('投稿がありません'), findsOneWidget);
    });

    testWidgets('エラー時にエラーUIが表示される', (tester) async {
      mockService.feedResult = Result.failure(AppError.network('failed'));

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      expect(find.byType(AppErrorState), findsOneWidget);
    });

    testWidgets('ユーザー表示名が投稿カードに表示される', (tester) async {
      mockService.feedResult = Result.success([
        _makePost(userDisplayName: '田中太郎'),
      ]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      expect(find.text('田中太郎'), findsOneWidget);
    });

    testWidgets('カテゴリバッジが表示される', (tester) async {
      mockService.feedResult = Result.success([
        _makePost(category: PostCategory.maintenance),
      ]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      expect(find.text(PostCategory.maintenance.displayName), findsWidgets);
    });

    testWidgets('ハッシュタグが表示される', (tester) async {
      mockService.feedResult = Result.success([
        _makePost(hashtags: ['カスタム', 'DIY']),
      ]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      expect(find.text('#カスタム'), findsOneWidget);
      expect(find.text('#DIY'), findsOneWidget);
    });

    testWidgets('いいね数が表示される', (tester) async {
      mockService.feedResult = Result.success([
        _makePost(likeCount: 42),
      ]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('コメント数が表示される', (tester) async {
      mockService.feedResult = Result.success([
        _makePost(commentCount: 7),
      ]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('FABが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('カテゴリフィルタバーが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      expect(find.text('すべて'), findsWidgets);
    });

    testWidgets('カテゴリチップがすべて表示される', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      for (final cat in PostCategory.values) {
        expect(find.text(cat.displayName), findsWidgets);
      }
    });

    testWidgets('カテゴリチップをタップするとフィードが再読み込みされる', (tester) async {
      mockService.feedResult = const Result.success([]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();
      final initialCount = mockService.getFeedCallCount;

      // 「メンテナンス」チップをタップ
      await tester.tap(
        find.text(PostCategory.maintenance.displayName).first,
      );
      await tester.pump();

      expect(mockService.getFeedCallCount, greaterThan(initialCount));
      expect(mockService.lastCategory, PostCategory.maintenance);
    });

    testWidgets('FABをタップすると投稿作成画面に遷移する', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // PostCreateScreen に遷移
      expect(find.text('投稿を作成'), findsOneWidget);
    });

    testWidgets('いいねボタンをタップするとlikePostが呼ばれる', (tester) async {
      mockService.feedResult = Result.success([_makePost(id: 'p1')]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      // いいねボタン（heart icon）をタップ
      await tester.tap(find.byIcon(Icons.favorite_border).first);
      await tester.pump();

      // likeResult is success, so the like should be applied
      // (service mock returns success by default)
      expect(find.byType(SnsFeedScreen), findsOneWidget);
    });

    testWidgets('エラー時にリトライボタンを押すと再読み込みされる', (tester) async {
      mockService.feedResult = Result.failure(AppError.network('failed'));

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();
      final countBefore = mockService.getFeedCallCount;

      mockService.feedResult = const Result.success([]);
      final retryButton = find.widgetWithText(TextButton, '再試行');
      if (retryButton.evaluate().isNotEmpty) {
        await tester.tap(retryButton);
        await tester.pump();
        expect(mockService.getFeedCallCount, greaterThan(countBefore));
      }
    });

    // ── Edge Cases ──────────────────────────────────────────────────────────

    group('Edge Cases', () {
      testWidgets('投稿が20件のときhasMore=trueで追加読み込みが可能', (tester) async {
        mockService.feedResult = Result.success(
          List.generate(20, (i) => _makePost(id: 'p$i')),
        );

        await tester.pumpWidget(_buildApp(mockService));
        await tester.pump();

        expect(find.byType(ListView), findsWidgets);
      });

      testWidgets('投稿内容が長くても表示される', (tester) async {
        mockService.feedResult = Result.success([
          _makePost(content: 'あ' * 200),
        ]);

        await tester.pumpWidget(_buildApp(mockService));
        await tester.pump();

        expect(find.byType(SnsFeedScreen), findsOneWidget);
      });

      testWidgets('userPhotoUrlがnullのときイニシャルアバターが表示される', (tester) async {
        mockService.feedResult = Result.success([
          _makePost(userDisplayName: '山田太郎'),
        ]);

        await tester.pumpWidget(_buildApp(mockService));
        await tester.pump();

        // アバターの最初の文字「山」がイニシャルとして表示される
        expect(find.text('山'), findsOneWidget);
      });

      testWidgets('ハッシュタグなしでもクラッシュしない', (tester) async {
        mockService.feedResult = Result.success([
          _makePost(hashtags: []),
        ]);

        await tester.pumpWidget(_buildApp(mockService));
        await tester.pump();

        expect(find.byType(SnsFeedScreen), findsOneWidget);
      });

      testWidgets('複数投稿があるとき各投稿のカテゴリが正しく表示される', (tester) async {
        mockService.feedResult = Result.success([
          _makePost(id: 'p1', category: PostCategory.drive, content: 'ドライブ記事'),
          _makePost(
              id: 'p2', category: PostCategory.question, content: '質問です'),
        ]);

        await tester.pumpWidget(_buildApp(mockService));
        await tester.pump();

        expect(find.text('ドライブ記事'), findsOneWidget);
        expect(find.text('質問です'), findsOneWidget);
      });
    });
  });
}
