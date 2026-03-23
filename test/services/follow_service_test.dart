// FollowService / Follow Model Unit Tests
//
// Since FollowService requires FirebaseFirestore, we test:
//   1. Self-follow validation logic (pure, no Firebase)
//   2. SocialNotification.message getter
//   3. NotificationType enum behavior
//   4. getUserProfiles chunk-splitting logic (verified via pure utility)
//   5. AppError patterns for service error scenarios

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/follow.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SocialNotification _makeNotification({
  String id = 'n1',
  String userId = 'user1',
  String actorId = 'actor1',
  String? actorDisplayName,
  NotificationType type = NotificationType.like,
  bool isRead = false,
}) {
  return SocialNotification(
    id: id,
    userId: userId,
    actorId: actorId,
    actorDisplayName: actorDisplayName,
    type: type,
    isRead: isRead,
    createdAt: DateTime.now(),
  );
}

/// Replicates the chunk-splitting logic from FollowService.getUserProfiles
List<List<String>> _splitIntoChunks(List<String> ids, int chunkSize) {
  final chunks = <List<String>>[];
  for (var i = 0; i < ids.length; i += chunkSize) {
    chunks.add(ids.sublist(
      i,
      i + chunkSize > ids.length ? ids.length : i + chunkSize,
    ));
  }
  return chunks;
}

