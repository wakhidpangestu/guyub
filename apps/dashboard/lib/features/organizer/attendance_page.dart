import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/user_role.dart';
import '../../data/backend.dart';
import '../../data/backend_scope.dart';
import '../../data/models.dart';
import '../../ui/shell/role_shell.dart';
import '../../ui/widgets/feedback.dart';
import '../../ui/widgets/page_body.dart';
import '../../ui/widgets/stream_view.dart';
import 'organizer_session.dart';

enum _Filter { all, inside, notYet }

/// Everyone registered for an event, with live check-in state. Organizers
/// can check someone in by hand when their phone cannot show the ticket.
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key, required this.eventId});

  final String eventId;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _checkIn(Registration registration) async {
    final backend = BackendScope.of(context);
    final ok = await confirm(
      context,
      title: 'Check in ${registration.label}?',
      message: 'Use this only when you have confirmed who they are, for example when their phone cannot show the ticket.',
      confirmLabel: 'Check in',
    );
    if (!ok || !mounted) return;
    await runAction(context, () async {
      final outcome = await backend.checkIn(widget.eventId, attendanceId: registration.attendanceId);
      final problem = switch (outcome.result) {
        CheckInResult.checkedIn || CheckInResult.alreadyCheckedIn => null,
        CheckInResult.closed => 'Check-in is closed: the event is not published.',
        CheckInResult.notRegistered => 'This registration was cancelled.',
        _ => 'Could not check in (${outcome.result.wire}).',
      };
      if (problem != null) throw BackendFailure(problem);
    }, success: '${registration.label} checked in.');
  }

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    final orgId = organizerOrgId(context);
    final theme = Theme.of(context);
    final l10n = MaterialLocalizations.of(context);

    return RoleShell(
      role: UserRole.organizer,
      title: 'Attendance',
      child: PageBody(
        maxWidth: 900,
        children: [
          if (orgId == null)
            const ErrorNote('Your account has no organization.')
          else
            StreamView<List<Registration>>(
              streamKey: (widget.eventId, orgId),
              create: () => backend.watchAttendance(widget.eventId, orgId: orgId),
              builder: (context, all) {
                final inside = all.where((r) => r.isCheckedIn).length;
                final term = _search.text.trim().toLowerCase();
                final shown = all.where((r) {
                  if (_filter == _Filter.inside && !r.isCheckedIn) return false;
                  if (_filter == _Filter.notYet && r.isCheckedIn) return false;
                  return term.isEmpty || r.label.toLowerCase().contains(term);
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      '$inside of ${all.length} checked in',
                      subtitle: 'Updates live while the committee scans.',
                      action: FilledButton.icon(
                        onPressed: () => context.go('/organizer/events/${widget.eventId}/scan'),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Open scanner'),
                      ),
                    ),
                    if (all.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: inside / all.length, minHeight: 8),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _search,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search by name', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<_Filter>(
                      segments: const [
                        ButtonSegment(value: _Filter.all, label: Text('All')),
                        ButtonSegment(value: _Filter.inside, label: Text('Checked in')),
                        ButtonSegment(value: _Filter.notYet, label: Text('Not yet')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (selection) => setState(() => _filter = selection.first),
                    ),
                    const SizedBox(height: 12),
                    if (all.isEmpty)
                      const EmptyNote(icon: Icons.people_outline, message: 'Nobody has registered yet.')
                    else if (shown.isEmpty)
                      const EmptyNote(icon: Icons.search_off, message: 'Nobody matches.')
                    else
                      Card(
                        child: Column(
                          children: [
                            for (final registration in shown)
                              ListTile(
                                leading: Icon(
                                  registration.isCheckedIn ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: registration.isCheckedIn ? theme.colorScheme.primary : theme.colorScheme.outline,
                                ),
                                title: Text(registration.label),
                                subtitle: Text(registration.isCheckedIn
                                    ? [
                                        'Checked in',
                                        if (registration.checkedInAt != null)
                                          l10n.formatTimeOfDay(TimeOfDay.fromDateTime(registration.checkedInAt!.toLocal())),
                                        if (registration.checkInMethod == 'manual') 'manually',
                                      ].join(' · ')
                                    : 'Not checked in'),
                                trailing: registration.isCheckedIn
                                    ? null
                                    : OutlinedButton(onPressed: () => _checkIn(registration), child: const Text('Check in')),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
