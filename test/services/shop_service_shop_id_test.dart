// 店のIDと店主を切り離す（段階1。docs/SHOP_ID_DECOUPLING_DESIGN.md）。
//
// - 新しく作る店は、`shops` の自動IDで作る。作った人を ownerId と
//   スタッフ名簿（members/{uid}）の owner にする
// - これまでの形（店のID ＝ 店主の uid）の店も、今までどおり自分の店として開く
// - 自分の店は、店のIDではなく ownerId で探す

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/services/shop_service.dart';

Shop _shop({
  String id = '',
  String? ownerId = 'owner1',
  String name = 'タカヤモーター',
  DateTime? createdAt,
}) {
  final at = createdAt ?? DateTime(2026, 10, 1);
  return Shop(
    id: id,
    name: name,
    type: ShopType.maintenanceShop,
    ownerId: ownerId,
    createdAt: at,
    updatedAt: at,
  );
}

Future<void> _seedShop(
  FakeFirebaseFirestore fs,
  String id, {
  required String ownerId,
  String name = '店',
  DateTime? createdAt,
}) =>
    fs.collection('shops').doc(id).set({
      'name': name,
      'type': 'maintenanceShop',
      'ownerId': ownerId,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime(2026, 9, 30)),
      'updatedAt': Timestamp.fromDate(createdAt ?? DateTime(2026, 9, 30)),
    });

/// ルールが新しい形を知らない本番を真似る。バッチの書き込みを
/// permission-denied で弾く（1件ずつの書き込みは通す）。
class _OldRulesFirestore extends FakeFirebaseFirestore {
  int batchCommits = 0;

  @override
  WriteBatch batch() => _DeniedBatch(this);
}

class _DeniedBatch implements WriteBatch {
  final _OldRulesFirestore owner;
  _DeniedBatch(this.owner);

  @override
  Future<void> commit() async {
    owner.batchCommits++;
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );
  }

  @override
  void delete(DocumentReference document) {}

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {}

  @override
  void update<T>(DocumentReference<T> document, T data) {}
}

/// 権限以外の理由で書き込みが失敗する（通信が切れたなど）。
class _OfflineBatchFirestore extends FakeFirebaseFirestore {
  @override
  WriteBatch batch() => _UnavailableBatch();
}

class _UnavailableBatch implements WriteBatch {
  @override
  Future<void> commit() async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

  @override
  void delete(DocumentReference document) {}

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {}

  @override
  void update<T>(DocumentReference<T> document, T data) {}
}

