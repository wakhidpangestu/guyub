import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_scope.dart';
import '../../auth/auth_state.dart';
import '../../auth/user_role.dart';
import '../widgets/page_body.dart';
import 'role_shell.dart';

/// A tile on a role's home. Built features have a [route]. Features not built
/// yet have a [milestone] instead: the handbook requires unfinished features
/// to be labelled, so they show "Planned · Mx".
class Feature {
  const Feature({required this.icon, required this.title, required this.description, this.route, this.milestone})
      : assert((route == null) != (milestone == null), 'A feature has either a route or a milestone.');

  final IconData icon;
  final String title;
  final String description;
  final String? route;

  /// Milestone from docs/SPEC.md §7, for example "M4".
  final String? milestone;
}

/// Landing screen of a role's area. [body] goes between the intro and the tiles.
class RoleHome extends StatelessWidget {
  const RoleHome({super.key, required this.role, required this.intro, required this.features, this.body});

  final UserRole role;
  final String intro;
  final List<Feature> features;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = AuthScope.of(context).state;
    final name = session is SignedIn ? session.name : '';

    return RoleShell(
      role: role,
      child: PageBody(
        children: [
          Text('Welcome, $name', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(intro, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ?body,
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [for (final feature in features) _FeatureCard(feature)],
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard(this.feature);

  final Feature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final route = feature.route;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340, minWidth: 260),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: route == null ? null : () => context.go(route),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(feature.icon, color: theme.colorScheme.primary),
                    const Spacer(),
                    if (feature.milestone != null)
                      Chip(label: Text('Planned · ${feature.milestone}'), visualDensity: VisualDensity.compact)
                    else
                      Icon(Icons.arrow_forward, color: theme.colorScheme.primary),
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
      ),
    );
  }
}
