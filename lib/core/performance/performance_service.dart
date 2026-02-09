import 'metrics_aggregator.dart';

/// Performance monitoring service interface
///
/// Provides methods for measuring operation durations, recording metrics,
/// and analyzing performance data. Integrates with Firebase Performance SDK
/// for production monitoring and provides in-memory aggregation for development.
abstract class PerformanceService {
  /// Start a named trace and return a handle to stop it
  ///
  /// [name] - Trace name (use TraceNames constants for consistency)
  /// [attributes] - Optional key-value attributes to attach to the trace
  Future<PerformanceTrace> startTrace(
    String name, {
    Map<String, String>? attributes,
  });

  /// Measure an async operation (convenience method)
  ///
  /// Wraps the operation with start/stop trace calls automatically.
  /// Returns the result of the operation.
  ///
  /// Example:
  /// ```dart
  /// final result = await performanceService.measureAsync(
  ///   TraceNames.addVehicle,
  ///   () => firebaseService.addVehicle(vehicle),
  /// );
  /// ```
  Future<T> measureAsync<T>(
    String name,
    Future<T> Function() operation, {
    Map<String, String>? attributes,
  });

  /// Measure a synchronous operation
  ///
  /// For CPU-bound operations like image processing.
  T measureSync<T>(
    String name,
    T Function() operation, {
    Map<String, String>? attributes,
  });

  /// Record a metric value directly
  ///
  /// Useful for recording pre-calculated values or counts.
  void recordMetric(String name, int value, {String? unit});

  /// Get aggregated metrics snapshot
  ///
  /// Returns collected metrics for all tracked operations.
  /// Useful for development-time analysis.
  MetricsSnapshot getMetrics();

  /// Configure slow operation threshold
  ///
  /// Operations exceeding this threshold will be logged as warnings.
  void setSlowOperationThreshold(Duration threshold);

  /// Get current slow operation threshold
  Duration get slowOperationThreshold;

  /// Whether performance monitoring is enabled
  ///
  /// Firebase Performance SDK is typically disabled in debug mode.
  bool get isEnabled;

  /// Clear all collected metrics
  void clearMetrics();
}

/// Handle for an active performance trace
///
/// Represents an in-progress measurement that should be stopped
/// when the operation completes.
abstract class PerformanceTrace {
  /// Stop the trace and record duration
  ///
  /// Should be called in a finally block to ensure cleanup.
  Future<void> stop();

  /// Add an attribute to the trace
  ///
  /// Attributes are key-value pairs that provide context.
  /// Maximum 5 attributes per trace in Firebase Performance.
  void putAttribute(String name, String value);

  /// Set a metric on the trace
  ///
  /// Metrics are numeric values associated with the trace.
  void setMetric(String name, int value);

  /// The operation name
  String get name;

  /// Duration since start (before stop)
  Duration get elapsed;
}
