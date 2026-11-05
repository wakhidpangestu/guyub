import 'package:flutter/material.dart';

import 'feedback.dart';

/// Subscribes to a stream once and renders loading, error, empty, and data
/// states. Pass [streamKey] to resubscribe when an input (such as an ID) changes.
///
/// The stream is created in initState, not in build, so rebuilds do not open
/// new Firestore listeners.
class StreamView<T> extends StatefulWidget {
  const StreamView({
    super.key,
    required this.create,
    required this.builder,
    this.streamKey,
    this.isEmpty,
    this.empty,
    this.errorText,
  });

  final Stream<T> Function() create;
  final Widget Function(BuildContext context, T data) builder;
  final Object? streamKey;

  /// Replaces the generic error message, when a page knows the likely cause.
  final String? errorText;

  /// When it returns true, [empty] is shown instead of [builder].
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  @override
  State<StreamView<T>> createState() => _StreamViewState<T>();
}

class _StreamViewState<T> extends State<StreamView<T>> {
  late Stream<T> _stream = widget.create();

  @override
  void didUpdateWidget(StreamView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamKey != widget.streamKey) _stream = widget.create();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorNote(widget.errorText ?? describeError(snapshot.error!));
        // Waiting means no value yet. Do not use hasData: null is a valid
        // value (for example "this event does not exist").
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data as T;
        if (widget.isEmpty?.call(data) ?? false) return widget.empty ?? const SizedBox.shrink();
        return widget.builder(context, data);
      },
    );
  }
}

/// Shown in place of content that failed to load.
class ErrorNote extends StatelessWidget {
  const ErrorNote(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: TextStyle(color: scheme.onErrorContainer))),
          ],
        ),
      ),
    );
  }
}

/// Friendly placeholder for an empty list.
class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}
