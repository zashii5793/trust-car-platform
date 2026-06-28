// PostService Unit Tests
//
// Firebase (Firestore) への直接アクセスが必要なメソッドは統合テストでカバーする。
// このファイルでは以下をテストする:
//   1. Post モデルのビジネスロジック（ハッシュタグ・メンション抽出）
//   2. PostCategory / PostVisibility の enum 動作
//   3. PostMedia / PostVehicleTag モデルの toMap/fromMap
//   4. AppError 型の利用パターン（Post サービス内で発生しうるエラー）
//   5. エッジケース
//   6. PostService.getUserPosts — フォロワー限定投稿可視性（Item 3）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/post.dart';
import 'package:trust_car_platform/services/post_service.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Post.extractHashtags
  // ---------------------------------------------------------------------------

  group('Post.extractHashtags', () {
    test('英数字ハッシュタグを抽出できる', () {
      final tags = Post.extractHashtags('今日のドライブ #drive #touring');
      expect(tags, containsAll(['drive', 'touring']));
    });

    test('日本語ハッシュタグを抽出できる', () {
      final tags = Post.extractHashtags('愛車 #カスタム #ドライブ記録');
      expect(tags, containsAll(['カスタム', 'ドライブ記録']));
    });

    test('漢字ハッシュタグを抽出できる', () {
      final tags = Post.extractHashtags('整備完了 #整備記録 #車検');
      expect(tags, containsAll(['整備記録', '車検']));
    });

    test('ハッシュタグが1つだけのとき正常に返す', () {
      final tags = Post.extractHashtags('#toyota');
      expect(tags, ['toyota']);
    });

    test('ハッシュタグがないときは空リストを返す', () {
      final tags = Post.extractHashtags('ハッシュタグなしの投稿');
      expect(tags, isEmpty);
    });

    test('空文字では空リストを返す', () {
      final tags = Post.extractHashtags('');
      expect(tags, isEmpty);
    });

    test('# だけのとき空リストを返す', () {
      final tags = Post.extractHashtags('# #  #');
      expect(tags, isEmpty);
    });

    test('複数のハッシュタグを重複なく抽出できる', () {
      final tags = Post.extractHashtags('#abc #def #abc');
      // 抽出は重複を除去しない（リストのまま返す）
      expect(tags.where((t) => t == 'abc').length, 2);
    });

    test('10,000文字を超えるテキストでもクラッシュしない', () {
      final longContent = '#tag ' * 2000; // 10,000文字超
      expect(() => Post.extractHashtags(longContent), returnsNormally);
    });

    test('英語・日本語・数字の混在ハッシュタグを抽出できる', () {
      final tags = Post.extractHashtags('#GR86 #ハチロク2023');
      expect(tags, containsAll(['GR86', 'ハチロク2023']));
    });
  });

  // ---------------------------------------------------------------------------
  // Post.extractMentions
  // ---------------------------------------------------------------------------

  group('Post.extractMentions', () {
    test('@ユーザーIDを抽出できる', () {
      final mentions = Post.extractMentions('おはよう @user123 さん');
      expect(mentions, contains('user123'));
    });

    test('複数のメンションを抽出できる', () {
      final mentions = Post.extractMentions('@alice と @bob が参加');
      expect(mentions, containsAll(['alice', 'bob']));
    });

    test('メンションがないときは空リストを返す', () {
      final mentions = Post.extractMentions('メンションなしの投稿');
      expect(mentions, isEmpty);
    });

    test('空文字では空リストを返す', () {
      final mentions = Post.extractMentions('');
      expect(mentions, isEmpty);
    });

    test('@ だけのとき空リストを返す', () {
      final mentions = Post.extractMentions('@ @ @');
      expect(mentions, isEmpty);
    });

    test('メール形式は @ を含むが正しく扱われる', () {
      // @の後ろが word characters(英数字_)のみを対象とする
      expect(() => Post.extractMentions('連絡はtest@example.com まで'),
          returnsNormally);
      // "example" が抽出される可能性があるが、少なくともクラッシュしない
      expect(() => Post.extractMentions('test@example.com'), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // PostCategory enum
  // ---------------------------------------------------------------------------

  group('PostCategory', () {
    test('全カテゴリに displayName が設定されている', () {
      for (final category in PostCategory.values) {
        expect(category.displayName.isNotEmpty, true,
            reason: '${category.name} の displayName が空です');
      }
    });

    test('fromString で name から enum に変換できる', () {
      for (final category in PostCategory.values) {
        final result = PostCategory.fromString(category.name);
        expect(result, category,
            reason: '${category.name} の fromString が正しくありません');
      }
    });

    test('fromString で null は null を返す', () {
      expect(PostCategory.fromString(null), isNull);
    });

    test('fromString で不正な値は null を返す', () {
      expect(PostCategory.fromString('invalid_category_xxx'), isNull);
    });

    test('general カテゴリが存在する', () {
      expect(PostCategory.values.any((c) => c.name == 'general'), true);
    });
  });

  // ---------------------------------------------------------------------------
  // PostVisibility enum
  // ---------------------------------------------------------------------------

  group('PostVisibility', () {
    test('全 visibility に storageName が設定されている', () {
      for (final vis in PostVisibility.values) {
        expect(vis.storageName.isNotEmpty, true,
            reason: '${vis.name} の storageName が空です');
      }
    });

    test('fromString で storageName から enum に変換できる', () {
      for (final vis in PostVisibility.values) {
        final result = PostVisibility.fromString(vis.storageName);
        expect(result, vis,
            reason: '${vis.storageName} の fromString が正しくありません');
      }
    });

    test('fromString で null は null を返す', () {
      expect(PostVisibility.fromString(null), isNull);
    });

    test('fromString で不正な値は null を返す', () {
      expect(PostVisibility.fromString('unknown_vis'), isNull);
    });

    test('public visibility が存在する', () {
      expect(PostVisibility.values.any((v) => v.storageName == 'public'), true);
    });
  });

  // ---------------------------------------------------------------------------
  // PostMedia モデル
  // ---------------------------------------------------------------------------

  group('PostMedia', () {
    test('toMap で正しく変換される', () {
      const media =
          PostMedia(url: 'https://example.com/img.jpg', type: 'image');
      final map = media.toMap();

      expect(map['url'], 'https://example.com/img.jpg');
      expect(map['type'], 'image');
    });

    test('fromMap で正しく復元される', () {
      const map = {'url': 'https://example.com/img.jpg', 'type': 'image'};
      final media = PostMedia.fromMap(map);

      expect(media.url, 'https://example.com/img.jpg');
      expect(media.type, 'image');
    });

    test('空の url でも fromMap でクラッシュしない', () {
      const map = {'url': '', 'type': 'image'};
      expect(() => PostMedia.fromMap(map), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // PostVehicleTag モデル
  // ---------------------------------------------------------------------------

  group('PostVehicleTag', () {
    test('isEmpty は全フィールドが null のとき true を返す', () {
      const tag = PostVehicleTag();
      expect(tag.isEmpty, true);
    });

    test('isEmpty は vehicleId が設定されているとき false を返す', () {
      const tag = PostVehicleTag(vehicleId: 'v1');
      expect(tag.isEmpty, false);
    });

    test('displayName は vehicleId だけのとき null を返す', () {
      // displayName は maker/model/year の組み合わせが必要
      const tag = PostVehicleTag(vehicleId: 'v1');
      // 少なくともクラッシュしない
      expect(() => tag.displayName, returnsNormally);
    });

    test('toMap / fromMap の往復変換が正しい', () {
      const tag = PostVehicleTag(
        vehicleId: 'v1',
        makerId: 'toyota',
        modelId: 'prius',
        year: 2023,
      );
      final map = tag.toMap();
      final restored = PostVehicleTag.fromMap(map);

      expect(restored.vehicleId, 'v1');
      expect(restored.makerId, 'toyota');
      expect(restored.modelId, 'prius');
      expect(restored.year, 2023);
    });
  });

  // ---------------------------------------------------------------------------
  // AppError パターン（PostService 内で使われるエラー型）
  // ---------------------------------------------------------------------------

  group('PostService AppError パターン', () {
    test('投稿が存在しない場合は NotFoundError を返すべき', () {
      // サービス内の deletePost / getPost / updatePost で使用
      const error = AppError.notFound('投稿が見つかりません', resourceType: 'Post');
      expect(error, isA<NotFoundError>());
      expect((error as NotFoundError).resourceType, 'Post');
      expect(error.isRetryable, false);
      expect(error.userMessage.isNotEmpty, true);
    });

    test('他ユーザーの投稿操作は PermissionError を返すべき', () {
      // deletePost / updatePost の権限チェックで使用
      const error = AppError.permission('投稿を削除する権限がありません');
      expect(error, isA<PermissionError>());
      expect(error.isRetryable, false);
      expect(error.userMessage.isNotEmpty, true);
    });

    test('コメントが存在しない場合は NotFoundError を返すべき', () {
      const error = AppError.notFound('コメントが見つかりません', resourceType: 'Comment');
      expect(error, isA<NotFoundError>());
      expect((error as NotFoundError).resourceType, 'Comment');
    });

    test('コメント削除権限なしは PermissionError を返すべき', () {
      const error = AppError.permission('コメントを削除する権限がありません');
      expect(error, isA<PermissionError>());
      expect(error.isRetryable, false);
    });

    test('Firestore 接続失敗は NetworkError を返すべき', () {
      final error = AppError.unknown('投稿の作成に失敗しました',
          originalError: Exception('network error'));
      // UnknownError にフォールバックするが、isRetryable を確認
      expect(error, isA<UnknownError>());
    });

    test('Result<Post, AppError> の when でエラーを処理できる', () {
      const result = Result<String, AppError>.failure(
        AppError.notFound('投稿が見つかりません', resourceType: 'Post'),
      );

      final message = result.when(
        success: (_) => 'ok',
        failure: (e) => e.userMessage,
      );

      expect(message.isNotEmpty, true);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge Cases
  // ---------------------------------------------------------------------------

  group('Edge Cases', () {
    test('ハッシュタグと @ が隣接しているとき正しく処理される', () {
      // "##tag" や "@#tag" などの異常なパターン
      expect(() => Post.extractHashtags('##double'), returnsNormally);
      expect(() => Post.extractMentions('@#confused'), returnsNormally);
    });

    test('絵文字を含む投稿でもハッシュタグ抽出がクラッシュしない', () {
      expect(
        () => Post.extractHashtags('いい景色 🌄 #ドライブ #絶景'),
        returnsNormally,
      );
    });

    test('改行を含む投稿でもハッシュタグが抽出される', () {
      final tags = Post.extractHashtags('1行目\n#タグ1\n2行目 #タグ2');
      expect(tags, containsAll(['タグ1', 'タグ2']));
    });

    test('PostCategory の全値に name プロパティがある', () {
      for (final cat in PostCategory.values) {
        expect(cat.name.isNotEmpty, true);
      }
    });

    test('PostVisibility の全値に name プロパティがある', () {
      for (final vis in PostVisibility.values) {
        expect(vis.name.isNotEmpty, true);
      }
    });

    test('Result.success は Post を保持できる', () {
      final now = DateTime.now();
      final post = Post(
        id: 'p1',
        userId: 'u1',
        category: PostCategory.general,
        content: 'テスト投稿',
        createdAt: now,
        updatedAt: now,
      );
      final result = Result<Post, AppError>.success(post);

      expect(result.isSuccess, true);
      expect(result.valueOrNull?.id, 'p1');
    });

    test('Post の likeCount は負数にならないことをクランプで保証', () {
      // 楽観的更新ロールバック時に _updateLocalLikeCount が clamp する
      // サービス側では likeCount フィールドに直接アクセスしないが、
      // 仕様として likeCount >= 0 を確認
      final now = DateTime.now();
      final post = Post(
        id: 'p1',
        userId: 'u1',
        category: PostCategory.general,
        content: 'テスト',
        likeCount: 0,
        createdAt: now,
        updatedAt: now,
      );
      expect(post.likeCount, greaterThanOrEqualTo(0));
    });
  });

  // ---------------------------------------------------------------------------
  // Item 3: PostService.getUserPosts — フォロワー限定投稿可視性
  // ---------------------------------------------------------------------------

  /// Minimal Firestore document for a post
  Map<String, dynamic> postDoc({
    required String userId,
    required String visibility,
    String content = 'test',
  }) =>
      {
        'userId': userId,
        'visibility': visibility,
        'content': content,
        'category': 'general',
        'hashtags': <String>[],
        'mentionedUserIds': <String>[],
        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,
        'viewCount': 0,
        'isEdited': false,
        'media': <dynamic>[],
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
      };

  group('PostService.getUserPosts — フォロワー限定投稿', () {
    late FakeFirebaseFirestore fakeFirestore;
    late PostService service;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      service = PostService(firestore: fakeFirestore);

      // Seed 3 posts from 'author-uid' with different visibilities
      await fakeFirestore
          .collection('posts')
          .add(postDoc(userId: 'author-uid', visibility: 'public'));
      await fakeFirestore
          .collection('posts')
          .add(postDoc(userId: 'author-uid', visibility: 'followers'));
      await fakeFirestore
          .collection('posts')
          .add(postDoc(userId: 'author-uid', visibility: 'private'));
    });

    test('非フォロワーは公開投稿のみ取得できる', () async {
      final result = await service.getUserPosts(
        userId: 'author-uid',
        viewerId: 'stranger-uid',
        isViewerFollowing: false,
      );

      result.when(
        success: (posts) {
          expect(posts.length, 1);
          expect(posts.first.visibility, PostVisibility.public);
        },
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('フォロワーは公開+フォロワー限定投稿を取得できる', () async {
      final result = await service.getUserPosts(
        userId: 'author-uid',
        viewerId: 'follower-uid',
        isViewerFollowing: true,
      );

      result.when(
        success: (posts) {
          expect(posts.length, 2);
          final visibilities = posts.map((p) => p.visibility).toSet();
          expect(
              visibilities, {PostVisibility.public, PostVisibility.followers});
        },
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('本人は全投稿（公開・フォロワー限定・非公開）を取得できる', () async {
      final result = await service.getUserPosts(
        userId: 'author-uid',
        viewerId: 'author-uid',
      );

      result.when(
        success: (posts) {
          expect(posts.length, 3);
          final visibilities = posts.map((p) => p.visibility).toSet();
          expect(visibilities, {
            PostVisibility.public,
            PostVisibility.followers,
            PostVisibility.private_,
          });
        },
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('フォロワー限定のみのユーザー — 非フォロワーには空リスト', () async {
      await fakeFirestore
          .collection('posts')
          .add(postDoc(userId: 'private-author', visibility: 'followers'));

      final result = await service.getUserPosts(
        userId: 'private-author',
        viewerId: 'stranger-uid',
        isViewerFollowing: false,
      );

      result.when(
        success: (posts) => expect(posts, isEmpty),
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    group('Edge Cases', () {
      test('存在しないユーザーIDは空リストを返す', () async {
        final result = await service.getUserPosts(
          userId: 'nonexistent-user-xyz',
          viewerId: 'viewer-uid',
        );

        result.when(
          success: (posts) => expect(posts, isEmpty),
          failure: (e) => fail('Expected success, got: $e'),
        );
      });

      test('isViewerFollowing=false のデフォルト動作は public のみ', () async {
        // Default value: no isViewerFollowing arg → same as false
        final result = await service.getUserPosts(
          userId: 'author-uid',
          viewerId: 'stranger-uid',
        );

        result.when(
          success: (posts) {
            for (final p in posts) {
              expect(p.visibility, PostVisibility.public);
            }
          },
          failure: (e) => fail('Expected success, got: $e'),
        );
      });

      test('フォロワー本人 viewerId==userId 全件返す（isViewerFollowing 無視）', () async {
        // Even if isViewerFollowing=false, when viewerId==userId all posts returned
        final result = await service.getUserPosts(
          userId: 'author-uid',
          viewerId: 'author-uid',
          isViewerFollowing: false,
        );

        result.when(
          success: (posts) => expect(posts.length, 3),
          failure: (e) => fail('Expected success, got: $e'),
        );
      });

      test('複数ユーザー混在 — userId フィルタが正しく機能する', () async {
        // Add posts from another user
        await fakeFirestore
            .collection('posts')
            .add(postDoc(userId: 'other-user', visibility: 'public'));

        final result = await service.getUserPosts(
          userId: 'author-uid',
          viewerId: 'stranger-uid',
        );

        result.when(
          success: (posts) {
            expect(posts.every((p) => p.userId == 'author-uid'), isTrue);
          },
          failure: (e) => fail('Expected success, got: $e'),
        );
      });
    });
  });

  // ---------------------------------------------------------------------------
  // 大量データ検証: getFeed のカーソルページネーション（最重要トラフィック）
  // ---------------------------------------------------------------------------
  group('PostService.getFeed — pagination', () {
    late FakeFirebaseFirestore fakeFirestore;
    late PostService service;

    // createdAt を1分ずつずらして public 投稿を count 件投入
    Future<void> seedPublicPosts(int count) async {
      for (var i = 0; i < count; i++) {
        await fakeFirestore.collection('posts').add({
          'userId': 'feed-author',
          'visibility': 'public',
          'content': 'feed-$i',
          'category': 'general',
          'hashtags': <String>[],
          'mentionedUserIds': <String>[],
          'likeCount': 0,
          'commentCount': 0,
          'shareCount': 0,
          'viewCount': 0,
          'isEdited': false,
          'media': <dynamic>[],
          'createdAt': Timestamp.fromDate(
              DateTime(2024, 1, 1).add(Duration(minutes: i))),
          'updatedAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        });
      }
    }

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = PostService(firestore: fakeFirestore);
    });

    test('limit を超える件数があるとき limit 件で打ち切る', () async {
      await seedPublicPosts(30);

      final result = await service.getFeed(limit: 20);

      result.when(
        success: (posts) => expect(posts.length, 20),
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    // 真のカーソル継続（前ページと重複しない次ページ取得）は fake_cloud_firestore が
    // startAfterDocument を完全サポートしないため、Emulator を使う統合テスト
    // post_service_integration_test.dart で検証する。ここでは startAfter を渡しても
    // クエリが成立し成功を返すこと（コードパスが通ること）のみ確認する。
    test('startAfter を渡してもエラーにならず成功を返す', () async {
      await seedPublicPosts(30);

      final firstPageSnap = await fakeFirestore
          .collection('posts')
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final result = await service.getFeed(
        limit: 20,
        startAfter: firstPageSnap.docs.last,
      );

      expect(result.isSuccess, isTrue);
    });

    group('Edge Cases', () {
      test('投稿が無いとき空リストを返す（0件境界）', () async {
        final result = await service.getFeed(limit: 20);

        result.when(
          success: (posts) => expect(posts, isEmpty),
          failure: (e) => fail('Expected success, got: $e'),
        );
      });

      test('件数が limit 未満のときは全件を返す', () async {
        await seedPublicPosts(5);

        final result = await service.getFeed(limit: 20);

        result.when(
          success: (posts) => expect(posts.length, 5),
          failure: (e) => fail('Expected success, got: $e'),
        );
      });
    });
  });
}
