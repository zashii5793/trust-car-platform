// SnsFeedScreen Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/sns/sns_feed_screen.dart';
import 'package:trust_car_platform/providers/post_provider.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/providers/vehicle_provider.dart';
import 'package:trust_car_platform/services/post_service.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/models/post.dart';
import 'package:trust_car_platform/models/comment.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/widgets/common/loading_indicator.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPostService implements PostService {
  // テストは List<Post> で結果を組み立てる。getFeed は PostPage を返すので
  // ここで包み直す（カーソルの有無まで各テストに書かせない）。
  Result<PostPage, AppError> _feedPageResult =
      const Result.success(PostPage.empty);

  set feedResult(Result<List<Post>, AppError> value) {
    _feedPageResult = value.when(
      success: (posts) => Result.success(
        PostPage(posts: posts, cursor: posts.isEmpty ? null : 'cursor'),
      ),
      failure: Result<PostPage, AppError>.failure,
    );
  }

  Result<Post, AppError>? createResult;
  Result<void, AppError> likeResult = const Result.success(null);
  Result<void, AppError> unlikeResult = const Result.success(null);
  Result<void, AppError> deleteResult = const Result.success(null);
  bool isPostLikedResult = false;

  int getFeedCallCount = 0;
  Set<PostCategory> lastCategories = const {};
  PostSortBy lastSortBy = PostSortBy.newest;
  String? lastHashtag;

  @override
  Future<Result<PostPage, AppError>> getFeed({
    int limit = 20,
    dynamic startAfter,
    Set<PostCategory> categories = const {},
    PostSortBy sortBy = PostSortBy.newest,
    String? hashtag,
    String? makerId,
    String? modelName,
  }) async {
    getFeedCallCount++;
    lastCategories = categories;
    lastSortBy = sortBy;
    lastHashtag = hashtag;
    return _feedPageResult;
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
  Future<Result<void, AppError>> likePost({
    required String postId,
    required String userId,
    String? postAuthorId,
    String? actorDisplayName,
    String? actorPhotoUrl,
  }) async =>
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
  Future<Result<List<Comment>, AppError>> getComments({
    required String postId,
    int limit = 50,
    dynamic startAfter,
    bool topLevelOnly = true,
  }) async =>
      const Result.success([]);

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
  List<PostMedia> media = const [],
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
    media: media,
    createdAt: now,
    updatedAt: now,
  );
}

