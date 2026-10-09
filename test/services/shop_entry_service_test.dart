import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/shop_entry_service.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/shop_staff_service.dart';

/// ログインした人が、どの店の店主・スタッフか（2026-10-08 使用感テスト #2）。
///
/// 店主がログインしても、お客さん用の「マイカー」が出て、顧客台帳まで
/// 5手かかっていた。ログイン直後にこれで振り分ける。
void main() {
  late FakeFirebaseFirestore fs;
  late ShopEntryService service;

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = ShopEntryService(
      shopService: ShopService(firestore: fs),
      staffService: ShopStaffService(firestore: fs),
    );
  });

  Future<void> shop(String id, String ownerId, String name) =>
      fs.collection('shops').doc(id).set({
        'name': name,
        'type': 'maintenanceShop',
        'ownerId': ownerId,
        'createdAt': Timestamp.fromDate(DateTime(2026)),
        'updatedAt': Timestamp.fromDate(DateTime(2026)),
      });

  test('店主なら、自分の店（店主として）', () async {
    await shop('shop_a', 'owner1', 'タカヤモーター');
    final e = (await service.resolve('owner1')).valueOrNull!;
    expect(e.shopId, 'shop_a');
    expect(e.shopName, 'タカヤモーター');
    expect(e.isOwner, isTrue);
    expect(e.ownerUid, 'owner1');
  });

  test('スタッフなら、入っている店（スタッフとして）と、いまの店主', () async {
    await shop('shop_a', 'owner1', 'タカヤモーター');
    await fs
        .collection('shop_staff')
        .doc('staff1')
        .set({'shopId': 'shop_a', 'shopName': 'タカヤモーター'});
    final e = (await service.resolve('staff1')).valueOrNull!;
    expect(e.shopId, 'shop_a');
    expect(e.isOwner, isFalse);
    expect(e.ownerUid, 'owner1');
  });

  test('どちらでもなければ null（お客さん）', () async {
    await shop('shop_a', 'owner1', 'タカヤモーター');
    expect((await service.resolve('user1')).valueOrNull, isNull);
  });

  group('Edge Cases', () {
    test('uid が空なら null（読まない）', () async {
      expect((await service.resolve('')).valueOrNull, isNull);
    });

    test('店主でもあり別の店のスタッフでもあれば、自分の店を優先する', () async {
      await shop('mine', 'u1', '自分の店');
      await shop('other', 'owner2', '別の店');
      await fs
          .collection('shop_staff')
          .doc('u1')
          .set({'shopId': 'other', 'shopName': '別の店'});
      final e = (await service.resolve('u1')).valueOrNull!;
      expect(e.shopId, 'mine');
      expect(e.isOwner, isTrue);
    });

    test('スタッフの札の店が消えていても、札の名前で開ける（店主は不明）', () async {
      await fs
          .collection('shop_staff')
          .doc('staff1')
          .set({'shopId': 'gone', 'shopName': '閉じた店'});
      final e = (await service.resolve('staff1')).valueOrNull!;
      expect(e.shopName, '閉じた店');
      expect(e.ownerUid, isNull);
    });

    test('札の店IDが空なら、スタッフとみなさない', () async {
      await fs.collection('shop_staff').doc('staff1').set({'shopName': 'x'});
      expect((await service.resolve('staff1')).valueOrNull, isNull);
    });
  });
}
