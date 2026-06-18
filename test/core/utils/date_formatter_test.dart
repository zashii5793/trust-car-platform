import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/utils/date_formatter.dart';

void main() {
  group('weekdayJp', () {
    test('月〜日が DateTime.weekday に正しく対応する', () {
      // 2026/06/15 は月曜
      expect(weekdayJp(DateTime(2026, 6, 15)), '月');
      expect(weekdayJp(DateTime(2026, 6, 16)), '火');
      expect(weekdayJp(DateTime(2026, 6, 17)), '水');
      expect(weekdayJp(DateTime(2026, 6, 18)), '木');
      expect(weekdayJp(DateTime(2026, 6, 19)), '金');
      expect(weekdayJp(DateTime(2026, 6, 20)), '土');
      expect(weekdayJp(DateTime(2026, 6, 21)), '日');
    });
  });

  group('formatDateWithWeekday', () {
    test('yyyy/MM/dd(E) 形式・ゼロ埋めあり', () {
      expect(formatDateWithWeekday(DateTime(2026, 6, 18)), '2026/06/18(木)');
      expect(formatDateWithWeekday(DateTime(2026, 1, 5)), '2026/01/05(月)');
    });
  });

  group('formatDateLongWithWeekday', () {
    test('yyyy年M月d日(E) 形式・ゼロ埋めなし', () {
      expect(formatDateLongWithWeekday(DateTime(2026, 6, 18)), '2026年6月18日(木)');
    });

    group('Edge Cases', () {
      test('うるう日 2024/02/29 は木曜', () {
        expect(
            formatDateLongWithWeekday(DateTime(2024, 2, 29)), '2024年2月29日(木)');
      });
    });
  });
}
