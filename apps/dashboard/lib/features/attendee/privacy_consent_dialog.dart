import 'package:flutter/material.dart';

/// Privacy notice shown before every registration (UU PDP, SPEC §0 decision 6).
/// Returns true only if the attendee ticked the box and confirmed.
Future<bool> askPrivacyConsent(BuildContext context, {required String orgName, required String eventTitle}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _PrivacyConsentDialog(orgName: orgName, eventTitle: eventTitle),
  );
  return result ?? false;
}

class _PrivacyConsentDialog extends StatefulWidget {
  const _PrivacyConsentDialog({required this.orgName, required this.eventTitle});

  final String orgName;
  final String eventTitle;

  @override
  State<_PrivacyConsentDialog> createState() => _PrivacyConsentDialogState();
}

class _PrivacyConsentDialogState extends State<_PrivacyConsentDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
            ],
          ),
        );

    return AlertDialog(
      title: Text('Register for ${widget.eventTitle}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Privacy notice', style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              point(Icons.badge_outlined, 'Your name is shared with ${widget.orgName} and its committee to run this event.'),
              point(Icons.mail_outline, 'Your email is not shared with the organizer. Guyub uses it only to send your ticket and certificate.'),
              point(Icons.qr_code_2, 'Your ticket and check-in time are recorded for attendance and your certificate.'),
              point(Icons.schedule, 'Attendance records are deleted automatically 12 months after the event.'),
              point(Icons.cancel_outlined, 'You can cancel your registration any time before check-in.'),
              const SizedBox(height: 4),
              CheckboxListTile(
                value: _agreed,
                onChanged: (value) => setState(() => _agreed = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I have read the privacy notice and agree.'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _agreed ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Register'),
        ),
      ],
    );
  }
}
