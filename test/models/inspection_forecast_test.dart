// 車検満了日から、この先の来店見込みを月ごとに数える。
//
// なぜ要るか:
//   店が持っているのは「今この期間に何台満了するか」という1つの数字だけ
//   だった（InspectionPipeline）。それだと**いつ忙しくなるかが分からない。**
//   独立系の工場はリフトも人も限られているので、
//   「来月は車検が5件来る」が先に分かることに意味がある。
//
// **個人を特定しない。** 店に渡っているのは満了日の配列だけで、どの車の
// ものかも誰のものかも入っていない（shop_invite_service.dart の設計）。
// ここでもその線は越えない。月ごとの件数だけを出す。

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/inspection_pipeline.dart';
import 'package:trust_car_platform/models/inspection_forecast.dart';

CustomerExpirySummary _c(
  List<DateTime> expiries, {
  int vehicleCount = 1,
  bool isSharing = true,
}) {
  return CustomerExpirySummary(
    vehicleCount: vehicleCount,
    expiries: expiries,
    isSharing: isSharing,
  );
}

void main() {
  final today = DateTime(2026, 9, 22);

  group('InspectionForecast.build', () {
    test('満了日を月ごとに数える', () {
      final f = InspectionForecast.build(
        customers: [
          _c([DateTime(2026, 10, 5)]),
          _c([DateTime(2026, 10, 20)]),
          _c([DateTime(2026, 11, 2)]),
        ],
        today: today,
        months: 3,
      );

      expect(f.months.length, 3);
      expect(f.countFor(DateTime(2026, 9)), 0);
      expect(f.countFor(DateTime(2026, 10)), 2);
      expect(f.countFor(DateTime(2026, 11)), 1);
    });

    test('今月ぶんも数える（月初から今日までを落とさない）', () {
      final f = InspectionForecast.build(
        customers: [
          _c([DateTime(2026, 9, 5)]), // 今日より前だが今月
          _c([DateTime(2026, 9, 30)]),
        ],
        today: today,
        months: 2,
      );

      expect(f.countFor(DateTime(2026, 9)), 2);
    });

    test('期間より先の満了日は数えない', () {
      final f = InspectionForecast.build(
        customers: [
          _c([DateTime(2027, 6, 1)]),
        ],
        today: today,
        months: 3,
      );

      expect(f.total, 0);
    });

    test('共有していない顧客は数に入れない', () {
      final f = InspectionForecast.build(
        customers: [
          _c([DateTime(2026, 10, 5)], isSharing: false),
        ],
        today: today,
        months: 3,
      );

      expect(f.total, 0);
    });

    test('1人が複数台でも、台数ぶん数える', () {
      final f = InspectionForecast.build(
        customers: [
          _c(
            [DateTime(2026, 10, 5), DateTime(2026, 10, 18)],
            vehicleCount: 2,
          ),
        ],
        today: today,
        months: 3,
      );

      expect(f.countFor(DateTime(2026, 10)), 2);
    });

    test('いちばん混む月が分かる', () {
      final f = InspectionForecast.build(
        customers: [
          _c([DateTime(2026, 10, 5)]),
          _c([DateTime(2026, 11, 2)]),
          _c([DateTime(2026, 11, 9)]),
          _c([DateTime(2026, 11, 20)]),
        ],
        today: today,
        months: 3,
      );

      expect(f.busiestMonth, DateTime(2026, 11));
      expect(f.countFor(f.busiestMonth!), 3);
    });

    group('Edge Cases', () {
      test('顧客がいなければ、全部0の月が並ぶ', () {
        final f = InspectionForecast.build(
          customers: const [],
          today: today,
          months: 3,
        );

        expect(f.months.length, 3);
        expect(f.total, 0);
        expect(f.busiestMonth, isNull);
      });

      test('満了日が1件も無ければ0', () {
        final f = InspectionForecast.build(
          customers: [_c(const [], vehicleCount: 2)],
          today: today,
          months: 3,
        );

        expect(f.total, 0);
      });

      test('月数に0以下を渡しても落ちない', () {
        final f = InspectionForecast.build(
          customers: [
            _c([DateTime(2026, 10, 5)]),
          ],
          today: today,
          months: 0,
        );

        expect(f.months, isEmpty);
        expect(f.total, 0);
      });

      test('年をまたいでも順番が崩れない', () {
        final f = InspectionForecast.build(
          customers: [
            _c([DateTime(2027, 1, 10)]),
          ],
          today: DateTime(2026, 12, 1),
          months: 3,
        );

        expect(f.months.first, DateTime(2026, 12));
        expect(f.months[1], DateTime(2027, 1));
        expect(f.countFor(DateTime(2027, 1)), 1);
      });
    });
  });
}
