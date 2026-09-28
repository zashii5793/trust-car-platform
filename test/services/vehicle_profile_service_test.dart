import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/vehicle_profile.dart';
import 'package:trust_car_platform/services/vehicle_profile_service.dart';

/// 愛車ページ。**集めるのは、もともと公開されているものだけ**、を確かめる。
void main() {
  late FakeFirebaseFirestore fs;
  late VehicleProfileService service;
  final now = DateTime(2026, 9, 27);

  final vehicle = Vehicle(
    id: 'v1',
    userId: 'u1',
    maker: 'MINI',
    model: 'クーパー',
    year: 2019,
    grade: 'S',
    mileage: 48000,
    licensePlate: '品川300あ1234',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  MaintenanceRecord rec(String id, MaintenanceType t, DateTime d,
          {String vehicleId = 'v1'}) =>
      MaintenanceRecord(
        id: id,
        vehicleId: vehicleId,
        userId: 'u1',
        type: t,
        title: t.displayName,
        cost: 99999,
        date: d,
        createdAt: d,
      );

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = VehicleProfileService(firestore: fs, now: () => now);
  });

  group('save', () {
    test('車種・年式・グレードだけを写し、走行距離やナンバーは写さない', () async {
      await service.save(
        ownerId: 'u1',
        ownerName: 'みにお',
        vehicle: vehicle,
        isPublic: true,
        showsMaintenance: false,
      );
      final d = (await fs.doc('vehicle_profiles/v1').get()).data()!;
      expect(d['maker'], 'MINI');
      expect(d['grade'], 'S');
      expect(d.containsKey('mileage'), isFalse);
      expect(d.containsKey('licensePlate'), isFalse);
      expect(d['maintenance'], isEmpty);
    });

    test('整備を出すなら、種類と回数と最後の日だけ（金額は無い）', () async {
      final p = (await service.save(
        ownerId: 'u1',
        ownerName: 'みにお',
        vehicle: vehicle,
        isPublic: true,
        showsMaintenance: true,
        records: [
          rec('a', MaintenanceType.oilChange, DateTime(2025, 1, 1)),
          rec('b', MaintenanceType.oilChange, DateTime(2026, 5, 1)),
          rec('c', MaintenanceType.carInspection, DateTime(2025, 4, 1)),
          // 別の車の記録は数えない
          rec('d', MaintenanceType.oilChange, DateTime(2026, 6, 1),
              vehicleId: 'v2'),
        ],
      ))
          .valueOrNull!;
      final oil = p.maintenance.first;
      expect(oil.type, MaintenanceType.oilChange.displayName);
      expect(oil.count, 2);
      expect(oil.lastDate, DateTime(2026, 5, 1));
      final d = (await fs.doc('vehicle_profiles/v1').get()).data()!;
      final m = (d['maintenance'] as List).first as Map;
      expect(m.containsKey('cost'), isFalse);
    });

    group('Edge Cases', () {
      test('他人の車は公開できない', () async {
        final r = await service.save(
          ownerId: 'someone',
          ownerName: 'x',
          vehicle: vehicle,
          isPublic: true,
          showsMaintenance: false,
        );
        expect(r.errorOrNull, isA<PermissionError>());
      });

      test('空白の呼び名は入れない。長すぎる紹介文は切る', () async {
        final p = (await service.save(
          ownerId: 'u1',
          ownerName: 'みにお',
          vehicle: vehicle,
          isPublic: true,
          showsMaintenance: false,
          nickname: '  ',
          bio: 'あ' * 500,
        ))
            .valueOrNull!;
        expect(p.nickname, isNull);
        expect(p.title, 'MINI クーパー');
        expect(p.bio!.length, 300);
      });

      test('無いページは null', () async {
        expect((await service.get('nope')).valueOrNull, isNull);
      });
    });
  });

  group('contents', () {
    Future<VehicleProfile> profile() async => (await service.save(
          ownerId: 'u1',
          ownerName: 'みにお',
          vehicle: vehicle,
          isPublic: true,
          showsMaintenance: false,
        ))
            .valueOrNull!;

    Future<void> post(String id, String visibility, String vehicleId) =>
        fs.collection('posts').doc(id).set({
          'userId': 'u1',
          'content': id,
          'visibility': visibility,
          'vehicleTag': {'vehicleId': vehicleId},
          'createdAt': Timestamp.fromDate(now),
        });

    test('公開の投稿だけ。別の車・フォロワー限定・非公開は集めない', () async {
      await post('公開', 'public', 'v1');
      await post('フォロワー限定', 'followers', 'v1');
      await post('非公開', 'private', 'v1');
      await post('別の車', 'public', 'v2');
      final c = await service.contents(await profile());
      expect(c.posts.map((p) => p.content), ['公開']);
    });

    test('公開にしたドライブだけ', () async {
      Future<void> drive(String id, bool public) =>
          fs.collection('drive_logs').doc(id).set({
            'userId': 'u1',
            'vehicleId': 'v1',
            'isPublic': public,
            'title': id,
            'status': 'completed',
            'startTime': Timestamp.fromDate(now),
            'statistics': {'totalDistance': 12.5},
            'createdAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
          });
      await drive('公開ドライブ', true);
      await drive('非公開ドライブ', false);
      final c = await service.contents(await profile());
      expect(c.driveLogs.map((d) => d.title), ['公開ドライブ']);
    });

    test('この車に付けたパーツのレビュー', () async {
      await fs.collection('accessory_showcases').doc('s1').set({
        'userId': 'u1',
        'vehicleId': 'v1',
        'category': 'dashcam',
        'itemName': 'N2 Pro',
        'rating': 4,
        'createdAt': Timestamp.fromDate(now),
      });
      final c = await service.contents(await profile());
      expect(c.showcases.single.itemName, 'N2 Pro');
    });

    group('Edge Cases', () {
      test('壊れたドライブが1件あっても、ほかは出す', () async {
        await fs.collection('drive_logs').doc('broken').set({
          'userId': 'u1',
          'vehicleId': 'v1',
          'isPublic': true,
        });
        await fs.collection('drive_logs').doc('ok').set({
          'userId': 'u1',
          'vehicleId': 'v1',
          'isPublic': true,
          'title': 'ok',
          'startTime': Timestamp.fromDate(now),
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
        final c = await service.contents(await profile());
        expect(c.driveLogs.map((d) => d.title), ['ok']);
      });

      test('何も無ければ空', () async {
        final c = await service.contents(await profile());
        expect(c.isEmpty, isTrue);
      });
    });
  });

  group('フォロー・同じ車種', () {
    Vehicle other(String id, String owner, {String model = 'クーパー'}) => Vehicle(
          id: id,
          userId: owner,
          maker: 'MINI',
          model: model,
          year: 2020,
          grade: '',
          mileage: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

    Future<VehicleProfile> publish(Vehicle v, {bool isPublic = true}) async =>
        (await service.save(
          ownerId: v.userId,
          ownerName: v.userId,
          vehicle: v,
          isPublic: isPublic,
          showsMaintenance: false,
        ))
            .valueOrNull!;

    test('フォローすると人数が増え、やめると減る', () async {
      final p = await publish(vehicle);
      await service.follow(uid: 'fan1', profile: p);
      await service.follow(uid: 'fan2', profile: p);
      expect(await service.followerCount('v1'), 2);
      expect(await service.isFollowing(uid: 'fan1', vehicleId: 'v1'), isTrue);
      await service.unfollow(uid: 'fan1', vehicleId: 'v1');
      expect(await service.followerCount('v1'), 1);
      expect(await service.isFollowing(uid: 'fan1', vehicleId: 'v1'), isFalse);
    });

    test('同じ車種の公開ページだけ。自分と非公開と別の車種は出さない', () async {
      final mine = await publish(vehicle);
      await publish(other('v2', 'u2'));
      await publish(other('v3', 'u3'), isPublic: false);
      await publish(other('v4', 'u4', model: 'クラブマン'));
      // 表記が揺れていても同じ車種
      await publish(other('v5', 'u5', model: 'ｸｰﾊﾟｰ'));
      final list = await service.sameModel(mine);
      expect(list.map((p) => p.vehicleId).toSet(), {'v2', 'v5'});
    });

    test('フォロー中の公開ページを返す（非公開になったものは出さない）', () async {
      final a = await publish(other('v2', 'u2'));
      final b = await publish(other('v3', 'u3'));
      await service.follow(uid: 'fan', profile: a);
      await service.follow(uid: 'fan', profile: b);
      await publish(other('v3', 'u3'), isPublic: false);
      final list = await service.followed('fan');
      expect(list.map((p) => p.vehicleId), ['v2']);
    });

    group('Edge Cases', () {
      test('自分の車はフォローできない', () async {
        final p = await publish(vehicle);
        final r = await service.follow(uid: 'u1', profile: p);
        expect(r.isFailure, isTrue);
      });

      test('何もフォローしていなければ空', () async {
        expect(await service.followed('nobody'), isEmpty);
      });
    });
  });
}
