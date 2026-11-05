import 'package:flutter/material.dart';

import '../../data/models.dart';

/// "Tue, Dec 1 · 7:00 PM" in the viewer's locale and time zone.
/// Adds the year when the event is not in the current year.
String formatEventDate(BuildContext context, DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final l10n = MaterialLocalizations.of(context);
  final day = local.year == (now ?? DateTime.now()).year ? l10n.formatMediumDate(local) : l10n.formatFullDate(local);
  return '$day · ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (status) {
      EventStatus.draft => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, Icons.edit_note),
      EventStatus.active => (scheme.primaryContainer, scheme.onPrimaryContainer, Icons.public),
      EventStatus.completed => (scheme.secondaryContainer, scheme.onSecondaryContainer, Icons.task_alt),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: foreground),
      label: Text(status.label, style: TextStyle(color: foreground)),
      backgroundColor: background,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Compact event row for lists: title, date, location, and status.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, this.onTap});

  final GuyubEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(formatEventDate(context, event.date), style: muted),
                    if (event.location.isNotEmpty) Text(event.location, style: muted),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(event.status),
                  if (event.registrationOpen)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Registration open', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                    ),
                ],
              ),
              if (onTap != null) ...[const SizedBox(width: 4), const Icon(Icons.chevron_right)],
            ],
          ),
        ),
      ),
    );
  }
}
