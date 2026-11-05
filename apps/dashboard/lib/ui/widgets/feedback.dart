import 'package:flutter/material.dart';

import '../../data/backend.dart';

/// User-facing text for any error from the backend.
String describeError(Object error) =>
    error is BackendFailure ? error.message : 'Something went wrong. Please try again.';

/// Runs [action] and reports the result in a snackbar.
/// Returns true on success, so callers can navigate afterwards.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
    return true;
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(describeError(error))));
    return false;
  }
}

/// Asks before a destructive or hard-to-undo action.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError) : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
