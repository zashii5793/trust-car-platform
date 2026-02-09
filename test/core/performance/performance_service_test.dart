import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/logging/log_level.dart';
import 'package:trust_car_platform/core/logging/logging_service.dart';
import 'package:trust_car_platform/core/performance/metrics_aggregator.dart';
import 'package:trust_car_platform/core/performance/performance_service_impl.dart';
import 'package:trust_car_platform/core/performance/trace_names.dart';

// Mock LoggingService for testing
class MockLoggingService implements LoggingService {
  final List<LogEntry> entries = [];
  String? lastUserId;

  @override
  LogLevel get minimumLevel => LogLevel.debug;

  @override
  void debug(String message, {String? tag, Map<String, dynamic>? data}) {
    entries.add(LogEntry(LogLevel.debug, message, tag: tag, data: data));
  }

  @override
  void info(String message, {String? tag, Map<String, dynamic>? data}) {
    entries.add(LogEntry(LogLevel.info, message, tag: tag, data: data));
  }

  @override
  void warning(String message, {String? tag, Map<String, dynamic>? data}) {
    entries.add(LogEntry(LogLevel.warning, message, tag: tag, data: data));
  }

  @override
  void error(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    entries.add(LogEntry(LogLevel.error, message, tag: tag));
  }

  @override
  void fatal(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    entries.add(LogEntry(LogLevel.fatal, message, tag: tag));
  }

  @override
  void logAppError(AppError appError, {String? tag, StackTrace? stackTrace}) {
    entries.add(LogEntry(LogLevel.error, appError.message, tag: tag));
  }

  @override
  Future<void> setUserId(String? userId) async {
    lastUserId = userId;
  }

  void clear() => entries.clear();
}

class LogEntry {
  final LogLevel level;
  final String message;
  final String? tag;
  final Map<String, dynamic>? data;

  LogEntry(this.level, this.message, {this.tag, this.data});
}

