import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../auth/auth_state.dart';
import '../../auth/user_role.dart';
import 'role_shell.dart';

/// A feature that is designed but not built yet. The handbook requires
/// unfinished features to be labelled, so every card shows its milestone.
class PlannedFeature {
  const PlannedFeature({required this.icon, required this.title, required this.description, required this.milestone});

  final IconData icon;
  final String title;
  final String description;

  /// Milestone from docs/SPEC.md §7, for example "M2".
  final String milestone;
}

/// Landing screen of a role's area. M1 shows planned features only.
class RoleHome extends StatelessWidget {
  const RoleHome({super.key, required this.role, required this.intro, required this.features});

  final UserRole role;
  final String intro;
  final List<PlannedFeature> features;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = AuthScope.of(context).state;
    final name = session is SignedIn ? session.name : '';

    return RoleShell(
      role: role,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              // Full width up to the max, so pages with few cards stay left-aligned.
              child: SizedBox(
                width: double.infinity,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome, $name', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(intro, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [for (final feature in features) _FeatureCard(feature)],
                  ),
                ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard(this.feature);

  final PlannedFeature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340, minWidth: 260),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(feature.icon, color: theme.colorScheme.primary),
                  const Spacer(),
                  Chip(
                    label: Text('Planned · ${feature.milestone}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(feature.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(feature.description, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
