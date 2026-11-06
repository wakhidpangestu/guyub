import 'package:flutter_test/flutter_test.dart';
import 'package:guyub_dashboard/data/models.dart';
import 'package:guyub_dashboard/ui/dashboard/attendance_series.dart';

void main() {
  final now = DateTime(2026, 11, 6, 15);

  Registration reg(String name, {DateTime? at, DateTime? inAt}) => Registration(
        eventId: 'e',
        userId: name,
        attendeeName: name,
        registeredAt: at,
        isCheckedIn: inAt != null,
        checkedInAt: inAt,
      );

  group('attendanceSeries', () {
    test('counts up by day and ends at the current totals', () {
      final series = attendanceSeries([
        reg('a', at: DateTime(2026, 11, 3, 9)),
        reg('b', at: DateTime(2026, 11, 3, 18)),
        reg('c', at: DateTime(2026, 11, 5, 8), inAt: DateTime(2026, 11, 6, 10)),
      ], now: now);

      expect(series.days, hasLength(7));
      expect(series.days.last, DateTime(2026, 11, 6));
      expect(series.registered, [0, 0, 0, 2, 2, 3, 3]);
      expect(series.checkedIn, [0, 0, 0, 0, 0, 0, 1]);
      expect(series.hasData, isTrue);
    });

    test('with nobody registered there is nothing to chart', () {
      expect(attendanceSeries([], now: now).hasData, isFalse);
    });

    test('older registrations extend the range, up to the limit', () {
      final month = attendanceSeries([reg('a', at: DateTime(2026, 10, 20))], now: now);
      expect(month.days.first, DateTime(2026, 10, 20));

      final old = attendanceSeries([reg('a', at: DateTime(2026, 1, 1))], now: now);
      expect(old.days, hasLength(30));
      expect(old.registered.first, 1, reason: 'counted from the first point');
    });

    test('a missing timestamp counts from the start, a future one counts today', () {
      final series = attendanceSeries([reg('a'), reg('b', at: now.add(const Duration(days: 2)))], now: now);
      expect(series.registered.first, 1);
      expect(series.registered.last, 2);
    });

    test('crossing daylight saving keeps one point per calendar day', () {
      final series = attendanceSeries([], now: DateTime(2026, 3, 31), minDays: 30);
      expect(series.days, hasLength(30));
      expect(series.days.toSet(), hasLength(30));
    });
  });

  test('recentActivity lists registrations and check-ins, newest first', () {
    final entries = recentActivity([
      reg('a', at: DateTime(2026, 11, 1), inAt: DateTime(2026, 11, 6)),
      reg('b', at: DateTime(2026, 11, 5)),
      reg('no-time'),
    ]);
    expect(entries.map((e) => '${e.name} ${e.action}'), ['a checked in', 'b registered', 'a registered']);
  });

  test('timeAgo', () {
    expect(timeAgo(now, now), 'now');
    expect(timeAgo(now.subtract(const Duration(minutes: 12)), now), '12m');
    expect(timeAgo(now.subtract(const Duration(hours: 2)), now), '2h');
    expect(timeAgo(now.subtract(const Duration(days: 3)), now), '3d');
  });

  test('countdownLabel uses calendar days', () {
    expect(countdownLabel(DateTime(2026, 11, 6, 23), now), 'Today');
    expect(countdownLabel(DateTime(2026, 11, 7, 1), now), 'Tomorrow');
    expect(countdownLabel(DateTime(2026, 11, 10), now), 'In 4 days');
    expect(countdownLabel(DateTime(2026, 11, 5), now), 'Ended');
  });

  test('nextEvent picks the soonest published event', () {
    GuyubEvent event(String id, DateTime date, EventStatus status) =>
        GuyubEvent(id: id, orgId: 'o', title: id, date: date, status: status, registrationOpen: true);
    final picked = nextEvent([
      event('past', DateTime(2026, 11, 1), EventStatus.active),
      event('draft', DateTime(2026, 11, 7), EventStatus.draft),
      event('later', DateTime(2026, 12, 1), EventStatus.active),
      event('soon', DateTime(2026, 11, 8), EventStatus.active),
    ], now);
    expect(picked!.id, 'soon');
    expect(nextEvent([], now), isNull);
  });

  test('initialsOf', () {
    expect(initialsOf('Rina'), 'R');
    expect(initialsOf('Ahmad Dandi Subhani'), 'AS');
    expect(initialsOf('  '), '?');
    expect(initialsOf('HIMATIF (demo)'), 'H');
    expect(initialsOf('Ñandú Órtiz'), 'ÑÓ');
  });
}
