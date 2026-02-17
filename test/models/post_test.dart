import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/post.dart';

void main() {
  group('PostCategory', () {
    test('fromString returns correct enum value', () {
      expect(PostCategory.fromString('general'), PostCategory.general);
      expect(PostCategory.fromString('carLife'), PostCategory.carLife);
      expect(PostCategory.fromString('maintenance'), PostCategory.maintenance);
      expect(PostCategory.fromString('review'), PostCategory.review);
    });

    test('fromString returns null for invalid value', () {
      expect(PostCategory.fromString('invalid'), isNull);
      expect(PostCategory.fromString(null), isNull);
    });

    test('displayName returns Japanese name', () {
      expect(PostCategory.general.displayName, '一般');
      expect(PostCategory.carLife.displayName, 'カーライフ');
      expect(PostCategory.maintenance.displayName, 'メンテナンス');
      expect(PostCategory.question.displayName, '質問');
    });
  });

  group('PostVisibility', () {
    test('fromString returns correct enum value', () {
      expect(PostVisibility.fromString('public'), PostVisibility.public);
      expect(PostVisibility.fromString('followers'), PostVisibility.followers);
      expect(PostVisibility.fromString('private'), PostVisibility.private_);
    });

    test('fromString returns null for invalid value', () {
      expect(PostVisibility.fromString('invalid'), isNull);
      expect(PostVisibility.fromString(null), isNull);
    });

    test('displayName returns Japanese name', () {
      expect(PostVisibility.public.displayName, '全体公開');
      expect(PostVisibility.followers.displayName, 'フォロワーのみ');
      expect(PostVisibility.private_.displayName, '自分のみ');
    });

    test('storageName returns correct storage name', () {
      expect(PostVisibility.public.storageName, 'public');
      expect(PostVisibility.private_.storageName, 'private');
    });
  });

  group('PostMedia', () {
    test('creates with required fields', () {
      const media = PostMedia(
        url: 'https://example.com/image.jpg',
        type: 'image',
      );

      expect(media.url, 'https://example.com/image.jpg');
      expect(media.type, 'image');
      expect(media.isImage, true);
      expect(media.isVideo, false);
    });

    test('fromMap creates from map', () {
      final media = PostMedia.fromMap({
        'url': 'https://example.com/video.mp4',
        'type': 'video',
        'thumbnailUrl': 'https://example.com/thumb.jpg',
        'width': 1920,
        'height': 1080,
      });

      expect(media.url, 'https://example.com/video.mp4');
      expect(media.type, 'video');
      expect(media.isVideo, true);
      expect(media.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(media.width, 1920);
      expect(media.height, 1080);
    });

    test('toMap converts to map', () {
      const media = PostMedia(
        url: 'https://example.com/image.jpg',
        type: 'image',
        width: 800,
        height: 600,
      );

      final map = media.toMap();

      expect(map['url'], 'https://example.com/image.jpg');
      expect(map['type'], 'image');
      expect(map['width'], 800);
      expect(map['height'], 600);
    });
  });

  group('PostVehicleTag', () {
    test('creates with vehicle info', () {
      const tag = PostVehicleTag(
        vehicleId: 'v1',
        makerId: 'toyota',
        makerName: 'トヨタ',
        modelId: 'prius',
        modelName: 'プリウス',
        year: 2022,
      );

      expect(tag.makerName, 'トヨタ');
      expect(tag.modelName, 'プリウス');
      expect(tag.isEmpty, false);
    });

    test('isEmpty returns true when no vehicle info', () {
      const tag = PostVehicleTag();

      expect(tag.isEmpty, true);
      expect(tag.displayName, isNull);
    });

    test('displayName combines maker, model and year', () {
      const tag = PostVehicleTag(
        makerName: 'ホンダ',
        modelName: 'フィット',
        year: 2021,
      );

      expect(tag.displayName, 'ホンダ フィット (2021年式)');
    });

    test('fromMap handles null map', () {
      final tag = PostVehicleTag.fromMap(null);

      expect(tag.isEmpty, true);
    });

    test('toMap converts to map', () {
      const tag = PostVehicleTag(
        makerId: 'nissan',
        makerName: '日産',
        modelId: 'note',
        modelName: 'ノート',
      );

      final map = tag.toMap();

      expect(map['makerId'], 'nissan');
      expect(map['makerName'], '日産');
      expect(map['modelId'], 'note');
      expect(map['modelName'], 'ノート');
    });
  });

  group('Post', () {
    late Post post;

    setUp(() {
      post = Post(
        id: 'post1',
        userId: 'user1',
        userDisplayName: 'テストユーザー',
        userPhotoUrl: 'https://example.com/photo.jpg',
        category: PostCategory.carLife,
        visibility: PostVisibility.public,
        content: '今日は #ドライブ 日和 @friend1',
        media: [
          const PostMedia(url: 'https://example.com/img1.jpg', type: 'image'),
        ],
        vehicleTag: const PostVehicleTag(
          makerName: 'トヨタ',
          modelName: 'カローラ',
        ),
        hashtags: ['ドライブ'],
        mentionedUserIds: ['friend1'],
        likeCount: 10,
        commentCount: 5,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
    });

    test('hasMedia returns true when media exists', () {
      expect(post.hasMedia, true);
    });

    test('hasMedia returns false when no media', () {
      final noMediaPost = post.copyWith(media: []);
      expect(noMediaPost.hasMedia, false);
    });

    test('hasVehicleTag returns true when vehicle tag exists', () {
      expect(post.hasVehicleTag, true);
    });

    test('extractHashtags extracts hashtags from content', () {
      final hashtags = Post.extractHashtags('今日は #ドライブ #カーライフ');
      expect(hashtags, ['ドライブ', 'カーライフ']);
    });

    test('extractHashtags returns empty for no hashtags', () {
      final hashtags = Post.extractHashtags('今日は良い天気');
      expect(hashtags, isEmpty);
    });

    test('extractMentions extracts mentions from content', () {
      final mentions = Post.extractMentions('こんにちは @user1 @user2');
      expect(mentions, ['user1', 'user2']);
    });

    test('toMap converts to map correctly', () {
      final map = post.toMap();

      expect(map['userId'], 'user1');
      expect(map['category'], 'carLife');
      expect(map['visibility'], 'public');
      expect(map['likeCount'], 10);
      expect(map['commentCount'], 5);
      expect(map['hashtags'], ['ドライブ']);
    });

    test('copyWith creates modified copy', () {
      final modified = post.copyWith(
        content: '新しい内容',
        likeCount: 20,
      );

      expect(modified.content, '新しい内容');
      expect(modified.likeCount, 20);
      expect(modified.userId, post.userId);
    });

    test('equality is based on id', () {
      final post2 = post.copyWith(content: '別の内容');

      expect(post == post2, true);
      expect(post.hashCode, post2.hashCode);
    });

    test('toString returns readable format', () {
      expect(post.toString(), contains('Post('));
    });
  });

  group('PostLike', () {
    test('creates with required fields', () {
      final like = PostLike(
        id: 'like1',
        postId: 'post1',
        userId: 'user1',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(like.postId, 'post1');
      expect(like.userId, 'user1');
    });

    test('toMap converts to map', () {
      final like = PostLike(
        id: 'like1',
        postId: 'post1',
        userId: 'user1',
        createdAt: DateTime(2024, 1, 1),
      );

      final map = like.toMap();

      expect(map['postId'], 'post1');
      expect(map['userId'], 'user1');
    });
  });
}
