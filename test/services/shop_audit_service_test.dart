import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/shop_audit_service.dart';

void main() {
  late FakeFirebaseFirestore fs;
  late ShopAuditService service;
  var clock = DateTime(2026, 9, 29, 9);

  setUp(() {
    fs = FakeFirebaseFirestore();
    clock = DateTime(2026, 9, 29, 9);
    service = ShopAuditService(firestore: fs, now: () => clock);
  });

  test('記録は新しい順に並び、顧客で絞れる', () async {
    final rec =
        service.recorderFor(shopId: 's1', actorUid: 'u1', actorName: '佐藤');
    rec(ShopAuditAction.viewCustomer, targetId: 'c1', targetLabel: '山田');
    await Future<void>.delayed(Duration.zero);
    clock = clock.add(const Duration(minutes: 5));
    rec(ShopAuditAction.updateCustomer, targetId: 'c2', targetLabel: '田中');
    await Future<void>.delayed(Duration.zero);
    clock = clock.add(const Duration(minutes: 5));
    rec(ShopAuditAction.importRoster, detail: '名簿.csv・新規2人');
    await Future<void>.delayed(Duration.zero);

    final all = (await service.list(shopId: 's1')).valueOrNull!.items;
    expect(all.map((e) => e.action), [
      ShopAuditAction.importRoster,
      ShopAuditAction.updateCustomer,
      ShopAuditAction.viewCustomer,
    ]);
    expect(all.last.actorName, '佐藤');

    final c1 =
        (await service.list(shopId: 's1', customerId: 'c1')).valueOrNull!.items;
    expect(c1.single.targetLabel, '山田');
  });

  group('Edge Cases', () {
    test('店か人が分からなければ記録しない', () async {
      await service.record(
          shopId: '',
          actorUid: 'u1',
          actorName: 'x',
          action: ShopAuditAction.viewCustomer);
      await service.record(
          shopId: 's1',
          actorUid: '',
          actorName: 'x',
          action: ShopAuditAction.viewCustomer);
      expect((await service.list(shopId: 's1')).valueOrNull!.items, isEmpty);
    });

    test('知らない操作名が入っていても読める', () async {
      await fs.collection('shops/s1/audit_logs').add({
        'actorUid': 'u1',
        'actorName': 'x',
        'action': 'future_action',
        'at': DateTime(2026),
      });
      final e = (await service.list(shopId: 's1')).valueOrNull!.items.single;
      expect(e.action, isNull);
    });
  });
}
