import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trust_car_platform/models/drive_spot.dart';

void main() {
  group('SpotCategory', () {
    test('should have correct display names', () {
      expect(SpotCategory.scenicView.displayName, '景勝地');
      expect(SpotCategory.restaurant.displayName, 'レストラン');
      expect(SpotCategory.cafe.displayName, 'カフェ');
      expect(SpotCategory.gasStation.displayName, 'ガソリンスタンド');
      expect(SpotCategory.parkingArea.displayName, '駐車場・PA');
      expect(SpotCategory.serviceArea.displayName, 'サービスエリア');
      expect(SpotCategory.shrine.displayName, '神社');
      expect(SpotCategory.temple.displayName, '寺院');
      expect(SpotCategory.hotSpring.displayName, '温泉');
      expect(SpotCategory.campsite.displayName, 'キャンプ場');
      expect(SpotCategory.beach.displayName, 'ビーチ');
      expect(SpotCategory.mountain.displayName, '山');
      expect(SpotCategory.lake.displayName, '湖');
      expect(SpotCategory.waterfall.displayName, '滝');
      expect(SpotCategory.historicSite.displayName, '史跡');
      expect(SpotCategory.museum.displayName, '博物館');
      expect(SpotCategory.park.displayName, '公園');
      expect(SpotCategory.shopping.displayName, 'ショッピング');
      expect(SpotCategory.carWash.displayName, '洗車場');
      expect(SpotCategory.other.displayName, 'その他');
    });

    test('should have correct emojis', () {
      expect(SpotCategory.scenicView.emoji, '🏞️');
      expect(SpotCategory.restaurant.emoji, '🍽️');
      expect(SpotCategory.cafe.emoji, '☕');
      expect(SpotCategory.gasStation.emoji, '⛽');
      expect(SpotCategory.shrine.emoji, '⛩️');
      expect(SpotCategory.hotSpring.emoji, '♨️');
      expect(SpotCategory.mountain.emoji, '⛰️');
    });

    test('fromString should return correct enum value', () {
      expect(SpotCategory.fromString('scenicView'), SpotCategory.scenicView);
      expect(SpotCategory.fromString('restaurant'), SpotCategory.restaurant);
      expect(SpotCategory.fromString('hotSpring'), SpotCategory.hotSpring);
      expect(SpotCategory.fromString('invalid'), isNull);
      expect(SpotCategory.fromString(null), isNull);
    });
  });

  group('SpotImage', () {
    test('should create from map', () {
      final map = {
        'url': 'https://example.com/image.jpg',
        'thumbnailUrl': 'https://example.com/thumb.jpg',
        'order': 1,
        'caption': 'Beautiful view',
      };

      final image = SpotImage.fromMap(map);

      expect(image.url, 'https://example.com/image.jpg');
      expect(image.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(image.order, 1);
      expect(image.caption, 'Beautiful view');
    });

    test('should convert to map', () {
      const image = SpotImage(
        url: 'https://example.com/image.jpg',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        order: 1,
        caption: 'Beautiful view',
      );

      final map = image.toMap();

      expect(map['url'], 'https://example.com/image.jpg');
      expect(map['thumbnailUrl'], 'https://example.com/thumb.jpg');
      expect(map['order'], 1);
      expect(map['caption'], 'Beautiful view');
    });

    test('should exclude null values from map', () {
      const image = SpotImage(
        url: 'https://example.com/image.jpg',
        order: 0,
      );

      final map = image.toMap();

      expect(map.containsKey('thumbnailUrl'), isFalse);
      expect(map.containsKey('caption'), isFalse);
    });
  });

  group('SpotBusinessHours', () {
    test('should create from map', () {
      final map = {
        'dayOfWeek': 1,
        'openTime': '09:00',
        'closeTime': '18:00',
        'isClosed': false,
      };

      final hours = SpotBusinessHours.fromMap(map);

      expect(hours.dayOfWeek, 1);
      expect(hours.openTime, '09:00');
      expect(hours.closeTime, '18:00');
      expect(hours.isClosed, isFalse);
    });

    test('should convert to map', () {
      const hours = SpotBusinessHours(
        dayOfWeek: 1,
        openTime: '09:00',
        closeTime: '18:00',
        isClosed: false,
      );

      final map = hours.toMap();

      expect(map['dayOfWeek'], 1);
      expect(map['openTime'], '09:00');
      expect(map['closeTime'], '18:00');
      expect(map['isClosed'], isFalse);
    });

    test('dayName should return correct day', () {
      expect(const SpotBusinessHours(dayOfWeek: 0).dayName, '日');
      expect(const SpotBusinessHours(dayOfWeek: 1).dayName, '月');
      expect(const SpotBusinessHours(dayOfWeek: 2).dayName, '火');
      expect(const SpotBusinessHours(dayOfWeek: 3).dayName, '水');
      expect(const SpotBusinessHours(dayOfWeek: 4).dayName, '木');
      expect(const SpotBusinessHours(dayOfWeek: 5).dayName, '金');
      expect(const SpotBusinessHours(dayOfWeek: 6).dayName, '土');
    });

    test('displayHours should return correct string', () {
      expect(
        const SpotBusinessHours(
          dayOfWeek: 1,
          openTime: '09:00',
          closeTime: '18:00',
        ).displayHours,
        '09:00 - 18:00',
      );

      expect(
        const SpotBusinessHours(
          dayOfWeek: 0,
          isClosed: true,
        ).displayHours,
        '定休日',
      );

      expect(
        const SpotBusinessHours(
          dayOfWeek: 1,
        ).displayHours,
        '時間不明',
      );
    });
  });

  group('DriveSpot', () {
    late DateTime now;
    late Map<String, dynamic> validMap;

    setUp(() {
      now = DateTime.now();
      validMap = {
        'userId': 'user123',
        'driveLogId': 'log456',
        'name': '河口湖',
        'description': '富士山の絶景スポット',
        'category': 'scenicView',
        'tags': ['富士山', '湖', '絶景'],
        'location': {'latitude': 35.5108, 'longitude': 138.7642},
        'address': '山梨県南都留郡富士河口湖町',
        'prefecture': '山梨県',
        'city': '富士河口湖町',
        'phoneNumber': '0555-72-1234',
        'website': 'https://kawaguchiko.jp',
        'businessHours': [
          {'dayOfWeek': 1, 'openTime': '09:00', 'closeTime': '18:00'},
        ],
        'isParkingAvailable': true,
        'parkingCapacity': 100,
        'images': [
          {'url': 'https://example.com/image.jpg', 'order': 0},
        ],
        'thumbnailUrl': 'https://example.com/thumb.jpg',
        'averageRating': 4.5,
        'ratingCount': 120,
        'visitCount': 500,
        'isPublic': true,
        'favoriteCount': 50,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };
    });

    test('should create from map', () {
      final spot = DriveSpot.fromMap(validMap, 'spot123');

      expect(spot.id, 'spot123');
      expect(spot.userId, 'user123');
      expect(spot.driveLogId, 'log456');
      expect(spot.name, '河口湖');
      expect(spot.description, '富士山の絶景スポット');
      expect(spot.category, SpotCategory.scenicView);
      expect(spot.tags, contains('富士山'));
      expect(spot.location.latitude, 35.5108);
      expect(spot.address, '山梨県南都留郡富士河口湖町');
      expect(spot.prefecture, '山梨県');
      expect(spot.city, '富士河口湖町');
      expect(spot.phoneNumber, '0555-72-1234');
      expect(spot.website, 'https://kawaguchiko.jp');
      expect(spot.businessHours.length, 1);
      expect(spot.isParkingAvailable, isTrue);
      expect(spot.parkingCapacity, 100);
      expect(spot.images.length, 1);
      expect(spot.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(spot.averageRating, 4.5);
      expect(spot.ratingCount, 120);
      expect(spot.visitCount, 500);
      expect(spot.isPublic, isTrue);
      expect(spot.favoriteCount, 50);
    });

    test('should convert to map', () {
      final spot = DriveSpot.fromMap(validMap, 'spot123');
      final map = spot.toMap();

      expect(map['userId'], 'user123');
      expect(map['name'], '河口湖');
      expect(map['category'], 'scenicView');
      expect(map['location']['latitude'], 35.5108);
      expect(map['isParkingAvailable'], isTrue);
      expect(map['averageRating'], 4.5);
      expect(map['isPublic'], isTrue);
    });

    test('copyWith should work correctly', () {
      final spot = DriveSpot.fromMap(validMap, 'spot123');
      final updated = spot.copyWith(
        name: 'Updated Name',
        averageRating: 4.8,
        visitCount: 600,
      );

      expect(updated.id, spot.id);
      expect(updated.userId, spot.userId);
      expect(updated.name, 'Updated Name');
      expect(updated.averageRating, 4.8);
      expect(updated.visitCount, 600);
      expect(updated.description, spot.description); // unchanged
    });

    test('primaryImageUrl should return thumbnailUrl first', () {
      final spot = DriveSpot.fromMap(validMap, 'spot123');
      expect(spot.primaryImageUrl, 'https://example.com/thumb.jpg');
    });

    test('primaryImageUrl should return first image if no thumbnail', () {
      validMap['thumbnailUrl'] = null;
      final spot = DriveSpot.fromMap(validMap, 'spot123');
      expect(spot.primaryImageUrl, 'https://example.com/image.jpg');
    });

    test('primaryImageUrl should return null if no images', () {
      validMap['thumbnailUrl'] = null;
      validMap['images'] = [];
      final spot = DriveSpot.fromMap(validMap, 'spot123');
      expect(spot.primaryImageUrl, isNull);
    });

    test('hasRatings should return correct value', () {
      final spotWithRatings = DriveSpot.fromMap(validMap, 'spot123');
      expect(spotWithRatings.hasRatings, isTrue);

      validMap['ratingCount'] = 0;
      final spotWithoutRatings = DriveSpot.fromMap(validMap, 'spot456');
      expect(spotWithoutRatings.hasRatings, isFalse);
    });

    test('formattedRating should return correct string', () {
      final spot = DriveSpot.fromMap(validMap, 'spot123');
      expect(spot.formattedRating, '4.5 (120件)');

      validMap['ratingCount'] = 0;
      final spotNoRatings = DriveSpot.fromMap(validMap, 'spot456');
      expect(spotNoRatings.formattedRating, '評価なし');
    });

    test('categoryWithEmoji should return formatted string', () {
      final spot = DriveSpot.fromMap(validMap, 'spot123');
      expect(spot.categoryWithEmoji, '🏞️ 景勝地');
    });

    test('should implement equality correctly', () {
      final spot1 = DriveSpot.fromMap(validMap, 'spot123');
      final spot2 = DriveSpot.fromMap(validMap, 'spot123');
      final spot3 = DriveSpot.fromMap(validMap, 'spot456');

      expect(spot1, equals(spot2));
      expect(spot1, isNot(equals(spot3)));
    });

    test('toString should return formatted string', () {
      final spot = DriveSpot.fromMap(validMap, 'spot123');
      expect(spot.toString(), contains('河口湖'));
      expect(spot.toString(), contains('景勝地'));
    });
  });

  group('SpotRating', () {
    test('should create from map', () {
      final now = DateTime.now();
      final visitedAt = now.subtract(const Duration(days: 1));
      final map = {
        'spotId': 'spot123',
        'userId': 'user456',
        'userName': 'テストユーザー',
        'userAvatarUrl': 'https://example.com/avatar.jpg',
        'rating': 5,
        'comment': '素晴らしい景色でした！',
        'photoUrls': ['https://example.com/photo1.jpg'],
        'visitedAt': Timestamp.fromDate(visitedAt),
        'createdAt': Timestamp.fromDate(now),
      };

      final rating = SpotRating.fromMap(map, 'rating789');

      expect(rating.id, 'rating789');
      expect(rating.spotId, 'spot123');
      expect(rating.userId, 'user456');
      expect(rating.userName, 'テストユーザー');
      expect(rating.userAvatarUrl, 'https://example.com/avatar.jpg');
      expect(rating.rating, 5);
      expect(rating.comment, '素晴らしい景色でした！');
      expect(rating.photoUrls.length, 1);
    });

    test('should convert to map', () {
      final now = DateTime.now();
      final rating = SpotRating(
        id: 'rating789',
        spotId: 'spot123',
        userId: 'user456',
        userName: 'テストユーザー',
        rating: 5,
        comment: '素晴らしい！',
        visitedAt: now,
        createdAt: now,
      );

      final map = rating.toMap();

      expect(map['spotId'], 'spot123');
      expect(map['userId'], 'user456');
      expect(map['userName'], 'テストユーザー');
      expect(map['rating'], 5);
      expect(map['comment'], '素晴らしい！');
    });

    test('ratingStars should return correct stars', () {
      final now = DateTime.now();

      expect(
        SpotRating(
          id: '1',
          spotId: 's1',
          userId: 'u1',
          rating: 5,
          visitedAt: now,
          createdAt: now,
        ).ratingStars,
        '★★★★★',
      );

      expect(
        SpotRating(
          id: '2',
          spotId: 's2',
          userId: 'u2',
          rating: 3,
          visitedAt: now,
          createdAt: now,
        ).ratingStars,
        '★★★☆☆',
      );

      expect(
        SpotRating(
          id: '3',
          spotId: 's3',
          userId: 'u3',
          rating: 1,
          visitedAt: now,
          createdAt: now,
        ).ratingStars,
        '★☆☆☆☆',
      );
    });
  });

  group('SpotFavorite', () {
    test('should create from map', () {
      final now = DateTime.now();
      final map = {
        'spotId': 'spot123',
        'userId': 'user456',
        'note': '次回必ず行きたい！',
        'createdAt': Timestamp.fromDate(now),
      };

      final favorite = SpotFavorite.fromMap(map, 'fav789');

      expect(favorite.id, 'fav789');
      expect(favorite.spotId, 'spot123');
      expect(favorite.userId, 'user456');
      expect(favorite.note, '次回必ず行きたい！');
    });

    test('should convert to map', () {
      final now = DateTime.now();
      final favorite = SpotFavorite(
        id: 'fav789',
        spotId: 'spot123',
        userId: 'user456',
        note: '次回必ず行きたい！',
        createdAt: now,
      );

      final map = favorite.toMap();

      expect(map['spotId'], 'spot123');
      expect(map['userId'], 'user456');
      expect(map['note'], '次回必ず行きたい！');
      expect(map.containsKey('id'), isFalse);
    });
  });

  group('SpotVisit', () {
    test('should create from map', () {
      final now = DateTime.now();
      final map = {
        'spotId': 'spot123',
        'userId': 'user456',
        'driveLogId': 'log789',
        'visitedAt': Timestamp.fromDate(now),
        'note': '天気が良くて最高でした',
        'photoUrls': ['https://example.com/photo1.jpg', 'https://example.com/photo2.jpg'],
      };

      final visit = SpotVisit.fromMap(map, 'visit123');

      expect(visit.id, 'visit123');
      expect(visit.spotId, 'spot123');
      expect(visit.userId, 'user456');
      expect(visit.driveLogId, 'log789');
      expect(visit.note, '天気が良くて最高でした');
      expect(visit.photoUrls.length, 2);
    });

    test('should convert to map', () {
      final now = DateTime.now();
      final visit = SpotVisit(
        id: 'visit123',
        spotId: 'spot123',
        userId: 'user456',
        driveLogId: 'log789',
        visitedAt: now,
        note: '天気が良くて最高でした',
        photoUrls: ['https://example.com/photo1.jpg'],
      );

      final map = visit.toMap();

      expect(map['spotId'], 'spot123');
      expect(map['userId'], 'user456');
      expect(map['driveLogId'], 'log789');
      expect(map['note'], '天気が良くて最高でした');
      expect(map['photoUrls'].length, 1);
      expect(map.containsKey('id'), isFalse);
    });

    test('should handle null optional fields', () {
      final now = DateTime.now();
      final visit = SpotVisit(
        id: 'visit123',
        spotId: 'spot123',
        userId: 'user456',
        visitedAt: now,
      );

      final map = visit.toMap();

      expect(map.containsKey('driveLogId'), isFalse);
      expect(map.containsKey('note'), isFalse);
      expect(map['photoUrls'], isEmpty);
    });
  });
}
