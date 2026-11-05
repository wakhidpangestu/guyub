import 'package:flutter/material.dart';

/// A centered card for single-purpose pages (login, forbidden, not found).
/// Scrolls on short screens so nothing is cut off on phones.
class CenteredPanel extends StatelessWidget {
  const CenteredPanel({super.key, required this.child, this.maxWidth = 440});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
