import 'package:flutter/material.dart';

import '../../auth/session.dart';
import '../../auth/user_role.dart';
import '../../data/backend_scope.dart';
import '../../data/models.dart';
import '../../ui/shell/role_shell.dart';
import '../../ui/widgets/event_widgets.dart';
import '../../ui/widgets/feedback.dart';
import '../../ui/widgets/page_body.dart';
import '../../ui/widgets/stream_view.dart';
import 'camera_scanner.dart';
import 'check_in_result_card.dart';

/// The door screen: scan tickets, see the result, see who came in last.
/// Used by assigned committee members and by the event's organizers.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.eventId, required this.role});

  final String eventId;
  final UserRole role;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  CheckInOutcome? _last;
  bool _busy = false;
  String? _lastCode;
  String? _lastKey;
  DateTime? _lastAt;

  /// A camera reads the same QR many times per second, and the person stays
  /// in front of it for a while. After a final result (checked in, or already
  /// in), the same ticket is ignored for this long, so the screen keeps
  /// showing "Checked in" instead of flipping to "Already checked in".
  static const _sameTicketWindow = Duration(seconds: 15);

  /// The exact same code is ignored this long whatever the result. After a
  /// refusal (for example "Code expired"), a new code from the same person is
  /// sent at once, so they can retry by reopening their ticket.
  static const _sameCodeWindow = Duration(seconds: 3);

  bool get _lastWasFinal =>
      _last?.result == CheckInResult.checkedIn || _last?.result == CheckInResult.alreadyCheckedIn;

  /// The ticket a code belongs to. Rotating codes change every 30 seconds,
  /// so repeats are matched on the ticket, not on the exact code.
  static String _ticketKey(String code) {
    if (!code.startsWith('G1.')) return code;
    final signatureDot = code.lastIndexOf('.');
    final windowDot = signatureDot > 0 ? code.lastIndexOf('.', signatureDot - 1) : -1;
    return windowDot > 3 ? code.substring(3, windowDot) : code;
  }

  @override
  void dispose() {
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  /// [fromCamera]: typed codes are always sent, so staff can retry on purpose.
  Future<void> _submit(String raw, {bool fromCamera = false}) async {
    final code = raw.trim();
    if (code.isEmpty || _busy) return;
    final now = DateTime.now();
    final key = _ticketKey(code);
    if (fromCamera && _lastAt != null) {
      final since = now.difference(_lastAt!);
      if (code == _lastCode && since < _sameCodeWindow) return;
      if (key == _lastKey && _lastWasFinal && since < _sameTicketWindow) return;
    }
    _lastCode = code;
    _lastKey = key;
    _lastAt = now;

    final backend = BackendScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final outcome = await backend.checkIn(widget.eventId, payload: code);
      if (mounted) setState(() => _last = outcome);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(error))));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _code.clear();
        // Ready for the next person (also for USB scanners that type the code).
        _codeFocus.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    final session = currentSession(context);
    final orgId = widget.role == UserRole.organizer ? session?.orgId : null;
    final theme = Theme.of(context);

    return RoleShell(
      role: widget.role,
      title: 'Check-in',
      child: PageBody(
        maxWidth: 560,
        children: [
          StreamView<GuyubEvent?>(
            streamKey: widget.eventId,
            create: () => backend.watchEvent(widget.eventId),
            errorText: 'You are not assigned to this event.',
            builder: (context, event) => event == null
                ? const EmptyNote(icon: Icons.search_off, message: 'This event no longer exists.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, style: theme.textTheme.titleLarge),
                      Text(formatEventDate(context, event.date), style: theme.textTheme.bodyMedium),
                      if (event.status != EventStatus.active)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: ErrorNote('Check-in is closed: this event is not published.'),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          CameraScanner(onCode: (code) => _submit(code, fromCamera: true)),
          const SizedBox(height: 16),
          // Stays enabled while a request runs: disabling a focused field
          // throws inside Flutter web's text editing. _submit ignores input
          // while busy instead.
          TextField(
            controller: _code,
            focusNode: _codeFocus,
            decoration: InputDecoration(
              labelText: 'Ticket code',
              helperText: 'Type or paste a code, or use a USB scanner.',
              border: const OutlineInputBorder(),
              suffixIcon: _busy
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(tooltip: 'Check in', icon: const Icon(Icons.login), onPressed: () => _submit(_code.text)),
            ),
            onSubmitted: _submit,
          ),
          const SizedBox(height: 16),
          if (_last != null) CheckInResultCard(_last!),
          StreamView<List<Registration>>(
            streamKey: (widget.eventId, orgId),
            create: () => backend.watchAttendance(widget.eventId, orgId: orgId),
            builder: (context, attendance) => _RecentCheckIns(attendance),
          ),
        ],
      ),
    );
  }
}

class _RecentCheckIns extends StatelessWidget {
  const _RecentCheckIns(this.attendance);

  final List<Registration> attendance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = MaterialLocalizations.of(context);
    final inside = attendance.where((r) => r.isCheckedIn).toList()
      ..sort((a, b) => (b.checkedInAt ?? DateTime(0)).compareTo(a.checkedInAt ?? DateTime(0)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('${inside.length} of ${attendance.length} checked in'),
        for (final registration in inside.take(8))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.check, color: theme.colorScheme.primary),
            title: Text(registration.label),
            trailing: registration.checkedInAt == null
                ? null
                : Text(l10n.formatTimeOfDay(TimeOfDay.fromDateTime(registration.checkedInAt!.toLocal()))),
          ),
      ],
    );
  }
}
