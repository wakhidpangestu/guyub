import 'package:flutter/material.dart';

import '../../data/models.dart';

/// Where an attendee stands with one event.
enum RegistrationState { registered, open, full, closed }

RegistrationState registrationStateOf(GuyubEvent event, {required bool registered}) {
  if (registered) return RegistrationState.registered;
  if (event.status != EventStatus.active || !event.registrationOpen) return RegistrationState.closed;
  if (event.isFull) return RegistrationState.full;
  return RegistrationState.open;
}

class RegistrationBadge extends StatelessWidget {
  const RegistrationBadge(this.state, {super.key, this.spotsLeft});

  final RegistrationState state;
  final int? spotsLeft;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, background, foreground) = switch (state) {
      RegistrationState.registered => ('Registered', Icons.check_circle, scheme.primaryContainer, scheme.onPrimaryContainer),
      RegistrationState.open => (
          spotsLeft == null ? 'Registration open' : '$spotsLeft ${spotsLeft == 1 ? 'spot' : 'spots'} left',
          Icons.how_to_reg,
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      RegistrationState.full => ('Full', Icons.block, scheme.errorContainer, scheme.onErrorContainer),
      RegistrationState.closed => ('Registration closed', Icons.lock_outline, scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: foreground),
      label: Text(label, style: TextStyle(color: foreground)),
      backgroundColor: background,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
