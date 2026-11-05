import 'package:flutter/material.dart';

import '../../auth/session.dart';
import '../../auth/user_role.dart';
import '../../data/backend_scope.dart';
import '../../data/models.dart';
import '../../ui/shell/role_shell.dart';
import '../../ui/widgets/event_widgets.dart';
import '../../ui/widgets/page_body.dart';
import '../../ui/widgets/stream_view.dart';
import 'rotating_ticket_qr.dart';

/// One ticket: the rotating QR the committee scans at the door.
class TicketPage extends StatelessWidget {
  const TicketPage({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    final session = currentSession(context);
    final uid = session?.uid ?? '';
    final theme = Theme.of(context);

    return RoleShell(
      role: UserRole.attendee,
      title: 'Ticket',
      child: PageBody(
        maxWidth: 520,
        children: [
          StreamView<Registration?>(
            streamKey: (eventId, uid),
            create: () => backend.watchRegistration(eventId, uid),
            builder: (context, registration) {
              if (registration == null) {
                return const EmptyNote(icon: Icons.confirmation_number_outlined, message: 'You are not registered for this event.');
              }
              return StreamView<GuyubEvent?>(
                streamKey: eventId,
                create: () => backend.watchEvent(eventId),
                builder: (context, event) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        if (event != null) ...[
                          Text(event.title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text(formatEventDate(context, event.date), style: theme.textTheme.bodyMedium),
                          if (event.location.isNotEmpty) Text(event.location, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 20),
                        ],
                        if (registration.isCheckedIn) ...[
                          Icon(Icons.verified, size: 72, color: theme.colorScheme.primary),
                          const SizedBox(height: 8),
                          Text('Checked in', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          const Text('Enjoy the event.', textAlign: TextAlign.center),
                        ] else if (event?.status == EventStatus.completed) ...[
                          Icon(Icons.event_busy, size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 8),
                          const Text('This event is over.'),
                        ] else ...[
                          StreamView<String?>(
                            streamKey: registration.attendanceId,
                            create: () => backend.watchTicketKey(eventId, uid),
                            // Tickets issued before the key moved to its own document.
                            errorText: 'This ticket cannot show a code. Cancel the registration and register again.',
                            builder: (context, key) => key == null
                                ? const ErrorNote('This ticket cannot show a code. Cancel the registration and register again.')
                                : RotatingTicketQr(qrToken: key, attendanceId: registration.attendanceId),
                          ),
                          const SizedBox(height: 16),
                          Text(session?.name ?? '', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            'Show this code at the entrance. It changes every 30 seconds, so screenshots stop working.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
