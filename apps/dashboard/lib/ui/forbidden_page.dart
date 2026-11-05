import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_scope.dart';
import '../auth/auth_state.dart';
import '../auth/user_role.dart';
import 'centered_panel.dart';

/// Shown when a signed-in user opens another role's area.
class ForbiddenPage extends StatelessWidget {
  const ForbiddenPage({super.key, this.attempted});

  /// The location the user tried to open.
  final String? attempted;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final theme = Theme.of(context);
    final session = auth.state;
    final role = session is SignedIn ? session.role : null;
    final area = attempted == null ? null : UserRole.owningArea(Uri.parse(attempted!).path);

    return CenteredPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('No access to this area', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            [
              if (role != null) 'You are signed in as ${role.label}.',
              if (area != null) 'This page is for the ${area.label} role.',
              'If your role was just changed, refresh your access.',
            ].join(' '),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (role != null)
            FilledButton(
              onPressed: () => context.go(role.homePath),
              child: const Text('Go to my dashboard'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: auth.busy ? null : auth.refreshClaims,
            child: const Text('Refresh access'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: auth.busy ? null : auth.signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
