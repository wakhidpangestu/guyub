import 'package:flutter/material.dart';

import 'centered_panel.dart';
import 'theme.dart';

/// Shown instead of the app when Firebase keys were not passed at build time.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.missingKeys});

  final List<String> missingKeys;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guyub · configuration needed',
      debugShowCheckedModeBanner: false,
      theme: GuyubTheme.light(),
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return CenteredPanel(
            maxWidth: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Firebase is not configured', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text('Missing: ${missingKeys.join(', ')}'),
                const SizedBox(height: 12),
                const Text('Run with an env file, for example the local emulators:'),
                const SizedBox(height: 8),
                const SelectableText(
                  'flutter run -d chrome --dart-define-from-file=env/emulator.json',
                  style: TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
