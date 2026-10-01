/// Odometer continuity checks.
///
/// The records in this app are only worth something if they read as a
/// plausible sequence. A history where the odometer walks backwards is not
/// trusted at trade-in time, and it is the first thing a buyer notices.
///
/// Before this file the checks lived inline in three screens and disagreed
/// with each other: the vehicle screen asked for confirmation on a rollback,
/// the maintenance form rejected values above the vehicle's current mileage,
/// and the fuel form checked nothing at all. Milestone detection quietly
/// skipped rollbacks without telling anyone.
///
/// Kept as pure functions so both the services and the forms can use them.
library;

/// What is wrong with an odometer value, if anything.
enum OdometerIssue {
  none,

  /// Below the previous reading. Happens for real (cluster swap, engine
  /// change), so this asks rather than refuses.
  wentBackwards,

  /// Plausible on its own but too large a jump for the time that passed.
  implausibleJump,

  /// Not a usable number at all — negative, or far past any real vehicle.
  outOfRange;

  /// Whether the value should be refused outright.
  ///
  /// Only [outOfRange] blocks. A rollback or a big jump can be genuine, and
  /// refusing them would stop people recording what actually happened.
  bool get isBlocking => this == OdometerIssue.outOfRange;
}

/// The result of checking one odometer reading.
class OdometerCheckResult {
  const OdometerCheckResult(this.severity, [this.message]);

  final OdometerIssue severity;

  /// Text to show the person. Null when there is nothing to say.
  final String? message;

  bool get hasProblem => severity != OdometerIssue.none;
}

/// Checks a single odometer reading against what came before it.
abstract final class OdometerCheck {
  /// Past any vehicle that is still on the road. A larger number is a typo.
  static const int maxPlausibleKm = 2000000;

  /// More than this in a day is worth a second look. Long-distance drivers
  /// and transporters exist, so it asks instead of refusing.
  static const int maxKmPerDay = 2000;

  /// Same-day entries (a refuel and a service on one day) still need a
  /// ceiling, or any pair of records on one date would pass unchecked.
  static const int maxKmSameDay = 2000;

  /// Checks [value] against [previous].
  ///
  /// [elapsed] is the time between the two readings. When it is null the
  /// jump check is skipped — without it there is no way to say whether an
  /// increase is too fast.
  static OdometerCheckResult against({
    required int value,
    required int? previous,
    Duration? elapsed,
  }) {
    // Range first: a typo like 120000 → 1200000 should be called a typo,
    // not "went backwards", even when it also happens to be lower.
    if (value < 0) {
      return const OdometerCheckResult(
        OdometerIssue.outOfRange,
        '走行距離に負の数は入れられません',
      );
    }
    if (value > maxPlausibleKm) {
      return const OdometerCheckResult(
        OdometerIssue.outOfRange,
        '走行距離が大きすぎます。桁をお確かめください',
      );
    }

    if (previous == null) return const OdometerCheckResult(OdometerIssue.none);

    if (value < previous) {
      return OdometerCheckResult(
        OdometerIssue.wentBackwards,
        '前回の記録（${_km(previous)}）より小さい値です。'
        'メーター交換などでなければ、入力をお確かめください',
      );
    }

    if (elapsed == null) return const OdometerCheckResult(OdometerIssue.none);

    final gained = value - previous;
    final days = elapsed.inDays;
    final allowed = days <= 0 ? maxKmSameDay : days * maxKmPerDay;
    if (gained > allowed) {
      return OdometerCheckResult(
        OdometerIssue.implausibleJump,
        '前回から ${_km(gained)} 増えています。'
        '入力をお確かめください',
      );
    }

    return const OdometerCheckResult(OdometerIssue.none);
  }

  static String _km(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf}km';
  }
}
