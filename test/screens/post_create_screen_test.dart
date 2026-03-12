// PostCreateScreen Widget Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/screens/sns/post_create_screen.dart';
import 'package:trust_car_platform/providers/post_provider.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/post_service.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/models/post.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

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
    PostCategory? category,
    dynamic startAfter,
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
  Future<Result<void, AppError>> likePost(
          {required String postId, required String userId}) async =>
      const Result.success(null);

  @override
  Future<Result<void, AppError>> unlikePost(
          {required String postId, required String userId}) async =>
      const Result.success(null);

  @override
  Future<bool> isPostLiked(
          {required String postId, required String userId}) async => false;

  @override
  Future<Result<void, AppError>> deletePost(
          {required String postId, required String userId}) async =>
      const Result.success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockAuthService implements AuthService {
  @override
  Stream<dynamic> get authStateChanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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
    child: const MaterialApp(home: PostCreateScreen()),
  );
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

    testWidgets('画面タイトルが「投稿を作成」になっている', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));
      expect(find.text('投稿を作成'), findsOneWidget);
    });

    testWidgets('カテゴリチップが全種表示される', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));

      for (final cat in PostCategory.values) {
        expect(find.text(cat.displayName), findsWidgets);
      }
    });

    testWidgets('本文テキストフィールドが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));

      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('公開設定のラジオボタンが3種表示される', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));

      for (final vis in PostVisibility.values) {
        expect(find.text(vis.displayName), findsOneWidget);
      }
    });

    testWidgets('送信ボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));

      expect(find.text('投稿する'), findsOneWidget);
    });

    testWidgets('本文なしで送信するとバリデーションエラーになる', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));

      await tester.tap(find.text('投稿する'));
      await tester.pump();

      expect(mockService.createCallCount, 0);
      expect(find.text('本文を入力してください'), findsOneWidget);
    });

    testWidgets('空白のみで送信するとバリデーションエラーになる', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));

      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('投稿する'));
      await tester.pump();

      expect(mockService.createCallCount, 0);
    });

    testWidgets('本文を入力して送信するとcreatePostが呼ばれる', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));

      await tester.enterText(find.byType(TextFormField), 'テスト投稿です');
      await tester.tap(find.text('投稿する'));
      await tester.pump();

      expect(mockService.createCallCount, 1);
      expect(mockService.lastContent, 'テスト投稿です');
    });

    testWidgets('カテゴリを選択して投稿するとカテゴリが送信される', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));

      // 「メンテナンス」チップをタップ
      await tester.tap(
        find.text(PostCategory.maintenance.displayName).first,
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), 'メンテ記録です');
      await tester.tap(find.text('投稿する'));
      await tester.pump();

      expect(mockService.lastCategory, PostCategory.maintenance);
    });

    testWidgets('公開設定を変更して投稿するとvisibilityが送信される', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));

      await tester.tap(find.text(PostVisibility.followers.displayName));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), '投稿テスト');
      await tester.tap(find.text('投稿する'));
      await tester.pump();

      expect(mockService.lastVisibility, PostVisibility.followers);
    });

    testWidgets('文字数カウンタが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));

      expect(find.textContaining('/ 1000'), findsOneWidget);
    });

    testWidgets('文字を入力すると文字数カウンタが更新される', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));

      await tester.enterText(find.byType(TextFormField), 'あいう'); // 3文字
      await tester.pump();

      expect(find.text('3 / 1000'), findsOneWidget);
    });

    testWidgets('AppBarに投稿ボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));

      // AppBar の「投稿」テキストボタン
      expect(find.widgetWithText(TextButton, '投稿'), findsOneWidget);
    });

    testWidgets('AppBarの投稿ボタンからも送信できる', (tester) async {
      await tester.pumpWidget(_buildApp(mockService));

      await tester.enterText(find.byType(TextFormField), 'AppBarから投稿テスト');
      await tester.tap(find.widgetWithText(TextButton, '投稿'));
      await tester.pump();

      expect(mockService.createCallCount, 1);
    });

    testWidgets('サービス失敗時にSnackBarでエラーが表示される', (tester) async {
      mockService.createResult =
          Result.failure(AppError.network('connection failed'));

      await tester.pumpWidget(_buildApp(mockService));

      await tester.enterText(find.byType(TextFormField), '失敗する投稿');
      await tester.tap(find.text('投稿する'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    // ── Edge Cases ──────────────────────────────────────────────────────────

    group('Edge Cases', () {
      testWidgets('999文字の投稿は送信できる', (tester) async {
        await tester.pumpWidget(_buildApp(mockService));

        final longContent = 'あ' * 999;
        await tester.enterText(find.byType(TextFormField), longContent);
        await tester.tap(find.text('投稿する'));
        await tester.pump();

        expect(mockService.createCallCount, 1);
      });

      testWidgets('デフォルトカテゴリは「一般」になっている', (tester) async {
        await tester.pumpWidget(_buildApp(mockService));

        await tester.enterText(find.byType(TextFormField), '一般投稿');
        await tester.tap(find.text('投稿する'));
        await tester.pump();

        expect(mockService.lastCategory, PostCategory.general);
      });

      testWidgets('デフォルト公開設定は「全体公開」になっている', (tester) async {
        await tester.pumpWidget(_buildApp(mockService));

        await tester.enterText(find.byType(TextFormField), '公開投稿');
        await tester.tap(find.text('投稿する'));
        await tester.pump();

        expect(mockService.lastVisibility, PostVisibility.public);
      });

      testWidgets('カテゴリを複数回変更しても最後に選んだものが送信される', (tester) async {
        await tester.pumpWidget(_buildApp(mockService));

        await tester.tap(
            find.text(PostCategory.drive.displayName).first);
        await tester.pump();
        await tester.tap(
            find.text(PostCategory.review.displayName).first);
        await tester.pump();

        await tester.enterText(find.byType(TextFormField), 'レビュー投稿');
        await tester.tap(find.text('投稿する'));
        await tester.pump();

        expect(mockService.lastCategory, PostCategory.review);
      });

      testWidgets('投稿説明テキストのヒントが表示される', (tester) async {
        await tester.pumpWidget(_buildApp(mockService));

        expect(find.textContaining('ハッシュタグ'), findsOneWidget);
      });
    });
  });
}
