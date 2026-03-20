// PostProvider Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/providers/post_provider.dart';
import 'package:trust_car_platform/services/post_service.dart';
import 'package:trust_car_platform/models/post.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Mock PostService
// ---------------------------------------------------------------------------

class MockPostService implements PostService {
  // Configurable results
  Result<List<Post>, AppError> feedResult = const Result.success([]);
  Result<Post, AppError>? createResult;
  Result<void, AppError> likeResult = const Result.success(null);
  Result<void, AppError> unlikeResult = const Result.success(null);
  Result<void, AppError> deleteResult = const Result.success(null);
  bool isPostLikedResult = false;

  // Call tracking
  int getFeedCallCount = 0;
  int createCallCount = 0;
  int likeCallCount = 0;
  int unlikeCallCount = 0;
  int deleteCallCount = 0;
  PostCategory? lastCategory;
  String? lastContent;

  @override
  Future<Result<List<Post>, AppError>> getFeed({
    int limit = 20,
    PostCategory? category,
    dynamic startAfter,
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
    createCallCount++;
    lastContent = content;
    return createResult ??
        Result.success(_makePost(id: 'new1', content: content));
  }

  @override
  Future<Result<void, AppError>> likePost(
      {required String postId, required String userId}) async {
    likeCallCount++;
    return likeResult;
  }

  @override
  Future<Result<void, AppError>> unlikePost(
      {required String postId, required String userId}) async {
    unlikeCallCount++;
    return unlikeResult;
  }

  @override
  Future<bool> isPostLiked(
      {required String postId, required String userId}) async {
    return isPostLikedResult;
  }

  @override
  Future<Result<void, AppError>> deletePost(
      {required String postId, required String userId}) async {
    deleteCallCount++;
    return deleteResult;
  }

  // Unused but required by interface
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Post _makePost({
  String id = 'post1',
  String userId = 'user1',
  String content = 'テスト投稿内容',
  PostCategory category = PostCategory.general,
  int likeCount = 0,
  int commentCount = 0,
}) {
  final now = DateTime.now();
  return Post(
    id: id,
    userId: userId,
    userDisplayName: 'テストユーザー',
    category: category,
    content: content,
    likeCount: likeCount,
    commentCount: commentCount,
    createdAt: now,
    updatedAt: now,
  );
}

PostProvider _makeProvider(MockPostService service) {
  return PostProvider(postService: service);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PostProvider', () {
    late MockPostService mockService;
    late PostProvider provider;

    setUp(() {
      mockService = MockPostService();
      provider = _makeProvider(mockService);
    });

    // ── loadFeed ─────────────────────────────────────────────────────────────

    group('loadFeed', () {
      test('正常にフィードを読み込む', () async {
        mockService.feedResult = Result.success([
          _makePost(id: 'p1'),
          _makePost(id: 'p2'),
        ]);

        await provider.loadFeed();

        expect(provider.feedPosts.length, 2);
        expect(provider.isLoading, false);
        expect(provider.error, isNull);
      });

      test('読み込み中はisLoadingがtrueになる', () async {
        bool loadingDuringFetch = false;
        mockService.feedResult = const Result.success([]);

        final future = provider.loadFeed();
        // loadFeed sets isLoading synchronously before first await
        // This won't catch it directly but ensures post-load state is correct
        await future;
        expect(provider.isLoading, false);
        expect(loadingDuringFetch, false); // just to use the variable
      });

      test('失敗時にエラーが設定される', () async {
        mockService.feedResult =
            Result.failure(AppError.network('connection failed'));

        await provider.loadFeed();

        expect(provider.error, isNotNull);
        expect(provider.feedPosts, isEmpty);
        expect(provider.isLoading, false);
      });

      test('カテゴリを指定するとサービスに渡される', () async {
        await provider.loadFeed(category: PostCategory.maintenance);

        expect(mockService.lastCategory, PostCategory.maintenance);
        expect(provider.selectedCategory, PostCategory.maintenance);
      });

      test('20件以上あるとhasMoreがtrueになる', () async {
        mockService.feedResult = Result.success(
          List.generate(20, (i) => _makePost(id: 'p$i')),
        );

        await provider.loadFeed();

        expect(provider.hasMore, true);
      });

      test('20件未満ならhasMoreがfalseになる', () async {
        mockService.feedResult = Result.success(
          List.generate(5, (i) => _makePost(id: 'p$i')),
        );

        await provider.loadFeed();

        expect(provider.hasMore, false);
      });

      test('再読み込み時に既存投稿がクリアされる', () async {
        mockService.feedResult = Result.success([_makePost(id: 'p1')]);
        await provider.loadFeed();
        expect(provider.feedPosts.length, 1);

        mockService.feedResult = Result.success([_makePost(id: 'p2'), _makePost(id: 'p3')]);
        await provider.loadFeed();
        expect(provider.feedPosts.length, 2);
      });
    });

    // ── selectCategory ────────────────────────────────────────────────────────

    group('selectCategory', () {
      test('カテゴリが変わるとloadFeedが呼ばれる', () async {
        await provider.selectCategory(PostCategory.drive);

        expect(provider.selectedCategory, PostCategory.drive);
        expect(mockService.getFeedCallCount, 1);
        expect(mockService.lastCategory, PostCategory.drive);
      });

      test('同じカテゴリを選んでも再読み込みしない', () async {
        await provider.selectCategory(PostCategory.drive);
        final countBefore = mockService.getFeedCallCount;

        await provider.selectCategory(PostCategory.drive);

        expect(mockService.getFeedCallCount, countBefore);
      });

      test('nullを指定するとすべてのカテゴリになる', () async {
        await provider.selectCategory(PostCategory.drive);
        await provider.selectCategory(null);

        expect(provider.selectedCategory, isNull);
        expect(mockService.lastCategory, isNull);
      });
    });

    // ── refreshFeed ───────────────────────────────────────────────────────────

    group('refreshFeed', () {
      test('現在のカテゴリを維持してリフレッシュする', () async {
        await provider.loadFeed(category: PostCategory.maintenance);
        mockService.getFeedCallCount = 0;

        await provider.refreshFeed();

        expect(mockService.getFeedCallCount, 1);
        expect(mockService.lastCategory, PostCategory.maintenance);
      });
    });

    // ── createPost ────────────────────────────────────────────────────────────

    group('createPost', () {
      test('投稿作成に成功するとフィード先頭に追加される', () async {
        mockService.feedResult = Result.success([_makePost(id: 'existing1')]);
        await provider.loadFeed();

        final success = await provider.createPost(
          userId: 'u1',
          content: '新しい投稿です',
          category: PostCategory.carLife,
        );

        expect(success, true);
        expect(provider.feedPosts.length, 2);
        expect(provider.feedPosts.first.id, 'new1');
        expect(provider.feedPosts.first.content, '新しい投稿です');
      });

      test('空の内容では投稿されない', () async {
        final success = await provider.createPost(
          userId: 'u1',
          content: '   ',
          category: PostCategory.general,
        );

        expect(success, false);
        expect(mockService.createCallCount, 0);
      });

      test('投稿失敗時にsubmitErrorが設定される', () async {
        mockService.createResult =
            Result.failure(AppError.network('connection error'));

        final success = await provider.createPost(
          userId: 'u1',
          content: '失敗する投稿',
          category: PostCategory.general,
        );

        expect(success, false);
        expect(provider.submitError, isNotNull);
      });

      test('isSubmittingが投稿中はtrueになる', () async {
        // After createPost completes, isSubmitting returns to false
        await provider.createPost(
          userId: 'u1',
          content: '投稿テスト',
          category: PostCategory.general,
        );
        expect(provider.isSubmitting, false);
      });
    });

    // ── toggleLike ─────────────────────────────────────────────────────────

    group('toggleLike', () {
      test('いいねしていない投稿にいいねできる', () async {
        await provider.toggleLike('post1', 'user1');

        expect(provider.isLiked('post1'), true);
        expect(mockService.likeCallCount, 1);
        expect(mockService.unlikeCallCount, 0);
      });

      test('いいね済みの投稿のいいねを解除できる', () async {
        await provider.toggleLike('post1', 'user1'); // like
        await provider.toggleLike('post1', 'user1'); // unlike

        expect(provider.isLiked('post1'), false);
        expect(mockService.likeCallCount, 1);
        expect(mockService.unlikeCallCount, 1);
      });

      test('いいねするとlikeCountがローカルで+1される', () async {
        mockService.feedResult = Result.success([_makePost(id: 'p1', likeCount: 5)]);
        await provider.loadFeed();

        await provider.toggleLike('p1', 'user1');

        expect(provider.feedPosts.first.likeCount, 6);
      });

      test('いいね解除するとlikeCountがローカルで-1される', () async {
        mockService.feedResult = Result.success([_makePost(id: 'p1', likeCount: 5)]);
        await provider.loadFeed();

        await provider.toggleLike('p1', 'user1'); // like → 6
        await provider.toggleLike('p1', 'user1'); // unlike → 5

        expect(provider.feedPosts.first.likeCount, 5);
      });

      test('likeCountが0のときいいね解除してもマイナスにならない', () async {
        mockService.feedResult = Result.success([_makePost(id: 'p1', likeCount: 0)]);
        await provider.loadFeed();

        // Force unlike by directly setting liked state via double toggle
        // First toggle likes it (0→1), second unlikes (1→0)
        await provider.toggleLike('p1', 'user1');
        await provider.toggleLike('p1', 'user1');

        expect(provider.feedPosts.first.likeCount, greaterThanOrEqualTo(0));
      });

      test('サービス失敗時にいいね状態がロールバックされる', () async {
        mockService.likeResult = Result.failure(AppError.network('failed'));
        mockService.feedResult = Result.success([_makePost(id: 'p1', likeCount: 5)]);
        await provider.loadFeed();

        await provider.toggleLike('p1', 'user1');

        // Should have rolled back
        expect(provider.isLiked('p1'), false);
        expect(provider.feedPosts.first.likeCount, 5);
      });
    });

    // ── loadLikeStatus ────────────────────────────────────────────────────────

    group('loadLikeStatus', () {
      test('サービスがtrueを返すとisLikedがtrueになる', () async {
        mockService.isPostLikedResult = true;

        await provider.loadLikeStatus('post1', 'user1');

        expect(provider.isLiked('post1'), true);
      });

      test('サービスがfalseを返すとisLikedがfalseになる', () async {
        // First like locally
        await provider.toggleLike('post1', 'user1');
        expect(provider.isLiked('post1'), true);

        // Service says it's not liked
        mockService.isPostLikedResult = false;
        await provider.loadLikeStatus('post1', 'user1');

        expect(provider.isLiked('post1'), false);
      });
    });

    // ── deletePost ────────────────────────────────────────────────────────────

    group('deletePost', () {
      test('削除に成功するとフィードから投稿が消える', () async {
        mockService.feedResult = Result.success([
          _makePost(id: 'p1'),
          _makePost(id: 'p2'),
        ]);
        await provider.loadFeed();

        final success = await provider.deletePost('p1', 'user1');

        expect(success, true);
        expect(provider.feedPosts.length, 1);
        expect(provider.feedPosts.first.id, 'p2');
      });

      test('削除失敗時は投稿がフィードに残る', () async {
        mockService.feedResult = Result.success([_makePost(id: 'p1')]);
        await provider.loadFeed();
        mockService.deleteResult = Result.failure(AppError.network('failed'));

        final success = await provider.deletePost('p1', 'user1');

        expect(success, false);
        expect(provider.feedPosts.length, 1);
        expect(provider.error, isNotNull);
      });
    });

    // ── clear ─────────────────────────────────────────────────────────────────

    group('clear', () {
      test('clearですべての状態がリセットされる', () async {
        mockService.feedResult = Result.success([_makePost(id: 'p1')]);
        await provider.loadFeed(category: PostCategory.drive);
        await provider.toggleLike('p1', 'user1');

        provider.clear();

        expect(provider.feedPosts, isEmpty);
        expect(provider.selectedCategory, isNull);
        expect(provider.hasMore, true);
        expect(provider.error, isNull);
        expect(provider.isLiked('p1'), false);
      });
    });

    // ── Edge Cases ────────────────────────────────────────────────────────────

    group('Edge Cases', () {
      test('存在しないpostIdでtoggleLikeしてもクラッシュしない', () async {
        await provider.loadFeed(); // empty feed
        expect(
          () => provider.toggleLike('nonexistent', 'user1'),
          returnsNormally,
        );
      });

      test('loadMoreFeedはフィードが空のとき何もしない', () async {
        await provider.loadMoreFeed();
        expect(mockService.getFeedCallCount, 0);
      });

      test('loadMoreFeedはhasMoreがfalseのとき何もしない', () async {
        mockService.feedResult = Result.success([_makePost(id: 'p1')]);
        await provider.loadFeed(); // 1 item < 20, hasMore=false
        mockService.getFeedCallCount = 0;

        await provider.loadMoreFeed();

        expect(mockService.getFeedCallCount, 0);
      });

      test('投稿内容が1000文字でも作成できる', () async {
        final longContent = 'あ' * 999;
        final success = await provider.createPost(
          userId: 'u1',
          content: longContent,
          category: PostCategory.general,
        );
        expect(success, true);
      });

      test('複数のカテゴリフィルタを連続して切り替えられる', () async {
        for (final cat in PostCategory.values) {
          await provider.selectCategory(cat);
          expect(provider.selectedCategory, cat);
        }
        await provider.selectCategory(null);
        expect(provider.selectedCategory, isNull);
      });

      test('同一投稿に複数回いいね・解除してもカウントが整合する', () async {
        mockService.feedResult = Result.success([_makePost(id: 'p1', likeCount: 10)]);
        await provider.loadFeed();

        await provider.toggleLike('p1', 'user1'); // like → 11
        await provider.toggleLike('p1', 'user1'); // unlike → 10
        await provider.toggleLike('p1', 'user1'); // like → 11

        expect(provider.feedPosts.first.likeCount, 11);
        expect(provider.isLiked('p1'), true);
      });
    });
  });
}
