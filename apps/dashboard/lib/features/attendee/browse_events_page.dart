import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/session.dart';
import '../../auth/user_role.dart';
import '../../data/backend_scope.dart';
import '../../data/models.dart';
import '../../ui/shell/role_shell.dart';
import '../../ui/widgets/event_widgets.dart';
import '../../ui/widgets/page_body.dart';
import '../../ui/widgets/stream_view.dart';
import 'registration_badge.dart';

class BrowseEventsPage extends StatelessWidget {
  const BrowseEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    final uid = currentSession(context)?.uid ?? '';
    return RoleShell(
      role: UserRole.attendee,
      title: 'Browse events',
      child: PageBody(
        children: [
          const SectionHeader('Upcoming events', subtitle: 'Published events from every organization on Guyub.'),
          StreamView<List<GuyubEvent>>(
            create: backend.watchUpcomingEvents,
            isEmpty: (events) => events.isEmpty,
            empty: const EmptyNote(icon: Icons.event_busy_outlined, message: 'No upcoming events right now. Check back soon.'),
            builder: (context, events) => StreamView<List<Organization>>(
              create: backend.watchOrganizations,
              builder: (context, orgs) => StreamView<List<Ticket>>(
                streamKey: uid,
                create: () => backend.watchTickets(uid),
                builder: (context, tickets) {
                  final names = {for (final org in orgs) org.id: org.name};
                  final registered = {for (final ticket in tickets) ticket.event.id};
                  return Column(
                    children: [
                      for (final event in events)
                        _AttendeeEventTile(
                          event: event,
                          orgName: names[event.orgId] ?? event.orgId,
                          state: registrationStateOf(event, registered: registered.contains(event.id)),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendeeEventTile extends StatelessWidget {
  const _AttendeeEventTile({required this.event, required this.orgName, required this.state});

  final GuyubEvent event;
  final String orgName;
  final RegistrationState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/attendee/events/${event.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(orgName.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, letterSpacing: 0.8)),
                    const SizedBox(height: 2),
                    Text(event.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(formatEventDate(context, event.date), style: muted),
                    if (event.location.isNotEmpty) Text(event.location, style: muted),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              RegistrationBadge(state, spotsLeft: event.spotsLeft),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