/// Simulates self-follow validation (matches FollowService.followUser logic)
Result<void, AppError> _validateFollowUser({
  required String followerId,
  required String followingId,
}) {
  if (followerId == followingId) {
    return Result.failure(const AppError.validation(
      '自分自身をフォローすることはできません',
      field: 'followingId',
    ));
  }
  return const Result.success(null);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('NotificationType enum', () {
    test('全タイプの displayName が空でない', () {
      for (final type in NotificationType.values) {
        expect(type.displayName, isNotEmpty);
      }
    });

    test('fromString が既知の値を正しく変換する', () {
      expect(NotificationType.fromString('like'), NotificationType.like);
      expect(NotificationType.fromString('comment'), NotificationType.comment);
      expect(NotificationType.fromString('follow'), NotificationType.follow);
      expect(NotificationType.fromString('mention'), NotificationType.mention);
      expect(NotificationType.fromString('reply'), NotificationType.reply);
    });

    test('fromString が null を返す（不明な値）', () {
      expect(NotificationType.fromString(null), isNull);
      expect(NotificationType.fromString(''), isNull);
      expect(NotificationType.fromString('unknown'), isNull);
    });

    test('fromString: 全 enum 値を往復変換できる', () {
      for (final type in NotificationType.values) {
        expect(NotificationType.fromString(type.name), type);
      }
    });

    test('displayName が各タイプで異なる', () {
      final names = NotificationType.values.map((t) => t.displayName).toSet();
      expect(names.length, NotificationType.values.length);
    });
  });

  // ── SocialNotification.message ────────────────────────────────────────────

  group('SocialNotification.message', () {
    test('like: actorDisplayName あり → 「〜がいいねしました」', () {
      final n = _makeNotification(
        type: NotificationType.like,
        actorDisplayName: '田中太郎',
      );
      expect(n.message, '田中太郎があなたの投稿にいいねしました');
    });

    test('like: actorDisplayName null → 「ユーザーがいいねしました」', () {
      final n = _makeNotification(
        type: NotificationType.like,
        actorDisplayName: null,
      );
      expect(n.message, 'ユーザーがあなたの投稿にいいねしました');
    });

    test('comment: actorDisplayName あり → 「〜がコメントしました」', () {
      final n = _makeNotification(
        type: NotificationType.comment,
        actorDisplayName: '鈴木一郎',
      );
      expect(n.message, '鈴木一郎があなたの投稿にコメントしました');
    });

    test('comment: actorDisplayName null → フォールバック表示', () {
      final n = _makeNotification(
        type: NotificationType.comment,
        actorDisplayName: null,
      );
      expect(n.message, 'ユーザーがあなたの投稿にコメントしました');
    });

    test('follow: actorDisplayName あり → 「〜がフォローしました」', () {
      final n = _makeNotification(
        type: NotificationType.follow,
        actorDisplayName: '山田花子',
      );
      expect(n.message, '山田花子があなたをフォローしました');
    });

    test('follow: actorDisplayName null → フォールバック表示', () {
      final n = _makeNotification(
        type: NotificationType.follow,
        actorDisplayName: null,
      );
      expect(n.message, 'ユーザーがあなたをフォローしました');
    });

    test('mention: 「〜がメンションしました」', () {
      final n = _makeNotification(
        type: NotificationType.mention,
        actorDisplayName: '佐藤次郎',
      );
      expect(n.message, '佐藤次郎があなたをメンションしました');
    });

    test('mention: actorDisplayName null → フォールバック表示', () {
      final n = _makeNotification(
        type: NotificationType.mention,
        actorDisplayName: null,
      );
      expect(n.message, 'ユーザーがあなたをメンションしました');
    });

    test('reply: 「〜が返信しました」', () {
      final n = _makeNotification(
        type: NotificationType.reply,
        actorDisplayName: '高橋三郎',
      );
      expect(n.message, '高橋三郎があなたのコメントに返信しました');
    });

    test('reply: actorDisplayName null → フォールバック表示', () {
      final n = _makeNotification(
        type: NotificationType.reply,
        actorDisplayName: null,
      );
      expect(n.message, 'ユーザーがあなたのコメントに返信しました');
    });

    test('全 NotificationType で message が空でない', () {
      for (final type in NotificationType.values) {
        final n = _makeNotification(type: type);
        expect(n.message, isNotEmpty);
      }
    });
  });

  // ── SocialNotification モデル ─────────────────────────────────────────────

  group('SocialNotification モデル', () {
    test('isRead の初期値は false', () {
      final n = _makeNotification();
      expect(n.isRead, false);
    });

    test('copyWith で isRead を更新できる', () {
      final n = _makeNotification(isRead: false);
      final updated = n.copyWith(isRead: true);
      expect(updated.isRead, true);
      expect(updated.id, n.id);
    });

    test('id が等価性を決定する', () {
      final a = _makeNotification(id: 'n1', type: NotificationType.like);
      final b = _makeNotification(id: 'n1', type: NotificationType.follow);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('異なる id は等しくない', () {
      final a = _makeNotification(id: 'n1');
      final b = _makeNotification(id: 'n2');
      expect(a, isNot(equals(b)));
    });

    test('toMap で isRead が含まれる', () {
      final n = _makeNotification(isRead: true, type: NotificationType.like);
      final map = n.toMap();
      expect(map['isRead'], true);
      expect(map['type'], 'like');
      expect(map['userId'], 'user1');
      expect(map['actorId'], 'actor1');
    });
  });

  // ── 自己フォロー検証 ──────────────────────────────────────────────────────

  group('FollowService: 自己フォロー検証', () {
    test('followerId == followingId のとき ValidationError を返す', () {
      final result = _validateFollowUser(
        followerId: 'user1',
        followingId: 'user1',
      );
      expect(result.isFailure, true);
      result.when(
        success: (_) => fail('success should not be called'),
        failure: (error) {
          switch (error) {
            case ValidationError(:final message, :final field):
              expect(field, 'followingId');
              expect(message, contains('自分自身'));
            default:
              fail('wrong error type: $error');
          }
        },
      );
    });

    test('followerId != followingId のとき success を返す', () {
      final result = _validateFollowUser(
        followerId: 'user1',
        followingId: 'user2',
      );
      expect(result.isSuccess, true);
    });

    test('両方が空文字列でも自己フォロー扱いになる', () {
      final result = _validateFollowUser(followerId: '', followingId: '');
      expect(result.isFailure, true);
    });

    test('大文字小文字が異なる場合は別ユーザー扱い', () {
      final result = _validateFollowUser(
        followerId: 'User1',
        followingId: 'user1',
      );
      expect(result.isSuccess, true);
    });
  });

  // ── getUserProfiles チャンク分割 ──────────────────────────────────────────

  group('getUserProfiles: チャンク分割ロジック', () {
    test('空リストのとき空チャンクを返す', () {
      final chunks = _splitIntoChunks([], 10);
      expect(chunks, isEmpty);
    });

    test('10件以下のとき1チャンクになる', () {
      final ids = List.generate(5, (i) => 'u$i');
      final chunks = _splitIntoChunks(ids, 10);
      expect(chunks.length, 1);
      expect(chunks.first.length, 5);
    });

    test('ちょうど10件のとき1チャンクになる', () {
      final ids = List.generate(10, (i) => 'u$i');
      final chunks = _splitIntoChunks(ids, 10);
      expect(chunks.length, 1);
      expect(chunks.first.length, 10);
    });

    test('11件のとき2チャンク（10+1）になる', () {
      final ids = List.generate(11, (i) => 'u$i');
      final chunks = _splitIntoChunks(ids, 10);
      expect(chunks.length, 2);
      expect(chunks[0].length, 10);
      expect(chunks[1].length, 1);
    });

    test('25件のとき3チャンク（10+10+5）になる', () {
      final ids = List.generate(25, (i) => 'u$i');
      final chunks = _splitIntoChunks(ids, 10);
      expect(chunks.length, 3);
      expect(chunks[0].length, 10);
      expect(chunks[1].length, 10);
      expect(chunks[2].length, 5);
    });

    test('30件のとき3チャンク（10+10+10）になる', () {
      final ids = List.generate(30, (i) => 'u$i');
      final chunks = _splitIntoChunks(ids, 10);
      expect(chunks.length, 3);
      for (final chunk in chunks) {
        expect(chunk.length, 10);
      }
    });

    test('全チャンクをフラット化すると元のリストと同じ', () {
      final ids = List.generate(23, (i) => 'u$i');
      final chunks = _splitIntoChunks(ids, 10);
      final flat = chunks.expand((c) => c).toList();
      expect(flat, ids);
    });
  });

  // ── AppError パターン ─────────────────────────────────────────────────────

  group('AppError パターン（サービスエラーシナリオ）', () {
    test('validation error は isRetryable=false', () {
      const error = AppError.validation('自分自身をフォローすることはできません', field: 'followingId');
      expect(error.isRetryable, false);
    });

    test('validation error の userMessage が空でない', () {
      const error = AppError.validation('invalid', field: 'field');
      expect(error.userMessage, isNotEmpty);
    });

    test('network error は isRetryable=true', () {
      const error = AppError.network('connection failed');
      expect(error.isRetryable, true);
    });

    test('unknown error に originalError を含められる', () {
      final original = Exception('Firestore error');
      final error = AppError.unknown('予期しないエラー', originalError: original);
      expect(error.userMessage, isNotEmpty);
    });

    test('Result.failure で自己フォローエラーを表現できる', () {
      const result = Result<void, AppError>.failure(
        AppError.validation('自分自身をフォローすることはできません', field: 'followingId'),
      );
      expect(result.isFailure, true);
    });

    test('Result.success で正常フォローを表現できる', () {
      const result = Result<void, AppError>.success(null);
      expect(result.isSuccess, true);
    });
  });

  // ── Edge Cases ────────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('SocialNotification: actorDisplayName が空文字列でも message は正常', () {
      final n = _makeNotification(
        type: NotificationType.like,
        actorDisplayName: '',
      );
      // 空文字列は null でないため、フォールバックは使わない
      expect(n.message, 'があなたの投稿にいいねしました');
    });

    test('SocialNotification: 非常に長い actorDisplayName でも message は正常', () {
      final longName = 'あ' * 100;
      final n = _makeNotification(
        type: NotificationType.follow,
        actorDisplayName: longName,
      );
      expect(n.message, contains('フォローしました'));
      expect(n.message, contains(longName));
    });

    test('チャンク分割: 1件のとき1チャンク（1要素）', () {
      final chunks = _splitIntoChunks(['u1'], 10);
      expect(chunks.length, 1);
      expect(chunks.first, ['u1']);
    });

    test('自己フォロー検証: ID に特殊文字が含まれていても正常', () {
      const specialId = 'user@test.com';
      final result = _validateFollowUser(
        followerId: specialId,
        followingId: specialId,
      );
      expect(result.isFailure, true);
    });

    test('toMap: optionalフィールドが null のとき含まれない', () {
      final n = _makeNotification();
      final map = n.toMap();
      // postId, commentId, previewText が null なら key 自体なし
      expect(map.containsKey('postId'), false);
      expect(map.containsKey('commentId'), false);
      expect(map.containsKey('previewText'), false);
    });

    test('SocialNotification の toString が空でない', () {
      final n = _makeNotification(type: NotificationType.like);
      expect(n.toString(), isNotEmpty);
      expect(n.toString(), contains('like'));
    });
  });
}
