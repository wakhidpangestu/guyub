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

class AttendeeHomePage extends StatelessWidget {
  const AttendeeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AuthScope.of(context).state;
    final uid = session is SignedIn ? session.uid : null;
    final backend = BackendScope.of(context);

    return RoleHome(
      role: UserRole.attendee,
      child: uid == null
          ? const SizedBox.shrink()
          : StreamView<List<Ticket>>(
              streamKey: uid,
              create: () => backend.watchTickets(uid),
              loading: const DashboardSkeleton(),
              builder: (context, tickets) => StreamView<List<GuyubEvent>>(
                create: backend.watchUpcomingEvents,
                loading: const DashboardSkeleton(),
                builder: (context, upcoming) => _AttendeeBoard(tickets: tickets, upcoming: upcoming),
              ),
            ),
    );
  }
}

class _AttendeeBoard extends StatelessWidget {
  const _AttendeeBoard({required this.tickets, required this.upcoming});

  final List<Ticket> tickets;
  final List<GuyubEvent> upcoming;

  @override
  Widget build(BuildContext context) {
    final start = startOfTodayWib(DateTime.now());
    final active = tickets.where((t) => t.event.status == EventStatus.active && !t.event.date.isBefore(start)).toList()
      ..sort((a, b) => a.event.date.compareTo(b.event.date));

    return DashboardGrid(
      layoutName: 'attendee',
      cards: [
        DashboardCard(
          id: 'hero',
          size: CardSize.wide,
          label: 'Welcome',
          builder: (context) => HeroTile(
            title: welcomeBack(context),
            intro: 'Find events, keep your tickets, and collect your certificates.',
            actionLabel: 'Find events',
            actionIcon: Icons.explore_outlined,
            onAction: () => context.go('/attendee/events'),
          ),
        ),
        DashboardCard(
          id: 'tickets',
          size: CardSize.sm,
          label: 'Your tickets',
          builder: (context) => StatTile(
            label: 'Your tickets',
            value: '${active.length}',
            hint: 'For upcoming events',
            icon: Icons.confirmation_number_outlined,
            tone: TileTone.cyan,
            onTap: () => context.go('/attendee/tickets'),
          ),
        ),
        DashboardCard(
          id: 'upcoming',
          size: CardSize.sm,
          label: 'Events to join',
          builder: (context) => StatTile(
            label: 'Events to join',
            value: '${upcoming.where((e) => e.acceptsRegistrations).length}',
            hint: 'Open for registration now',
            icon: Icons.event_outlined,
            tone: TileTone.pink,
            onTap: () => context.go('/attendee/events'),
          ),
        ),
        DashboardCard(
          id: 'events',
          size: CardSize.lg,
          label: 'Upcoming events',
          builder: (context) => _UpcomingCard(events: upcoming),
        ),
        DashboardCard(
          id: 'ticket',
          size: CardSize.wide,
          label: 'Next ticket',
          builder: (context) => _NextTicketCard(ticket: active.firstOrNull),
        ),
        DashboardCard(
          id: 'certificates',
          size: CardSize.sm,
          label: 'Certificates, planned',
          builder: (context) => const PlannedTile(
            title: 'Certificates',
            description: 'Arrive here and by email after check-in.',
            icon: Icons.workspace_premium_outlined,
            milestone: 'M5',
          ),
        ),
        DashboardCard(
          id: 'twibbon',
          size: CardSize.sm,
          label: 'Twibbon, planned',
          builder: (context) => const PlannedTile(
            title: 'Twibbon',
            description: 'Frame your photo with the event overlay.',
            icon: Icons.photo_filter_outlined,
            milestone: 'M6',
          ),
        ),
      ],
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.events});

  final List<GuyubEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GuyubTokens.of(context);
    return Tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Upcoming events', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium)),
              TextButton(onPressed: () => context.go('/attendee/events'), child: const Text('View all')),
            ],
          ),
          SizedBox(height: tokens.sp(1)),
          Expanded(
            child: events.isEmpty
                ? const Center(child: EmptyNote(icon: Icons.event_busy_outlined, message: 'No events coming up right now. Check back soon.'))
                : FitList(
                    rowHeight: EventRow.height,
                    count: events.length,
                    builder: (context, i) => EventRow(
                      event: events[i],
                      showStatus: false,
                      onTap: () => context.go('/attendee/events/${events[i].id}'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NextTicketCard extends StatelessWidget {
  const _NextTicketCard({required this.ticket});

  final Ticket? ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ticket = this.ticket;
    return Tile(
      tone: TileTone.green,
      onTap: ticket == null ? null : () => context.go('/attendee/tickets/${ticket.event.id}'),
      child: Builder(
        builder: (context) {
          final colors = TileScope.of(context);
          if (ticket == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TileHeader('Next ticket', icon: Icons.qr_code_2),
                const Spacer(),
                Text('Nothing booked yet', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(color: colors.ink)),
                Text('Register for an event to get your QR ticket.', maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: colors.mutedInk)),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TileHeader(
                'Next ticket',
                trailing: TonePill(countdownLabel(ticket.event.date, DateTime.now()), background: colors.soft, foreground: colors.ink),
              ),
              const Spacer(),
              Text(ticket.event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(color: colors.ink)),
              Text(formatEventDate(context, ticket.event.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: colors.mutedInk)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.qr_code_2, color: colors.ink),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ticket.registration.isCheckedIn ? 'You are checked in' : 'Tap to show your QR code',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(color: colors.ink),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
