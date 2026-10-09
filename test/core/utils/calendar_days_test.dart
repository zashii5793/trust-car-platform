// 日付の差（あと何日）を、時刻・タイムゾーンに左右されずに数える。
//
// なぜ要るか（使用感テスト 2026-10-09）:
//   車検満了日 11/20 を 10/8 に入れると「あと42日」（正しくは43日）。
//   10/28 満了のハイエースは「残19日」（正しくは20日）。満了日は 0 時、
//   今は昼なので、`difference().inDays` が端数を切り捨てて1日少なく出ていた。
//   日付どうしで数えれば、何時に開いても同じ数になる。

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/utils/calendar_days.dart';
import 'package:trust_car_platform/core/utils/expiry_summary.dart';
import 'package:trust_car_platform/models/vehicle.dart';

void main() {
  group('calendarDaysUntil', () {
    // 使用感テストの日（2026-10-08）の昼。
    final testDay = DateTime(2026, 10, 8, 14, 30);

    test('11/20 満了は 10/8 から 43日', () {
      expect(calendarDaysUntil(DateTime(2026, 11, 20), now: testDay), 43);
    });

    test('10/28 満了は 10/8 から 20日', () {
      expect(calendarDaysUntil(DateTime(2026, 10, 28), now: testDay), 20);
    });

    test('2027/03/15 満了は 10/8 から 158日', () {
      expect(calendarDaysUntil(DateTime(2027, 3, 15), now: testDay), 158);
    });

    test('2027/03/07 満了は 10/9 から 149日', () {
      expect(
        calendarDaysUntil(DateTime(2027, 3, 7), now: DateTime(2026, 10, 9, 9)),
        149,
      );
    });

    test('開いた時刻で数が変わらない（朝0時1分と夜23時59分）', () {
      final target = DateTime(2026, 11, 20);
      expect(calendarDaysUntil(target, now: DateTime(2026, 10, 8, 0, 1)), 43);
      expect(calendarDaysUntil(target, now: DateTime(2026, 10, 8, 23, 59)), 43);
    });

    test('満了日の時刻（UTC 0時が JST 9時になる等）にも左右されない', () {
      expect(
        calendarDaysUntil(DateTime(2026, 11, 20, 9), now: testDay),
        43,
      );
    });

    group('Edge Cases', () {
      test('当日は 0', () {
        expect(calendarDaysUntil(DateTime(2026, 10, 8), now: testDay), 0);
      });

      test('昨日は -1（過ぎている）', () {
        expect(calendarDaysUntil(DateTime(2026, 10, 7), now: testDay), -1);
      });

      test('うるう年の2月をまたいでも1日ずれない', () {
        expect(
          calendarDaysUntil(DateTime(2028, 3, 1), now: DateTime(2028, 2, 28)),
          2,
        );
      });
    });
  });

  group('Vehicle の残日数', () {
    Vehicle vehicle({DateTime? inspection, DateTime? insurance}) => Vehicle(
          id: 'v',
          userId: 'u',
          maker: 'Toyota',
          model: 'Hiace',
          year: 2020,
          grade: '',
          mileage: 0,
          inspectionExpiryDate: inspection,
          insuranceExpiryDate: insurance,
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        );

    test('車検の残日数は日付で数える（10/28 は 10/8 から 20日）', () {
      final v = vehicle(inspection: DateTime(2026, 10, 28));
      expect(v.daysUntilInspectionAt(DateTime(2026, 10, 8, 15)), 20);
    });

    test('自賠責の残日数も同じ数え方', () {
      final v = vehicle(insurance: DateTime(2026, 11, 20));
      expect(v.daysUntilInsuranceExpiryAt(DateTime(2026, 10, 8, 15)), 43);
    });

    test('ダッシュボードの期限一覧も同じ数え方', () {
      final v = vehicle(inspection: DateTime(2026, 11, 20));
      final items = vehicleExpiryItems(v, now: DateTime(2026, 10, 8, 15));
      expect(items.single.days, 43);
    });

    group('Edge Cases', () {
      test('満了日が無ければ null', () {
        expect(vehicle().daysUntilInspectionAt(DateTime(2026, 10, 8)), isNull);
      });
    });
  });
}
