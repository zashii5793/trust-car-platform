// FleetPlan Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/fleet_plan.dart';

void main() {
  group('FleetPlan.requiresPaidPlan', () {
    test('4台まで → 無料（対象外）', () {
      expect(FleetPlan.requiresPaidPlan(0), isFalse);
      expect(FleetPlan.requiresPaidPlan(1), isFalse);
      expect(FleetPlan.requiresPaidPlan(4), isFalse);
    });

    test('5台以上 → 有料プラン対象', () {
      expect(FleetPlan.requiresPaidPlan(5), isTrue);
      expect(FleetPlan.requiresPaidPlan(50), isTrue);
    });

    group('Edge Cases', () {
      test('境界値: 4/5台で切り替わる', () {
        expect(FleetPlan.requiresPaidPlan(4), isFalse);
        expect(FleetPlan.requiresPaidPlan(5), isTrue);
      });
    });
  });

  group('FleetPlan.monthlyPriceFor', () {
    test('4台まで → null（無料）', () {
      expect(FleetPlan.monthlyPriceFor(4), isNull);
    });

    test('5〜20台 → フリート価格 ¥4,980', () {
      expect(FleetPlan.monthlyPriceFor(5), 4980);
      expect(FleetPlan.monthlyPriceFor(20), 4980);
    });

    test('21〜50台 → ビジネス価格 ¥9,800', () {
      expect(FleetPlan.monthlyPriceFor(21), 9800);
      expect(FleetPlan.monthlyPriceFor(50), 9800);
    });

    test('51台以上 → null（エンタープライズ個別見積もり）', () {
      expect(FleetPlan.monthlyPriceFor(51), isNull);
    });
  });

  group('FleetPlan.planLabelFor', () {
    test('台数ごとのプラン名', () {
      expect(FleetPlan.planLabelFor(1), 'フリー');
      expect(FleetPlan.planLabelFor(5), 'フリート');
      expect(FleetPlan.planLabelFor(21), 'ビジネス');
      expect(FleetPlan.planLabelFor(51), 'エンタープライズ');
    });
  });

  group('FleetPlan.isBillableNow', () {
    test('無料開放期間中は何台でも課金されない', () {
      // ローンチ戦略: まず使ってもらいメリットを実感してから有料化
      expect(FleetPlan.isPromotionalFreePeriod, isTrue);
      expect(FleetPlan.isBillableNow(5), isFalse);
      expect(FleetPlan.isBillableNow(100), isFalse);
    });
  });
}
