import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../auth/auth_state.dart';
import '../../auth/user_role.dart';

/// Frame shared by every role's area: app bar with role badge and account menu.
class RoleShell extends StatelessWidget {
  const RoleShell({super.key, required this.role, required this.child});

  final UserRole role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Text('Guyub', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Flexible(
              child: Chip(
                label: Text(role.label, overflow: TextOverflow.ellipsis),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        actions: const [_AccountMenu(), SizedBox(width: 8)],
      ),
      body: SafeArea(child: child),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final session = auth.state;
    if (session is! SignedIn) return const SizedBox.shrink();

    final initial = session.name.characters.first.toUpperCase();
    return PopupMenuButton<_MenuAction>(
      tooltip: 'Account',
      onSelected: (action) => switch (action) {
        _MenuAction.refresh => auth.refreshClaims(),
        _MenuAction.signOut => auth.signOut(),
      },
      itemBuilder: (context) => [
        PopupMenuItem<_MenuAction>(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(session.name),
            subtitle: Text([
              if (session.email != null) session.email!,
              if (session.orgId != null) 'Org: ${session.orgId}',
            ].join('\n')),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: _MenuAction.refresh, child: Text('Refresh access')),
        const PopupMenuItem(value: _MenuAction.signOut, child: Text('Sign out')),
      ],
      child: CircleAvatar(child: Text(initial)),
    );
  }
}

enum _MenuAction { refresh, signOut }
