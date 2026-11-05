import 'package:flutter/material.dart';

import '../../data/models.dart';

/// Big, colored outcome of the last scan, readable at arm's length at a door.
class CheckInResultCard extends StatelessWidget {
  const CheckInResultCard(this.outcome, {super.key});

  final CheckInOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = outcome.attendeeName;
    final l10n = MaterialLocalizations.of(context);

    final (title, detail, icon, background, foreground) = switch (outcome.result) {
      CheckInResult.checkedIn => ('Checked in', 'Welcome!', Icons.check_circle, Colors.green.shade700, Colors.white),
      CheckInResult.alreadyCheckedIn => (
          'Already checked in',
          outcome.checkedInAt == null
              ? 'This ticket was used before.'
              : 'First came in at ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(outcome.checkedInAt!.toLocal()))}.',
          Icons.history,
          Colors.amber.shade700,
          Colors.black,
        ),
      CheckInResult.expired => (
          'Code expired',
          'Ask them to open their ticket again. The code changes every 30 seconds, so screenshots do not work.',
          Icons.timer_off_outlined,
          Colors.orange.shade800,
          Colors.white,
        ),
      CheckInResult.invalid => ('Not a valid ticket', 'This code was not issued by Guyub.', Icons.gpp_bad_outlined, scheme.error, scheme.onError),
      CheckInResult.wrongEvent => ('Ticket for another event', 'This ticket is not for this event.', Icons.wrong_location_outlined, scheme.error, scheme.onError),
      CheckInResult.notRegistered => (
          'Not registered',
          'This ticket was cancelled or does not exist.',
          Icons.person_off_outlined,
          scheme.error,
          scheme.onError,
        ),
      CheckInResult.closed => (
          'Check-in is closed',
          'The event is not published, or it is completed.',
          Icons.lock_outline,
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, size: 48, color: foreground),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge?.copyWith(color: foreground, fontWeight: FontWeight.w700)),
                  if (name != null && name.isNotEmpty)
                    Text(name, style: theme.textTheme.titleMedium?.copyWith(color: foreground)),
                  const SizedBox(height: 4),
                  Text(detail, style: theme.textTheme.bodyMedium?.copyWith(color: foreground)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
