import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/services/maintenance_trend_service.dart';

void main() {
  group('MaintenanceTrendService', () {
    const service = MaintenanceTrendService();

    MaintenanceRecord _record({
      required String id,
      required MaintenanceType type,
      required DateTime date,
      int? mileage,
      int cost = 5000,
    }) =>
        MaintenanceRecord(
          id: id,
          vehicleId: 'v1',
          userId: 'u1',
          type: type,
          title: type.displayName,
          cost: cost,
          date: date,
          mileageAtService: mileage,
          imageUrls: const [],
          createdAt: date,
        );

    group('analyzeHistory', () {
      test('正常系: オイル交換の平均間隔（km）を計算する', () {
        final records = [
          _record(
            id: '1',
            type: MaintenanceType.oilChange,
            date: DateTime(2023, 1, 1),
            mileage: 10000,
          ),
          _record(
            id: '2',
            type: MaintenanceType.oilChange,
            date: DateTime(2023, 7, 1),
            mileage: 15000,
          ),
          _record(
            id: '3',
            type: MaintenanceType.oilChange,
            date: DateTime(2024, 1, 1),
            mileage: 20000,
          ),
        ];

        final trends = service.analyzeHistory(records);
        final oilTrend = trends.firstWhere(
          (t) => t.type == MaintenanceType.oilChange,
        );

        expect(oilTrend.averageIntervalKm, closeTo(5000, 1));
        expect(oilTrend.sampleCount, equals(3));
      });

      test('正常系: オイル交換の平均間隔（日数）を計算する', () {
        final records = [
          _record(
            id: '1',
            type: MaintenanceType.oilChange,
            date: DateTime(2023, 1, 1),
          ),
          _record(
            id: '2',
            type: MaintenanceType.oilChange,
            date: DateTime(2023, 7, 1),
          ),
          _record(
            id: '3',
            type: MaintenanceType.oilChange,
            date: DateTime(2024, 1, 1),
          ),
        ];

        final trends = service.analyzeHistory(records);
        final oilTrend = trends.firstWhere(
          (t) => t.type == MaintenanceType.oilChange,
        );

        // ~180 days between each
        expect(oilTrend.averageIntervalDays, closeTo(181, 3));
      });

      test('正常系: 次回交換予測日を計算する', () {
        final now = DateTime.now();
        final records = [
          _record(
            id: '1',
            type: MaintenanceType.oilChange,
            date: now.subtract(const Duration(days: 360)),
            mileage: 10000,
          ),
          _record(
            id: '2',
            type: MaintenanceType.oilChange,
            date: now.subtract(const Duration(days: 180)),
            mileage: 15000,
          ),
        ];

        final trends = service.analyzeHistory(records, currentMileage: 20000);
        final oilTrend = trends.firstWhere(
          (t) => t.type == MaintenanceType.oilChange,
        );

        // Last service was 180 days ago, avg interval ~180 days
        // → predicted next ~today
        expect(oilTrend.predictedNextDate, isNotNull);
        final diff = oilTrend.predictedNextDate!.difference(now).inDays.abs();
        expect(diff, lessThan(10));
      });

      test('正常系: 次回交換予測走行距離を計算する', () {
        final records = [
          _record(
            id: '1',
            type: MaintenanceType.oilChange,
            date: DateTime(2023, 1, 1),
            mileage: 10000,
          ),
          _record(
            id: '2',
            type: MaintenanceType.oilChange,
            date: DateTime(2023, 7, 1),
            mileage: 15000,
          ),
        ];

        final trends = service.analyzeHistory(records, currentMileage: 18000);
        final oilTrend = trends.firstWhere(
          (t) => t.type == MaintenanceType.oilChange,
        );

        // avg interval = 5000km, last at 15000 → next at 20000
        expect(oilTrend.predictedNextMileage, equals(20000));
      });

      test('正常系: 平均費用を計算する', () {
        final records = [
          _record(
            id: '1',
            type: MaintenanceType.oilChange,
            date: DateTime(2023, 1, 1),
            cost: 3000,
          ),
          _record(
            id: '2',
            type: MaintenanceType.oilChange,
            date: DateTime(2023, 7, 1),
            cost: 5000,
          ),
          _record(
            id: '3',
            type: MaintenanceType.oilChange,
            date: DateTime(2024, 1, 1),
            cost: 4000,
          ),
        ];

        final trends = service.analyzeHistory(records);
        final oilTrend = trends.firstWhere(
          (t) => t.type == MaintenanceType.oilChange,
        );

        expect(oilTrend.averageCost, closeTo(4000, 1));
      });

      test('正常系: 信頼度 high = 3件以上', () {
        final records = List.generate(
          3,
          (i) => _record(
            id: 'r$i',
            type: MaintenanceType.oilChange,
            date: DateTime(2023 + i, 1, 1),
          ),
        );

        final trends = service.analyzeHistory(records);
        final oilTrend = trends.firstWhere(
          (t) => t.type == MaintenanceType.oilChange,
        );

        expect(oilTrend.confidence, equals(TrendConfidence.high));
      });

      test('正常系: 信頼度 medium = 2件', () {
        final records = [
          _record(
            id: '1',
            type: MaintenanceType.tireChange,
            date: DateTime(2023, 1, 1),
          ),
          _record(
            id: '2',
            type: MaintenanceType.tireChange,
            date: DateTime(2024, 1, 1),
          ),
        ];

        final trends = service.analyzeHistory(records);
        final tireTrend = trends.firstWhere(
          (t) => t.type == MaintenanceType.tireChange,
        );

        expect(tireTrend.confidence, equals(TrendConfidence.medium));
      });

      test('正常系: 信頼度 low = 1件', () {
        final records = [
          _record(
            id: '1',
            type: MaintenanceType.batteryChange,
            date: DateTime(2023, 1, 1),
          ),
        ];

        final trends = service.analyzeHistory(records);
        final batteryTrend = trends.firstWhere(
          (t) => t.type == MaintenanceType.batteryChange,
        );

        expect(batteryTrend.confidence, equals(TrendConfidence.low));
        expect(batteryTrend.averageIntervalKm, isNull);
        expect(batteryTrend.averageIntervalDays, isNull);
      });

      test('正常系: 複数タイプを個別に分析する', () {
        final records = [
          _record(
            id: '1',
            type: MaintenanceType.oilChange,
            date: DateTime(2023, 1, 1),
          ),
          _record(
            id: '2',
            type: MaintenanceType.tireChange,
            date: DateTime(2023, 3, 1),
          ),
          _record(
            id: '3',
            type: MaintenanceType.oilChange,
            date: DateTime(2023, 7, 1),
          ),
        ];

        final trends = service.analyzeHistory(records);

        expect(trends.length, equals(2));
        expect(
          trends.any((t) => t.type == MaintenanceType.oilChange),
          isTrue,
        );
        expect(
          trends.any((t) => t.type == MaintenanceType.tireChange),
          isTrue,
        );
      });

      test('正常系: 直近のサービス日・走行距離を記録する', () {
        final records = [
          _record(
            id: '1',
            type: MaintenanceType.oilChange,
            date: DateTime(2023, 1, 1),
            mileage: 10000,
          ),
          _record(
            id: '2',
            type: MaintenanceType.oilChange,
            date: DateTime(2024, 6, 1),
            mileage: 25000,
          ),
        ];

        final trends = service.analyzeHistory(records);
        final oilTrend = trends.firstWhere(
          (t) => t.type == MaintenanceType.oilChange,
        );

        expect(oilTrend.lastServiceDate, equals(DateTime(2024, 6, 1)));
        expect(oilTrend.lastServiceMileage, equals(25000));
      });

      group('Edge Cases', () {
        test('空リストは空のトレンドを返す', () {
          final trends = service.analyzeHistory([]);
          expect(trends, isEmpty);
        });

        test('走行距離データなしでも日数ベース予測は返る', () {
          final now = DateTime.now();
          final records = [
            _record(
              id: '1',
              type: MaintenanceType.oilChange,
              date: now.subtract(const Duration(days: 180)),
            ),
            _record(
              id: '2',
              type: MaintenanceType.oilChange,
              date: now.subtract(const Duration(days: 360)),
            ),
          ];

          final trends = service.analyzeHistory(records);
          final oilTrend = trends.firstWhere(
            (t) => t.type == MaintenanceType.oilChange,
          );

          expect(oilTrend.predictedNextDate, isNotNull);
          expect(oilTrend.predictedNextMileage, isNull);
        });

        test('同日の重複レコードは正しく処理する', () {
          final date = DateTime(2023, 6, 1);
          final records = [
            _record(id: '1', type: MaintenanceType.oilChange, date: date),
            _record(id: '2', type: MaintenanceType.oilChange, date: date),
          ];

          final trends = service.analyzeHistory(records);
          expect(trends, isNotEmpty);
        });

        test('将来日付のレコードは無視しない（テストデータ用）', () {
          final future = DateTime.now().add(const Duration(days: 30));
          final records = [
            _record(
              id: '1',
              type: MaintenanceType.oilChange,
              date: future,
              mileage: 10000,
            ),
          ];

          final trends = service.analyzeHistory(records);
          expect(trends.length, equals(1));
        });
      });
    });

    group('sortByUrgency', () {
      test('予測次回日が近い順にソートされる', () {
        final now = DateTime.now();
        final records = [
          _record(
            id: '1',
            type: MaintenanceType.batteryChange,
            date: now.subtract(const Duration(days: 700)),
          ),
          _record(
            id: '2',
            type: MaintenanceType.batteryChange,
            date: now.subtract(const Duration(days: 720)),
          ),
          _record(
            id: '3',
            type: MaintenanceType.oilChange,
            date: now.subtract(const Duration(days: 10)),
          ),
          _record(
            id: '4',
            type: MaintenanceType.oilChange,
            date: now.subtract(const Duration(days: 20)),
          ),
        ];

        final trends = service.analyzeHistory(records);
        final sorted = service.sortByUrgency(trends, currentDate: now);

        // Battery was last done ~700 days ago with 20-day avg → overdue
        // Oil was last done ~10 days ago with 10-day avg → close
        expect(sorted.first.type, isNot(equals(MaintenanceType.oilChange)));
      });
    });
  });
}
