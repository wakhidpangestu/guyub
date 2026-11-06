// Numbers behind the dashboard cards, computed from real attendance. Pure Dart.

import '../../data/models.dart';

/// Cumulative registrations and check-ins, one point per local day.
class AttendanceSeries {
  const AttendanceSeries(this.days, this.registered, this.checkedIn);

  final List<DateTime> days;
  final List<int> registered;
  final List<int> checkedIn;

  bool get hasData => registered.isNotEmpty && registered.last > 0;
}

DateTime _day(DateTime instant) {
  final local = instant.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Builds the series up to [now]. Shows at least [minDays] and at most
/// [maxDays] days; anything older counts in the first point. A registration
/// without a timestamp also counts from the first point.
AttendanceSeries attendanceSeries(
  List<Registration> registrations, {
  required DateTime now,
  int minDays = 7,
  int maxDays = 30,
}) {
  final today = _day(now);
  var start = DateTime(today.year, today.month, today.day - (minDays - 1));
  for (final registration in registrations) {
    final at = registration.registeredAt;
    if (at != null && _day(at).isBefore(start)) start = _day(at);
  }
  final earliest = DateTime(today.year, today.month, today.day - (maxDays - 1));
  if (start.isBefore(earliest)) start = earliest;

  final count = DateTime.utc(today.year, today.month, today.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays + 1;
  final days = [for (var i = 0; i < count; i++) DateTime(start.year, start.month, start.day + i)];

  int upTo(DateTime day, DateTime? Function(Registration) time, bool Function(Registration) counts, {required bool missingCounts}) {
    var total = 0;
    for (final registration in registrations) {
      if (!counts(registration)) continue;
      final at = time(registration);
      if (at == null ? missingCounts : !_day(at).isAfter(day) || day == today) total++;
    }
    return total;
  }

  return AttendanceSeries(
    days,
    [for (final day in days) upTo(day, (r) => r.registeredAt, (r) => true, missingCounts: true)],
    [for (final day in days) upTo(day, (r) => r.checkedInAt, (r) => r.isCheckedIn, missingCounts: false)],
  );
}

/// One line of the activity list.
class ActivityEntry {
  const ActivityEntry(this.name, this.action, this.at);

  final String name;
  final String action;
  final DateTime at;
}

/// Newest first: each registration and each check-in is one entry.
List<ActivityEntry> recentActivity(List<Registration> registrations, {int limit = 8}) {
  final entries = <ActivityEntry>[
    for (final r in registrations) ...[
      if (r.registeredAt != null) ActivityEntry(r.label, 'registered', r.registeredAt!),
      if (r.isCheckedIn && r.checkedInAt != null) ActivityEntry(r.label, 'checked in', r.checkedInAt!),
    ],
  ]..sort((a, b) => b.at.compareTo(a.at));
  return entries.take(limit).toList();
}

/// "now", "12m", "2h", "3d".
String timeAgo(DateTime at, DateTime now) {
  final elapsed = now.difference(at);
  if (elapsed.inMinutes < 1) return 'now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h';
  return '${elapsed.inDays}d';
}

/// "Today", "Tomorrow", "In 3 days", or "Ended", in the viewer's calendar.
String countdownLabel(DateTime date, DateTime now) {
  final a = _day(now);
  final b = _day(date);
  final days = DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  if (days < 0) return 'Ended';
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return 'In $days days';
}

/// The published event coming up first, or null. "Upcoming" starts at midnight
/// WIB, like the attendee list.
GuyubEvent? nextEvent(List<GuyubEvent> events, DateTime now) {
  final start = startOfTodayWib(now);
  final upcoming = events.where((e) => e.status == EventStatus.active && !e.date.isBefore(start)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return upcoming.firstOrNull;
}

/// Up to two initials for an avatar.
String initialsOf(String name) {
  String firstOf(String word) => String.fromCharCode(word.runes.first);
  // Skips words like "(demo)" that do not start with a letter or digit.
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => RegExp(r'^[\p{L}\p{N}]', unicode: true).hasMatch(part)).toList();
  if (parts.isEmpty) return '?';
  final first = firstOf(parts.first);
  return (parts.length == 1 ? first : '$first${firstOf(parts.last)}').toUpperCase();
}
