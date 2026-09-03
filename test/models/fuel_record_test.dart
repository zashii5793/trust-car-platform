import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/fuel_record.dart';

/// 給油の記録と、そこから出す燃費。
///
/// `docs/HABIT_DESIGN.md` 打ち手1。**唯一、月単位の接点を作れる行為。**
///
/// ```
///  給油        月2〜4回   ← アプリに機能が無い
///  整備・点検  年2〜4回
///  車検        2年に1回   ← いまの中心機能
/// ```
///
/// 入力は3項目（日付・給油量・金額）＋走行距離。20秒で終わること。
/// 保存した瞬間に燃費が出るのが肝で、**毎回違う数字が返る**から見たくなる。
///
/// 燃費は満タン法で出す。**満タンでない給油からは出せない**（次に満タンに
/// するまで、何リットル使ったか確定しないため）。ここを間違えると
/// でたらめな燃費を見せることになる。
void main() {
  FuelRecord rec({
    required DateTime date,
    required double liters,
    required int cost,
    int? odometer,
    bool isFull = true,
  }) {
    return FuelRecord(
      id: 'f-${date.millisecondsSinceEpoch}',
      vehicleId: 'v1',
      userId: 'u1',
      date: date,
      liters: liters,
      cost: cost,
      odometer: odometer,
      isFullTank: isFull,
      createdAt: date,
    );
  }

  group('FuelRecord — 1件の値', () {
    test('リットル単価を出す', () {
      final r = rec(date: DateTime(2026, 8, 1), liters: 40, cost: 6800);

      expect(r.pricePerLiter, closeTo(170, 0.01));
    });

    group('Edge Cases', () {
      test('給油量が0ならリットル単価は出さない', () {
        final r = rec(date: DateTime(2026, 8, 1), liters: 0, cost: 6800);

        expect(r.pricePerLiter, isNull);
      });

      test('金額0でも単価は0として出す（自宅の携行缶など）', () {
        final r = rec(date: DateTime(2026, 8, 1), liters: 20, cost: 0);

        expect(r.pricePerLiter, 0);
      });
    });
  });

  group('FuelEfficiency.calculate — 満タン法', () {
    test('前回の満タンからの距離を給油量で割る', () {
      // 30,000km で満タン → 30,500km で 40L 入れて満タン
      // 500km を 40L で走った = 12.5 km/L
      final result = FuelEfficiency.calculate(
        previousFull: rec(
            date: DateTime(2026, 7, 1),
            liters: 35,
            cost: 5950,
            odometer: 30000),
        current: rec(
            date: DateTime(2026, 8, 1),
            liters: 40,
            cost: 6800,
            odometer: 30500),
      );

      expect(result, closeTo(12.5, 0.001));
    });

    test('走行距離が短くても出る', () {
      final result = FuelEfficiency.calculate(
        previousFull: rec(
            date: DateTime(2026, 7, 1),
            liters: 10,
            cost: 1700,
            odometer: 10000),
        current: rec(
            date: DateTime(2026, 7, 5), liters: 8, cost: 1360, odometer: 10080),
      );

      expect(result, closeTo(10.0, 0.001));
    });

    group('Edge Cases', () {
      test('今回が満タンでなければ出せない', () {
        // 満タンにしていないと、何リットル使ったかが確定しない。
        final result = FuelEfficiency.calculate(
          previousFull: rec(
              date: DateTime(2026, 7, 1),
              liters: 35,
              cost: 5950,
              odometer: 30000),
          current: rec(
            date: DateTime(2026, 8, 1),
            liters: 20,
            cost: 3400,
            odometer: 30500,
            isFull: false,
          ),
        );

        expect(result, isNull);
      });

      test('走行距離が入っていなければ出せない', () {
        final result = FuelEfficiency.calculate(
          previousFull: rec(
              date: DateTime(2026, 7, 1),
              liters: 35,
              cost: 5950,
              odometer: 30000),
          current: rec(date: DateTime(2026, 8, 1), liters: 40, cost: 6800),
        );

        expect(result, isNull);
      });

      test('前回の走行距離が無ければ出せない', () {
        final result = FuelEfficiency.calculate(
          previousFull: rec(date: DateTime(2026, 7, 1), liters: 35, cost: 5950),
          current: rec(
              date: DateTime(2026, 8, 1),
              liters: 40,
              cost: 6800,
              odometer: 30500),
        );

        expect(result, isNull);
      });

      test('オドメーターが逆行していたら出さない（入力ミス）', () {
        final result = FuelEfficiency.calculate(
          previousFull: rec(
              date: DateTime(2026, 7, 1),
              liters: 35,
              cost: 5950,
              odometer: 30500),
          current: rec(
              date: DateTime(2026, 8, 1),
              liters: 40,
              cost: 6800,
              odometer: 30000),
        );

        expect(result, isNull);
      });

      test('走行距離が同じなら出さない（0km を 40L で走ったことになる）', () {
        final result = FuelEfficiency.calculate(
          previousFull: rec(
              date: DateTime(2026, 7, 1),
              liters: 35,
              cost: 5950,
              odometer: 30000),
          current: rec(
              date: DateTime(2026, 8, 1),
              liters: 40,
              cost: 6800,
              odometer: 30000),
        );

        expect(result, isNull);
      });

      test('給油量が0なら出さない（0で割る）', () {
        final result = FuelEfficiency.calculate(
          previousFull: rec(
              date: DateTime(2026, 7, 1),
              liters: 35,
              cost: 5950,
              odometer: 30000),
          current: rec(
              date: DateTime(2026, 8, 1), liters: 0, cost: 0, odometer: 30500),
        );

        expect(result, isNull);
      });

      test('あり得ない燃費は出さない（桁の入力ミス）', () {
        // 30,000 → 40,000km を 40L で走ったら 250km/L。桁を間違えている。
        // 黙って見せると「燃費が良くなった」と誤解される。
        final result = FuelEfficiency.calculate(
          previousFull: rec(
              date: DateTime(2026, 7, 1),
              liters: 35,
              cost: 5950,
              odometer: 30000),
          current: rec(
              date: DateTime(2026, 8, 1),
              liters: 40,
              cost: 6800,
              odometer: 40000),
        );

        expect(result, isNull);
      });

      test('あり得ないほど悪い燃費も出さない', () {
        // 1km を 40L。給油量の桁を間違えている。
        final result = FuelEfficiency.calculate(
          previousFull: rec(
              date: DateTime(2026, 7, 1),
              liters: 35,
              cost: 5950,
              odometer: 30000),
          current: rec(
              date: DateTime(2026, 8, 1),
              liters: 40,
              cost: 6800,
              odometer: 30001),
        );

        expect(result, isNull);
      });
    });
  });

  group('FuelEfficiency.latestFor — 履歴から最新の燃費', () {
    test('直近の満タン2件から出す', () {
      final records = [
        rec(
            date: DateTime(2026, 6, 1),
            liters: 35,
            cost: 5950,
            odometer: 30000),
        rec(
            date: DateTime(2026, 7, 1),
            liters: 38,
            cost: 6460,
            odometer: 30450),
        rec(
            date: DateTime(2026, 8, 1),
            liters: 40,
            cost: 6800,
            odometer: 30950),
      ];

      // 30,450 → 30,950 = 500km を 40L
      expect(FuelEfficiency.latestFor(records), closeTo(12.5, 0.001));
    });

    test('順番がばらばらでも日付で並べ直す', () {
      final records = [
        rec(
            date: DateTime(2026, 8, 1),
            liters: 40,
            cost: 6800,
            odometer: 30950),
        rec(
            date: DateTime(2026, 6, 1),
            liters: 35,
            cost: 5950,
            odometer: 30000),
        rec(
            date: DateTime(2026, 7, 1),
            liters: 38,
            cost: 6460,
            odometer: 30450),
      ];

      expect(FuelEfficiency.latestFor(records), closeTo(12.5, 0.001));
    });

    test('満タンでない給油は飛ばして、その前の満タンと比べる', () {
      final records = [
        rec(
            date: DateTime(2026, 7, 1),
            liters: 38,
            cost: 6460,
            odometer: 30000),
        rec(
            date: DateTime(2026, 7, 15),
            liters: 15,
            cost: 2550,
            odometer: 30200,
            isFull: false),
        rec(
            date: DateTime(2026, 8, 1),
            liters: 40,
            cost: 6800,
            odometer: 30500),
      ];

      // 満タン→満タンで 500km。途中の継ぎ足し 15L も使っている。
      // 満タン法は「前の満タンから今回の満タンまでに入れた総量」で割る。
      // 15 + 40 = 55L で 500km = 9.09 km/L
      expect(FuelEfficiency.latestFor(records), closeTo(500 / 55, 0.01));
    });

    group('Edge Cases', () {
      test('記録が0件なら出さない', () {
        expect(FuelEfficiency.latestFor([]), isNull);
      });

      test('記録が1件なら出さない（比べる相手がいない）', () {
        expect(
          FuelEfficiency.latestFor([
            rec(
                date: DateTime(2026, 8, 1),
                liters: 40,
                cost: 6800,
                odometer: 30000),
          ]),
          isNull,
        );
      });

      test('満タンが1件しか無ければ出さない', () {
        expect(
          FuelEfficiency.latestFor([
            rec(
                date: DateTime(2026, 7, 1),
                liters: 20,
                cost: 3400,
                odometer: 30000,
                isFull: false),
            rec(
                date: DateTime(2026, 8, 1),
                liters: 40,
                cost: 6800,
                odometer: 30500),
          ]),
          isNull,
        );
      });
    });
  });

  group('FuelRecord の保存と復元', () {
    test('保存して読み戻すと同じになる', () {
      final original = rec(
        date: DateTime(2026, 8, 1),
        liters: 40.5,
        cost: 6885,
        odometer: 30500,
      );

      final restored = FuelRecord.fromMap(original.toMap(), original.id);

      expect(restored.vehicleId, original.vehicleId);
      expect(restored.liters, original.liters);
      expect(restored.cost, original.cost);
      expect(restored.odometer, original.odometer);
      expect(restored.isFullTank, original.isFullTank);
      expect(restored.date, original.date);
    });

    group('Edge Cases', () {
      test('欠けた項目があっても落ちない', () {
        final restored = FuelRecord.fromMap(const {}, 'f1');

        expect(restored.id, 'f1');
        expect(restored.liters, 0);
        expect(restored.cost, 0);
        expect(restored.odometer, isNull);
      });

      test('満タンかどうかが欠けていたら満タン扱いにしない', () {
        // 分からないものを満タンとして扱うと、でたらめな燃費が出る。
        final restored = FuelRecord.fromMap(const {}, 'f1');

        expect(restored.isFullTank, isFalse);
      });
    });
  });

  group('FuelRecord.validate — 入力の検査', () {
    test('通常の入力は通る', () {
      expect(FuelRecord.validateLiters('40.5'), isNull);
      expect(FuelRecord.validateCost('6800'), isNull);
    });

    group('Edge Cases', () {
      test('給油量が空なら理由を返す', () {
        expect(FuelRecord.validateLiters(''), isNotNull);
      });

      test('給油量が0以下なら理由を返す', () {
        expect(FuelRecord.validateLiters('0'), isNotNull);
        expect(FuelRecord.validateLiters('-5'), isNotNull);
      });

      test('あり得ない給油量は理由を返す', () {
        // 乗用車のタンクは大きくても100L台。桁の間違いを止める。
        expect(FuelRecord.validateLiters('9999'), isNotNull);
      });

      test('数字でなければ理由を返す', () {
        expect(FuelRecord.validateLiters('あ'), isNotNull);
      });

      test('金額は0を許す（携行缶・自社給油）', () {
        expect(FuelRecord.validateCost('0'), isNull);
      });

      test('金額が負なら理由を返す', () {
        expect(FuelRecord.validateCost('-100'), isNotNull);
      });

      test('文言に開発者向けの用語が出てこない', () {
        final messages = [
          FuelRecord.validateLiters(''),
          FuelRecord.validateLiters('0'),
          FuelRecord.validateLiters('9999'),
          FuelRecord.validateCost('-1'),
        ];
        for (final m in messages) {
          expect(m, isNotNull);
          for (final ng in ['null', 'error', 'invalid', 'parse']) {
            expect(m!.contains(ng), isFalse, reason: '$m に $ng');
          }
        }
      });
    });
  });
}
