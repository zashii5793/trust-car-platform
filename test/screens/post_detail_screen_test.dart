// PostDetailScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows '投稿の詳細' title
//     2. Delete button hidden for non-owner
//     3. Delete button visible for post owner
//   Post body:
//     4. Shows post content
//     5. Shows author display name
//     6. Shows like count
//     7. Shows hashtags
//     8. Shows category badge
//   Comments section:
//     9. Shows 'コメント' header
//    10. Shows spinner while loading comments
//    11. Shows 'まだコメントがありません' when comments empty
//    12. Shows comment content when loaded
//    13. Shows comment author display name
//   Comment input:
//    14. Shows comment input field
//    15. Empty comment does not call addComment
//    16. Non-empty comment calls addComment
//   Like:
//    17. Like count displayed
//    18. Logged-in user can toggle like
//   Edge Cases:
//    19. Post with no hashtags → no hashtag text
//    20. Multiple comments all displayed

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;

import 'package:trust_car_platform/screens/sns/post_detail_screen.dart';
import 'package:trust_car_platform/providers/post_provider.dart';
import 'package:trust_car_platform/providers/auth_provider.dart';
import 'package:trust_car_platform/services/auth_service.dart';
import 'package:trust_car_platform/services/post_service.dart';
import 'package:trust_car_platform/models/post.dart';
import 'package:trust_car_platform/models/comment.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

// ---------------------------------------------------------------------------
// Stubs
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

class _FakeFirebaseUser implements User {
  final String _uid;
  @override
  String get uid => _uid;
  @override
  String? get displayName => 'テストユーザー';
  @override
  String? get photoURL => null;
  @override
  String? get email => 'test@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  _FakeFirebaseUser(this._uid);
}

// ---------------------------------------------------------------------------
// Fake PostProvider
// ---------------------------------------------------------------------------

class _FakePostService implements PostService {
  List<Comment> commentsToReturn = [];
  bool addCommentShouldSucceed = true;
  bool deletePostShouldSucceed = true;
  int addCommentCallCount = 0;
  int likeToggleCallCount = 0;

  @override
  Future<Result<List<Comment>, AppError>> getComments({
    required String postId,
    int limit = 50,
    dynamic startAfter,
    bool topLevelOnly = true,
  }) async {
    return Result.success(commentsToReturn);
  }

  @override
  Future<Result<Comment, AppError>> addComment({
    required String postId,
    required String userId,
    String? userDisplayName,
    String? userPhotoUrl,
    required String content,
    String? parentCommentId,
    String? postAuthorId,
  }) async {
    addCommentCallCount++;
    if (addCommentShouldSucceed) {
      final now = DateTime.now();
      return Result.success(Comment(
        id: 'new-comment',
        postId: postId,
        userId: userId,
        userDisplayName: userDisplayName,
        content: content,
        createdAt: now,
        updatedAt: now,
      ));
    }
    return Result.failure(AppError.server('失敗'));
  }

  @override
  Future<Result<void, AppError>> deletePost({
    required String postId,
    required String userId,
  }) async {
    if (deletePostShouldSucceed) {
      return const Result.success(null);
    }
    return Result.failure(AppError.server('失敗'));
  }

  @override
  Future<Result<void, AppError>> likePost({
    required String postId,
    required String userId,
  }) async {
    likeToggleCallCount++;
    return const Result.success(null);
  }

  @override
  Future<Result<void, AppError>> unlikePost({
    required String postId,
    required String userId,
  }) async {
    likeToggleCallCount++;
    return const Result.success(null);
  }

