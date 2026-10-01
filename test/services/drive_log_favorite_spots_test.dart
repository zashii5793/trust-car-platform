// DriveLogService.getUserFavoriteSpots のテスト（Issue #192）。
//
// 本番のルールでは、documentId の whereIn は文書ごとに評価され、1件でも
// 読めないスポット（後から非公開にされた・消された）が混ざると一覧全体が
// permission-denied になっていた。いまは1件ずつ get して、読めない1件だけを
// 抜かす。拒否そのものは test/rules/firestore.rules.test.js の
// 「spots — お気に入りスポット」で確かめている（FakeFirestore はルールを
// 評価しないため）。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/drive_log_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late DriveLogService service;
  const viewer = 'viewer-1';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = DriveLogService(firestore: firestore);
  });

  Future<void> seedSpot(String id, {String name = 'スポット'}) async {
    await firestore.collection('spots').doc(id).set({
      'userId': 'creator',
      'name': name,
      'isPublic': true,
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });
  }

  Future<void> seedFavorite(String spotId, DateTime at,
      {String userId = viewer}) async {
    await firestore.collection('spot_favorites').add({
      'spotId': spotId,
      'userId': userId,
      'createdAt': Timestamp.fromDate(at),
    });
  }

  group('getUserFavoriteSpots', () {
    test('お気に入りのスポットを、新しくお気に入りにした順に返す', () async {
      await seedSpot('s1', name: '古い');
      await seedSpot('s2', name: '新しい');
      await seedFavorite('s1', DateTime(2026, 9, 1));
      await seedFavorite('s2', DateTime(2026, 9, 5));

      final result = await service.getUserFavoriteSpots(userId: viewer);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.map((s) => s.name), ['新しい', '古い']);
    });

    test('他人のお気に入りは混ざらない', () async {
      await seedSpot('s1');
      await seedSpot('s2');
      await seedFavorite('s1', DateTime(2026, 9, 1));
      await seedFavorite('s2', DateTime(2026, 9, 2), userId: 'someone-else');

      final result = await service.getUserFavoriteSpots(userId: viewer);

      expect(result.valueOrNull!.map((s) => s.id), ['s1']);
    });

    test('11件以上でも全部返す（whereIn の件数制限に縛られない）', () async {
      for (var i = 0; i < 12; i++) {
        await seedSpot('s$i');
        await seedFavorite('s$i', DateTime(2026, 9, 1, i));
      }

      final result = await service.getUserFavoriteSpots(userId: viewer);

      expect(result.valueOrNull!.length, 12);
    });

    group('Edge Cases', () {
      test('消されたスポットは抜かし、残りは返す（一覧全体を落とさない）', () async {
        await seedSpot('s1');
        await seedFavorite('s1', DateTime(2026, 9, 1));
        await seedFavorite('deleted', DateTime(2026, 9, 2));

        final result = await service.getUserFavoriteSpots(userId: viewer);

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.map((s) => s.id), ['s1']);
      });

      test('お気に入りが無い → 空', () async {
        final result = await service.getUserFavoriteSpots(userId: viewer);
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!, isEmpty);
      });

      test('空のユーザーID → 空（他人のお気に入りを舐めない）', () async {
        await seedSpot('s1');
        await seedFavorite('s1', DateTime(2026, 9, 1), userId: '');

        final result = await service.getUserFavoriteSpots(userId: '');

        expect(result.valueOrNull!, isEmpty);
      });

      test('limit が 0 以下 → 空', () async {
        await seedSpot('s1');
        await seedFavorite('s1', DateTime(2026, 9, 1));

        expect(
            (await service.getUserFavoriteSpots(userId: viewer, limit: 0))
                .valueOrNull!,
            isEmpty);
        expect(
            (await service.getUserFavoriteSpots(userId: viewer, limit: -1))
                .valueOrNull!,
            isEmpty);
      });

      test('limit 件までしか返さない', () async {
        for (var i = 0; i < 5; i++) {
          await seedSpot('s$i');
          await seedFavorite('s$i', DateTime(2026, 9, 1, i));
        }

        final result =
            await service.getUserFavoriteSpots(userId: viewer, limit: 2);

        expect(result.valueOrNull!.map((s) => s.id), ['s4', 's3']);
      });

      test('spotId が空・欠けたお気に入りは無視する', () async {
        await seedSpot('s1');
        await seedFavorite('s1', DateTime(2026, 9, 1));
        await seedFavorite('', DateTime(2026, 9, 2));
        await firestore.collection('spot_favorites').add({
          'userId': viewer,
          'createdAt': Timestamp.fromDate(DateTime(2026, 9, 3)),
        });

        final result = await service.getUserFavoriteSpots(userId: viewer);

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.map((s) => s.id), ['s1']);
      });

      test('同じスポットが2回お気に入りにあっても1件', () async {
        await seedSpot('s1');
        await seedFavorite('s1', DateTime(2026, 9, 1));
        await seedFavorite('s1', DateTime(2026, 9, 2));

        final result = await service.getUserFavoriteSpots(userId: viewer);

        expect(result.valueOrNull!.length, 1);
      });
    });
  });
}
