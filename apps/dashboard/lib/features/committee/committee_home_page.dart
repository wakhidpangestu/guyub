import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_scope.dart';
import '../../auth/auth_state.dart';
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

class CommitteeHomePage extends StatelessWidget {
  const CommitteeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AuthScope.of(context).state;
    final uid = session is SignedIn ? session.uid : null;
    final backend = BackendScope.of(context);

    return RoleHome(
      role: UserRole.committee,
      child: uid == null
          ? const SizedBox.shrink()
          : StreamView<List<GuyubEvent>>(
              streamKey: uid,
              create: () => backend.watchAssignedEvents(uid),
              loading: const DashboardSkeleton(),
              builder: (context, events) => _CommitteeBoard(events: events),
            ),
    );
  }
}

class _CommitteeBoard extends StatelessWidget {
  const _CommitteeBoard({required this.events});

  final List<GuyubEvent> events;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final next = nextEvent(events, now);
    final today = events.where((e) => countdownLabel(e.date, now) == 'Today').length;

    return DashboardGrid(
      layoutName: 'committee',
      cards: [
        DashboardCard(
          id: 'hero',
          size: CardSize.wide,
          label: 'Welcome',
          builder: (context) => HeroTile(
            title: welcomeBack(context),
            intro: 'Open an event to scan tickets at the entrance.',
            actionLabel: next == null ? null : 'Scan tickets',
            actionIcon: Icons.qr_code_scanner,
            onAction: next == null ? null : () => context.go('/committee/events/${next.id}'),
          ),
        ),
        DashboardCard(
          id: 'assigned',
          size: CardSize.sm,
          label: 'Assigned events',
          builder: (context) => StatTile(
            label: 'Assigned',
            value: '${events.length}',
            hint: 'Your organizer chooses your events',
            icon: Icons.event_available_outlined,
            tone: TileTone.cyan,
          ),
        ),
        DashboardCard(
          id: 'today',
          size: CardSize.sm,
          label: 'Events today',
          builder: (context) => StatTile(
            label: 'Today',
            value: '$today',
            hint: today == 1 ? 'Event to work on' : 'Events to work on',
            icon: Icons.today_outlined,
            tone: TileTone.pink,
          ),
        ),
        DashboardCard(
          id: 'events',
          size: CardSize.lg,
          label: 'Your events',
          builder: (context) => _EventsCard(events: events),
        ),
        DashboardCard(
          id: 'door',
          size: CardSize.wide,
          label: 'At the door',
          builder: (context) => _DoorCard(event: next),
        ),
        DashboardCard(
          id: 'tips',
          size: CardSize.wide,
          label: 'Scanning tips',
          builder: (context) => const _TipsCard(),
        ),
      ],
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
    return Tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your events', style: theme.textTheme.titleMedium),
          SizedBox(height: tokens.sp(2)),
          Expanded(
            child: events.isEmpty
                ? const Center(
                    child: EmptyNote(
                      icon: Icons.event_available_outlined,
                      message: 'No events assigned yet. Your organizer assigns you to events.',
                    ),
                  )
                : FitList(
                    rowHeight: EventRow.height,
                    count: events.length,
                    builder: (context, i) => EventRow(
                      event: events[i],
                      onTap: () => context.go('/committee/events/${events[i].id}'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Live numbers for the next event. Committee members can read the attendance
/// of events they are assigned to.
class _DoorCard extends StatelessWidget {
  const _DoorCard({required this.event});

  final GuyubEvent? event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backend = BackendScope.of(context);
    final event = this.event;
    return Tile(
      tone: TileTone.green,
      onTap: event == null ? null : () => context.go('/committee/events/${event.id}'),
      child: Builder(
        builder: (context) {
          final colors = TileScope.of(context);
          if (event == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TileHeader('At the door', icon: Icons.door_front_door_outlined),
                const Spacer(),
                Text('No upcoming event', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(color: colors.ink)),
                Text('Assigned events show their check-ins here.', maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: colors.mutedInk)),
              ],
            );
          }
          return LiveValue<List<Registration>>(
            streamKey: event.id,
            create: () => backend.watchAttendance(event.id),
            builder: (context, snapshot) {
              final people = snapshot.data ?? const <Registration>[];
              final checkedIn = people.where((r) => r.isCheckedIn).length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TileHeader(
                    'At the door',
                    trailing: TonePill(countdownLabel(event.date, DateTime.now()), background: colors.soft, foreground: colors.ink),
                  ),
                  const Spacer(),
                  Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(color: colors.ink)),
                  Text(formatEventDate(context, event.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: colors.mutedInk)),
                  const SizedBox(height: 10),
                  SeatsBar(checkedIn: checkedIn, registered: people.length),
                  const SizedBox(height: 6),
                  Text(
                    snapshot.hasError ? 'Could not load check-ins' : '$checkedIn of ${people.length} checked in',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.mutedInk),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tile(
      tone: TileTone.violet,
      child: Builder(
        builder: (context) {
          final colors = TileScope.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TileHeader('Scanning tips', icon: Icons.tips_and_updates_outlined),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  'Codes change every 30 seconds, so a screenshot stops working. If a code has expired, ask the attendee to reopen their ticket.',
                  overflow: TextOverflow.fade,
                  style: theme.textTheme.bodyMedium?.copyWith(color: colors.ink),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
