import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_scope.dart';
import '../../auth/auth_state.dart';
import '../../auth/user_role.dart';
import '../../data/backend_scope.dart';
import '../../data/models.dart';
import '../../ui/shell/role_home.dart';
import '../../ui/widgets/event_widgets.dart';
import '../../ui/widgets/page_body.dart';
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
      intro: 'Open an event to scan tickets at the entrance.',
      body: uid == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('Your events', subtitle: 'Your organizer chooses which events you work on.'),
                StreamView<List<GuyubEvent>>(
                  streamKey: uid,
                  create: () => backend.watchAssignedEvents(uid),
                  isEmpty: (events) => events.isEmpty,
                  empty: const EmptyNote(
                    icon: Icons.event_available_outlined,
                    message: 'No events assigned yet. Your organizer assigns you to events.',
                  ),
                  builder: (context, events) => Column(children: [
                    for (final event in events)
                      EventTile(event: event, onTap: () => context.go('/committee/events/${event.id}')),
                  ]),
                ),
              ],
            ),
      features: const [],
    );
  }
}