void main() {
  late FakeFirebaseFirestore fs;
  late ShopService service;

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = ShopService(firestore: fs);
  });

  group('createMyShop — 新しい形（自動ID）', () {
    test('id を空で渡すと、自動IDで作り、店主の uid とは別のIDになる', () async {
      final r = await service.createMyShop(_shop());

      expect(r.isSuccess, isTrue);
      final shop = r.valueOrNull!;
      expect(shop.id, isNotEmpty);
      expect(shop.id, isNot('owner1'));
      expect(shop.ownerId, 'owner1');
      final doc = await fs.collection('shops').doc(shop.id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['ownerId'], 'owner1');
      // これまでの形の場所には作らない
      expect(
          (await fs.collection('shops').doc('owner1').get()).exists, isFalse);
    });

    test('作った人をスタッフ名簿の owner にする', () async {
      final shop =
          (await service.createMyShop(_shop(), ownerName: '高谷')).valueOrNull!;

      final member = await fs
          .collection('shops')
          .doc(shop.id)
          .collection('members')
          .doc('owner1')
          .get();
      expect(member.exists, isTrue);
      expect(member.data()!['role'], 'owner');
      expect(member.data()!['displayName'], '高谷');
      expect(member.data()!['addedAt'], isA<Timestamp>());
    });

    test('自動IDの店でもフリーで作る', () async {
      final shop = (await service.createMyShop(_shop())).valueOrNull!;
      final d = (await fs.collection('shops').doc(shop.id).get()).data()!;
      expect(d['planType'], 'free');
      expect(d['subscriptionStatus'], 'free');
      expect(d['planExpiresAt'], isNull);
    });

    test('作った店は getMyShop で自分の店として開く', () async {
      final created = (await service.createMyShop(_shop())).valueOrNull!;
      final mine = (await service.getMyShop('owner1')).valueOrNull;
      expect(mine?.id, created.id);
    });

    test('店を引き継いで手放した人も、新しい店を作れる', () async {
      // 前に作った店（ID ＝ 自分の uid）は、もう別の人の店
      await _seedShop(fs, 'owner1', ownerId: 'staff-sato');

      final r = await service.createMyShop(_shop(name: '2号店'));

      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull!.id, isNot('owner1'));
      expect((await service.getMyShop('owner1')).valueOrNull?.name, '2号店');
      // 引き継いだ店はそのまま
      final old = (await fs.collection('shops').doc('owner1').get()).data()!;
      expect(old['ownerId'], 'staff-sato');
    });

    group('Edge Cases', () {
      test('ownerId が null なら作らない', () async {
        final r = await service.createMyShop(_shop(ownerId: null));
        expect(r.isFailure, isTrue);
        expect((await fs.collection('shops').get()).docs, isEmpty);
      });

      test('ownerId が空なら作らない', () async {
        final r = await service.createMyShop(_shop(ownerId: ''));
        expect(r.isFailure, isTrue);
        expect((await fs.collection('shops').get()).docs, isEmpty);
      });

      test('名前が渡されなければ、名簿の名前は「店主」', () async {
        final shop = (await service.createMyShop(_shop())).valueOrNull!;
        final member = await fs.doc('shops/${shop.id}/members/owner1').get();
        expect(member.data()!['displayName'], '店主');
      });

      test('名前が空白だけなら、名簿の名前は「店主」', () async {
        final shop =
            (await service.createMyShop(_shop(), ownerName: '  ')).valueOrNull!;
        final member = await fs.doc('shops/${shop.id}/members/owner1').get();
        expect(member.data()!['displayName'], '店主');
      });

      test('ルールが古い本番（バッチが permission-denied）では、これまでの形で作る', () async {
        final old = _OldRulesFirestore();
        final r = await ShopService(firestore: old).createMyShop(_shop());

        expect(r.isSuccess, isTrue);
        expect(old.batchCommits, 1);
        expect(r.valueOrNull!.id, 'owner1');
        final d = (await old.collection('shops').doc('owner1').get()).data()!;
        expect(d['ownerId'], 'owner1');
        expect(d['planType'], 'free');
        // 古いルールでは名簿を一緒に書けないので、これまでどおり書かない
        expect(
            (await old
                    .collection('shops')
                    .doc('owner1')
                    .collection('members')
                    .get())
                .docs,
            isEmpty);
        // 自動IDの店は残らない
        expect((await old.collection('shops').get()).docs.length, 1);
      });

      test('権限以外の失敗では、これまでの形に作り直さない', () async {
        final offline = _OfflineBatchFirestore();
        final r = await ShopService(firestore: offline).createMyShop(_shop());

        expect(r.isFailure, isTrue);
        expect((await offline.collection('shops').get()).docs, isEmpty);
      });
    });
  });

  group('createMyShop — これまでの形（id を渡す）', () {
    test('id に店主の uid を渡せば、shops/{uid} に作る（名簿は書かない）', () async {
      final r = await service.createMyShop(_shop(id: 'owner1'));

      expect(r.valueOrNull!.id, 'owner1');
      expect((await fs.collection('shops').doc('owner1').get()).exists, isTrue);
      expect((await fs.collection('shops/owner1/members').get()).docs, isEmpty);
    });
  });

  group('getMyShop', () {
    test('これまでの形（ID ＝ 自分の uid）の店を開く', () async {
      await _seedShop(fs, 'owner1', ownerId: 'owner1', name: 'タカヤモーター');
      final mine = (await service.getMyShop('owner1')).valueOrNull;
      expect(mine?.id, 'owner1');
      expect(mine?.name, 'タカヤモーター');
    });

    test('自動IDの店を開く', () async {
      await _seedShop(fs, 'AbCdEfGhIjKlMnOpQrSt', ownerId: 'owner1');
      final mine = (await service.getMyShop('owner1')).valueOrNull;
      expect(mine?.id, 'AbCdEfGhIjKlMnOpQrSt');
    });

    test('引き継いで受け取った店（ID ＝ 前の店主の uid）を開く', () async {
      await _seedShop(fs, 'owner-old', ownerId: 'staff-sato');
      final mine = (await service.getMyShop('staff-sato')).valueOrNull;
      expect(mine?.id, 'owner-old');
    });

    test('引き継いで手放した店（ID ＝ 自分の uid）は、自分の店ではない', () async {
      await _seedShop(fs, 'owner-old', ownerId: 'staff-sato');
      final mine = await service.getMyShop('owner-old');
      expect(mine.isSuccess, isTrue);
      expect(mine.valueOrNull, isNull);
    });

    test('店主の店が2つあるときは、ID ＝ 自分の uid の店を先に選ぶ', () async {
      await _seedShop(fs, 'AAAAAAAAAAAAAAAAAAAA',
          ownerId: 'owner1', createdAt: DateTime(2020));
      await _seedShop(fs, 'owner1',
          ownerId: 'owner1', createdAt: DateTime(2026));
      expect((await service.getMyShop('owner1')).valueOrNull?.id, 'owner1');
    });

    test('ID ＝ uid の店が無ければ、作った日が古い店を選ぶ（何度開いても同じ）', () async {
      await _seedShop(fs, 'ZZZZZZZZZZZZZZZZZZZZ',
          ownerId: 'owner1', createdAt: DateTime(2026, 10, 2));
      await _seedShop(fs, 'BBBBBBBBBBBBBBBBBBBB',
          ownerId: 'owner1', createdAt: DateTime(2026, 10, 1));
      for (var i = 0; i < 3; i++) {
        expect((await service.getMyShop('owner1')).valueOrNull?.id,
            'BBBBBBBBBBBBBBBBBBBB');
      }
    });

    group('Edge Cases', () {
      test('店が無ければ null', () async {
        final r = await service.getMyShop('nobody');
        expect(r.isSuccess, isTrue);
        expect(r.valueOrNull, isNull);
      });

      test('uid が空なら null（ownerId が空の店を拾わない）', () async {
        await _seedShop(fs, 'broken', ownerId: '');
        final r = await service.getMyShop('');
        expect(r.isSuccess, isTrue);
        expect(r.valueOrNull, isNull);
      });

      test('他人の店は返さない', () async {
        await _seedShop(fs, 'other', ownerId: 'other');
        expect((await service.getMyShop('owner1')).valueOrNull, isNull);
      });
    });
  });

  group('deleteMyShop', () {
    test('自動IDの自分の店を消せる', () async {
      final shop = (await service.createMyShop(_shop())).valueOrNull!;
      final r = await service.deleteMyShop('owner1');
      expect(r.isSuccess, isTrue);
      expect((await fs.collection('shops').doc(shop.id).get()).exists, isFalse);
    });

    test('これまでの形の自分の店を消せる', () async {
      await _seedShop(fs, 'owner1', ownerId: 'owner1');
      expect((await service.deleteMyShop('owner1')).isSuccess, isTrue);
      expect(
          (await fs.collection('shops').doc('owner1').get()).exists, isFalse);
    });

    group('Edge Cases', () {
      test('引き継いで手放した店（ID ＝ 自分の uid）は消せない', () async {
        await _seedShop(fs, 'owner-old', ownerId: 'staff-sato');
        final r = await service.deleteMyShop('owner-old');
        expect(r.isFailure, isTrue);
        expect((await fs.collection('shops').doc('owner-old').get()).exists,
            isTrue);
      });
    });
  });
}
