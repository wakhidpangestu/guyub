import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/user_role.dart';
import '../../data/backend_scope.dart';
import '../../data/models.dart';
import '../../ui/dashboard/attendance_series.dart';
import '../../ui/dashboard/dashboard_grid.dart';
import '../../ui/dashboard/grid_layout.dart';
import '../../ui/dashboard/tiles.dart';
import '../../ui/shell/role_home.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/event_widgets.dart';
import '../../ui/widgets/stream_view.dart';
import 'organizer_session.dart';

class OrganizerHomePage extends StatelessWidget {
  const OrganizerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final orgId = organizerOrgId(context);
    final backend = BackendScope.of(context);
    return RoleHome(
      role: UserRole.organizer,
      child: orgId == null
          ? const ErrorNote('This account has no organization yet. Ask an admin to add you to one.')
          : StreamView<List<GuyubEvent>>(
              streamKey: orgId,
              create: () => backend.watchEvents(orgId),
              loading: const DashboardSkeleton(),
              builder: (context, events) => _OrganizerBoard(orgId: orgId, events: events),
            ),
    );
  }
}

class _OrganizerBoard extends StatelessWidget {
  const _OrganizerBoard({required this.orgId, required this.events});

  final String orgId;
  final List<GuyubEvent> events;

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    final now = DateTime.now();
    final next = nextEvent(events, now);
    final start = startOfTodayWib(now);
    final upcoming = events.where((e) => e.status == EventStatus.active && !e.date.isBefore(start)).length;
    final drafts = events.where((e) => e.status == EventStatus.draft).length;
    final registrations = events.fold<int>(0, (sum, e) => sum + e.registeredCount);

