import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/performance/metrics_aggregator.dart';

void main() {
  group('MetricsAggregator', () {
    late MetricsAggregator aggregator;

    setUp(() {
      aggregator = MetricsAggregator();
    });

    test('can be instantiated', () {
      expect(aggregator, isNotNull);
      expect(aggregator.trackedOperations, isEmpty);
      expect(aggregator.totalSampleCount, equals(0));
    });

    test('can be instantiated with custom max samples', () {
      final customAggregator = MetricsAggregator(maxSamplesPerOperation: 50);
      expect(customAggregator, isNotNull);
    });

    test('recordDuration adds sample to operation', () {
      aggregator.recordDuration('test.operation', 100);

      expect(aggregator.trackedOperations, contains('test.operation'));
      expect(aggregator.totalSampleCount, equals(1));
    });

    test('recordDuration tracks multiple operations', () {
      aggregator.recordDuration('operation.a', 100);
      aggregator.recordDuration('operation.b', 200);

      expect(aggregator.trackedOperations.length, equals(2));
      expect(aggregator.totalSampleCount, equals(2));
    });

    test('recordDuration accumulates samples for same operation', () {
      aggregator.recordDuration('test.operation', 100);
      aggregator.recordDuration('test.operation', 150);
      aggregator.recordDuration('test.operation', 200);

      expect(aggregator.trackedOperations.length, equals(1));
      expect(aggregator.totalSampleCount, equals(3));
    });

    test('FIFO eviction when max samples reached', () {
      final smallAggregator = MetricsAggregator(maxSamplesPerOperation: 3);

      smallAggregator.recordDuration('test.operation', 100);
      smallAggregator.recordDuration('test.operation', 200);
      smallAggregator.recordDuration('test.operation', 300);
      smallAggregator.recordDuration('test.operation', 400);

      final metrics = smallAggregator.getOperationMetrics('test.operation');
      expect(metrics?.count, equals(3));
      // First sample (100) should be evicted
      expect(metrics?.minMs, equals(200));
      expect(metrics?.maxMs, equals(400));
    });

    test('clear removes all samples', () {
      aggregator.recordDuration('operation.a', 100);
      aggregator.recordDuration('operation.b', 200);

      aggregator.clear();

      expect(aggregator.trackedOperations, isEmpty);
      expect(aggregator.totalSampleCount, equals(0));
    });
  });

  group('MetricsAggregator.getOperationMetrics', () {
    late MetricsAggregator aggregator;

    setUp(() {
      aggregator = MetricsAggregator();
    });

    test('returns null for unknown operation', () {
      final metrics = aggregator.getOperationMetrics('unknown');
      expect(metrics, isNull);
    });

    test('returns metrics for tracked operation', () {
      aggregator.recordDuration('test.operation', 100);
      aggregator.recordDuration('test.operation', 200);

      final metrics = aggregator.getOperationMetrics('test.operation');
      expect(metrics, isNotNull);
      expect(metrics?.name, equals('test.operation'));
      expect(metrics?.count, equals(2));
    });
  });

  group('MetricsAggregator.getSnapshot', () {
    late MetricsAggregator aggregator;

    setUp(() {
      aggregator = MetricsAggregator();
    });

    test('returns empty snapshot when no data', () {
      final snapshot = aggregator.getSnapshot();

      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.operationCount, equals(0));
      expect(snapshot.timestamp, isNotNull);
    });

    test('returns snapshot with all operations', () {
      aggregator.recordDuration('operation.a', 100);
      aggregator.recordDuration('operation.b', 200);

      final snapshot = aggregator.getSnapshot();

      expect(snapshot.isEmpty, isFalse);
      expect(snapshot.operationCount, equals(2));
      expect(snapshot.operations.containsKey('operation.a'), isTrue);
      expect(snapshot.operations.containsKey('operation.b'), isTrue);
    });

    test('snapshot toString includes all operations', () {
      aggregator.recordDuration('operation.a', 100);
      aggregator.recordDuration('operation.b', 200);

      final snapshot = aggregator.getSnapshot();
      final output = snapshot.toString();

      expect(output, contains('Performance Metrics'));
      expect(output, contains('operation.a'));
      expect(output, contains('operation.b'));
    });

    test('empty snapshot toString', () {
      final snapshot = aggregator.getSnapshot();
      final output = snapshot.toString();

      expect(output, contains('No data collected'));
    });
  });

  group('OperationMetrics', () {
    test('fromSamples calculates correct statistics', () {
      final samples = [100, 200, 300, 400, 500];
      final metrics = OperationMetrics.fromSamples('test', samples);

      expect(metrics.name, equals('test'));
      expect(metrics.count, equals(5));
      expect(metrics.minMs, equals(100));
      expect(metrics.maxMs, equals(500));
      expect(metrics.avgMs, equals(300)); // (100+200+300+400+500)/5 = 300
      expect(metrics.p50Ms, equals(300)); // Median
    });

    test('fromSamples with single sample', () {
      final metrics = OperationMetrics.fromSamples('test', [150]);

      expect(metrics.count, equals(1));
      expect(metrics.minMs, equals(150));
      expect(metrics.maxMs, equals(150));
      expect(metrics.avgMs, equals(150));
      expect(metrics.p50Ms, equals(150));
      expect(metrics.p95Ms, equals(150));
    });

    test('fromSamples with empty samples', () {
      final metrics = OperationMetrics.fromSamples('test', []);

      expect(metrics.count, equals(0));
      expect(metrics.minMs, equals(0));
      expect(metrics.maxMs, equals(0));
      expect(metrics.avgMs, equals(0));
      expect(metrics.p50Ms, equals(0));
      expect(metrics.p95Ms, equals(0));
    });

    test('fromSamples calculates p95 correctly', () {
      // 20 samples: 1-20
      final samples = List.generate(20, (i) => (i + 1) * 10);
      final metrics = OperationMetrics.fromSamples('test', samples);

      // p95 at index 19 * 0.95 = 18.05 -> floor = 18 -> samples[18] = 190
      expect(metrics.p95Ms, equals(190));
    });

    test('toString formats correctly', () {
      final metrics = OperationMetrics.fromSamples('test.operation', [100, 200, 300]);
      final output = metrics.toString();

      expect(output, contains('test.operation'));
      expect(output, contains('count=3'));
      expect(output, contains('avg='));
      expect(output, contains('p50='));
      expect(output, contains('p95='));
    });

    test('toString for empty metrics', () {
      final metrics = OperationMetrics.fromSamples('test', []);
      final output = metrics.toString();

      expect(output, contains('no data'));
    });

    test('toMap returns correct structure', () {
      final metrics = OperationMetrics.fromSamples('test', [100, 200]);
      final map = metrics.toMap();

      expect(map['name'], equals('test'));
      expect(map['count'], equals(2));
      expect(map.containsKey('minMs'), isTrue);
      expect(map.containsKey('maxMs'), isTrue);
      expect(map.containsKey('avgMs'), isTrue);
      expect(map.containsKey('p50Ms'), isTrue);
      expect(map.containsKey('p95Ms'), isTrue);
    });
  });

  group('OperationMetrics statistical accuracy', () {
    test('calculates correct average', () {
      final samples = [10, 20, 30, 40];
      final metrics = OperationMetrics.fromSamples('test', samples);

      expect(metrics.avgMs, equals(25)); // (10+20+30+40)/4 = 25
    });

    test('handles unsorted input', () {
      final samples = [300, 100, 200];
      final metrics = OperationMetrics.fromSamples('test', samples);

      expect(metrics.minMs, equals(100));
      expect(metrics.maxMs, equals(300));
      expect(metrics.p50Ms, equals(200));
    });

    test('handles large samples', () {
      final samples = List.generate(1000, (i) => i + 1);
      final metrics = OperationMetrics.fromSamples('test', samples);

      expect(metrics.count, equals(1000));
      expect(metrics.minMs, equals(1));
      expect(metrics.maxMs, equals(1000));
      // Average of 1-1000 is 500.5, rounded to 501
      expect(metrics.avgMs, equals(501));
    });
  });
}
