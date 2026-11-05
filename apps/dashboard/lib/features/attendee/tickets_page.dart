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

class TicketsPage extends StatelessWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    final uid = currentSession(context)?.uid ?? '';
    return RoleShell(
      role: UserRole.attendee,
      title: 'My tickets',
      child: PageBody(
        children: [
          const SectionHeader('My tickets', subtitle: 'Open a ticket at the entrance to show your QR code.'),
          StreamView<List<Ticket>>(
            streamKey: uid,
            create: () => backend.watchTickets(uid),
            isEmpty: (tickets) => tickets.isEmpty,
            empty: EmptyNote(
              icon: Icons.confirmation_number_outlined,
              message: 'No tickets yet.',
              action: OutlinedButton(onPressed: () => context.go('/attendee/events'), child: const Text('Browse events')),
            ),
            builder: (context, tickets) {
              final today = DateUtils.dateOnly(DateTime.now());
              final upcoming = tickets.where((t) => !t.event.date.isBefore(today)).toList();
              final past = tickets.where((t) => t.event.date.isBefore(today)).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final ticket in upcoming) _TicketTile(ticket),
                  if (past.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text('Past', style: Theme.of(context).textTheme.titleSmall),
                    ),
                    for (final ticket in past.reversed) _TicketTile(ticket),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile(this.ticket);

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = ticket.event;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(ticket.registration.isCheckedIn ? Icons.verified : Icons.qr_code_2, color: theme.colorScheme.primary, size: 32),
        title: Text(event.title),
        subtitle: Text([
          formatEventDate(context, event.date),
          if (event.location.isNotEmpty) event.location,
          if (ticket.registration.isCheckedIn) 'Checked in',
        ].join('\n')),
        isThreeLine: event.location.isNotEmpty || ticket.registration.isCheckedIn,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/attendee/tickets/${event.id}'),
      ),
    );
  }
}