    return LiveValue<List<Registration>>(
      streamKey: next?.id,
      create: () => next == null ? Stream.value(const []) : backend.watchAttendance(next.id, orgId: orgId),
      builder: (context, attendance) {
        final people = attendance.data ?? const <Registration>[];
        final failed = attendance.hasError;
        final checkedIn = people.where((r) => r.isCheckedIn).length;

        return DashboardGrid(
          layoutName: 'organizer',
          cards: [
            DashboardCard(
              id: 'hero',
              size: CardSize.wide,
              label: 'Welcome',
              builder: (context) => HeroTile(
                title: welcomeBack(context),
                intro: 'Plan events, assign your committee, and track attendance.',
                actionLabel: 'New event',
                actionIcon: Icons.add,
                onAction: () => context.go('/organizer/events/new'),
              ),
            ),
            DashboardCard(
              id: 'upcoming',
              size: CardSize.sm,
              label: 'Upcoming events',
              builder: (context) => StatTile(
                label: 'Upcoming events',
                value: '$upcoming',
                hint: drafts == 1 ? '1 draft waiting' : '$drafts drafts waiting',
                icon: Icons.event_outlined,
                tone: TileTone.cyan,
                onTap: () => context.go('/organizer/events'),
              ),
            ),
            DashboardCard(
              id: 'registrations',
              size: CardSize.sm,
              label: 'Registrations',
              builder: (context) => StatTile(
                label: 'Registrations',
                value: '$registrations',
                hint: 'Across all your events',
                icon: Icons.how_to_reg_outlined,
                tone: TileTone.pink,
              ),
            ),
            DashboardCard(
              id: 'chart',
              size: CardSize.lg,
              label: 'Registrations and check-ins',
              builder: (context) => _ChartCard(event: next, people: people, failed: failed),
            ),
            DashboardCard(
              id: 'next',
              size: CardSize.wide,
              label: 'Next event',
              builder: (context) => _NextEventCard(event: next, checkedIn: checkedIn),
            ),
            DashboardCard(
              id: 'activity',
              size: CardSize.wide,
              label: 'Recent activity',
              builder: (context) => _ActivityCard(people: people, failed: failed),
            ),
            DashboardCard(
              id: 'events',
              size: CardSize.lg,
              label: 'Your events',
              builder: (context) => _EventsCard(events: events),
            ),
            DashboardCard(
              id: 'rate',
              size: CardSize.sm,
              label: 'Check-in rate',
              builder: (context) => _RateCard(event: next, checkedIn: checkedIn, total: people.length),
            ),
            DashboardCard(
              id: 'committee',
              size: CardSize.sm,
              label: 'Committee',
              builder: (context) => LiveValue<List<Member>>(
                streamKey: orgId,
                create: () => backend.watchMembers(orgId, UserRole.committee),
                builder: (context, members) => StatTile(
                  label: 'Committee',
                  value: members.hasData ? '${members.data!.length}' : '–',
                  hint: 'Add people and assign them to events',
                  icon: Icons.groups_outlined,
                  tone: TileTone.violet,
                  onTap: () => context.go('/organizer/committee'),
                ),
              ),
            ),
            DashboardCard(
              id: 'certificates',
              size: CardSize.sm,
              label: 'Certificates, planned',
              builder: (context) => const PlannedTile(
                title: 'Certificates',
                description: 'Upload a template. Certificates are emailed on check-in.',
                icon: Icons.workspace_premium_outlined,
                milestone: 'M5',
              ),
            ),
            DashboardCard(
              id: 'sheets',
              size: CardSize.sm,
              label: 'Sheets export, planned',
              builder: (context) => const PlannedTile(
                title: 'Export to Google Sheets',
                description: 'Send registrations and attendance to a Sheet.',
                icon: Icons.table_chart_outlined,
                milestone: 'M6',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.event, required this.people, required this.failed});

  final GuyubEvent? event;
  final List<Registration> people;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GuyubTokens.of(context);
    final series = attendanceSeries(people, now: DateTime.now());
    final Widget body;
    if (failed) {
      body = const _TileMessage(icon: Icons.error_outline, message: 'Could not load attendance.');
    } else if (event == null) {
      body = const _TileMessage(icon: Icons.show_chart, message: 'Publish an event to follow its registrations here.');
    } else if (!series.hasData) {
      body = const _TileMessage(icon: Icons.show_chart, message: 'No registrations yet for this event.');
    } else {
      body = AttendanceChart(series: series);
    }
    return Tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registrations and check-ins', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
          if (event != null)
            Text(
              '${event!.title}: running total by day',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedForeground),
            ),
          SizedBox(height: tokens.sp(3)),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _NextEventCard extends StatelessWidget {
  const _NextEventCard({required this.event, required this.checkedIn});

  final GuyubEvent? event;
  final int checkedIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = this.event;
    return Tile(
      tone: TileTone.green,
      onTap: event == null ? null : () => context.go('/organizer/events/${event.id}'),
      child: Builder(
        builder: (context) {
          final colors = TileScope.of(context);
          if (event == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TileHeader('Next event', icon: Icons.upcoming_outlined),
                const Spacer(),
                Text('Nothing published yet', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(color: colors.ink)),
                Text('Publish a draft to open it to attendees.', maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: colors.mutedInk)),
              ],
            );
          }
          final spots = event.spotsLeft;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TileHeader(
                'Next event',
                trailing: TonePill(countdownLabel(event.date, DateTime.now()), background: colors.soft, foreground: colors.ink),
              ),
              const Spacer(),
              Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(color: colors.ink)),
              Text(formatEventDate(context, event.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: colors.mutedInk)),
              const SizedBox(height: 10),
              SeatsBar(checkedIn: checkedIn, registered: event.registeredCount, capacity: event.capacity),
              const SizedBox(height: 6),
              Text(
                '$checkedIn in · ${event.registeredCount} registered${spots == null ? '' : ' · $spots left'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.mutedInk),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({required this.event, required this.checkedIn, required this.total});

  final GuyubEvent? event;
  final int checkedIn;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = total == 0 ? 0.0 : checkedIn / total;
    return Tile(
      tone: TileTone.orchid,
      child: Builder(
        builder: (context) {
          final colors = TileScope.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TileHeader('Check-in rate', icon: Icons.qr_code_scanner),
              const SizedBox(height: 8),
              Expanded(child: Gauge(value: rate, label: '${(rate * 100).round()} percent checked in')),
              const SizedBox(height: 4),
              Text(
                event == null ? 'No event coming up' : '$checkedIn of $total checked in',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.mutedInk),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.people, required this.failed});

  final List<Registration> people;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GuyubTokens.of(context);
    final now = DateTime.now();
    final entries = recentActivity(people);
    return Tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent activity', style: theme.textTheme.titleMedium),
          SizedBox(height: tokens.sp(2)),
          Expanded(
            child: failed
                ? const _TileMessage(icon: Icons.error_outline, message: 'Could not load attendance.')
                : entries.isEmpty
                    ? const _TileMessage(icon: Icons.history, message: 'Registrations and check-ins for your next event appear here.')
                    : FitList(
                        rowHeight: 44,
                        count: entries.length,
                        builder: (context, i) {
                          final entry = entries[i];
                          return Row(
                            children: [
                              InitialsAvatar(entry.name, size: 32),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(children: [
                                    TextSpan(text: entry.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    TextSpan(text: ' ${entry.action}', style: TextStyle(color: tokens.mutedForeground)),
                                  ]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(timeAgo(entry.at, now), style: tokens.numeric(theme.textTheme.labelSmall).copyWith(color: tokens.mutedForeground)),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _EventsCard extends StatelessWidget {
  const _EventsCard({required this.events});

  final List<GuyubEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GuyubTokens.of(context);
    // Soonest first, with finished events last.
    final sorted = [...events]..sort((a, b) {
        final done = (a.status == EventStatus.completed ? 1 : 0) - (b.status == EventStatus.completed ? 1 : 0);
        return done != 0 ? done : a.date.compareTo(b.date);
      });
    return Tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your events', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium)),
              TextButton(onPressed: () => context.go('/organizer/events'), child: const Text('View all')),
            ],
          ),
          SizedBox(height: tokens.sp(1)),
          Expanded(
            child: sorted.isEmpty
                ? _TileMessage(
                    icon: Icons.event_outlined,
                    message: 'No events yet. Create your first draft.',
                    action: FilledButton(onPressed: () => context.go('/organizer/events/new'), child: const Text('Create event')),
                  )
                : FitList(
                    rowHeight: EventRow.height,
                    count: sorted.length,
                    builder: (context, i) => EventRow(
                      event: sorted[i],
                      onTap: () => context.go('/organizer/events/${sorted[i].id}'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TileMessage extends StatelessWidget {
  const _TileMessage({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GuyubTokens.of(context);
    return Center(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: tokens.mutedForeground),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedForeground)),
            if (action != null) ...[const SizedBox(height: 10), action!],
          ],
        ),
      ),
    );
  }
}