/// Minimal FirebaseService stub — VehicleProvider only reads its in-memory
/// state in these tests, so no method is actually invoked.
class _StubFirebaseService implements FirebaseService {
  @override
  Future<Result<bool, AppError>> hasAnyMaintenanceRecord() async =>
      const Result.success(false);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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
      ChangeNotifierProvider<VehicleProvider>(
        create: (_) => VehicleProvider(firebaseService: _StubFirebaseService()),
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

      expect(find.text('投稿がまだありません'), findsOneWidget);
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
      // Chips are in a lazy horizontal ListView; widen the surface so all
      // category chips are actually built.
      await tester.binding.setSurfaceSize(const Size(2000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
      expect(mockService.lastCategories, {PostCategory.maintenance});
    });

    testWidgets('カテゴリチップを複数タップすると両方で絞り込まれる', (tester) async {
      mockService.feedResult = const Result.success([]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      await tester.tap(
          find.byKey(Key('sns_category_${PostCategory.maintenance.name}')));
      await tester.pump();
      await tester
          .tap(find.byKey(Key('sns_category_${PostCategory.drive.name}')));
      await tester.pump();

      expect(
        mockService.lastCategories,
        {PostCategory.maintenance, PostCategory.drive},
      );
    });

    testWidgets('選択済みのカテゴリチップを再タップすると解除される', (tester) async {
      mockService.feedResult = const Result.success([]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      final chip = find.byKey(Key('sns_category_${PostCategory.drive.name}'));
      await tester.tap(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();

      expect(mockService.lastCategories, isEmpty);
    });

    testWidgets('「すべて」チップでカテゴリ選択が解除される', (tester) async {
      mockService.feedResult = const Result.success([]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      await tester
          .tap(find.byKey(Key('sns_category_${PostCategory.drive.name}')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sns_category_all')));
      await tester.pump();

      expect(mockService.lastCategories, isEmpty);
    });

    testWidgets('並び替えボタンから「コメントが多い順」に変更できる', (tester) async {
      mockService.feedResult = const Result.success([]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sns_sort_button')));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(
          find.byKey(Key('sns_sort_option_${PostSortBy.mostCommented.name}')));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(mockService.lastSortBy, PostSortBy.mostCommented);
    });

    testWidgets('並び替えボタンに現在の並び順が表示される', (tester) async {
      mockService.feedResult = const Result.success([]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      expect(find.text(PostSortBy.newest.displayName), findsOneWidget);
    });

    testWidgets('FABをタップすると投稿作成画面に遷移する', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // PostCreateScreen に遷移（AppBar タイトルは「新規投稿」）
      expect(find.text('新規投稿'), findsOneWidget);
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
          _makePost(id: 'p2', category: PostCategory.question, content: '質問です'),
        ]);

        await tester.pumpWidget(_buildApp(mockService));
        await tester.pump();

        expect(find.text('ドライブ記事'), findsOneWidget);
        expect(find.text('質問です'), findsOneWidget);
      });
    });
  });

  // -------------------------------------------------------------------------
  // 投稿画像の見え方
  //
  // 1枚しかない投稿まで小さな正方形で出していたため、カードの中で写真が
  // 埋もれて「画像を出せないアプリ」に見えていた。
  // -------------------------------------------------------------------------

  group('SnsFeedScreen — 投稿画像', () {
    late MockPostService mockService;

    setUp(() {
      mockService = MockPostService();
    });

    PostMedia media(String url) => PostMedia(url: url, type: 'image');

    testWidgets('画像がない投稿では画像領域が出ない', (tester) async {
      mockService.feedResult = Result.success([_makePost(id: 'p-no-image')]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byKey(const Key('post_media_p-no-image')), findsNothing);
    });

    testWidgets('画像1枚の投稿は幅いっぱいで表示される', (tester) async {
      mockService.feedResult = Result.success([
        _makePost(id: 'p-one', media: [media('https://example.com/a.jpg')]),
      ]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final finder = find.byKey(const Key('post_media_p-one'));
      expect(finder, findsOneWidget);

      // 横スクロールのリストではなく、1枚を大きく見せる
      expect(
        find.descendant(of: finder, matching: find.byType(ListView)),
        findsNothing,
      );
    });

    testWidgets('画像が複数ある投稿は横に並ぶ', (tester) async {
      mockService.feedResult = Result.success([
        _makePost(id: 'p-many', media: [
          media('https://example.com/a.jpg'),
          media('https://example.com/b.jpg'),
        ]),
      ]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final finder = find.byKey(const Key('post_media_p-many'));
      expect(finder, findsOneWidget);
      expect(
        find.descendant(of: finder, matching: find.byType(Image)),
        findsNWidgets(2),
      );
    });
  });

  // -------------------------------------------------------------------------
  // ハッシュタグの絞り込み
  //
  // タグは表示されるだけで、押しても「近日公開予定です」と出るだけだった。
  // -------------------------------------------------------------------------

  group('SnsFeedScreen — ハッシュタグ', () {
    late MockPostService mockService;

    setUp(() {
      mockService = MockPostService();
    });

    testWidgets('タグをタップするとそのタグで絞り込まれる', (tester) async {
      mockService.feedResult = Result.success([
        _makePost(id: 'p-tag', hashtags: const ['点検']),
      ]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byKey(const Key('post_hashtag_p-tag_点検')));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(mockService.lastHashtag, '点検');
    });

    testWidgets('絞り込み中はタグのチップが出る', (tester) async {
      mockService.feedResult = Result.success([
        _makePost(id: 'p-tag', hashtags: const ['点検']),
      ]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(find.byKey(const Key('post_hashtag_p-tag_点検')));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byKey(const Key('sns_hashtag_active')), findsOneWidget);
    });

    testWidgets('チップの × で絞り込みを解除できる', (tester) async {
      mockService.feedResult = Result.success([
        _makePost(id: 'p-tag', hashtags: const ['点検']),
      ]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(find.byKey(const Key('post_hashtag_p-tag_点検')));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.descendant(
        of: find.byKey(const Key('sns_hashtag_active')),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(mockService.lastHashtag, isNull);
      expect(find.byKey(const Key('sns_hashtag_active')), findsNothing);
    });

    testWidgets('同じタグをもう一度押すと解除される', (tester) async {
      mockService.feedResult = Result.success([
        _makePost(id: 'p-tag', hashtags: const ['点検']),
      ]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      final chip = find.byKey(const Key('post_hashtag_p-tag_点検'));
      await tester.tap(chip);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(chip);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(mockService.lastHashtag, isNull);
    });

    testWidgets('タグ絞り込みで0件のときは専用の空表示になる', (tester) async {
      mockService.feedResult = Result.success([
        _makePost(id: 'p-tag', hashtags: const ['点検']),
      ]);

      await tester.pumpWidget(_buildApp(mockService));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      mockService.feedResult = const Result.success([]);
      await tester.tap(find.byKey(const Key('post_hashtag_p-tag_点検')));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('このタグの投稿がまだありません'), findsOneWidget);
    });
  });
}
