// ServiceMenuService / ServiceMenu Model Unit Tests
//
// Since ServiceMenuService requires FirebaseFirestore, we test pure business logic:
//   1. ServiceCategory enum (icons, colors, fromString)
//   2. PricingType enum (fromString, デフォルト挙動)
//   3. ServiceMenu.priceDisplay (4パターン × null/値あり)
//   4. ServiceMenu.estimatedTimeDisplay (null/< 1h/整数h/範囲)
//   5. ServiceMenu equality
//   6. AppError patterns

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/service_menu.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

ServiceMenu _makeMenu({
  String id = 'menu1',
  ServiceCategory category = ServiceCategory.maintenance,
  PricingType pricingType = PricingType.fixed,
  int? basePrice,
  int? laborCostPerHour,
  double? estimatedHours,
  double? minHours,
  double? maxHours,
}) {
  final now = DateTime.now();
  return ServiceMenu(
    id: id,
    category: category,
    name: 'テストサービス',
    pricingType: pricingType,
    basePrice: basePrice,
    laborCostPerHour: laborCostPerHour,
    estimatedHours: estimatedHours,
    minHours: minHours,
    maxHours: maxHours,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ServiceCategory enum', () {
    test('全カテゴリの displayName が空でない', () {
      for (final cat in ServiceCategory.values) {
        expect(cat.displayName, isNotEmpty);
      }
    });

    test('icon / color フィールドが存在する', () {
      for (final cat in ServiceCategory.values) {
        expect(cat.icon, isNotNull);
        expect(cat.color, isNotNull);
      }
    });

    test('fromString が既知の値を正しく変換する', () {
      expect(ServiceCategory.fromString('inspection'), ServiceCategory.inspection);
      expect(ServiceCategory.fromString('maintenance'), ServiceCategory.maintenance);
      expect(ServiceCategory.fromString('oilChange'), ServiceCategory.oilChange);
      expect(ServiceCategory.fromString('tire'), ServiceCategory.tire);
      expect(ServiceCategory.fromString('coating'), ServiceCategory.coating);
      expect(ServiceCategory.fromString('washing'), ServiceCategory.washing);
    });

    test('fromString(null) はデフォルト（other）を返す', () {
      expect(ServiceCategory.fromString(null), ServiceCategory.other);
    });

    test('fromString 不明な文字列は other を返す', () {
      expect(ServiceCategory.fromString(''), ServiceCategory.other);
      expect(ServiceCategory.fromString('invalid_category'), ServiceCategory.other);
    });

    test('全 enum 値を往復変換できる', () {
      for (final cat in ServiceCategory.values) {
        expect(ServiceCategory.fromString(cat.name), cat);
      }
    });
  });

  group('PricingType enum', () {
    test('全タイプの displayName が空でない', () {
      for (final type in PricingType.values) {
        expect(type.displayName, isNotEmpty);
      }
    });

    test('fromString が既知の値を正しく変換する', () {
      expect(PricingType.fromString('fixed'), PricingType.fixed);
      expect(PricingType.fromString('perHour'), PricingType.perHour);
      expect(PricingType.fromString('estimate'), PricingType.estimate);
      expect(PricingType.fromString('fromPrice'), PricingType.fromPrice);
    });

    test('fromString(null) はデフォルト（fixed）を返す', () {
      expect(PricingType.fromString(null), PricingType.fixed);
    });

    test('fromString 不明な文字列は fixed を返す', () {
      expect(PricingType.fromString(''), PricingType.fixed);
      expect(PricingType.fromString('unknown'), PricingType.fixed);
    });

    test('全 enum 値を往復変換できる', () {
      for (final t in PricingType.values) {
        expect(PricingType.fromString(t.name), t);
      }
    });
  });

  // ── ServiceMenu.priceDisplay ──────────────────────────────────────────────

  group('ServiceMenu.priceDisplay — fixed', () {
    test('basePrice あり → 「¥X,XXX」', () {
      final menu = _makeMenu(pricingType: PricingType.fixed, basePrice: 5000);
      expect(menu.priceDisplay, '¥5,000');
    });

    test('basePrice なし → 「要問合せ」', () {
      final menu = _makeMenu(pricingType: PricingType.fixed, basePrice: null);
      expect(menu.priceDisplay, '要問合せ');
    });

    test('basePrice=0 → 「¥0」', () {
      final menu = _makeMenu(pricingType: PricingType.fixed, basePrice: 0);
      expect(menu.priceDisplay, '¥0');
    });

    test('basePrice=100000 → 「¥100,000」', () {
      final menu = _makeMenu(pricingType: PricingType.fixed, basePrice: 100000);
      expect(menu.priceDisplay, '¥100,000');
    });
  });

  group('ServiceMenu.priceDisplay — perHour', () {
    test('laborCostPerHour あり → 「¥X,XXX/時間」', () {
      final menu = _makeMenu(
        pricingType: PricingType.perHour, laborCostPerHour: 8000);
      expect(menu.priceDisplay, '¥8,000/時間');
    });

    test('laborCostPerHour なし → 「要問合せ」', () {
      final menu = _makeMenu(
        pricingType: PricingType.perHour, laborCostPerHour: null);
      expect(menu.priceDisplay, '要問合せ');
    });

    test('laborCostPerHour=1000 → 「¥1,000/時間」', () {
      final menu = _makeMenu(
        pricingType: PricingType.perHour, laborCostPerHour: 1000);
      expect(menu.priceDisplay, '¥1,000/時間');
    });
  });

  group('ServiceMenu.priceDisplay — estimate', () {
    test('basePrice あり・なし関わらず「要見積」', () {
      final withPrice = _makeMenu(pricingType: PricingType.estimate, basePrice: 50000);
      final withoutPrice = _makeMenu(pricingType: PricingType.estimate, basePrice: null);
      expect(withPrice.priceDisplay, '要見積');
      expect(withoutPrice.priceDisplay, '要見積');
    });
  });

  group('ServiceMenu.priceDisplay — fromPrice', () {
    test('basePrice あり → 「¥X,XXX〜」', () {
      final menu = _makeMenu(pricingType: PricingType.fromPrice, basePrice: 30000);
      expect(menu.priceDisplay, '¥30,000〜');
    });

    test('basePrice なし → 「要問合せ」', () {
      final menu = _makeMenu(pricingType: PricingType.fromPrice, basePrice: null);
      expect(menu.priceDisplay, '要問合せ');
    });

    test('basePrice=500 → 「¥500〜」', () {
      final menu = _makeMenu(pricingType: PricingType.fromPrice, basePrice: 500);
      expect(menu.priceDisplay, '¥500〜');
    });
  });

  // ── ServiceMenu.estimatedTimeDisplay ─────────────────────────────────────

  group('ServiceMenu.estimatedTimeDisplay', () {
    test('全フィールド null のとき「要問合せ」', () {
      final menu = _makeMenu();
      expect(menu.estimatedTimeDisplay, '要問合せ');
    });

    test('estimatedHours < 1 のとき「約X分」', () {
      final menu = _makeMenu(estimatedHours: 0.5);
      expect(menu.estimatedTimeDisplay, '約30分');
    });

    test('estimatedHours = 0.25 (15分) のとき「約15分」', () {
      final menu = _makeMenu(estimatedHours: 0.25);
      expect(menu.estimatedTimeDisplay, '約15分');
    });

    test('estimatedHours = 1.0 のとき「約1.0時間」', () {
      final menu = _makeMenu(estimatedHours: 1.0);
      expect(menu.estimatedTimeDisplay, '約1.0時間');
    });

    test('estimatedHours = 2.5 のとき「約2.5時間」', () {
      final menu = _makeMenu(estimatedHours: 2.5);
      expect(menu.estimatedTimeDisplay, '約2.5時間');
    });

    test('minHours + maxHours の範囲表示', () {
      final menu = _makeMenu(minHours: 1.0, maxHours: 3.0);
      expect(menu.estimatedTimeDisplay, '1.0〜3.0時間');
    });

    test('minHours のみ（maxHours null）のとき「要問合せ」', () {
      final menu = _makeMenu(minHours: 1.0, maxHours: null);
      expect(menu.estimatedTimeDisplay, '要問合せ');
    });

    test('maxHours のみ（minHours null）のとき「要問合せ」', () {
      final menu = _makeMenu(minHours: null, maxHours: 3.0);
      expect(menu.estimatedTimeDisplay, '要問合せ');
    });

    test('estimatedHours が設定されていれば minHours/maxHours より優先', () {
      final menu = _makeMenu(
        estimatedHours: 2.0,
        minHours: 1.0,
        maxHours: 5.0,
      );
      expect(menu.estimatedTimeDisplay, '約2.0時間');
    });
  });

  // ── ServiceMenu.toString ──────────────────────────────────────────────────

  group('ServiceMenu.toString', () {
    test('toString に name, category, price が含まれる', () {
      final menu = _makeMenu(
        category: ServiceCategory.oilChange,
        basePrice: 5000,
      );
      expect(menu.toString(), contains('テストサービス'));
      expect(menu.toString(), contains('オイル関連'));
      expect(menu.toString(), contains('¥5,000'));
    });
  });

  // ── ServiceMenu equality ──────────────────────────────────────────────────

  group('ServiceMenu equality', () {
    test('同じ id は等しい', () {
      final a = _makeMenu(id: 'm1', basePrice: 5000);
      final b = _makeMenu(id: 'm1', basePrice: 99999);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('異なる id は等しくない', () {
      final a = _makeMenu(id: 'm1');
      final b = _makeMenu(id: 'm2');
      expect(a, isNot(equals(b)));
    });
  });

  // ── AppError パターン ─────────────────────────────────────────────────────

  group('AppError パターン（サービスメニューエラーシナリオ）', () {
    test('network error は isRetryable=true', () {
      const error = AppError.network('接続失敗');
      expect(error.isRetryable, true);
    });

    test('notFound error は isRetryable=false', () {
      const error = AppError.notFound('メニューが見つかりません');
      expect(error.isRetryable, false);
    });

    test('Result.success に ServiceMenu リストを格納できる', () {
      final result = Result<List<ServiceMenu>, AppError>.success([_makeMenu()]);
      expect(result.isSuccess, true);
    });
  });

  // ── Edge Cases ────────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('priceDisplay: 1,000,000 円（百万円）のカンマ区切り', () {
      final menu = _makeMenu(pricingType: PricingType.fixed, basePrice: 1000000);
      expect(menu.priceDisplay, '¥1,000,000');
    });

    test('estimatedTimeDisplay: 0.1時間 = 6分', () {
      final menu = _makeMenu(estimatedHours: 0.1);
      expect(menu.estimatedTimeDisplay, '約6分');
    });

    test('estimatedTimeDisplay: minHours=maxHours でも範囲表示になる', () {
      final menu = _makeMenu(minHours: 2.0, maxHours: 2.0);
      expect(menu.estimatedTimeDisplay, '2.0〜2.0時間');
    });

    test('ServiceCategory: 全カテゴリで priceDisplay が例外なし', () {
      for (final cat in ServiceCategory.values) {
        final menu = _makeMenu(category: cat);
        expect(() => menu.priceDisplay, returnsNormally);
      }
    });

    test('PricingType: 全タイプで estimatedTimeDisplay が例外なし', () {
      for (final type in PricingType.values) {
        final menu = _makeMenu(pricingType: type);
        expect(() => menu.estimatedTimeDisplay, returnsNormally);
      }
    });
  });
}
