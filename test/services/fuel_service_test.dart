import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/fuel_record.dart';
import 'package:trust_car_platform/services/fuel_service.dart';

/// 給油の保存。
///
/// **保存した瞬間に燃費を返すのが肝**（`docs/HABIT_DESIGN.md` 打ち手1）。
/// 記録が増えただけでは何も返ってこず、続かない。
void main() {
  late FakeFirebaseFirestore firestore;
  late FuelService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = FuelService(firestore: firestore);
  });

  FuelRecord rec({
    required DateTime date,
    double liters = 40,
    int cost = 6800,
    int? odometer,
    bool isFull = true,
    String vehicleId = 'v1',
    String userId = 'u1',
  }) {
    return FuelRecord(
      id: '',
      vehicleId: vehicleId,
      userId: userId,
      date: date,
      liters: liters,
      cost: cost,
      odometer: odometer,
      isFullTank: isFull,
      createdAt: date,
    );
  }

  group('add', () {
    test('保存できる', () async {
      final result = await service.add(rec(date: DateTime(2026, 8, 1)));

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.id.isNotEmpty, isTrue);
    });

    test('1件目は燃費を返さない（比べる相手がいない）', () async {
      final result = await service.add(
        rec(date: DateTime(2026, 8, 1), odometer: 30000),
      );

      expect(result.valueOrNull?.efficiencyKmPerLiter, isNull);
    });

    test('2件目の満タンで燃費を返す', () async {
      await service.add(
        rec(date: DateTime(2026, 7, 1), liters: 35, odometer: 30000),
      );

      final result = await service.add(
        rec(date: DateTime(2026, 8, 1), liters: 40, odometer: 30500),
      );

      // 500km / 40L = 12.5
      expect(result.valueOrNull?.efficiencyKmPerLiter, closeTo(12.5, 0.01));
    });

    group('Edge Cases', () {
      test('車両が空なら断る', () async {
        final result =
            await service.add(rec(date: DateTime(2026, 8, 1), vehicleId: ''));

        expect(result.isFailure, isTrue);
      });

      test('ログインしていなければ断る', () async {
        final result =
            await service.add(rec(date: DateTime(2026, 8, 1), userId: ''));

        expect(result.isFailure, isTrue);
      });

      test('給油量が0なら断る', () async {
        final result =
            await service.add(rec(date: DateTime(2026, 8, 1), liters: 0));

        expect(result.isFailure, isTrue);
      });

      test('あり得ない給油量は断る', () async {
        final result =
            await service.add(rec(date: DateTime(2026, 8, 1), liters: 9999));

        expect(result.isFailure, isTrue);
      });

      test('金額が負なら断る', () async {
        final result =
            await service.add(rec(date: DateTime(2026, 8, 1), cost: -1));

        expect(result.isFailure, isTrue);
      });

      test('金額0は通す（携行缶・自社給油）', () async {
        final result =
            await service.add(rec(date: DateTime(2026, 8, 1), cost: 0));

        expect(result.isSuccess, isTrue);
      });

      test('桁を間違えた走行距離では燃費を返さない', () async {
        await service.add(
          rec(date: DateTime(2026, 7, 1), liters: 35, odometer: 30000),
        );

        final result = await service.add(
          rec(date: DateTime(2026, 8, 1), liters: 40, odometer: 40000),
        );

        // 250km/L はあり得ない。黙って見せない。
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull?.efficiencyKmPerLiter, isNull);
      });
    });
  });

  group('recordsFor', () {
    test('新しい順で返る', () async {
      await service.add(rec(date: DateTime(2026, 6, 1), odometer: 30000));
      await service.add(rec(date: DateTime(2026, 8, 1), odometer: 30900));
      await service.add(rec(date: DateTime(2026, 7, 1), odometer: 30450));

      final records = (await service.recordsFor('v1')).valueOrNull!;

      expect(records.first.date, DateTime(2026, 8, 1));
      expect(records.last.date, DateTime(2026, 6, 1));
    });

    test('別の車の記録は混ざらない', () async {
      await service.add(rec(date: DateTime(2026, 8, 1), vehicleId: 'v1'));
      await service.add(rec(date: DateTime(2026, 8, 2), vehicleId: 'v2'));

      final records = (await service.recordsFor('v1')).valueOrNull!;

      expect(records.length, 1);
      expect(records.first.vehicleId, 'v1');
    });

    group('Edge Cases', () {
      test('車両が空なら空で返す', () async {
        expect((await service.recordsFor('')).valueOrNull, isEmpty);
      });

      test('記録が無ければ空で返す', () async {
        expect((await service.recordsFor('v-none')).valueOrNull, isEmpty);
      });
    });
  });

  group('delete', () {
    test('消せる', () async {
      final added = await service.add(rec(date: DateTime(2026, 8, 1)));

      await service.delete(added.valueOrNull!.id);

      expect((await service.recordsFor('v1')).valueOrNull, isEmpty);
    });

    group('Edge Cases', () {
      test('IDが空なら断る', () async {
        expect((await service.delete('')).isFailure, isTrue);
      });
    });
  });
}
