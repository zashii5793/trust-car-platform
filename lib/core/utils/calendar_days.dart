/// Day counts between calendar dates ("あと N 日").
///
/// `target.difference(DateTime.now()).inDays` truncates the fraction of a
/// day, so a deadline stored at 00:00 read at noon came out one day short
/// (11/20 seen on 10/8 showed 42, not 43 — usability test 2026-10-09). It
/// also shifted with the time of day the screen was opened.
///
/// Counting whole calendar days in UTC removes both the time of day and
/// daylight-saving jumps from the result.
library;

/// Whole calendar days from [now] (default: today) to [target].
///
/// 0 on the day itself, negative once the day has passed. Only the date
/// parts are used, as read in each value's own time zone.
int calendarDaysUntil(DateTime target, {DateTime? now}) {
  final base = now ?? DateTime.now();
  final from = DateTime.utc(base.year, base.month, base.day);
  final to = DateTime.utc(target.year, target.month, target.day);
  return to.difference(from).inDays;
}
