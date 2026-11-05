import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'centered_panel.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CenteredPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Page not found', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Nothing lives at $location.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => context.go('/'), child: const Text('Go to my dashboard')),
        ],
      ),
    );
  }
}