  @override
  Future<bool> isPostLiked({
    required String postId,
    required String userId,
  }) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAuthProvider extends AuthProvider {
  final String? _uid;

  _FakeAuthProvider({String? uid})
      : _uid = uid,
        super(authService: _StubAuthService());

  @override
  User? get firebaseUser => _uid != null ? _FakeFirebaseUser(_uid!) : null;

  @override
  bool get isLoading => false;
}

// ---------------------------------------------------------------------------
// Test data factories
// ---------------------------------------------------------------------------

Post _makePost({
  String id = 'post-1',
  String userId = 'author-uid',
  String? userDisplayName = 'テスト投稿者',
  String content = 'テスト投稿内容',
  List<String> hashtags = const [],
  int likeCount = 5,
  int commentCount = 3,
  PostCategory category = PostCategory.general,
}) {
  final now = DateTime(2025, 6, 1, 12, 0);
  return Post(
    id: id,
    userId: userId,
    userDisplayName: userDisplayName,
    category: category,
    content: content,
    hashtags: hashtags,
    likeCount: likeCount,
    commentCount: commentCount,
    createdAt: now,
    updatedAt: now,
  );
}

Comment _makeComment({
  String id = 'comment-1',
  String postId = 'post-1',
  String userId = 'commenter-uid',
  String? userDisplayName = 'コメント投稿者',
  String content = 'テストコメント',
}) {
  final now = DateTime(2025, 6, 1, 13, 0);
  return Comment(
    id: id,
    postId: postId,
    userId: userId,
    userDisplayName: userDisplayName,
    content: content,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen(
  Post post, {
  String? loggedInUid,
  _FakePostService? postService,
}) {
  final svc = postService ?? _FakePostService();
  final postProvider = PostProvider(postService: svc);
  final authProvider = _FakeAuthProvider(uid: loggedInUid);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<PostProvider>.value(value: postProvider),
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
    ],
    child: MaterialApp(
      home: PostDetailScreen(post: post),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PostDetailScreen — AppBar', () {
    testWidgets('1. shows 投稿の詳細 title', (tester) async {
      await tester.pumpWidget(_buildScreen(_makePost()));
      await tester.pumpAndSettle();

      expect(find.text('投稿の詳細'), findsOneWidget);
    });

    testWidgets('2. delete button hidden for non-owner', (tester) async {
      final post = _makePost(userId: 'author-uid');
      await tester.pumpWidget(
        _buildScreen(post, loggedInUid: 'other-uid'),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('3. delete button visible for post owner', (tester) async {
      final post = _makePost(userId: 'author-uid');
      await tester.pumpWidget(
        _buildScreen(post, loggedInUid: 'author-uid'),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });

  group('PostDetailScreen — Post body', () {
    testWidgets('4. shows post content', (tester) async {
      final post = _makePost(content: 'これは投稿のテスト本文です');
      await tester.pumpWidget(_buildScreen(post));
      await tester.pumpAndSettle();

      expect(find.text('これは投稿のテスト本文です'), findsOneWidget);
    });

    testWidgets('5. shows author display name', (tester) async {
      final post = _makePost(userDisplayName: '山田太郎');
      await tester.pumpWidget(_buildScreen(post));
      await tester.pumpAndSettle();

      expect(find.text('山田太郎'), findsOneWidget);
    });

    testWidgets('6. shows like count', (tester) async {
      final post = _makePost(likeCount: 42);
      await tester.pumpWidget(_buildScreen(post));
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('7. shows hashtags', (tester) async {
      final post = _makePost(hashtags: ['クルマ', 'DIY']);
      await tester.pumpWidget(_buildScreen(post));
      await tester.pumpAndSettle();

      expect(find.textContaining('#クルマ'), findsOneWidget);
      expect(find.textContaining('#DIY'), findsOneWidget);
    });

    testWidgets('8. shows category badge', (tester) async {
      final post = _makePost(category: PostCategory.maintenance);
      await tester.pumpWidget(_buildScreen(post));
      await tester.pumpAndSettle();

      // Category badge renders the displayName
      expect(find.text('メンテナンス'), findsOneWidget);
    });
  });

  group('PostDetailScreen — Comments section', () {
    testWidgets('9. shows コメント header', (tester) async {
      await tester.pumpWidget(_buildScreen(_makePost()));
      await tester.pumpAndSettle();

      expect(find.text('コメント'), findsOneWidget);
    });

    testWidgets('10. shows spinner while loading', (tester) async {
      await tester.pumpWidget(_buildScreen(_makePost()));
      await tester.pump(); // single tick — still loading

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('11. shows まだコメントがありません when empty', (tester) async {
      await tester.pumpWidget(_buildScreen(_makePost()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('まだコメントがありません'),
        findsOneWidget,
      );
    });

    testWidgets('12. shows comment content when loaded', (tester) async {
      final svc = _FakePostService()
        ..commentsToReturn = [_makeComment(content: 'すごい投稿ですね！')];
      await tester.pumpWidget(_buildScreen(_makePost(), postService: svc));
      await tester.pumpAndSettle();

      expect(find.text('すごい投稿ですね！'), findsOneWidget);
    });

    testWidgets('13. shows comment author display name', (tester) async {
      final svc = _FakePostService()
        ..commentsToReturn = [_makeComment(userDisplayName: '鈴木コメント者')];
      await tester.pumpWidget(_buildScreen(_makePost(), postService: svc));
      await tester.pumpAndSettle();

      expect(find.text('鈴木コメント者'), findsOneWidget);
    });
  });

  group('PostDetailScreen — Comment input', () {
    testWidgets('14. shows comment input field', (tester) async {
      await tester.pumpWidget(_buildScreen(_makePost()));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('15. empty comment does not call addComment', (tester) async {
      final svc = _FakePostService();
      await tester.pumpWidget(
        _buildScreen(_makePost(), loggedInUid: 'user-uid', postService: svc),
      );
      await tester.pumpAndSettle();

      // Send button with empty field
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(svc.addCommentCallCount, equals(0));
    });

    testWidgets('16. non-empty comment calls addComment', (tester) async {
      final svc = _FakePostService();
      await tester.pumpWidget(
        _buildScreen(_makePost(), loggedInUid: 'user-uid', postService: svc),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'テストコメントを投稿します');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(svc.addCommentCallCount, greaterThan(0));
    });
  });

  group('PostDetailScreen — Like', () {
    testWidgets('17. like count displayed', (tester) async {
      final post = _makePost(likeCount: 7);
      await tester.pumpWidget(_buildScreen(post));
      await tester.pumpAndSettle();

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('18. logged-in user can tap like', (tester) async {
      final svc = _FakePostService();
      await tester.pumpWidget(
        _buildScreen(_makePost(), loggedInUid: 'user-uid', postService: svc),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(svc.likeToggleCallCount, greaterThan(0));
    });
  });

  group('PostDetailScreen — Edge Cases', () {
    testWidgets('19. post with no hashtags has no # text', (tester) async {
      final post = _makePost(hashtags: []);
      await tester.pumpWidget(_buildScreen(post));
      await tester.pumpAndSettle();

      expect(find.textContaining('#'), findsNothing);
    });

    testWidgets('20. multiple comments all displayed', (tester) async {
      final svc = _FakePostService()
        ..commentsToReturn = [
          _makeComment(id: 'c1', content: 'コメントA'),
          _makeComment(id: 'c2', content: 'コメントB'),
          _makeComment(id: 'c3', content: 'コメントC'),
        ];
      await tester.pumpWidget(_buildScreen(_makePost(), postService: svc));
      await tester.pumpAndSettle();

      expect(find.text('コメントA'), findsOneWidget);
      expect(find.text('コメントB'), findsOneWidget);
      expect(find.text('コメントC'), findsOneWidget);
    });
  });
}
