import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/utils/shop_map_utils.dart';
import 'package:trust_car_platform/models/shop.dart';

final _epoch = DateTime(2024);

Shop _makeShop({
  String id = 's1',
  bool isVerified = false,
  ShopSubscriptionStatus subscriptionStatus = ShopSubscriptionStatus.free,
  GeoPoint? location,
  String name = 'テスト工場',
}) {
  return Shop(
    id: id,
    name: name,
    type: ShopType.maintenanceShop,
    subscriptionStatus: subscriptionStatus,
    isVerified: isVerified,
    location: location,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

void main() {
  group('ShopPinCategory', () {
    test('アクティブ提携店はpartner', () {
      final shop = _makeShop(
        subscriptionStatus: ShopSubscriptionStatus.active,
      );
      expect(ShopMapUtils.categorize(shop), ShopPinCategory.partner);
    });

    test('トライアル提携店はpartner', () {
      final shop = _makeShop(
        subscriptionStatus: ShopSubscriptionStatus.trialing,
      );
      expect(ShopMapUtils.categorize(shop), ShopPinCategory.partner);
    });

    test('非提携店はnonPartner', () {
      final shop = _makeShop(
        subscriptionStatus: ShopSubscriptionStatus.free,
      );
      expect(ShopMapUtils.categorize(shop), ShopPinCategory.nonPartner);
    });

    test('expired提携店はnonPartner', () {
      final shop = _makeShop(
        subscriptionStatus: ShopSubscriptionStatus.expired,
      );
      expect(ShopMapUtils.categorize(shop), ShopPinCategory.nonPartner);
    });
  });

  group('filterShopsWithLocation', () {
    final withLocation = _makeShop(
      id: 'has-loc',
      location: const GeoPoint(35.68, 139.69),
    );
    final withoutLocation = _makeShop(id: 'no-loc');

    test('location nullの店舗を除外する', () {
      final result = ShopMapUtils.filterWithLocation(
        [withLocation, withoutLocation],
      );
      expect(result.length, 1);
      expect(result.first.id, 'has-loc');
    });

    test('全件locationありなら全件返す', () {
      final shops = [
        _makeShop(id: 'a', location: const GeoPoint(35.0, 139.0)),
        _makeShop(id: 'b', location: const GeoPoint(36.0, 140.0)),
      ];
      expect(ShopMapUtils.filterWithLocation(shops).length, 2);
    });

    test('空リストは空リストを返す', () {
      expect(ShopMapUtils.filterWithLocation([]), isEmpty);
    });
  });

  group('partitionShops', () {
    final partner = _makeShop(
      id: 'p1',
      subscriptionStatus: ShopSubscriptionStatus.active,
      location: const GeoPoint(35.68, 139.69),
    );
    final nonPartner = _makeShop(
      id: 'np1',
      location: const GeoPoint(35.70, 139.70),
    );

    test('提携店と非提携店を正しく分類する', () {
      final result = ShopMapUtils.partition([partner, nonPartner]);
      expect(result.partners.length, 1);
      expect(result.partners.first.id, 'p1');
      expect(result.nonPartners.length, 1);
      expect(result.nonPartners.first.id, 'np1');
    });

    test('全件提携店', () {
      final shops = [
        _makeShop(
          id: 'a',
          subscriptionStatus: ShopSubscriptionStatus.active,
          location: const GeoPoint(35.0, 139.0),
        ),
      ];
      final result = ShopMapUtils.partition(shops);
      expect(result.partners.length, 1);
      expect(result.nonPartners, isEmpty);
    });

    test('全件非提携店', () {
      final shops = [_makeShop(id: 'a', location: const GeoPoint(35.0, 139.0))];
      final result = ShopMapUtils.partition(shops);
      expect(result.partners, isEmpty);
      expect(result.nonPartners.length, 1);
    });

    test('空リスト', () {
      final result = ShopMapUtils.partition([]);
      expect(result.partners, isEmpty);
      expect(result.nonPartners, isEmpty);
    });
  });

  group('infoWindowTitle', () {
    test('提携店は名前＋「（審査済）」を返す', () {
      final shop = _makeShop(
        name: 'スマイル自動車',
        isVerified: true,
        subscriptionStatus: ShopSubscriptionStatus.active,
      );
      final title = ShopMapUtils.infoWindowTitle(shop);
      expect(title, contains('スマイル自動車'));
      expect(title, contains('審査済'));
    });

    test('非提携・非検証店は名前＋「（参考・未審査）」を返す', () {
      final shop = _makeShop(name: '未登録工場');
      final title = ShopMapUtils.infoWindowTitle(shop);
      expect(title, contains('未登録工場'));
      expect(title, contains('参考'));
      expect(title, contains('未審査'));
    });

    test('提携店で isVerified=false は名前のみ', () {
      final shop = _makeShop(
        name: '登録工場',
        subscriptionStatus: ShopSubscriptionStatus.active,
      );
      final title = ShopMapUtils.infoWindowTitle(shop);
      expect(title, contains('登録工場'));
      expect(title, isNot(contains('未審査')));
    });
  });

  group('Edge Cases', () {
    test('名前が空文字でもクラッシュしない', () {
      final shop = _makeShop(name: '');
      expect(() => ShopMapUtils.infoWindowTitle(shop), returnsNormally);
      expect(() => ShopMapUtils.categorize(shop), returnsNormally);
    });

    test('locationが(0,0)でもlocationありとして扱う', () {
      final shop = _makeShop(location: const GeoPoint(0, 0));
      final result = ShopMapUtils.filterWithLocation([shop]);
      expect(result.length, 1);
    });
  });
}
