import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/session.dart';
import '../../auth/user_role.dart';
import '../../data/backend.dart';
import '../../data/backend_scope.dart';
import '../../data/models.dart';
import '../../ui/shell/role_shell.dart';
import '../../ui/widgets/event_widgets.dart';
import '../../ui/widgets/feedback.dart';
import '../../ui/widgets/page_body.dart';
import '../../ui/widgets/stream_view.dart';
import 'privacy_consent_dialog.dart';
import 'registration_badge.dart';

/// Event details for an attendee, with register / show ticket / cancel.
class AttendeeEventPage extends StatelessWidget {
  const AttendeeEventPage({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    final uid = currentSession(context)?.uid ?? '';
    return RoleShell(
      role: UserRole.attendee,
      title: 'Event',
      child: PageBody(
        maxWidth: 820,
        children: [
          StreamView<GuyubEvent?>(
            streamKey: eventId,
            create: () => backend.watchEvent(eventId),
            // Unpublished events are not readable for people not registered.
            errorText: 'This event is not available. It may have been unpublished.',
            builder: (context, event) => event == null
                ? const EmptyNote(icon: Icons.search_off, message: 'This event is not available.')
                : StreamView<Organization?>(
                    streamKey: event.orgId,
                    create: () => backend.watchOrganization(event.orgId),
                    builder: (context, org) => StreamView<Registration?>(
                      streamKey: (eventId, uid),
                      create: () => backend.watchRegistration(eventId, uid),
                      builder: (context, registration) => _Details(
                        event: event,
                        orgName: org?.name ?? event.orgId,
                        registration: registration,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.event, required this.orgName, required this.registration});

  final GuyubEvent event;
  final String orgName;
  final Registration? registration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final state = registrationStateOf(event, registered: registration != null);
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: muted)),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(orgName.toUpperCase(), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(event.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        RegistrationBadge(state, spotsLeft: event.spotsLeft),
        const SizedBox(height: 8),
        line(Icons.schedule, formatEventDate(context, event.date)),
        if (event.location.isNotEmpty) line(Icons.place_outlined, event.location),
        if (event.capacity != null) line(Icons.people_outline, '${event.registeredCount} of ${event.capacity} registered'),
        if (event.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(event.description, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: 24),
        _Actions(event: event, orgName: orgName, state: state),
      ],
    );
  }
}

class _Actions extends StatefulWidget {
  const _Actions({required this.event, required this.orgName, required this.state});

  final GuyubEvent event;
  final String orgName;
  final RegistrationState state;

  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  bool _busy = false;

  Future<void> _register(Backend backend) async {
    final router = GoRouter.of(context);
    final agreed = await askPrivacyConsent(context, orgName: widget.orgName, eventTitle: widget.event.title);
    if (!agreed || !mounted) return;
    setState(() => _busy = true);
    final ok = await runAction(context, () => backend.register(widget.event.id), success: 'You are registered. Here is your ticket.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) router.go('/attendee/tickets/${widget.event.id}');
  }

  Future<void> _cancel(Backend backend) async {
    final ok = await confirm(
      context,
      title: 'Cancel your registration?',
      message: 'Your ticket stops working and your spot goes to someone else. You can register again while registration is open.',
      confirmLabel: 'Cancel registration',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    await runAction(context, () => backend.cancelRegistration(widget.event.id), success: 'Registration cancelled.');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    final note = Theme.of(context).textTheme.bodyMedium;
    return switch (widget.state) {
      RegistrationState.registered => Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => context.go('/attendee/tickets/${widget.event.id}'),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Show my ticket'),
            ),
            if (widget.event.status != EventStatus.completed)
              TextButton(onPressed: _busy ? null : () => _cancel(backend), child: const Text('Cancel registration')),
          ],
        ),
      RegistrationState.open => FilledButton.icon(
          onPressed: _busy ? null : () => _register(backend),
          icon: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.how_to_reg),
          label: const Text('Register'),
        ),
      RegistrationState.full => Text('This event is full.', style: note),
      RegistrationState.closed => Text('Registration is closed for this event.', style: note),
    };
  }
}
