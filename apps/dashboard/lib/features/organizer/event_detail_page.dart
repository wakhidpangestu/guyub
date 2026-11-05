import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/user_role.dart';
import '../../data/backend.dart';
import '../../data/backend_scope.dart';
import '../../data/models.dart';
import '../../ui/shell/role_shell.dart';
import '../../ui/widgets/event_widgets.dart';
import '../../ui/widgets/feedback.dart';
import '../../ui/widgets/page_body.dart';
import '../../ui/widgets/stream_view.dart';

class EventDetailPage extends StatelessWidget {
  const EventDetailPage({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    return RoleShell(
      role: UserRole.organizer,
      title: 'Event',
      child: PageBody(
        maxWidth: 900,
        children: [
          StreamView<GuyubEvent?>(
            streamKey: eventId,
            create: () => backend.watchEvent(eventId),
            builder: (context, event) => event == null
                ? const EmptyNote(icon: Icons.search_off, message: 'This event no longer exists.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Summary(event),
                      const SizedBox(height: 16),
                      _StatusActions(event),
                      _Committee(event),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.event);

  final GuyubEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [Icon(icon, size: 18, color: theme.colorScheme.primary), const SizedBox(width: 8), Expanded(child: Text(text, style: muted))]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(event.title, style: theme.textTheme.headlineSmall),
            StatusChip(event.status),
            if (event.registrationOpen)
              Chip(
                avatar: Icon(Icons.how_to_reg, size: 16, color: theme.colorScheme.primary),
                label: const Text('Registration open'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 8),
        line(Icons.schedule, formatEventDate(context, event.date)),
        if (event.location.isNotEmpty) line(Icons.place_outlined, event.location),
        line(Icons.people_outline, event.capacity == null ? 'No capacity limit' : 'Capacity: ${event.capacity}'),
        line(Icons.how_to_reg, '${event.registeredCount} registered${event.isFull ? ' (full)' : ''}'),
        if (event.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(event.description, style: theme.textTheme.bodyLarge),
        ],
      ],
    );
  }
}

/// Lifecycle actions. Allowed moves follow EventStatus.canBecome, the same
/// rule the Firestore rules enforce.
class _StatusActions extends StatelessWidget {
  const _StatusActions(this.event);

  final GuyubEvent event;

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    final edit = OutlinedButton.icon(
      onPressed: () => context.go('/organizer/events/${event.id}/edit'),
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Edit details'),
    );

    final buttons = switch (event.status) {
      EventStatus.draft => [
          FilledButton.icon(
            onPressed: () => runAction(
              context,
              () => backend.setEventStatus(event.id, EventStatus.active, registrationOpen: false),
              success: 'Published. Attendees can now see this event.',
            ),
            icon: const Icon(Icons.public),
            label: const Text('Publish'),
          ),
          edit,
          // A draft that was published before may still have tickets.
          if (event.registeredCount == 0)
            TextButton.icon(
              onPressed: () => _delete(context, backend),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete draft'),
            ),
        ],
      EventStatus.active => [
          FilledButton.icon(
            onPressed: () => runAction(
              context,
              () => backend.setEventStatus(event.id, EventStatus.active, registrationOpen: !event.registrationOpen),
              success: event.registrationOpen ? 'Registration closed.' : 'Registration opened.',
            ),
            icon: Icon(event.registrationOpen ? Icons.lock_outline : Icons.how_to_reg),
            label: Text(event.registrationOpen ? 'Close registration' : 'Open registration'),
          ),
          edit,
          OutlinedButton(
            onPressed: () => _move(
              context,
              backend,
              EventStatus.draft,
              title: 'Move back to draft?',
              message: event.registeredCount == 0
                  ? 'Attendees will no longer see this event, and registration closes.'
                  : '${event.registeredCount} ${event.registeredCount == 1 ? 'person holds' : 'people hold'} a ticket. '
                      'They keep it, but nobody can check in until you publish the event again. '
                      'Registration closes.',
              confirmLabel: 'Move to draft',
              success: 'Moved back to draft.',
            ),
            child: const Text('Move back to draft'),
          ),
          OutlinedButton(
            onPressed: () => _move(
              context,
              backend,
              EventStatus.completed,
              title: 'Mark as completed?',
              message: 'Registration closes and check-in is locked. This cannot be undone.',
              confirmLabel: 'Mark completed',
              success: 'Event completed.',
            ),
            child: const Text('Mark completed'),
          ),
        ],
      EventStatus.completed => [edit],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 12, runSpacing: 12, children: buttons),
        if (event.status == EventStatus.completed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('This event is completed. Registration and check-in are locked.',
                style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }

  Future<void> _move(
    BuildContext context,
    Backend backend,
    EventStatus next, {
    required String title,
    required String message,
    required String confirmLabel,
    required String success,
  }) async {
    if (!await confirm(context, title: title, message: message, confirmLabel: confirmLabel)) return;
    if (!context.mounted) return;
    await runAction(context, () => backend.setEventStatus(event.id, next, registrationOpen: false), success: success);
  }

  Future<void> _delete(BuildContext context, Backend backend) async {
    final router = GoRouter.of(context);
    final ok = await confirm(
      context,
      title: 'Delete "${event.title}"?',
      message: 'The draft and its committee assignments are deleted.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    if (await runAction(context, () => backend.deleteEvent(event.id), success: 'Draft deleted.')) {
      router.go('/organizer/events');
    }
  }
}

/// Committee members assigned to this event, and a picker to assign more
/// from the organization's committee.
class _Committee extends StatelessWidget {
  const _Committee(this.event);

  final GuyubEvent event;

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Committee for this event', subtitle: 'Only these members can scan tickets for this event.'),
        StreamView<List<Assignment>>(
          streamKey: event.id,
          create: () => backend.watchAssignments(event.id),
          builder: (context, assigned) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (assigned.isEmpty)
                const EmptyNote(icon: Icons.groups_outlined, message: 'Nobody is assigned yet.')
              else
                Card(
                  child: Column(
                    children: [
                      for (final member in assigned)
                        ListTile(
                          leading: CircleAvatar(child: Text(member.label.characters.first.toUpperCase())),
                          title: Text(member.label),
                          subtitle: member.email == null || member.email == member.label ? null : Text(member.email!),
                          trailing: IconButton(
                            tooltip: 'Unassign ${member.label}',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => runAction(
                              context,
                              () => backend.unassignCommittee(event.id, member.uid),
                              success: '${member.label} unassigned.',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              StreamView<List<Member>>(
                streamKey: event.orgId,
                create: () => backend.watchMembers(event.orgId, UserRole.committee),
                builder: (context, members) {
                  final assignedIds = {for (final a in assigned) a.uid};
                  final available = members.where((m) => !assignedIds.contains(m.uid)).toList();
                  if (members.isEmpty) {
                    return EmptyNote(
                      icon: Icons.person_add_alt,
                      message: 'Your organization has no committee members yet.',
                      action: OutlinedButton(
                        onPressed: () => context.go('/organizer/committee'),
                        child: const Text('Add committee members'),
                      ),
                    );
                  }
                  if (available.isEmpty) {
                    return Text('Every committee member is assigned.', style: Theme.of(context).textTheme.bodySmall);
                  }
                  return _AssignPicker(eventId: event.id, available: available);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssignPicker extends StatefulWidget {
  const _AssignPicker({required this.eventId, required this.available});

  final String eventId;
  final List<Member> available;

  @override
  State<_AssignPicker> createState() => _AssignPickerState();
}

class _AssignPickerState extends State<_AssignPicker> {
  String? _selected;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.available.any((m) => m.uid == _selected) ? _selected : null;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Committee member', border: OutlineInputBorder()),
            items: [
              for (final member in widget.available)
                DropdownMenuItem(value: member.uid, child: Text(member.label, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: _busy ? null : (value) => setState(() => _selected = value),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: selected == null || _busy ? null : () => _assign(selected),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Assign'),
        ),
      ],
    );
  }

  Future<void> _assign(String uid) async {
    final member = widget.available.firstWhere((m) => m.uid == uid);
    final backend = BackendScope.of(context);
    setState(() => _busy = true);
    await runAction(context, () => backend.assignCommittee(widget.eventId, member), success: '${member.label} assigned.');
    if (mounted) {
      setState(() {
        _busy = false;
        _selected = null;
      });
    }
  }
}
