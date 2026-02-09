/// In-memory metrics aggregator for development analysis
///
/// Collects timing samples for operations and provides statistical analysis
/// including average, percentiles (p50, p95), min, and max values.
class MetricsAggregator {
  final Map<String, List<int>> _operationDurations = {};
  final int _maxSamplesPerOperation;

  /// Create a new aggregator with configurable sample limit
  ///
  /// [maxSamplesPerOperation] - Maximum samples to keep per operation (FIFO eviction)
  MetricsAggregator({int maxSamplesPerOperation = 100})
      : _maxSamplesPerOperation = maxSamplesPerOperation;

  /// Record a duration for an operation
  void recordDuration(String operation, int durationMs) {
    _operationDurations.putIfAbsent(operation, () => []);
    final samples = _operationDurations[operation]!;
    if (samples.length >= _maxSamplesPerOperation) {
      samples.removeAt(0); // FIFO eviction
    }
    samples.add(durationMs);
  }

  /// Get a snapshot of all collected metrics
  MetricsSnapshot getSnapshot() {
    return MetricsSnapshot(
      operations: Map.fromEntries(
        _operationDurations.entries.map((entry) => MapEntry(
              entry.key,
              OperationMetrics.fromSamples(entry.key, entry.value),
            )),
      ),
    );
  }

  /// Get metrics for a specific operation
  OperationMetrics? getOperationMetrics(String operation) {
    final samples = _operationDurations[operation];
    if (samples == null || samples.isEmpty) return null;
    return OperationMetrics.fromSamples(operation, samples);
  }

  /// Clear all collected samples
  void clear() => _operationDurations.clear();

  /// Get the list of tracked operations
  List<String> get trackedOperations => _operationDurations.keys.toList();

  /// Get total sample count across all operations
  int get totalSampleCount =>
      _operationDurations.values.fold(0, (sum, samples) => sum + samples.length);
}

/// Snapshot of aggregated metrics at a point in time
class MetricsSnapshot {
  /// Metrics for each tracked operation
  final Map<String, OperationMetrics> operations;

  /// Timestamp when the snapshot was taken
  final DateTime timestamp;

  MetricsSnapshot({required this.operations}) : timestamp = DateTime.now();

  /// Check if the snapshot is empty
  bool get isEmpty => operations.isEmpty;

  /// Get the number of tracked operations
  int get operationCount => operations.length;

  @override
  String toString() {
    if (operations.isEmpty) {
      return 'MetricsSnapshot: No data collected';
    }

    final buffer = StringBuffer();
    buffer.writeln('=== Performance Metrics (${timestamp.toIso8601String()}) ===');

    // Sort by operation name for consistent output
    final sortedEntries = operations.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedEntries) {
      buffer.writeln(entry.value.toString());
    }

    return buffer.toString();
  }
}

/// Metrics for a single operation type
class OperationMetrics {
  /// Operation name
  final String name;

  /// Number of samples collected
  final int count;

  /// Minimum duration in milliseconds
  final int minMs;

  /// Maximum duration in milliseconds
  final int maxMs;

  /// Average duration in milliseconds
  final int avgMs;

  /// 50th percentile (median) duration in milliseconds
  final int p50Ms;

  /// 95th percentile duration in milliseconds
  final int p95Ms;

  OperationMetrics._({
    required this.name,
    required this.count,
    required this.minMs,
    required this.maxMs,
    required this.avgMs,
    required this.p50Ms,
    required this.p95Ms,
  });

  /// Create metrics from a list of duration samples
  factory OperationMetrics.fromSamples(String name, List<int> samples) {
    if (samples.isEmpty) {
      return OperationMetrics._(
        name: name,
        count: 0,
        minMs: 0,
        maxMs: 0,
        avgMs: 0,
        p50Ms: 0,
        p95Ms: 0,
      );
    }

    final sorted = List<int>.from(samples)..sort();
    final sum = sorted.reduce((a, b) => a + b);

    return OperationMetrics._(
      name: name,
      count: sorted.length,
      minMs: sorted.first,
      maxMs: sorted.last,
      avgMs: (sum / sorted.length).round(),
      p50Ms: _percentile(sorted, 0.50),
      p95Ms: _percentile(sorted, 0.95),
    );
  }

  /// Calculate percentile from sorted list
  static int _percentile(List<int> sorted, double percentile) {
    if (sorted.isEmpty) return 0;
    final index = ((sorted.length - 1) * percentile).floor();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  @override
  String toString() {
    if (count == 0) {
      return '$name: no data';
    }
    return '$name: count=$count, avg=${avgMs}ms, p50=${p50Ms}ms, p95=${p95Ms}ms, min=${minMs}ms, max=${maxMs}ms';
  }

  /// Convert to a map for JSON serialization
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'count': count,
      'minMs': minMs,
      'maxMs': maxMs,
      'avgMs': avgMs,
      'p50Ms': p50Ms,
      'p95Ms': p95Ms,
    };
  }
}
