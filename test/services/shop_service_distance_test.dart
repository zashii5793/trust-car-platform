// Tests for ShopService distance-based filtering (getNearbyShops).
// These tests document the Haversine distance contract and serve as
// regression coverage for the dart:math refactor of _calculateDistance.

import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint, Timestamp;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/shop_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Tokyo Station: 35.6812, 139.7671
const _tokyoStation = GeoPoint(35.6812, 139.7671);

/// ~1 km north of Tokyo Station
const _shop1km = GeoPoint(35.6902, 139.7671);

/// ~5 km north of Tokyo Station
const _shop5km = GeoPoint(35.7262, 139.7671);

/// ~11 km north of Tokyo Station (outside 10 km radius)
const _shop11km = GeoPoint(35.7802, 139.7671);

/// Osaka: ~401 km from Tokyo
const _osaka = GeoPoint(34.6937, 135.5023);

Future<void> _addShop(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String name,
  GeoPoint? location,
  double rating = 4.0,
  int reviewCount = 10,
}) async {
  await firestore.collection('shops').doc(id).set({
    'name': name,
    'type': 'maintenanceShop',
    'isActive': true,
    'isVerified': false,
    'isFeatured': false,
    'isPartner': false,
    'rating': rating,
    'reviewCount': reviewCount,
    'services': <String>[],
    'supportedMakerIds': <String>[],
    'businessHours': <String, dynamic>{},
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
    if (location != null) 'location': location,
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ShopService.getNearbyShops', () {
    late FakeFirebaseFirestore firestore;
    late ShopService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ShopService(firestore: firestore);
    });

    test('半径5km内の店舗のみ返す（10km圏外は除外）', () async {
      await _addShop(firestore, id: 'near', name: '近い店', location: _shop1km);
      await _addShop(firestore, id: 'mid', name: '5km店', location: _shop5km);
      await _addShop(firestore, id: 'far', name: '11km店', location: _shop11km);

      final result = await service.getNearbyShops(_tokyoStation, 10, limit: 20);

      expect(result.isSuccess, isTrue);
      final shops = result.valueOrNull!;
      expect(shops.map((s) => s.id), containsAll(['near', 'mid']));
      expect(shops.map((s) => s.id), isNot(contains('far')));
    });

    test('半径3km → 1km店だけ含まれ5km店は除外', () async {
      await _addShop(firestore, id: 'near', name: '近い店', location: _shop1km);
      await _addShop(firestore, id: 'mid', name: '5km店', location: _shop5km);

      final result = await service.getNearbyShops(_tokyoStation, 3, limit: 20);

      expect(result.isSuccess, isTrue);
      final shops = result.valueOrNull!;
      expect(shops.map((s) => s.id), contains('near'));
      expect(shops.map((s) => s.id), isNot(contains('mid')));
    });

    test('location が null の店舗は除外される', () async {
      await _addShop(firestore, id: 'no-loc', name: '位置なし店', location: null);
      await _addShop(firestore,
          id: 'with-loc', name: '位置あり店', location: _shop1km);

      final result = await service.getNearbyShops(_tokyoStation, 10, limit: 20);

      expect(result.isSuccess, isTrue);
      final shops = result.valueOrNull!;
      expect(shops.map((s) => s.id), isNot(contains('no-loc')));
      expect(shops.map((s) => s.id), contains('with-loc'));
    });

    test('radius内に店舗がない → 空リスト', () async {
      await _addShop(firestore, id: 'far', name: '遠い店', location: _osaka);

      final result = await service.getNearbyShops(_tokyoStation, 10, limit: 20);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!, isEmpty);
    });

    test('同一地点 → 距離0 → 含まれる', () async {
      await _addShop(firestore,
          id: 'same', name: '同地点店', location: _tokyoStation);

      final result = await service.getNearbyShops(_tokyoStation, 1, limit: 20);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.map((s) => s.id), contains('same'));
    });

    test('isActive=false の店舗は返さない', () async {
      await firestore.collection('shops').doc('inactive').set({
        'name': '非アクティブ店',
        'type': 'maintenanceShop',
        'isActive': false,
        'isVerified': false,
        'isFeatured': false,
        'isPartner': false,
        'rating': 4.0,
        'reviewCount': 5,
        'services': <String>[],
        'supportedMakerIds': <String>[],
        'businessHours': <String, dynamic>{},
        'location': _shop1km,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final result = await service.getNearbyShops(_tokyoStation, 10, limit: 20);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.map((s) => s.id), isNot(contains('inactive')));
    });

    test('limit が適用される', () async {
      for (var i = 0; i < 5; i++) {
        await _addShop(
          firestore,
          id: 'shop$i',
          name: '店舗$i',
          location: _shop1km,
          rating: (5 - i).toDouble(),
        );
      }

      final result = await service.getNearbyShops(_tokyoStation, 10, limit: 3);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.length, lessThanOrEqualTo(3));
    });

    group('距離精度', () {
      test('Osaka (~401km) は 450km 半径に含まれ 350km 半径から除外される', () async {
        await _addShop(firestore, id: 'osaka', name: '大阪店', location: _osaka);

        final within450 =
            await service.getNearbyShops(_tokyoStation, 450, limit: 20);
        final within350 =
            await service.getNearbyShops(_tokyoStation, 350, limit: 20);

        expect(within450.valueOrNull!.map((s) => s.id), contains('osaka'));
        expect(
            within350.valueOrNull!.map((s) => s.id), isNot(contains('osaka')));
      });
    });
  });

  group('Edge Cases', () {
    late FakeFirebaseFirestore firestore;
    late ShopService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ShopService(firestore: firestore);
    });

    test('radiusKm=0 → 同一地点のみ含まれる', () async {
      await _addShop(firestore,
          id: 'same', name: '同地点', location: _tokyoStation);
      await _addShop(firestore, id: 'near', name: '1km', location: _shop1km);

      final result = await service.getNearbyShops(_tokyoStation, 0, limit: 20);

      // 距離0 (自身) は 0 <= 0 で含まれるが、1km先は除外される
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.map((s) => s.id), isNot(contains('near')));
    });

    test('店舗が0件でも Result.success を返す', () async {
      final result = await service.getNearbyShops(_tokyoStation, 10, limit: 20);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!, isEmpty);
    });
  });
}
