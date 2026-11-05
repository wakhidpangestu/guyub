import 'package:flutter/material.dart';

import '../auth/auth_scope.dart';
import '../config/env.dart';
import 'centered_panel.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return CenteredPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Guyub', style: theme.textTheme.displaySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Event operations for communities and campus organizations.',
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: auth.busy ? null : auth.signInWithGoogle,
            icon: auth.busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.login),
            label: Text(auth.busy ? 'Signing in…' : 'Continue with Google'),
          ),
          if (auth.error case final error?) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(error, style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'New accounts start as attendees. Organizers and committee members get access from their organization.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (Env.useEmulators) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.science_outlined, size: 18),
                label: Text('Emulator mode · ${Env.projectId}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
