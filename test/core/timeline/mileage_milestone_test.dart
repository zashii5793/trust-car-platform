// MileageMilestoneDetector Unit Tests (TDD: RED first)
//
// 走行距離マイルストーン検出ロジックのテスト。
// 強み①「愛車カルテ」のタイムラインに「○○km突破」の節目を表示するための
// 純粋ロジックを検証する。

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/timeline/mileage_milestone.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MaintenanceRecord _rec({required DateTime date, int? mileage}) =>
    MaintenanceRecord(
      id: 'r-${date.microsecondsSinceEpoch}-${mileage ?? -1}',
      vehicleId: 'v1',
      userId: 'u1',
      type: MaintenanceType.oilChange,
      title: 'test',
      cost: 0,
      date: date,
      mileageAtService: mileage,
      createdAt: date,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MileageMilestoneDetector.detect', () {
    test('1件で1つの節目を超えると、その節目を検出する', () {
      final records = [_rec(date: DateTime(2024, 3, 1), mileage: 12000)];
      final result = MileageMilestoneDetector.detect(records);
      expect(result, [
        MileageMilestone(mileage: 10000, reachedOn: DateTime(2024, 3, 1)),
      ]);
    });

    test('1件で複数の節目を一気に超えると、すべて同じ日付で検出する', () {
      final records = [_rec(date: DateTime(2024, 5, 10), mileage: 35000)];
      final result = MileageMilestoneDetector.detect(records);
      expect(result.map((m) => m.mileage), [10000, 20000, 30000]);
      expect(result.every((m) => m.reachedOn == DateTime(2024, 5, 10)), isTrue);
    });

    test('ちょうど節目の値（10,000km）でも検出する（境界値）', () {
      final records = [_rec(date: DateTime(2024, 1, 1), mileage: 10000)];
      final result = MileageMilestoneDetector.detect(records);
      expect(result.map((m) => m.mileage), [10000]);
    });

    test('複数記録では、各節目は最初に到達した記録の日付に紐づく', () {
      final records = [
        _rec(date: DateTime(2024, 1, 1), mileage: 12000), // 10,000突破
        _rec(date: DateTime(2024, 6, 1), mileage: 25000), // 20,000突破
      ];
      final result = MileageMilestoneDetector.detect(records);
      expect(result, [
        MileageMilestone(mileage: 10000, reachedOn: DateTime(2024, 1, 1)),
        MileageMilestone(mileage: 20000, reachedOn: DateTime(2024, 6, 1)),
      ]);
    });

    test('記録が日付の逆順で渡されても昇順で評価する', () {
      final records = [
        _rec(date: DateTime(2024, 6, 1), mileage: 25000),
        _rec(date: DateTime(2024, 1, 1), mileage: 12000),
      ];
      final result = MileageMilestoneDetector.detect(records);
      expect(result, [
        MileageMilestone(mileage: 10000, reachedOn: DateTime(2024, 1, 1)),
        MileageMilestone(mileage: 20000, reachedOn: DateTime(2024, 6, 1)),
      ]);
    });

    test('同じ節目を複数回報告しない', () {
      final records = [
        _rec(date: DateTime(2024, 1, 1), mileage: 12000),
        _rec(date: DateTime(2024, 2, 1), mileage: 13000), // まだ20,000未満
      ];
      final result = MileageMilestoneDetector.detect(records);
      expect(result.map((m) => m.mileage), [10000]);
    });

    test('interval を指定すると、その間隔で検出する', () {
      final records = [_rec(date: DateTime(2024, 1, 1), mileage: 12000)];
      final result = MileageMilestoneDetector.detect(records, interval: 5000);
      expect(result.map((m) => m.mileage), [5000, 10000]);
    });

    group('Edge Cases', () {
      test('空リストでは空を返す', () {
        expect(MileageMilestoneDetector.detect([]), isEmpty);
      });

      test('走行距離が節目未満（5,000km）では検出しない', () {
        final records = [_rec(date: DateTime(2024, 1, 1), mileage: 5000)];
        expect(MileageMilestoneDetector.detect(records), isEmpty);
      });

      test('mileageAtService が null の記録は無視する', () {
        final records = [_rec(date: DateTime(2024, 1, 1), mileage: null)];
        expect(MileageMilestoneDetector.detect(records), isEmpty);
      });

      test('mileageAtService が 0 の記録は無視する', () {
        final records = [_rec(date: DateTime(2024, 1, 1), mileage: 0)];
        expect(MileageMilestoneDetector.detect(records), isEmpty);
      });

      test('mileageAtService が負の記録は無視する', () {
        final records = [_rec(date: DateTime(2024, 1, 1), mileage: -1)];
        expect(MileageMilestoneDetector.detect(records), isEmpty);
      });

      test('同日に複数記録があっても正しく検出する', () {
        final records = [
          _rec(date: DateTime(2024, 1, 1), mileage: 9000),
          _rec(date: DateTime(2024, 1, 1), mileage: 11000),
        ];
        final result = MileageMilestoneDetector.detect(records);
        expect(result.map((m) => m.mileage), [10000]);
      });

      test('interval が 0 では空を返す', () {
        final records = [_rec(date: DateTime(2024, 1, 1), mileage: 50000)];
        expect(MileageMilestoneDetector.detect(records, interval: 0), isEmpty);
      });

      test('interval が負では空を返す', () {
        final records = [_rec(date: DateTime(2024, 1, 1), mileage: 50000)];
        expect(
          MileageMilestoneDetector.detect(records, interval: -100),
          isEmpty,
        );
      });
    });
  });
}
