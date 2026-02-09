import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

import '../logging/logging_service.dart';
import 'metrics_aggregator.dart';
import 'performance_service.dart';

/// Implementation of PerformanceService
///
/// Integrates with Firebase Performance SDK for production monitoring
/// and provides in-memory metrics aggregation for development analysis.
class PerformanceServiceImpl implements PerformanceService {
  FirebasePerformance? _firebasePerformance;
  final MetricsAggregator _aggregator;
  final LoggingService _loggingService;
  Duration _slowThreshold;
  final bool _isEnabled;

  /// Create a new PerformanceServiceImpl
  ///
  /// [firebasePerformance] - Firebase Performance instance (optional, lazy loaded)
  /// [aggregator] - Metrics aggregator (defaults to new instance with 100 samples)
  /// [loggingService] - Logging service for slow operation warnings
  /// [slowThreshold] - Threshold for slow operation warnings (default: 1000ms)
  /// [enabled] - Override for enabling/disabling (defaults based on build mode)
  PerformanceServiceImpl({
    FirebasePerformance? firebasePerformance,
    MetricsAggregator? aggregator,
    required LoggingService loggingService,
    Duration slowThreshold = const Duration(milliseconds: 1000),
    bool? enabled,
  })  : _firebasePerformance = firebasePerformance,
        _aggregator = aggregator ?? MetricsAggregator(),
        _loggingService = loggingService,
        _slowThreshold = slowThreshold,
        _isEnabled = enabled ?? !kDebugMode;

  /// Get Firebase Performance instance lazily
  FirebasePerformance? get _performance {
    if (!_isEnabled) return null;
    try {
      _firebasePerformance ??= FirebasePerformance.instance;
      return _firebasePerformance;
    } catch (e) {
      // Firebase not initialized
      return null;
    }
  }

  @override
  bool get isEnabled => _isEnabled;

  @override
  Duration get slowOperationThreshold => _slowThreshold;

  @override
  void setSlowOperationThreshold(Duration threshold) {
    _slowThreshold = threshold;
  }

  @override
  Future<PerformanceTrace> startTrace(
    String name, {
    Map<String, String>? attributes,
  }) async {
    Trace? firebaseTrace;

    if (_isEnabled && _performance != null) {
      try {
        firebaseTrace = _performance!.newTrace(name);
        await firebaseTrace.start();

        attributes?.forEach((key, value) {
          firebaseTrace?.putAttribute(key, value);
        });
      } catch (e) {
        // Firebase Performance may not be available on all platforms
        _loggingService.debug(
          'Failed to start Firebase trace: $e',
          tag: 'Performance',
        );
      }
    }

    return _PerformanceTraceImpl(
      name: name,
      firebaseTrace: firebaseTrace,
      aggregator: _aggregator,
      loggingService: _loggingService,
      slowThreshold: _slowThreshold,
    );
  }

  @override
  Future<T> measureAsync<T>(
    String name,
    Future<T> Function() operation, {
    Map<String, String>? attributes,
  }) async {
    final trace = await startTrace(name, attributes: attributes);
    try {
      return await operation();
    } finally {
      await trace.stop();
    }
  }

  @override
  T measureSync<T>(
    String name,
    T Function() operation, {
    Map<String, String>? attributes,
  }) {
    final stopwatch = Stopwatch()..start();
    try {
      return operation();
    } finally {
      stopwatch.stop();
      final durationMs = stopwatch.elapsedMilliseconds;

      // Record to aggregator
      _aggregator.recordDuration(name, durationMs);

      // Log if slow
      if (stopwatch.elapsed > _slowThreshold) {
        _loggingService.warning(
          'Slow operation: $name took ${durationMs}ms (threshold: ${_slowThreshold.inMilliseconds}ms)',
          tag: 'Performance',
          data: {'operation': name, 'durationMs': durationMs},
        );
      } else if (kDebugMode) {
        _loggingService.debug(
          '$name completed in ${durationMs}ms',
          tag: 'Performance',
        );
      }
    }
  }

  @override
  void recordMetric(String name, int value, {String? unit}) {
    _aggregator.recordDuration(name, value);
    _loggingService.debug(
      'Metric: $name = $value${unit != null ? ' $unit' : ''}',
      tag: 'Performance',
    );
  }

  @override
  MetricsSnapshot getMetrics() => _aggregator.getSnapshot();

  @override
  void clearMetrics() => _aggregator.clear();
}

/// Implementation of PerformanceTrace
class _PerformanceTraceImpl implements PerformanceTrace {
  @override
  final String name;

  final Trace? _firebaseTrace;
  final MetricsAggregator _aggregator;
  final LoggingService _loggingService;
  final Duration _slowThreshold;
  final Stopwatch _stopwatch;
  bool _stopped = false;

  _PerformanceTraceImpl({
    required this.name,
    required Trace? firebaseTrace,
    required MetricsAggregator aggregator,
    required LoggingService loggingService,
    required Duration slowThreshold,
  })  : _firebaseTrace = firebaseTrace,
        _aggregator = aggregator,
        _loggingService = loggingService,
        _slowThreshold = slowThreshold,
        _stopwatch = Stopwatch()..start();

  @override
  Duration get elapsed => _stopwatch.elapsed;

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;

    _stopwatch.stop();
    final durationMs = _stopwatch.elapsedMilliseconds;

    // Stop Firebase trace
    try {
      await _firebaseTrace?.stop();
    } catch (e) {
      _loggingService.debug(
        'Failed to stop Firebase trace: $e',
        tag: 'Performance',
      );
    }

    // Record to aggregator
    _aggregator.recordDuration(name, durationMs);

    // Log slow operations
    if (_stopwatch.elapsed > _slowThreshold) {
      _loggingService.warning(
        'Slow operation: $name took ${durationMs}ms (threshold: ${_slowThreshold.inMilliseconds}ms)',
        tag: 'Performance',
        data: {'operation': name, 'durationMs': durationMs},
      );
    } else if (kDebugMode) {
      _loggingService.debug(
        '$name completed in ${durationMs}ms',
        tag: 'Performance',
      );
    }
  }

  @override
  void putAttribute(String name, String value) {
    try {
      _firebaseTrace?.putAttribute(name, value);
    } catch (e) {
      _loggingService.debug(
        'Failed to set trace attribute: $e',
        tag: 'Performance',
      );
    }
  }

  @override
  void setMetric(String name, int value) {
    try {
      _firebaseTrace?.setMetric(name, value);
    } catch (e) {
      _loggingService.debug(
        'Failed to set trace metric: $e',
        tag: 'Performance',
      );
    }
  }
}
