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
  bool isFeatured = false,
  String? prefecture,
}) {
  return Shop(
    id: id,
    name: name,
    type: ShopType.maintenanceShop,
    subscriptionStatus: subscriptionStatus,
    isVerified: isVerified,
    isFeatured: isFeatured,
    location: location,
    prefecture: prefecture,
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

  group('infoWindowTitle（広告）', () {
    test('広告（isFeatured）の店は「広告」を明示する', () {
      final shop = _makeShop(
        name: '広告工場',
        isFeatured: true,
        subscriptionStatus: ShopSubscriptionStatus.active,
      );
      expect(ShopMapUtils.infoWindowTitle(shop), contains('広告'));
    });

    test('審査済かつ広告は両方を出す', () {
      final shop = _makeShop(
        isVerified: true,
        isFeatured: true,
        subscriptionStatus: ShopSubscriptionStatus.active,
      );
      final title = ShopMapUtils.infoWindowTitle(shop);
      expect(title, contains('審査済'));
      expect(title, contains('広告'));
    });
  });

  group('buildPins', () {
    final partner = _makeShop(
      id: 'partner',
      subscriptionStatus: ShopSubscriptionStatus.active,
      isVerified: true,
      location: const GeoPoint(35.0, 139.0),
    );
    final nonPartner = _makeShop(
      id: 'non-partner',
      location: const GeoPoint(35.1, 139.1),
    );
    final noLocation = _makeShop(id: 'no-location');

    test('位置のある店だけがピンになる', () {
      final pins = ShopMapUtils.buildPins([partner, noLocation, nonPartner]);
      expect(pins.map((p) => p.shopId), ['partner', 'non-partner']);
    });

    test('提携・非提携でピンの種類が分かれる', () {
      final pins = ShopMapUtils.buildPins([partner, nonPartner]);
      expect(pins[0].category, ShopPinCategory.partner);
      expect(pins[1].category, ShopPinCategory.nonPartner);
    });

    test('ピンの座標は店の location', () {
      final pin = ShopMapUtils.buildPins([partner]).single;
      expect(pin.latitude, 35.0);
      expect(pin.longitude, 139.0);
    });

    test('審査済・広告のフラグがピンに載る', () {
      final featured = _makeShop(
        id: 'ad',
        isFeatured: true,
        location: const GeoPoint(35.2, 139.2),
      );
      final pins = ShopMapUtils.buildPins([partner, featured]);
      expect(pins[0].isVerified, isTrue);
      expect(pins[0].isFeatured, isFalse);
      expect(pins[1].isFeatured, isTrue);
    });

    test('距離があれば近い順に並び、ピンに距離が載る', () {
      final distances = {'partner': 5.0, 'non-partner': 1.2};
      final pins = ShopMapUtils.buildPins(
        [partner, nonPartner],
        distanceFor: (id) => distances[id],
      );
      expect(pins.map((p) => p.shopId), ['non-partner', 'partner']);
      expect(pins.first.distanceKm, 1.2);
    });

    test('距離が分からない店は末尾に並ぶ（入力順は保つ）', () {
      final third =
          _makeShop(id: 'third', location: const GeoPoint(35.3, 139.3));
      final pins = ShopMapUtils.buildPins(
        [partner, nonPartner, third],
        distanceFor: (id) => id == 'third' ? 3.0 : null,
      );
      expect(pins.map((p) => p.shopId), ['third', 'partner', 'non-partner']);
    });

    test('snippet に距離と住所が入る', () {
      final shop = _makeShop(
        id: 'a',
        prefecture: '東京都',
        location: const GeoPoint(35.0, 139.0),
      );
      final pin = ShopMapUtils.buildPins(
        [shop],
        distanceFor: (_) => 1.234,
      ).single;
      expect(pin.snippet, contains('1.2km'));
      expect(pin.snippet, contains('東京都'));
    });

    test('距離も住所も無ければ snippet は空', () {
      final pin = ShopMapUtils.buildPins([nonPartner]).single;
      expect(pin.snippet, isEmpty);
    });
  });

  group('initialCenter', () {
    final partner = _makeShop(
      id: 'partner',
      subscriptionStatus: ShopSubscriptionStatus.active,
      location: const GeoPoint(34.7, 135.5),
    );
    final nonPartner = _makeShop(
      id: 'non-partner',
      location: const GeoPoint(43.0, 141.3),
    );

    test('現在地があれば現在地を中心にする', () {
      final pins = ShopMapUtils.buildPins([partner]);
      final center = ShopMapUtils.initialCenter(
        pins,
        origin: (latitude: 35.68, longitude: 139.76),
      );
      expect(center.latitude, 35.68);
      expect(center.longitude, 139.76);
    });

    test('現在地が無ければ先頭の提携店を中心にする', () {
      final pins = ShopMapUtils.buildPins([nonPartner, partner]);
      final center = ShopMapUtils.initialCenter(pins);
      expect(center.latitude, 34.7);
      expect(center.longitude, 135.5);
    });

    test('提携店が無ければ先頭のピンを中心にする', () {
      final pins = ShopMapUtils.buildPins([nonPartner]);
      final center = ShopMapUtils.initialCenter(pins);
      expect(center.latitude, 43.0);
    });

    test('ピンも現在地も無ければ東京駅付近', () {
      final center = ShopMapUtils.initialCenter(const []);
      expect(center, ShopMapUtils.defaultCenter);
      expect(center.latitude, closeTo(35.68, 0.01));
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

    test('店0件ならピンも0件', () {
      expect(ShopMapUtils.buildPins(const []), isEmpty);
    });

    test('距離0kmでも snippet に出る', () {
      final shop = _makeShop(location: const GeoPoint(35.0, 139.0));
      final pin = ShopMapUtils.buildPins([shop], distanceFor: (_) => 0).single;
      expect(pin.snippet, contains('0.0km'));
    });
  });
}
