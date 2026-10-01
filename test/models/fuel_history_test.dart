// FuelEfficiency.history / FuelSummary のテスト
//
// なぜ要るか:
//   給油は記録できるのに、**振り返る場所が無かった**（保存直後に燃費が
//   1回出るだけ）。1年で75件たまる記録なので、一覧と平均が要る。
//
//   計算は純関数に置く。画面から切り離しておけば、満タン法の扱い
//   （継ぎ足しは飛ばさず量に足す）をテストで固定できる。

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/fuel_record.dart';

void main() {
  FuelRecord rec({
    required String id,
    required DateTime date,
    required double liters,
    required int cost,
    int? odometer,
    bool isFullTank = true,
  }) =>
      FuelRecord(
        id: id,
        vehicleId: 'v1',
        userId: 'u1',
        date: date,
        liters: liters,
        cost: cost,
        odometer: odometer,
        isFullTank: isFullTank,
        createdAt: date,
      );

  group('FuelEfficiency.history', () {
    test('新しい順に、その回の燃費を添えて返す', () {
      final records = [
        rec(
            id: 'f1',
            date: DateTime(2026, 6, 1),
            liters: 40,
            cost: 7000,
            odometer: 30000),
        rec(
            id: 'f2',
            date: DateTime(2026, 7, 1),
            liters: 40,
            cost: 7100,
            odometer: 30600),
        rec(
            id: 'f3',
            date: DateTime(2026, 8, 1),
            liters: 50,
            cost: 8800,
            odometer: 31350),
      ];

      final history = FuelEfficiency.history(records);

      // 新しい順。
      expect(history.map((e) => e.record.id).toList(), ['f3', 'f2', 'f1']);
      // 31350 - 30600 = 750km を 50L で割って 15.0km/L。
      expect(history[0].kmPerLiter, closeTo(15.0, 0.01));
      // 30600 - 30000 = 600km を 40L で 15.0km/L。
      expect(history[1].kmPerLiter, closeTo(15.0, 0.01));
      // 最初の1件は、前の満タンが無いので出せない。
      expect(history[2].kmPerLiter, isNull);
    });

    test('継ぎ足しは飛ばさず、次の満タンの量に足す（満タン法）', () {
      final records = [
        rec(
            id: 'f1',
            date: DateTime(2026, 6, 1),
            liters: 40,
            cost: 7000,
            odometer: 30000),
        rec(
          id: 'f2',
          date: DateTime(2026, 6, 15),
          liters: 10,
          cost: 1750,
          odometer: 30200,
          isFullTank: false,
        ),
        rec(
            id: 'f3',
            date: DateTime(2026, 7, 1),
            liters: 30,
            cost: 5300,
            odometer: 30600),
      ];

      final history = FuelEfficiency.history(records);

      // 600km を (10 + 30)L で割って 15.0km/L。継ぎ足しぶんも数える。
      expect(history[0].kmPerLiter, closeTo(15.0, 0.01));
      // 継ぎ足し自体の行では燃費を出さない。
      expect(history[1].kmPerLiter, isNull);
    });

    test('桁を間違えた記録では燃費を出さない', () {
      final records = [
        rec(
            id: 'f1',
            date: DateTime(2026, 6, 1),
            liters: 40,
            cost: 7000,
            odometer: 30000),
        // 10,000km を 40L → 250km/L。あり得ない。
        rec(
            id: 'f2',
            date: DateTime(2026, 7, 1),
            liters: 40,
            cost: 7000,
            odometer: 40000),
      ];

      expect(FuelEfficiency.history(records)[0].kmPerLiter, isNull);
    });

    group('Edge Cases', () {
      test('空なら空', () {
        expect(FuelEfficiency.history(const []), isEmpty);
      });

      test('1件だけなら燃費は出ない', () {
        final history = FuelEfficiency.history([
          rec(
              id: 'f1',
              date: DateTime(2026, 6, 1),
              liters: 40,
              cost: 7000,
              odometer: 30000),
        ]);

        expect(history.length, 1);
        expect(history[0].kmPerLiter, isNull);
      });

      test('走行距離が無い記録は燃費を出さない', () {
        final history = FuelEfficiency.history([
          rec(id: 'f1', date: DateTime(2026, 6, 1), liters: 40, cost: 7000),
          rec(id: 'f2', date: DateTime(2026, 7, 1), liters: 40, cost: 7000),
        ]);

        expect(history[0].kmPerLiter, isNull);
      });
    });
  });

  group('FuelSummary.of', () {
    test('件数・金額・給油量・平均燃費を出す', () {
      final records = [
        rec(
            id: 'f1',
            date: DateTime(2026, 6, 1),
            liters: 40,
            cost: 7000,
            odometer: 30000),
        rec(
            id: 'f2',
            date: DateTime(2026, 7, 1),
            liters: 40,
            cost: 7100,
            odometer: 30600),
        rec(
            id: 'f3',
            date: DateTime(2026, 8, 1),
            liters: 50,
            cost: 8800,
            odometer: 31350),
      ];

      final summary = FuelSummary.of(records);

      expect(summary.count, 3);
      expect(summary.totalCost, 22900);
      expect(summary.totalLiters, closeTo(130, 0.01));
      // 燃費が出た2回の平均。どちらも 15.0km/L。
      expect(summary.averageKmPerLiter, closeTo(15.0, 0.01));
      // 1,350km を走って 22,900円。1kmあたり約17円。
      expect(summary.costPerKm, closeTo(22900 / 1350, 0.1));
    });

    group('Edge Cases', () {
      test('空なら 0 件で、平均は出さない', () {
        final summary = FuelSummary.of(const []);

        expect(summary.count, 0);
        expect(summary.totalCost, 0);
        expect(summary.averageKmPerLiter, isNull);
        expect(summary.costPerKm, isNull);
      });

      test('燃費が1回も出せなければ平均も出さない', () {
        final summary = FuelSummary.of([
          rec(id: 'f1', date: DateTime(2026, 6, 1), liters: 40, cost: 7000),
        ]);

        expect(summary.count, 1);
        expect(summary.totalCost, 7000);
        expect(summary.averageKmPerLiter, isNull);
      });
    });
  });
}
