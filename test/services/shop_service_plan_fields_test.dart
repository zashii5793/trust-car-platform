// ShopService.createMyShop / updateMyShop とプランの項目。
//
// 2026-09-30: 店舗プランは請求書払い。プランの項目（planType・
// subscriptionStatus・planExpiresAt など）は運営者がサーバ側で切り替える。
// 店主の画面から保存しても、プランの項目は書かない（ルールでも止める）。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/services/shop_service.dart';

Shop _shop({
  String id = 'owner1',
  String ownerId = 'owner1',
  String name = 'テストモータース',
  ShopPlanType planType = ShopPlanType.free,
  ShopSubscriptionStatus status = ShopSubscriptionStatus.free,
  DateTime? planExpiresAt,
}) {
  final now = DateTime(2026, 9, 30);
  return Shop(
    id: id,
    name: name,
    type: ShopType.maintenanceShop,
    ownerId: ownerId,
    planType: planType,
    subscriptionStatus: status,
    planExpiresAt: planExpiresAt,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late FakeFirebaseFirestore fs;
  late ShopService service;

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = ShopService(firestore: fs);
  });

  group('createMyShop', () {
    test('有料プランを渡されても、フリーで作る', () async {
      final r = await service.createMyShop(_shop(
        planType: ShopPlanType.premium,
        status: ShopSubscriptionStatus.active,
        planExpiresAt: DateTime(2030),
      ));

      expect(r.isSuccess, isTrue);
      final d = (await fs.collection('shops').doc('owner1').get()).data()!;
      expect(d['planType'], 'free');
      expect(d['subscriptionStatus'], 'free');
      expect(d['planExpiresAt'], isNull);
      expect(d['revenueCatUserId'], isNull);
      expect(d['trialStartedAt'], isNull);
      expect(r.valueOrNull!.planType, ShopPlanType.free);
    });
  });

  group('updateMyShop', () {
    test('プランの項目は書き換えず、ほかの項目だけ保存する', () async {
      await fs.collection('shops').doc('owner1').set({
        'name': '旧店名',
        'ownerId': 'owner1',
        'planType': 'premium',
        'subscriptionStatus': 'active',
        'planExpiresAt': Timestamp.fromDate(DateTime(2027, 1, 1)),
        'revenueCatUserId': 'rc_1',
      });

      // 画面から来る Shop はプランを知らない（既定のフリー）
      final r = await service.updateMyShop(_shop(name: '新店名'));

      expect(r.isSuccess, isTrue);
      final d = (await fs.collection('shops').doc('owner1').get()).data()!;
      expect(d['name'], '新店名');
      expect(d['planType'], 'premium');
      expect(d['subscriptionStatus'], 'active');
      expect((d['planExpiresAt'] as Timestamp).toDate(), DateTime(2027, 1, 1));
      expect(d['revenueCatUserId'], 'rc_1');
    });

    group('Edge Cases', () {
      test('店が無ければ notFound', () async {
        final r = await service.updateMyShop(_shop());
        expect(r.errorOrNull, isA<NotFoundError>());
      });

      test('他人の店は permission', () async {
        await fs.collection('shops').doc('owner1').set({
          'name': '店',
          'ownerId': 'someone_else',
        });
        final r = await service.updateMyShop(_shop());
        expect(r.errorOrNull, isA<PermissionError>());
      });

      test('フリーの店をフリーのまま直しても、プランの項目は増えない', () async {
        await fs.collection('shops').doc('owner1').set({
          'name': '店',
          'ownerId': 'owner1',
        });
        await service.updateMyShop(_shop(name: '新店名'));
        final d = (await fs.collection('shops').doc('owner1').get()).data()!;
        expect(d.containsKey('planType'), isFalse);
        expect(d.containsKey('subscriptionStatus'), isFalse);
      });
    });
  });
}
