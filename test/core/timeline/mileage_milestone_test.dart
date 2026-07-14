import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/timeline/mileage_milestone.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';

MaintenanceRecord _record(DateTime date, {int? mileage}) {
  return MaintenanceRecord(
    id: 'r-${date.millisecondsSinceEpoch}',
    vehicleId: 'v1',
    userId: 'u1',
    type: MaintenanceType.oilChange,
    title: 'test',
    cost: 0,
    date: date,
    mileageAtService: mileage,
    createdAt: date,
  );
}

void main() {
  group('MileageMilestoneDetector', () {
    group('基本検出', () {
      test('記録なし → 空リスト', () {
        expect(MileageMilestoneDetector.detect([]), isEmpty);
      });

      test('走行距離なし記録のみ → 空リスト', () {
        final records = [
          _record(DateTime(2024, 1, 1), mileage: null),
          _record(DateTime(2024, 6, 1), mileage: null),
        ];
        expect(MileageMilestoneDetector.detect(records), isEmpty);
      });

      test('10,000km未満の記録 → 空リスト', () {
        final records = [_record(DateTime(2024, 1, 1), mileage: 5000)];
        expect(MileageMilestoneDetector.detect(records), isEmpty);
      });

      test('1万km到達 → 10,000kmマイルストーン', () {
        final date = DateTime(2024, 6, 15);
        final records = [_record(date, mileage: 10000)];
        final result = MileageMilestoneDetector.detect(records);
        expect(result, hasLength(1));
        expect(result.first.km, 10000);
        expect(result.first.date, date);
      });

      test('15,000kmの記録 → 10,000kmマイルストーンのみ（20,000kmは超えていない）', () {
        final records = [_record(DateTime(2024, 6, 1), mileage: 15000)];
        final result = MileageMilestoneDetector.detect(records);
        expect(result, hasLength(1));
        expect(result.first.km, 10000);
      });
    });

    group('複数マイルストーン', () {
      test('2つの記録で別の閾値を跨ぐ', () {
        final d1 = DateTime(2023, 3, 1);
        final d2 = DateTime(2024, 5, 1);
        final records = [
          _record(d1, mileage: 8000),
          _record(d2, mileage: 22000),
        ];
        final result = MileageMilestoneDetector.detect(records);
        // d1でまだ閾値未達, d2で10k・20kを跨ぐ → 同日なので20kのみ
        expect(result, hasLength(1));
        expect(result.first.km, 20000);
        expect(result.first.date, d2);
      });

      test('段階的に閾値を跨ぐ → 各日付にマイルストーン', () {
        final d1 = DateTime(2022, 1, 1); // 9k
        final d2 = DateTime(2022, 6, 1); // 15k (10k通過)
        final d3 = DateTime(2023, 1, 1); // 25k (20k通過)
        final records = [
          _record(d1, mileage: 9000),
          _record(d2, mileage: 15000),
          _record(d3, mileage: 25000),
        ];
        final result = MileageMilestoneDetector.detect(records);
        expect(result, hasLength(2));
        // newest-first
        expect(result[0].km, 20000);
        expect(result[0].date, d3);
        expect(result[1].km, 10000);
        expect(result[1].date, d2);
      });

      test('50,000kmも検出される', () {
        final records = [
          _record(DateTime(2020, 1, 1), mileage: 0),
          _record(DateTime(2025, 1, 1), mileage: 55000),
        ];
        final result = MileageMilestoneDetector.detect(records);
        // 10k,20k,30k,40k,50k の5マイルストーンが同日 → 最高値50kのみ
        expect(result, hasLength(1));
        expect(result.first.km, 50000);
      });

      test('100,000kmも検出される', () {
        final records = [
          _record(DateTime(2020, 1, 1), mileage: 95000),
          _record(DateTime(2025, 1, 1), mileage: 105000),
        ];
        final result = MileageMilestoneDetector.detect(records);
        expect(result.any((m) => m.km == 100000), isTrue);
      });
    });

    group('同日マイルストーン集約', () {
      test('初回記録で複数閾値 → 最高値のみ（同日集約）', () {
        final date = DateTime(2024, 4, 10);
        final records = [_record(date, mileage: 35000)];
        final result = MileageMilestoneDetector.detect(records);
        expect(result, hasLength(1));
        expect(result.first.km, 30000);
      });

      test('複数記録が同日に複数閾値 → 同日内で最高値のみ', () {
        final d1 = DateTime(2024, 1, 1);
        final d2 = DateTime(2024, 6, 15);
        final records = [
          _record(d1, mileage: 5000),
          _record(d2, mileage: 45000), // 10k/20k/30k/40k 全て同日
        ];
        final result = MileageMilestoneDetector.detect(records);
        expect(result, hasLength(1));
        expect(result.first.km, 40000);
        expect(result.first.date, d2);
      });
    });

    group('順序・ソート', () {
      test('入力が逆順でも正しく検出', () {
        final d1 = DateTime(2022, 1, 1);
        final d2 = DateTime(2023, 6, 1);
        final records = [
          _record(d2, mileage: 22000), // 後から入力
          _record(d1, mileage: 8000),
        ];
        final result = MileageMilestoneDetector.detect(records);
        expect(result, hasLength(1));
        expect(result.first.km, 20000);
        expect(result.first.date, d2);
      });

      test('結果は最新日付順（newest-first）', () {
        final d1 = DateTime(2021, 1, 1);
        final d2 = DateTime(2022, 6, 1);
        final d3 = DateTime(2024, 1, 1);
        final records = [
          _record(d1, mileage: 9000),
          _record(d2, mileage: 15000), // 10k
          _record(d3, mileage: 55000), // 20k/30k/40k/50k → 50k
        ];
        final result = MileageMilestoneDetector.detect(records);
        expect(result, hasLength(2));
        expect(result[0].km, 50000); // 最新
        expect(result[1].km, 10000); // 古い
      });
    });

    group('Edge Cases', () {
      test('走行距離ありと走行距離なしが混在 → ありのみ対象', () {
        final d1 = DateTime(2023, 1, 1);
        final d2 = DateTime(2023, 6, 1); // null
        final d3 = DateTime(2024, 1, 1);
        final records = [
          _record(d1, mileage: 8000),
          _record(d2, mileage: null),
          _record(d3, mileage: 15000), // 10k通過
        ];
        final result = MileageMilestoneDetector.detect(records);
        expect(result, hasLength(1));
        expect(result.first.km, 10000);
        expect(result.first.date, d3);
      });

      test('オドメーター逆行（データ誤り）は無視', () {
        final d1 = DateTime(2023, 1, 1);
        final d2 = DateTime(2023, 6, 1); // 異常に少ない
        final d3 = DateTime(2024, 1, 1);
        final records = [
          _record(d1, mileage: 12000), // 10k通過
          _record(d2, mileage: 5000), // オドメーター誤り
          _record(d3, mileage: 22000), // 20k通過
        ];
        final result = MileageMilestoneDetector.detect(records);
        // 10k は d1、20k は d3
        // d2 は逆行なので prev は 12000 のまま
        final sorted = result..sort((a, b) => a.date.compareTo(b.date));
        expect(sorted[0].km, 10000);
        expect(sorted[0].date, d1);
        expect(sorted[1].km, 20000);
        expect(sorted[1].date, d3);
      });

      test('走行距離が閾値ちょうど（境界値）', () {
        final records = [_record(DateTime(2024, 3, 1), mileage: 50000)];
        final result = MileageMilestoneDetector.detect(records);
        // 最高閾値（同日集約後）は50000
        expect(result.last.km, 50000);
      });

      test('200,000km超の記録でも200kマイルストーンを検出', () {
        final records = [
          _record(DateTime(2020, 1, 1), mileage: 195000),
          _record(DateTime(2025, 1, 1), mileage: 210000),
        ];
        final result = MileageMilestoneDetector.detect(records);
        expect(result.any((m) => m.km == 200000), isTrue);
      });

      test('同一閾値が2度出現しない', () {
        final records = [
          _record(DateTime(2023, 1, 1), mileage: 8000),
          _record(DateTime(2023, 6, 1), mileage: 12000), // 10k通過
          _record(DateTime(2024, 1, 1), mileage: 8000), // オドメーター誤り
          _record(DateTime(2024, 6, 1), mileage: 14000), // 10k は再度跨がない（追跡済み）
        ];
        final result = MileageMilestoneDetector.detect(records);
        final tenKMilestones = result.where((m) => m.km == 10000).toList();
        expect(tenKMilestones, hasLength(1));
      });
    });
  });
}
