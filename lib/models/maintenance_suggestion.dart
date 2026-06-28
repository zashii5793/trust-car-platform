import 'maintenance_record.dart';

/// Urgency level for a maintenance suggestion.
enum SuggestionUrgency {
  /// Service is overdue (remaining km <= 0).
  high,

  /// Service is due soon (1–1,000 km remaining).
  medium,

  /// Not yet urgent (> 1,000 km remaining).
  low,
}

/// A maintenance suggestion derived from the vehicle's schedule and mileage.
class MaintenanceSuggestion {
  final MaintenanceType type;
  final String title;

  /// Human-readable explanation that includes current mileage and next due km.
  final String reason;

  /// Kilometres remaining until the service is due; null if interval is
  /// month-based only (no km interval).
  final int? remainingKm;

  final SuggestionUrgency urgency;

  const MaintenanceSuggestion({
    required this.type,
    required this.title,
    required this.reason,
    required this.remainingKm,
    required this.urgency,
  });
}
