import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/comment.dart';

void main() {
  group('Comment', () {
    late Comment comment;

    setUp(() {
      comment = Comment(
        id: 'comment1',
        postId: 'post1',
        userId: 'user1',
        userDisplayName: 'テストユーザー',
        userPhotoUrl: 'https://example.com/photo.jpg',
        content: 'これはコメントです',
        likeCount: 5,
        replyCount: 2,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
    });

    test('creates with required fields', () {
      expect(comment.id, 'comment1');
      expect(comment.postId, 'post1');
      expect(comment.userId, 'user1');
      expect(comment.content, 'これはコメントです');
    });

    test('isTopLevel returns true for top-level comment', () {
      expect(comment.isTopLevel, true);
      expect(comment.isReply, false);
    });

    test('isReply returns true for reply comment', () {
      final reply = comment.copyWith(parentCommentId: 'parent1');

      expect(reply.isReply, true);
      expect(reply.isTopLevel, false);
    });

    test('toMap converts to map correctly', () {
      final map = comment.toMap();

      expect(map['postId'], 'post1');
      expect(map['userId'], 'user1');
      expect(map['content'], 'これはコメントです');
      expect(map['likeCount'], 5);
      expect(map['replyCount'], 2);
    });

    test('toMap includes parentCommentId when present', () {
      final reply = comment.copyWith(parentCommentId: 'parent1');
      final map = reply.toMap();

      expect(map['parentCommentId'], 'parent1');
    });

    test('copyWith creates modified copy', () {
      final modified = comment.copyWith(
        content: '新しいコメント',
        likeCount: 10,
      );

      expect(modified.content, '新しいコメント');
      expect(modified.likeCount, 10);
      expect(modified.postId, comment.postId);
    });

    test('equality is based on id', () {
      final comment2 = comment.copyWith(content: '別の内容');

      expect(comment == comment2, true);
      expect(comment.hashCode, comment2.hashCode);
    });

    test('toString returns readable format', () {
      expect(comment.toString(), contains('Comment('));
    });
  });

  group('CommentLike', () {
    test('creates with required fields', () {
      final like = CommentLike(
        id: 'like1',
        commentId: 'comment1',
        userId: 'user1',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(like.commentId, 'comment1');
      expect(like.userId, 'user1');
    });

    test('toMap converts to map', () {
      final like = CommentLike(
        id: 'like1',
        commentId: 'comment1',
        userId: 'user1',
        createdAt: DateTime(2024, 1, 1),
      );

      final map = like.toMap();

      expect(map['commentId'], 'comment1');
      expect(map['userId'], 'user1');
    });
  });
}
