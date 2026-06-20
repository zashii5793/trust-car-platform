import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/shop.dart';

void main() {
  group('ShopType', () {
    test('fromString returns correct enum value', () {
      expect(ShopType.fromString('maintenanceShop'), ShopType.maintenanceShop);
      expect(ShopType.fromString('dealer'), ShopType.dealer);
      expect(ShopType.fromString('partsShop'), ShopType.partsShop);
      expect(ShopType.fromString('gasStation'), ShopType.gasStation);
    });

    test('fromString returns null for invalid value', () {
      expect(ShopType.fromString('invalid'), isNull);
      expect(ShopType.fromString(null), isNull);
    });

    test('displayName returns Japanese name', () {
      expect(ShopType.maintenanceShop.displayName, '整備工場');
      expect(ShopType.dealer.displayName, 'ディーラー');
      expect(ShopType.partsShop.displayName, 'パーツショップ');
      expect(ShopType.gasStation.displayName, 'ガソリンスタンド');
    });
  });

  group('ServiceCategory', () {
    test('fromString returns correct enum value', () {
      expect(
          ServiceCategory.fromString('inspection'), ServiceCategory.inspection);
      expect(ServiceCategory.fromString('maintenance'),
          ServiceCategory.maintenance);
      expect(ServiceCategory.fromString('repair'), ServiceCategory.repair);
    });

    test('fromString returns null for invalid value', () {
      expect(ServiceCategory.fromString('invalid'), isNull);
      expect(ServiceCategory.fromString(null), isNull);
    });

    test('displayName returns Japanese name', () {
      expect(ServiceCategory.inspection.displayName, '車検');
      expect(ServiceCategory.maintenance.displayName, '整備・点検');
      expect(ServiceCategory.coating.displayName, 'コーティング');
    });
  });

  group('BusinessHours', () {
    test('creates with open and close times', () {
      const hours = BusinessHours(
        openTime: '09:00',
        closeTime: '18:00',
      );

      expect(hours.openTime, '09:00');
      expect(hours.closeTime, '18:00');
      expect(hours.isClosed, false);
    });

    test('creates closed day', () {
      const hours = BusinessHours(isClosed: true);

      expect(hours.isClosed, true);
      expect(hours.displayText, '定休日');
    });

    test('displayText shows time range', () {
      const hours = BusinessHours(
        openTime: '09:00',
        closeTime: '18:00',
      );

      expect(hours.displayText, '09:00〜18:00');
    });

    test('displayText shows dash when times are null', () {
      const hours = BusinessHours();

      expect(hours.displayText, '-');
    });

    test('fromMap creates from map', () {
      final hours = BusinessHours.fromMap({
        'openTime': '10:00',
        'closeTime': '19:00',
        'isClosed': false,
      });

      expect(hours.openTime, '10:00');
      expect(hours.closeTime, '19:00');
      expect(hours.isClosed, false);
    });

    test('fromMap handles null map', () {
      final hours = BusinessHours.fromMap(null);

      expect(hours.isClosed, true);
    });

    test('toMap converts to map', () {
      const hours = BusinessHours(
        openTime: '09:00',
        closeTime: '18:00',
        isClosed: false,
      );

      final map = hours.toMap();

      expect(map['openTime'], '09:00');
      expect(map['closeTime'], '18:00');
      expect(map['isClosed'], false);
    });
  });

  group('Shop', () {
    late Shop shop;

    setUp(() {
      shop = Shop(
        id: 'shop1',
        name: 'テスト整備工場',
        type: ShopType.maintenanceShop,
        description: 'テスト用の整備工場です',
        phone: '03-1234-5678',
        email: 'test@example.com',
        address: '1-2-3',
        prefecture: '東京都',
        city: '渋谷区',
        services: [ServiceCategory.inspection, ServiceCategory.maintenance],
        supportedMakerIds: ['toyota', 'honda'],
        businessHours: {
          1: const BusinessHours(openTime: '09:00', closeTime: '18:00'),
          2: const BusinessHours(openTime: '09:00', closeTime: '18:00'),
          0: const BusinessHours(isClosed: true),
        },
        rating: 4.5,
        reviewCount: 100,
        isVerified: true,
        isActive: true,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 15),
      );
    });

    test('displayAddress combines prefecture, city and address', () {
      expect(shop.displayAddress, '東京都 渋谷区 1-2-3');
    });

    test('supportsMaker returns true for supported maker', () {
      expect(shop.supportsMaker('toyota'), true);
      expect(shop.supportsMaker('honda'), true);
    });

    test('supportsMaker returns false for unsupported maker', () {
      expect(shop.supportsMaker('bmw'), false);
    });

    test('supportsMaker returns true for all when list is empty', () {
      final shopNoMakers = shop.copyWith(supportedMakerIds: []);

      expect(shopNoMakers.supportsMaker('bmw'), true);
      expect(shopNoMakers.supportsMaker('any'), true);
    });

    test('offersService returns true for offered service', () {
      expect(shop.offersService(ServiceCategory.inspection), true);
      expect(shop.offersService(ServiceCategory.maintenance), true);
    });

    test('offersService returns false for not offered service', () {
      expect(shop.offersService(ServiceCategory.coating), false);
    });

    test('toMap converts to map correctly', () {
      final map = shop.toMap();

      expect(map['name'], 'テスト整備工場');
      expect(map['type'], 'maintenanceShop');
      expect(map['prefecture'], '東京都');
      expect(map['rating'], 4.5);
      expect(map['reviewCount'], 100);
      expect(map['isVerified'], true);
      expect(map['services'], ['inspection', 'maintenance']);
      expect(map['supportedMakerIds'], ['toyota', 'honda']);
    });

    test('copyWith creates modified copy', () {
      final modified = shop.copyWith(
        name: '新しい名前',
        rating: 4.8,
      );

      expect(modified.name, '新しい名前');
      expect(modified.rating, 4.8);
      expect(modified.type, shop.type);
      expect(modified.id, shop.id);
    });

    test('equality is based on id', () {
      final shop2 = shop.copyWith(name: '別の名前');

      expect(shop == shop2, true);
      expect(shop.hashCode, shop2.hashCode);
    });

    test('toString returns readable format', () {
      expect(shop.toString(), 'Shop(テスト整備工場, 整備工場)');
    });
  });

  // -------------------------------------------------------------------------
  // ShopPlanType — Phase 7 (enterprise tier & helpers)
  // -------------------------------------------------------------------------
  group('ShopPlanType', () {
    test('fromString returns enterprise for "enterprise"', () {
      expect(ShopPlanType.fromString('enterprise'), ShopPlanType.enterprise);
    });

    test('fromString defaults to free for unknown string', () {
      expect(ShopPlanType.fromString('unknown'), ShopPlanType.free);
      expect(ShopPlanType.fromString(null), ShopPlanType.free);
    });

    test('displayName returns correct Japanese labels', () {
      expect(ShopPlanType.free.displayName, 'フリー');
      expect(ShopPlanType.standard.displayName, 'スタンダード');
      expect(ShopPlanType.premium.displayName, 'プレミアム');
      expect(ShopPlanType.enterprise.displayName, 'エンタープライズ');
    });

    test('monthlyPrice is null for free and set for paid tiers', () {
      expect(ShopPlanType.free.monthlyPrice, isNull);
      expect(ShopPlanType.standard.monthlyPrice, 3980);
      expect(ShopPlanType.premium.monthlyPrice, 9800);
      expect(ShopPlanType.enterprise.monthlyPrice, 14800);
    });
  });

  // -------------------------------------------------------------------------
  // ShopSubscriptionStatus
  // -------------------------------------------------------------------------
  group('ShopSubscriptionStatus', () {
    test('fromString parses all valid values', () {
      expect(ShopSubscriptionStatus.fromString('active'),
          ShopSubscriptionStatus.active);
      expect(ShopSubscriptionStatus.fromString('trialing'),
          ShopSubscriptionStatus.trialing);
      expect(ShopSubscriptionStatus.fromString('expired'),
          ShopSubscriptionStatus.expired);
      expect(ShopSubscriptionStatus.fromString('cancelled'),
          ShopSubscriptionStatus.cancelled);
      expect(ShopSubscriptionStatus.fromString('free'),
          ShopSubscriptionStatus.free);
    });

    test('fromString defaults to free for unknown string', () {
      expect(ShopSubscriptionStatus.fromString('invalid'),
          ShopSubscriptionStatus.free);
      expect(
          ShopSubscriptionStatus.fromString(null), ShopSubscriptionStatus.free);
    });
  });

  // -------------------------------------------------------------------------
  // Shop model — subscription fields
  // -------------------------------------------------------------------------
  group('Shop subscription fields', () {
    final now = DateTime(2026, 4, 29);
    final expiresAt = DateTime(2026, 5, 29);

    test('toMap serializes subscriptionStatus and revenueCatUserId', () {
      final s = Shop(
        id: 'shop1',
        name: 'Test',
        type: ShopType.maintenanceShop,
        planType: ShopPlanType.standard,
        subscriptionStatus: ShopSubscriptionStatus.active,
        revenueCatUserId: 'rc_123',
        planExpiresAt: expiresAt,
        createdAt: now,
        updatedAt: now,
      );

      final map = s.toMap();
      expect(map['planType'], 'standard');
      expect(map['subscriptionStatus'], 'active');
      expect(map['revenueCatUserId'], 'rc_123');
      expect(map['planExpiresAt'], isNotNull);
    });

    test('copyWith preserves subscriptionStatus', () {
      final s = Shop(
        id: 'shop1',
        name: 'Test',
        type: ShopType.maintenanceShop,
        subscriptionStatus: ShopSubscriptionStatus.trialing,
        createdAt: now,
        updatedAt: now,
      );

      final copy = s.copyWith(planType: ShopPlanType.premium);
      expect(copy.subscriptionStatus, ShopSubscriptionStatus.trialing);
      expect(copy.planType, ShopPlanType.premium);
    });

    test('default subscriptionStatus is free', () {
      final s = Shop(
        id: 'shop1',
        name: 'Test',
        type: ShopType.maintenanceShop,
        createdAt: now,
        updatedAt: now,
      );
      expect(s.subscriptionStatus, ShopSubscriptionStatus.free);
    });

    test('enterprise plan fields round-trip through copyWith', () {
      final s = Shop(
        id: 'shop1',
        name: 'Test',
        type: ShopType.maintenanceShop,
        planType: ShopPlanType.enterprise,
        subscriptionStatus: ShopSubscriptionStatus.active,
        revenueCatUserId: 'rc_ent',
        trialStartedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final copy = s.copyWith(name: 'Updated');
      expect(copy.planType, ShopPlanType.enterprise);
      expect(copy.revenueCatUserId, 'rc_ent');
      expect(copy.trialStartedAt, now);
    });
  });
}
