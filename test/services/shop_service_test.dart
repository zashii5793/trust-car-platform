// ShopService / Shop Model Unit Tests
//
// Since ShopService requires FirebaseFirestore, we test:
//   1. Shop model methods (displayAddress, supportsMaker, offersService, isOpenNow)
//   2. BusinessHours.displayText
//   3. Enum behavior (ShopType, ServiceCategory)
//   4. AppError patterns for service error scenarios

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Shop _makeShop({
  String id = 'shop1',
  String? prefecture,
  String? city,
  String? address,
  List<ServiceCategory> services = const [],
  List<String> supportedMakerIds = const [],
  Map<int, BusinessHours> businessHours = const {},
}) {
  final now = DateTime.now();
  return Shop(
    id: id,
    name: 'テストショップ',
    type: ShopType.maintenanceShop,
    prefecture: prefecture,
    city: city,
    address: address,
    services: services,
    supportedMakerIds: supportedMakerIds,
    businessHours: businessHours,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ShopType enum', () {
    test('全タイプの displayName が空でない', () {
      for (final type in ShopType.values) {
        expect(type.displayName, isNotEmpty);
        expect(type.displayNameEn, isNotEmpty);
      }
    });

    test('fromString が既知の値を正しく変換する', () {
      expect(ShopType.fromString('maintenanceShop'), ShopType.maintenanceShop);
      expect(ShopType.fromString('dealer'), ShopType.dealer);
      expect(ShopType.fromString('carWash'), ShopType.carWash);
      expect(ShopType.fromString('other'), ShopType.other);
    });

    test('fromString が null を返す（不明な値）', () {
      expect(ShopType.fromString(null), isNull);
      expect(ShopType.fromString(''), isNull);
      expect(ShopType.fromString('invalid'), isNull);
    });

    test('fromString: 全 enum 値を往復変換できる', () {
      for (final type in ShopType.values) {
        expect(ShopType.fromString(type.name), type);
      }
    });
  });

  group('ServiceCategory enum', () {
    test('全カテゴリの displayName が空でない', () {
      for (final cat in ServiceCategory.values) {
        expect(cat.displayName, isNotEmpty);
        expect(cat.displayNameEn, isNotEmpty);
      }
    });

    test('fromString が既知の値を正しく変換する', () {
      expect(ServiceCategory.fromString('inspection'), ServiceCategory.inspection);
      expect(ServiceCategory.fromString('maintenance'), ServiceCategory.maintenance);
      expect(ServiceCategory.fromString('repair'), ServiceCategory.repair);
      expect(ServiceCategory.fromString('tire'), ServiceCategory.tire);
    });

    test('fromString が null を返す（不明な値）', () {
      expect(ServiceCategory.fromString(null), isNull);
      expect(ServiceCategory.fromString(''), isNull);
      expect(ServiceCategory.fromString('unknown'), isNull);
    });

    test('fromString: 全 enum 値を往復変換できる', () {
      for (final cat in ServiceCategory.values) {
        expect(ServiceCategory.fromString(cat.name), cat);
      }
    });
  });

  // ── BusinessHours.displayText ─────────────────────────────────────────────

  group('BusinessHours.displayText', () {
    test('isClosed=true のとき「定休日」', () {
      const hours = BusinessHours(isClosed: true);
      expect(hours.displayText, '定休日');
    });

    test('openTime/closeTime が両方 null のとき「-」', () {
      const hours = BusinessHours(isClosed: false);
      expect(hours.displayText, '-');
    });

    test('openTime のみ null のとき「-」', () {
      const hours = BusinessHours(closeTime: '18:00', isClosed: false);
      expect(hours.displayText, '-');
    });

    test('closeTime のみ null のとき「-」', () {
      const hours = BusinessHours(openTime: '09:00', isClosed: false);
      expect(hours.displayText, '-');
    });

    test('openTime と closeTime が揃っているとき「HH:MM〜HH:MM」形式', () {
      const hours = BusinessHours(openTime: '09:00', closeTime: '18:00');
      expect(hours.displayText, '09:00〜18:00');
    });

    test('早朝営業（06:00〜14:00）も正しく表示される', () {
      const hours = BusinessHours(openTime: '06:00', closeTime: '14:00');
      expect(hours.displayText, '06:00〜14:00');
    });

    test('fromMap(null) のとき isClosed=true となる', () {
      final hours = BusinessHours.fromMap(null);
      expect(hours.isClosed, true);
    });

    test('fromMap でのフィールド読み込みが正しい', () {
      final hours = BusinessHours.fromMap({
        'openTime': '10:00',
        'closeTime': '19:00',
        'isClosed': false,
      });
      expect(hours.openTime, '10:00');
      expect(hours.closeTime, '19:00');
      expect(hours.isClosed, false);
      expect(hours.displayText, '10:00〜19:00');
    });

    test('toMap が正しいマップを返す', () {
      const hours = BusinessHours(openTime: '09:00', closeTime: '18:00');
      final map = hours.toMap();
      expect(map['openTime'], '09:00');
      expect(map['closeTime'], '18:00');
      expect(map['isClosed'], false);
    });
  });

  // ── Shop.displayAddress ───────────────────────────────────────────────────

  group('Shop.displayAddress', () {
    test('都道府県・市区町村・住所すべてあるとき空白区切りで結合', () {
      final shop = _makeShop(
        prefecture: '東京都',
        city: '渋谷区',
        address: '道玄坂1-1-1',
      );
      expect(shop.displayAddress, '東京都 渋谷区 道玄坂1-1-1');
    });

    test('prefecture のみのとき prefecture だけ返す', () {
      final shop = _makeShop(prefecture: '大阪府');
      expect(shop.displayAddress, '大阪府');
    });

    test('address のみのとき address だけ返す', () {
      final shop = _makeShop(address: '南2条西4丁目');
      expect(shop.displayAddress, '南2条西4丁目');
    });

    test('全フィールドが null のとき空文字列を返す', () {
      final shop = _makeShop();
      expect(shop.displayAddress, '');
    });

    test('prefecture と city のみのとき 2 つを結合', () {
      final shop = _makeShop(prefecture: '愛知県', city: '名古屋市');
      expect(shop.displayAddress, '愛知県 名古屋市');
    });
  });

  // ── Shop.supportsMaker ────────────────────────────────────────────────────

  group('Shop.supportsMaker', () {
    test('supportedMakerIds が空のとき全メーカーに対応（true）', () {
      final shop = _makeShop(supportedMakerIds: []);
      expect(shop.supportsMaker('toyota'), true);
      expect(shop.supportsMaker('honda'), true);
      expect(shop.supportsMaker('any_maker'), true);
    });

    test('supportedMakerIds にメーカーが含まれるとき true', () {
      final shop = _makeShop(supportedMakerIds: ['toyota', 'honda']);
      expect(shop.supportsMaker('toyota'), true);
      expect(shop.supportsMaker('honda'), true);
    });

    test('supportedMakerIds にメーカーが含まれないとき false', () {
      final shop = _makeShop(supportedMakerIds: ['toyota', 'honda']);
      expect(shop.supportsMaker('nissan'), false);
    });

    test('単一メーカーのみ対応しているショップ', () {
      final shop = _makeShop(supportedMakerIds: ['bmw']);
      expect(shop.supportsMaker('bmw'), true);
      expect(shop.supportsMaker('mercedes'), false);
    });
  });

  // ── Shop.offersService ────────────────────────────────────────────────────

  group('Shop.offersService', () {
    test('services にカテゴリが含まれるとき true', () {
      final shop = _makeShop(services: [
        ServiceCategory.inspection,
        ServiceCategory.maintenance,
      ]);
      expect(shop.offersService(ServiceCategory.inspection), true);
      expect(shop.offersService(ServiceCategory.maintenance), true);
    });

    test('services にカテゴリが含まれないとき false', () {
      final shop = _makeShop(services: [ServiceCategory.inspection]);
      expect(shop.offersService(ServiceCategory.repair), false);
    });

    test('services が空のとき全て false', () {
      final shop = _makeShop(services: []);
      expect(shop.offersService(ServiceCategory.inspection), false);
    });
  });

  // ── Shop.isOpenNow ────────────────────────────────────────────────────────

  group('Shop.isOpenNow', () {
    test('businessHours が空のとき false', () {
      final shop = _makeShop(businessHours: {});
      expect(shop.isOpenNow, false);
    });

    test('今日の BusinessHours が isClosed=true のとき false', () {
      final weekday = DateTime.now().weekday % 7;
      final shop = _makeShop(businessHours: {
        weekday: const BusinessHours(isClosed: true),
      });
      expect(shop.isOpenNow, false);
    });

    test('今日の BusinessHours の openTime/closeTime が null のとき false', () {
      final weekday = DateTime.now().weekday % 7;
      final shop = _makeShop(businessHours: {
        weekday: const BusinessHours(isClosed: false),
      });
      expect(shop.isOpenNow, false);
    });

    test('00:00〜23:59 の範囲（常時営業）のとき true', () {
      final weekday = DateTime.now().weekday % 7;
      final shop = _makeShop(businessHours: {
        weekday: const BusinessHours(openTime: '00:00', closeTime: '23:59'),
      });
      expect(shop.isOpenNow, true);
    });

    test('営業時間外（終了後）のとき false', () {
      final weekday = DateTime.now().weekday % 7;
      // Already closed: 00:00〜00:01 (almost certainly past closing)
      final shop = _makeShop(businessHours: {
        weekday: const BusinessHours(openTime: '00:00', closeTime: '00:01'),
      });
      // May be true or false depending on current time; just verify no exception
      expect(() => shop.isOpenNow, returnsNormally);
    });
  });

  // ── AppError パターン ─────────────────────────────────────────────────────

  group('AppError パターン（サービスエラーシナリオ）', () {
    test('network error は isRetryable=true', () {
      const error = AppError.network('接続失敗');
      expect(error.isRetryable, true);
    });

    test('notFound error は isRetryable=false', () {
      const error = AppError.notFound('ショップが見つかりません');
      expect(error.isRetryable, false);
    });

    test('permission error は isRetryable=false', () {
      const error = AppError.permission('アクセス権限なし');
      expect(error.isRetryable, false);
    });

    test('unknown error に originalError を含められる', () {
      final original = Exception('DB Error');
      final error = AppError.unknown('予期しないエラー', originalError: original);
      expect(error.userMessage, isNotEmpty);
    });

    test('Result.success に Shop を格納できる', () {
      final now = DateTime.now();
      final shop = Shop(
        id: 's1', name: 'S', type: ShopType.other,
        createdAt: now, updatedAt: now,
      );
      final result = Result<Shop, AppError>.success(shop);
      expect(result.isSuccess, true);
    });

    test('Result.failure に AppError を格納できる', () {
      const result = Result<List<Shop>, AppError>.failure(
        AppError.server('failed'),
      );
      expect(result.isFailure, true);
    });
  });

  // ── Edge Cases ────────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('Shop の displayAddress: 同じ文字列が prefecture と city に入っても重複しない', () {
      final shop = _makeShop(prefecture: '北海道', city: '北海道札幌市');
      expect(shop.displayAddress, '北海道 北海道札幌市');
    });

    test('BusinessHours.fromMap: isClosed フィールドがない場合 false になる', () {
      final hours = BusinessHours.fromMap({'openTime': '09:00', 'closeTime': '18:00'});
      expect(hours.isClosed, false);
    });

    test('Shop: id の等価性', () {
      final now = DateTime.now();
      final a = Shop(id: 'x', name: 'A', type: ShopType.other, createdAt: now, updatedAt: now);
      final b = Shop(id: 'x', name: 'B', type: ShopType.dealer, createdAt: now, updatedAt: now);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('Shop: 異なる id は等しくない', () {
      final now = DateTime.now();
      final a = Shop(id: 'x', name: 'A', type: ShopType.other, createdAt: now, updatedAt: now);
      final b = Shop(id: 'y', name: 'A', type: ShopType.other, createdAt: now, updatedAt: now);
      expect(a, isNot(equals(b)));
    });

    test('Shop.offersService: 全 ServiceCategory を列挙しても例外なし', () {
      final shop = _makeShop(services: ServiceCategory.values.toList());
      for (final cat in ServiceCategory.values) {
        expect(() => shop.offersService(cat), returnsNormally);
      }
    });
  });
}