void main() {
  group('PerformanceServiceImpl', () {
    late PerformanceServiceImpl service;
    late MockLoggingService mockLogging;
    late MetricsAggregator aggregator;

    setUp(() {
      mockLogging = MockLoggingService();
      aggregator = MetricsAggregator();
      service = PerformanceServiceImpl(
        loggingService: mockLogging,
        aggregator: aggregator,
        enabled: false, // Disable Firebase Performance for unit tests
      );
    });

    test('can be instantiated', () {
      expect(service, isNotNull);
      expect(service.isEnabled, isFalse);
    });

    test('default slow threshold is 1000ms', () {
      expect(service.slowOperationThreshold.inMilliseconds, equals(1000));
    });

    test('setSlowOperationThreshold updates threshold', () {
      service.setSlowOperationThreshold(const Duration(milliseconds: 500));
      expect(service.slowOperationThreshold.inMilliseconds, equals(500));
    });

    test('getMetrics returns empty snapshot initially', () {
      final metrics = service.getMetrics();
      expect(metrics.isEmpty, isTrue);
    });

    test('clearMetrics clears all data', () {
      aggregator.recordDuration('test', 100);
      expect(service.getMetrics().isEmpty, isFalse);

      service.clearMetrics();
      expect(service.getMetrics().isEmpty, isTrue);
    });
  });

  group('PerformanceServiceImpl.startTrace', () {
    late PerformanceServiceImpl service;
    late MockLoggingService mockLogging;
    late MetricsAggregator aggregator;

    setUp(() {
      mockLogging = MockLoggingService();
      aggregator = MetricsAggregator();
      service = PerformanceServiceImpl(
        loggingService: mockLogging,
        aggregator: aggregator,
        enabled: false,
      );
    });

    test('returns a trace object', () async {
      final trace = await service.startTrace('test.operation');

      expect(trace, isNotNull);
      expect(trace.name, equals('test.operation'));
    });

    test('trace elapsed increases over time', () async {
      final trace = await service.startTrace('test.operation');

      await Future.delayed(const Duration(milliseconds: 50));

      expect(trace.elapsed.inMilliseconds, greaterThanOrEqualTo(40));
    });

    test('trace stop records duration', () async {
      final trace = await service.startTrace('test.operation');
      await Future.delayed(const Duration(milliseconds: 10));
      await trace.stop();

      final metrics = service.getMetrics();
      expect(metrics.operations.containsKey('test.operation'), isTrue);
    });

    test('trace stop is idempotent', () async {
      final trace = await service.startTrace('test.operation');
      await trace.stop();
      await trace.stop(); // Should not throw or double-record

      final metrics = service.getMetrics();
      expect(metrics.operations['test.operation']?.count, equals(1));
    });
  });

  group('PerformanceServiceImpl.measureAsync', () {
    late PerformanceServiceImpl service;
    late MockLoggingService mockLogging;
    late MetricsAggregator aggregator;

    setUp(() {
      mockLogging = MockLoggingService();
      aggregator = MetricsAggregator();
      service = PerformanceServiceImpl(
        loggingService: mockLogging,
        aggregator: aggregator,
        enabled: false,
      );
    });

    test('returns operation result', () async {
      final result = await service.measureAsync(
        'test.operation',
        () async => 42,
      );

      expect(result, equals(42));
    });

    test('records duration after operation', () async {
      await service.measureAsync(
        'test.operation',
        () async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 'done';
        },
      );

      final metrics = service.getMetrics();
      expect(metrics.operations.containsKey('test.operation'), isTrue);
      expect(
        metrics.operations['test.operation']!.avgMs,
        greaterThanOrEqualTo(5),
      );
    });

    test('records duration even when operation throws', () async {
      try {
        await service.measureAsync(
          'test.failing',
          () async => throw Exception('Test error'),
        );
      } catch (_) {}

      final metrics = service.getMetrics();
      expect(metrics.operations.containsKey('test.failing'), isTrue);
    });

    test('propagates exception from operation', () async {
      expect(
        () => service.measureAsync(
          'test.failing',
          () async => throw Exception('Test error'),
        ),
        throwsException,
      );
    });
  });

  group('PerformanceServiceImpl.measureSync', () {
    late PerformanceServiceImpl service;
    late MockLoggingService mockLogging;
    late MetricsAggregator aggregator;

    setUp(() {
      mockLogging = MockLoggingService();
      aggregator = MetricsAggregator();
      service = PerformanceServiceImpl(
        loggingService: mockLogging,
        aggregator: aggregator,
        enabled: false,
      );
    });

    test('returns operation result', () {
      final result = service.measureSync(
        'test.operation',
        () => 42,
      );

      expect(result, equals(42));
    });

    test('records duration after operation', () {
      service.measureSync(
        'test.operation',
        () {
          // Simulate some work
          var sum = 0;
          for (var i = 0; i < 10000; i++) {
            sum += i;
          }
          return sum;
        },
      );

      final metrics = service.getMetrics();
      expect(metrics.operations.containsKey('test.operation'), isTrue);
    });

    test('records duration even when operation throws', () {
      try {
        service.measureSync(
          'test.failing',
          () => throw Exception('Test error'),
        );
      } catch (_) {}

      final metrics = service.getMetrics();
      expect(metrics.operations.containsKey('test.failing'), isTrue);
    });
  });

  group('PerformanceServiceImpl.recordMetric', () {
    late PerformanceServiceImpl service;
    late MockLoggingService mockLogging;

    setUp(() {
      mockLogging = MockLoggingService();
      service = PerformanceServiceImpl(
        loggingService: mockLogging,
        enabled: false,
      );
    });

    test('records metric value', () {
      service.recordMetric('custom.metric', 100);

      final metrics = service.getMetrics();
      expect(metrics.operations.containsKey('custom.metric'), isTrue);
      expect(metrics.operations['custom.metric']!.avgMs, equals(100));
    });

    test('logs metric with unit', () {
      service.recordMetric('custom.metric', 50, unit: 'ms');

      expect(mockLogging.entries.any((e) => e.message.contains('50')), isTrue);
    });
  });

  group('Slow operation logging', () {
    late PerformanceServiceImpl service;
    late MockLoggingService mockLogging;

    setUp(() {
      mockLogging = MockLoggingService();
      service = PerformanceServiceImpl(
        loggingService: mockLogging,
        slowThreshold: const Duration(milliseconds: 50),
        enabled: false,
      );
    });

    test('logs warning for slow async operations', () async {
      await service.measureAsync(
        'slow.operation',
        () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'done';
        },
      );

      final warningLogs =
          mockLogging.entries.where((e) => e.level == LogLevel.warning);
      expect(warningLogs.isNotEmpty, isTrue);
      expect(
        warningLogs.any((e) => e.message.contains('Slow operation')),
        isTrue,
      );
    });

    test('logs warning for slow sync operations', () {
      service.measureSync(
        'slow.operation',
        () {
          // Busy loop to ensure > 50ms
          final stopwatch = Stopwatch()..start();
          while (stopwatch.elapsedMilliseconds < 60) {
            // Spin
          }
          return 'done';
        },
      );

      final warningLogs =
          mockLogging.entries.where((e) => e.level == LogLevel.warning);
      expect(warningLogs.isNotEmpty, isTrue);
    });

    test('includes operation name in warning', () async {
      await service.measureAsync(
        'my.slow.operation',
        () async {
          await Future.delayed(const Duration(milliseconds: 100));
        },
      );

      final warning = mockLogging.entries
          .firstWhere((e) => e.level == LogLevel.warning);
      expect(warning.message, contains('my.slow.operation'));
    });
  });

  group('TraceNames', () {
    test('vehicle operation names are consistent', () {
      expect(TraceNames.addVehicle, equals('firebase.vehicle.add'));
      expect(TraceNames.updateVehicle, equals('firebase.vehicle.update'));
      expect(TraceNames.deleteVehicle, equals('firebase.vehicle.delete'));
      expect(TraceNames.getVehicle, equals('firebase.vehicle.get'));
      expect(TraceNames.getUserVehicles, equals('firebase.vehicle.list'));
    });

    test('maintenance operation names are consistent', () {
      expect(TraceNames.addMaintenanceRecord, equals('firebase.maintenance.add'));
      expect(TraceNames.getMaintenanceRecords, equals('firebase.maintenance.list'));
    });

    test('auth operation names are consistent', () {
      expect(TraceNames.signUp, equals('auth.signup'));
      expect(TraceNames.signInEmail, equals('auth.signin.email'));
      expect(TraceNames.signInGoogle, equals('auth.signin.google'));
    });

    test('CPU operation names are consistent', () {
      expect(TraceNames.compressImage, equals('image.compress'));
      expect(TraceNames.ocrVehicleCertificate, equals('ocr.vehicle_certificate'));
    });
  });

  group('PerformanceTrace.putAttribute', () {
    late PerformanceServiceImpl service;
    late MockLoggingService mockLogging;

    setUp(() {
      mockLogging = MockLoggingService();
      service = PerformanceServiceImpl(
        loggingService: mockLogging,
        enabled: false,
      );
    });

    test('putAttribute does not throw when disabled', () async {
      final trace = await service.startTrace('test');

      expect(() => trace.putAttribute('key', 'value'), returnsNormally);

      await trace.stop();
    });

    test('setMetric does not throw when disabled', () async {
      final trace = await service.startTrace('test');

      expect(() => trace.setMetric('count', 5), returnsNormally);

      await trace.stop();
    });
  });
}
