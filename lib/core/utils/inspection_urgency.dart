/// Visual urgency level for the vehicle inspection (車検) deadline.
///
/// Used by the home dashboard to color-code the "次の車検" chip so the
/// app's core promise — "見落とさない安心" — is visible at a glance.
enum InspectionUrgency {
  /// No inspection date registered.
  none,

  /// More than 30 days remaining.
  normal,

  /// 30 days or less remaining.
  warning,

  /// 7 days or less remaining (including today and overdue).
  critical,
}

/// Maps days-until-inspection to an [InspectionUrgency].
///
/// [days] is `Vehicle.daysUntilInspection`: null when no date is set,
/// negative when the deadline has passed.
InspectionUrgency inspectionUrgencyForDays(int? days) {
  if (days == null) return InspectionUrgency.none;
  if (days <= 7) return InspectionUrgency.critical;
  if (days <= 30) return InspectionUrgency.warning;
  return InspectionUrgency.normal;
}
