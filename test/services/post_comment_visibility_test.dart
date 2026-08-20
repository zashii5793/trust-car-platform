// 投稿のコメント一覧が取得できることのテスト。
//
// 背景: getComments は topLevelOnly のとき
//   where('parentCommentId', isNull: true)
// で絞っていた。Firestore の isNull は「フィールドが存在して値が null」に
// しかマッチせず、フィールド自体が無いドキュメントは返らない。
// 一方 Comment.toMap() は
//   if (parentCommentId != null) 'parentCommentId': parentCommentId,
// と省略して書くため、アプリが作ったトップレベルコメントは
// 一件も取得できなかった（commentCount は出るのに本文が読めない）。
//
// 「フィールドなし」と「明示的な null」の両方が取得できることを固定する。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/comment.dart';
import 'package:trust_car_platform/services/post_service.dart';

const _postId = 'post-1';

Future<void> _addComment(
  FakeFirebaseFirestore fs, {
  required String id,
  required String content,
  required int minutesAgo,
  Object? parentCommentId = #absent, // #absent = フィールド自体を書かない
}) async {
  final createdAt = DateTime(2026, 8, 18).subtract(Duration(minutes: minutesAgo));
  await fs.collection('comments').doc(id).set({
    'postId': _postId,
    'userId': 'user-a',
    'userDisplayName': '個人 太郎',
    'userPhotoUrl': null,
    'content': content,
    if (parentCommentId != #absent) 'parentCommentId': parentCommentId,
    'likeCount': 0,
    'replyCount': 0,
    'isEdited': false,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(createdAt),
  });
}

void main() {
  late FakeFirebaseFirestore fs;
  late PostService service;

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = PostService(firestore: fs);
  });

  group('getComments — トップレベルコメントの取得', () {
    test('parentCommentId フィールドが無いコメントも取得できる', () async {
      // アプリの Comment.toMap() が実際に書き込む形（フィールド省略）
      await _addComment(fs, id: 'c1', content: '最初のコメント', minutesAgo: 30);
      await _addComment(fs, id: 'c2', content: '2番目のコメント', minutesAgo: 20);

      final result = await service.getComments(postId: _postId);

      result.when(
        success: (comments) {
          expect(comments.map((c) => c.content).toList(),
              ['最初のコメント', '2番目のコメント'],
              reason: 'フィールドを省略して保存されたコメントが読めるべき');
        },
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('parentCommentId を明示的に null で保存したコメントも取得できる', () async {
      await _addComment(fs,
          id: 'c1', content: '明示null', minutesAgo: 10, parentCommentId: null);

      final result = await service.getComments(postId: _postId);

      result.when(
        success: (comments) => expect(comments, hasLength(1)),
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('返信は topLevelOnly の一覧に含まれない', () async {
      await _addComment(fs, id: 'c1', content: '親コメント', minutesAgo: 30);
      await _addComment(fs,
          id: 'c2', content: '返信', minutesAgo: 10, parentCommentId: 'c1');

      final result = await service.getComments(postId: _postId);

      result.when(
        success: (comments) {
          expect(comments.map((c) => c.content).toList(), ['親コメント'],
              reason: '返信はスレッド内に表示されるため一覧には出さない');
        },
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('topLevelOnly: false なら返信も含めて取得できる', () async {
      await _addComment(fs, id: 'c1', content: '親コメント', minutesAgo: 30);
      await _addComment(fs,
          id: 'c2', content: '返信', minutesAgo: 10, parentCommentId: 'c1');

      final result =
          await service.getComments(postId: _postId, topLevelOnly: false);

      result.when(
        success: (comments) => expect(comments, hasLength(2)),
        failure: (e) => fail('Expected success, got: $e'),
      );
    });
  });

  group('Comment.toMap', () {
    test('parentCommentId が null でもキーを書き出す', () {
      final comment = Comment(
        id: 'c1',
        postId: _postId,
        userId: 'user-a',
        content: 'トップレベル',
        createdAt: DateTime(2026, 8, 18),
        updatedAt: DateTime(2026, 8, 18),
      );

      final map = comment.toMap();

      expect(map.containsKey('parentCommentId'), isTrue,
          reason: 'キーが無いと isNull クエリにも参加できず、取りこぼしの原因になる');
      expect(map['parentCommentId'], isNull);
    });
  });

  group('Edge Cases', () {
    test('コメントが0件なら空リストを返す', () async {
      final result = await service.getComments(postId: _postId);

      result.when(
        success: (comments) => expect(comments, isEmpty),
        failure: (e) => fail('Expected success, got: $e'),
      );
    });

    test('他の投稿のコメントは混ざらない', () async {
      await _addComment(fs, id: 'c1', content: 'この投稿のコメント', minutesAgo: 10);
      await fs.collection('comments').doc('other').set({
        'postId': 'post-2',
        'userId': 'user-b',
        'content': '別投稿のコメント',
        'likeCount': 0,
        'replyCount': 0,
        'isEdited': false,
        'createdAt': Timestamp.fromDate(DateTime(2026, 8, 18)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 8, 18)),
      });

      final result = await service.getComments(postId: _postId);

      result.when(
        success: (comments) =>
            expect(comments.map((c) => c.content).toList(), ['この投稿のコメント']),
        failure: (e) => fail('Expected success, got: $e'),
      );
    });
  });
}
