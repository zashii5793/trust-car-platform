import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/follow.dart';

void main() {
  group('Follow', () {
    test('creates with required fields', () {
      final follow = Follow(
        id: 'follow1',
        followerId: 'user1',
        followingId: 'user2',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(follow.id, 'follow1');
      expect(follow.followerId, 'user1');
      expect(follow.followingId, 'user2');
    });

    test('toMap converts to map', () {
      final follow = Follow(
        id: 'follow1',
        followerId: 'user1',
        followingId: 'user2',
        createdAt: DateTime(2024, 1, 1),
      );

      final map = follow.toMap();

      expect(map['followerId'], 'user1');
      expect(map['followingId'], 'user2');
    });

    test('equality is based on id', () {
      final follow1 = Follow(
        id: 'follow1',
        followerId: 'user1',
        followingId: 'user2',
        createdAt: DateTime(2024, 1, 1),
      );
      final follow2 = Follow(
        id: 'follow1',
        followerId: 'user3',
        followingId: 'user4',
        createdAt: DateTime(2024, 1, 2),
      );

      expect(follow1 == follow2, true);
      expect(follow1.hashCode, follow2.hashCode);
    });

    test('toString returns readable format', () {
      final follow = Follow(
        id: 'follow1',
        followerId: 'user1',
        followingId: 'user2',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(follow.toString(), 'Follow(user1 → user2)');
    });
  });

  group('UserProfile', () {
    test('creates with required fields', () {
      const profile = UserProfile(
        userId: 'user1',
        displayName: 'テストユーザー',
        photoUrl: 'https://example.com/photo.jpg',
        bio: '車好きです',
        followerCount: 100,
        followingCount: 50,
        postCount: 25,
      );

      expect(profile.userId, 'user1');
      expect(profile.displayName, 'テストユーザー');
      expect(profile.followerCount, 100);
    });

    test('toMap converts to map', () {
      const profile = UserProfile(
        userId: 'user1',
        displayName: 'テストユーザー',
        followerCount: 100,
        followingCount: 50,
      );

      final map = profile.toMap();

      expect(map['displayName'], 'テストユーザー');
      expect(map['followerCount'], 100);
      expect(map['followingCount'], 50);
    });

    test('copyWith creates modified copy', () {
      const profile = UserProfile(
        userId: 'user1',
        displayName: 'テストユーザー',
        followerCount: 100,
      );

      final modified = profile.copyWith(
        displayName: '新しい名前',
        followerCount: 150,
      );

      expect(modified.displayName, '新しい名前');
      expect(modified.followerCount, 150);
      expect(modified.userId, profile.userId);
    });

    test('equality is based on userId', () {
      const profile1 = UserProfile(
        userId: 'user1',
        displayName: '名前1',
      );
      const profile2 = UserProfile(
        userId: 'user1',
        displayName: '名前2',
      );

      expect(profile1 == profile2, true);
      expect(profile1.hashCode, profile2.hashCode);
    });
  });

  group('NotificationType', () {
    test('fromString returns correct enum value', () {
      expect(NotificationType.fromString('like'), NotificationType.like);
      expect(NotificationType.fromString('comment'), NotificationType.comment);
      expect(NotificationType.fromString('follow'), NotificationType.follow);
      expect(NotificationType.fromString('mention'), NotificationType.mention);
      expect(NotificationType.fromString('reply'), NotificationType.reply);
    });

    test('fromString returns null for invalid value', () {
      expect(NotificationType.fromString('invalid'), isNull);
      expect(NotificationType.fromString(null), isNull);
    });

    test('displayName returns Japanese name', () {
      expect(NotificationType.like.displayName, 'いいね');
      expect(NotificationType.comment.displayName, 'コメント');
      expect(NotificationType.follow.displayName, 'フォロー');
    });
  });

  group('SocialNotification', () {
    test('creates with required fields', () {
      final notification = SocialNotification(
        id: 'notif1',
        userId: 'user1',
        actorId: 'user2',
        actorDisplayName: 'アクター',
        type: NotificationType.like,
        postId: 'post1',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(notification.id, 'notif1');
      expect(notification.type, NotificationType.like);
      expect(notification.isRead, false);
    });

    test('message returns correct message for like', () {
      final notification = SocialNotification(
        id: 'notif1',
        userId: 'user1',
        actorId: 'user2',
        actorDisplayName: 'タロウ',
        type: NotificationType.like,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(notification.message, 'タロウがあなたの投稿にいいねしました');
    });

    test('message returns correct message for follow', () {
      final notification = SocialNotification(
        id: 'notif1',
        userId: 'user1',
        actorId: 'user2',
        actorDisplayName: 'ハナコ',
        type: NotificationType.follow,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(notification.message, 'ハナコがあなたをフォローしました');
    });

    test('message uses default when no actorDisplayName', () {
      final notification = SocialNotification(
        id: 'notif1',
        userId: 'user1',
        actorId: 'user2',
        type: NotificationType.comment,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(notification.message, 'ユーザーがあなたの投稿にコメントしました');
    });

    test('toMap converts to map correctly', () {
      final notification = SocialNotification(
        id: 'notif1',
        userId: 'user1',
        actorId: 'user2',
        type: NotificationType.mention,
        postId: 'post1',
        commentId: 'comment1',
        isRead: true,
        createdAt: DateTime(2024, 1, 1),
      );

      final map = notification.toMap();

      expect(map['userId'], 'user1');
      expect(map['actorId'], 'user2');
      expect(map['type'], 'mention');
      expect(map['postId'], 'post1');
      expect(map['commentId'], 'comment1');
      expect(map['isRead'], true);
    });

    test('copyWith creates modified copy', () {
      final notification = SocialNotification(
        id: 'notif1',
        userId: 'user1',
        actorId: 'user2',
        type: NotificationType.like,
        isRead: false,
        createdAt: DateTime(2024, 1, 1),
      );

      final modified = notification.copyWith(isRead: true);

      expect(modified.isRead, true);
      expect(modified.type, NotificationType.like);
    });

    test('equality is based on id', () {
      final notif1 = SocialNotification(
        id: 'notif1',
        userId: 'user1',
        actorId: 'user2',
        type: NotificationType.like,
        createdAt: DateTime(2024, 1, 1),
      );
      final notif2 = SocialNotification(
        id: 'notif1',
        userId: 'user3',
        actorId: 'user4',
        type: NotificationType.follow,
        createdAt: DateTime(2024, 1, 2),
      );

      expect(notif1 == notif2, true);
      expect(notif1.hashCode, notif2.hashCode);
    });
  });
}
