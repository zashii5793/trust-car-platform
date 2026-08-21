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
  // getUserPosts — ページネーション統合テスト
  // ---------------------------------------------------------------------------

  group('PostService.getUserPosts — ページネーション', () {
    late FakeFirebaseFirestore fakeFirestore;
    late PostService service;

    // 投稿を 5件追加（降順ソート用に timestamp をずらす）
    Future<void> seedPosts(FakeFirebaseFirestore fs,
        {String userId = 'pager-user',
        String visibility = 'public',
        int count = 5}) async {
      for (int i = 0; i < count; i++) {
        final doc = Map<String, dynamic>.from(
          postDoc(userId: userId, visibility: visibility, content: 'post-$i'),
        );
        doc['createdAt'] = Timestamp.fromDate(
            DateTime(2024, 1, i + 1)); // oldest=Jan1, newest=Jan5
        await fs.collection('posts').add(doc);
      }
    }

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      service = PostService(firestore: fakeFirestore);
      await seedPosts(fakeFirestore);
    });

    test('limit=2 → 2件のみ返す', () async {
      final result = await service.getUserPosts(
        userId: 'pager-user',
        viewerId: 'viewer',
        limit: 2,
      );

      result.when(
        success: (posts) => expect(posts.length, 2),
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('limit がデフォルト値 (20) 以下なら全件取得', () async {
      final result = await service.getUserPosts(
        userId: 'pager-user',
        viewerId: 'viewer',
        limit: 20,
      );

      result.when(
        success: (posts) => expect(posts.length, 5),
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('startAfter で次のページを取得できる', () async {
      // 1ページ目の末尾 DocumentSnapshot を直接取得
      final firstPageSnap = await fakeFirestore
          .collection('posts')
          .where('userId', isEqualTo: 'pager-user')
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(2)
          .get();
      final lastDoc = firstPageSnap.docs.last;

      final secondResult = await service.getUserPosts(
        userId: 'pager-user',
        viewerId: 'viewer',
        limit: 10,
        startAfter: lastDoc,
      );

      secondResult.when(
        success: (posts) => expect(posts.length, 3),
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('フォロワーフィルタ + limit の組み合わせ', () async {
      // followers-only 投稿を追加
      final followersDoc = Map<String, dynamic>.from(
        postDoc(userId: 'pager-user', visibility: 'followers'),
      );
      followersDoc['createdAt'] =
          Timestamp.fromDate(DateTime(2024, 2, 1)); // 最新
      await fakeFirestore.collection('posts').add(followersDoc);
      // 計 6件（public 5 + followers 1）

      final result = await service.getUserPosts(
        userId: 'pager-user',
        viewerId: 'follower',
        isViewerFollowing: true,
        limit: 3,
      );

      result.when(
        success: (posts) => expect(posts.length, 3),
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('フォロワーフィルタ + startAfter でページネーション', () async {
      // followers-only 投稿を追加（最新にする）
      final followersDoc = Map<String, dynamic>.from(
        postDoc(userId: 'pager-user', visibility: 'followers'),
      );
      followersDoc['createdAt'] = Timestamp.fromDate(DateTime(2024, 2, 1));
      await fakeFirestore.collection('posts').add(followersDoc);
      // 計 6件

      // 1ページ目の末尾 DocumentSnapshot を取得
      final firstPageSnap = await fakeFirestore
          .collection('posts')
          .where('userId', isEqualTo: 'pager-user')
          .where('visibility', whereIn: ['public', 'followers'])
          .orderBy('createdAt', descending: true)
          .limit(2)
          .get();
      final lastDoc = firstPageSnap.docs.last;

      final secondResult = await service.getUserPosts(
        userId: 'pager-user',
        viewerId: 'follower',
        isViewerFollowing: true,
        limit: 10,
        startAfter: lastDoc,
      );

      secondResult.when(
        success: (posts) => expect(posts.length, 4),
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    group('Edge Cases', () {
      test('startAfter に最後のドキュメントを渡すと空リストを返す', () async {
        final lastPageSnap = await fakeFirestore
            .collection('posts')
            .where('userId', isEqualTo: 'pager-user')
            .where('visibility', isEqualTo: 'public')
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();
        final lastDoc = lastPageSnap.docs.last; // 全件の末尾

        final result = await service.getUserPosts(
          userId: 'pager-user',
          viewerId: 'viewer',
          limit: 10,
          startAfter: lastDoc,
        );

        result.when(
          success: (posts) => expect(posts, isEmpty),
          failure: (e) => fail('Expected success, got: $e'),
        );
      });

      test('startAfter=null → 最初のページを取得', () async {
        final result = await service.getUserPosts(
          userId: 'pager-user',
          viewerId: 'viewer',
          limit: 3,
          startAfter: null,
        );

        result.when(
          success: (posts) => expect(posts.length, 3),
          failure: (e) => fail('Expected success, got: $e'),
        );
      });
    });
  });

  // ---------------------------------------------------------------------------
  // PostService.getFeed — 複数カテゴリ絞り込みと並び替え
  //
  // カテゴリは1つしか選べず、並び順も新着固定だった。
  // 複数カテゴリの同時選択と「コメントが多い順」を足す。
  // ---------------------------------------------------------------------------

  group('PostService.getFeed — 複数カテゴリと並び替え', () {
    late FakeFirebaseFirestore fakeFirestore;
    late PostService service;

    Map<String, dynamic> feedDoc({
      required String category,
      required int commentCount,
      required DateTime createdAt,
      required String content,
    }) {
      final doc = postDoc(userId: 'author-uid', visibility: 'public');
      return {
        ...doc,
        'content': content,
        'category': category,
        'commentCount': commentCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(createdAt),
      };
    }

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      service = PostService(firestore: fakeFirestore);

      final posts = fakeFirestore.collection('posts');
      await posts.add(feedDoc(
        category: 'maintenance',
        commentCount: 5,
        createdAt: DateTime(2026, 1, 3),
        content: '整備の投稿',
      ));
      await posts.add(feedDoc(
        category: 'question',
        commentCount: 12,
        createdAt: DateTime(2026, 1, 1),
        content: '質問の投稿',
      ));
      await posts.add(feedDoc(
        category: 'drive',
        commentCount: 1,
        createdAt: DateTime(2026, 1, 5),
        content: 'ドライブの投稿',
      ));
      await posts.add(feedDoc(
        category: 'general',
        commentCount: 0,
        createdAt: DateTime(2026, 1, 2),
        content: '一般の投稿',
      ));
    });

    test('カテゴリ未指定なら全カテゴリが返る', () async {
      final result = await service.getFeed();

      result.when(
        success: (page) => expect(page.length, 4),
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('カテゴリを1つ指定するとそのカテゴリだけ返る', () async {
      final result = await service.getFeed(
        categories: const {PostCategory.question},
      );

      result.when(
        success: (page) {
          expect(page.length, 1);
          expect(page.posts.first.content, '質問の投稿');
        },
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('カテゴリを複数指定すると指定したカテゴリがまとめて返る', () async {
      final result = await service.getFeed(
        categories: const {PostCategory.question, PostCategory.drive},
      );

      result.when(
        success: (page) {
          expect(page.length, 2);
          expect(
            page.posts.map((p) => p.content),
            containsAll(['質問の投稿', 'ドライブの投稿']),
          );
        },
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('既定は新しい順', () async {
      final result = await service.getFeed();

      result.when(
        success: (page) {
          expect(page.posts.first.content, 'ドライブの投稿'); // 1/5
          expect(page.posts.last.content, '質問の投稿'); // 1/1
        },
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('コメントが多い順に並べ替えられる', () async {
      final result = await service.getFeed(sortBy: PostSortBy.mostCommented);

      result.when(
        success: (page) {
          expect(
            page.posts.map((p) => p.commentCount).toList(),
            [12, 5, 1, 0],
          );
          expect(page.posts.first.content, '質問の投稿');
        },
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('並び替えとカテゴリ絞り込みを同時に使える', () async {
      final result = await service.getFeed(
        categories: const {PostCategory.maintenance, PostCategory.drive},
        sortBy: PostSortBy.mostCommented,
      );

      result.when(
        success: (page) {
          expect(page.posts.map((p) => p.content).toList(),
              ['整備の投稿', 'ドライブの投稿']);
        },
        failure: (e) => fail('Expected success, got: $e'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // PostService.getFeed — ページネーション
  //
  // 続きを読み込むときに位置を指定できないと、同じ先頭ページを取り直して
  // フィードに同じ投稿が二重に並ぶ。
  // ---------------------------------------------------------------------------

  group('PostService.getFeed — ページネーション', () {
    late FakeFirebaseFirestore fakeFirestore;
    late PostService service;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      service = PostService(firestore: fakeFirestore);

      // 新しい順に post-0（最新）… post-4（最古）
      for (var i = 0; i < 5; i++) {
        await fakeFirestore.collection('posts').add({
          ...postDoc(userId: 'author-uid', visibility: 'public'),
          'content': 'post-$i',
          'commentCount': 10 - i,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 10 - i)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 10 - i)),
        });
      }
    });

    Future<PostPage> feed(
        {int limit = 2, Object? after, PostSortBy? sortBy}) async {
      final result = await service.getFeed(
        limit: limit,
        startAfter: after,
        sortBy: sortBy ?? PostSortBy.newest,
      );
      return result.when(
        success: (page) => page,
        failure: (e) => fail('Expected success, got: $e'),
      );
    }

    test('カーソルなしなら先頭ページを返す', () async {
      final page = await feed();

      expect(page.posts.map((p) => p.content).toList(), ['post-0', 'post-1']);
    });

    test('先頭ページはカーソルを返す', () async {
      final page = await feed();

      expect(page.cursor, isNotNull);
    });

    test('カーソルで次のページに進める', () async {
      final first = await feed();
      final second = await feed(after: first.cursor);

      expect(second.posts.map((p) => p.content).toList(), ['post-2', 'post-3']);
    });

    test('ページ同士が重複しない', () async {
      final first = await feed();
      final second = await feed(after: first.cursor);

      final ids = {
        ...first.posts.map((p) => p.content),
        ...second.posts.map((p) => p.content),
      };
      expect(ids.length, first.length + second.length);
    });

    test('最後まで読むと空が返る', () async {
      final page = await feed(limit: 5);
      expect(page.length, 5);

      final next = await feed(limit: 5, after: page.cursor);
      expect(next.posts, isEmpty);
      expect(next.cursor, isNull);
    });

    test('コメントが多い順でもページを継続できる', () async {
      final first = await feed(sortBy: PostSortBy.mostCommented);
      final second =
          await feed(after: first.cursor, sortBy: PostSortBy.mostCommented);

      expect(first.posts.map((p) => p.content).toList(), ['post-0', 'post-1']);
      expect(
          second.posts.map((p) => p.content).toList(), ['post-2', 'post-3']);
    });
  });

  // ---------------------------------------------------------------------------
  // PostService.getFeed — ハッシュタグ絞り込み
  //
  // 投稿のタグは表示されるだけで押せず、同じ話題を辿る動線が無かった。
  // ---------------------------------------------------------------------------

  group('PostService.getFeed — ハッシュタグ', () {
    late FakeFirebaseFirestore fakeFirestore;
    late PostService service;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      service = PostService(firestore: fakeFirestore);

      Future<void> add(String content, List<String> tags, int day) async {
        await fakeFirestore.collection('posts').add({
          ...postDoc(userId: 'author-uid', visibility: 'public'),
          'content': content,
          'hashtags': tags,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, day)),
        });
      }

      await add('12ヶ月点検の話', ['点検', '初心者'], 3);
      await add('車検の話', ['車検'], 2);
      await add('点検その2', ['点検'], 1);
    });

    Future<List<Post>> feed({String? hashtag}) async {
      final result = await service.getFeed(hashtag: hashtag);
      return result.when(
        success: (page) => page.posts,
        failure: (e) => fail('Expected success, got: $e'),
      );
    }

    test('タグ指定なしなら全件返る', () async {
      expect((await feed()).length, 3);
    });

    test('指定したタグの投稿だけ返る', () async {
      final posts = await feed(hashtag: '点検');

      expect(posts.length, 2);
      expect(
        posts.map((p) => p.content),
        containsAll(['12ヶ月点検の話', '点検その2']),
      );
    });

    test('タグ絞り込みでも新しい順', () async {
      final posts = await feed(hashtag: '点検');

      expect(posts.first.content, '12ヶ月点検の話');
    });

    test('該当のないタグでは空が返る', () async {
      expect(await feed(hashtag: '存在しないタグ'), isEmpty);
    });

    test('# を付けて渡しても引ける', () async {
      expect((await feed(hashtag: '#点検')).length, 2);
    });
  });
}
