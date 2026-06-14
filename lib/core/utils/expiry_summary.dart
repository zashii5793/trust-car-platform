import '../../models/vehicle.dart';
import 'inspection_urgency.dart';

/// Kind of upcoming deadline tracked for a vehicle.
enum ExpiryKind {
  inspection, // 車検
  compulsoryInsurance, // 自賠責
  voluntaryInsurance, // 任意保険
}

extension ExpiryKindLabel on ExpiryKind {
  String get label => switch (this) {
        ExpiryKind.inspection => '車検',
        ExpiryKind.compulsoryInsurance => '自賠責',
        ExpiryKind.voluntaryInsurance => '任意保険',
      };
}

/// A single dated deadline for a vehicle, with days-remaining and urgency.
class ExpiryItem {
  final ExpiryKind kind;
  final DateTime date;
  final int days; // days until date; negative = overdue

  const ExpiryItem({
    required this.kind,
    required this.date,
    required this.days,
  });

  String get label => kind.label;

  /// Reuses the inspection urgency thresholds (≤7 critical, ≤30 warning).
  InspectionUrgency get urgency => inspectionUrgencyForDays(days);

  bool get isOverdue => days < 0;
}

/// All known expiry items for [vehicle], sorted soonest-first (overdue first).
List<ExpiryItem> vehicleExpiryItems(Vehicle vehicle, {DateTime? now}) {
  final base = now ?? DateTime.now();
  final items = <ExpiryItem>[];

  void add(ExpiryKind kind, DateTime? date) {
    if (date == null) return;
    items.add(ExpiryItem(
      kind: kind,
      date: date,
      days: date.difference(base).inDays,
    ));
  }

  add(ExpiryKind.inspection, vehicle.inspectionExpiryDate);
  add(ExpiryKind.compulsoryInsurance, vehicle.insuranceExpiryDate);
  add(ExpiryKind.voluntaryInsurance, vehicle.voluntaryInsurance?.expiryDate);

  items.sort((a, b) => a.days.compareTo(b.days));
  return items;
}

/// The single most urgent (soonest / most overdue) deadline, or null if none
/// of 車検 / 自賠責 / 任意保険 has a date set.
ExpiryItem? nextVehicleExpiry(Vehicle vehicle, {DateTime? now}) {
  final items = vehicleExpiryItems(vehicle, now: now);
  return items.isEmpty ? null : items.first;
}

/// Aggregate view of voluntary-insurance status across a fleet of vehicles.
class FleetInsuranceSummary {
  final int total; // vehicles considered
  final int expired; // voluntary insurance already past expiry
  final int expiringSoon; // within 30 days (and not yet expired)
  final int missing; // no voluntary insurance expiry registered

  const FleetInsuranceSummary({
    required this.total,
    required this.expired,
    required this.expiringSoon,
    required this.missing,
  });

  /// Vehicles needing attention (expired or expiring soon).
  int get needsAttention => expired + expiringSoon;
}

/// Summarizes voluntary-insurance expiry across [vehicles].
FleetInsuranceSummary summarizeFleetInsurance(
  List<Vehicle> vehicles, {
  DateTime? now,
}) {
  final base = now ?? DateTime.now();
  var expired = 0;
  var expiringSoon = 0;
  var missing = 0;

  for (final v in vehicles) {
    final date = v.voluntaryInsurance?.expiryDate;
    if (date == null) {
      missing++;
      continue;
    }
    final days = date.difference(base).inDays;
    if (days < 0) {
      expired++;
    } else if (days <= 30) {
      expiringSoon++;
    }
  }

  return FleetInsuranceSummary(
    total: vehicles.length,
    expired: expired,
    expiringSoon: expiringSoon,
    missing: missing,
  );
}
