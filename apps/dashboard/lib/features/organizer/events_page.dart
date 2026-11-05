import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/user_role.dart';
import '../../data/backend_scope.dart';
import '../../data/models.dart';
import '../../ui/shell/role_shell.dart';
import '../../ui/widgets/event_widgets.dart';
import '../../ui/widgets/page_body.dart';
import '../../ui/widgets/stream_view.dart';
import 'organizer_session.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    final orgId = organizerOrgId(context);
    return RoleShell(
      role: UserRole.organizer,
      title: 'Events',
      child: PageBody(
        children: [
          SectionHeader(
            'Events',
            subtitle: 'New events start as drafts. Publish an event to show it to attendees.',
            action: FilledButton.icon(
              onPressed: () => context.go('/organizer/events/new'),
              icon: const Icon(Icons.add),
              label: const Text('New event'),
            ),
          ),
          if (orgId == null)
            const ErrorNote('Your account has no organization. Ask a Guyub admin to fix your organizer access.')
          else
            StreamView<List<GuyubEvent>>(
              streamKey: orgId,
              create: () => backend.watchEvents(orgId),
              isEmpty: (events) => events.isEmpty,
              empty: EmptyNote(
                icon: Icons.event_outlined,
                message: 'No events yet.',
                action: OutlinedButton(
                  onPressed: () => context.go('/organizer/events/new'),
                  child: const Text('Create your first event'),
                ),
              ),
              builder: (context, events) => Column(
                children: [
                  for (final event in events)
                    EventTile(event: event, onTap: () => context.go('/organizer/events/${event.id}')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
