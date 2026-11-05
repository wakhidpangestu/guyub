import 'package:flutter/material.dart';

import '../../auth/user_role.dart';
import '../../data/backend.dart';
import '../../data/backend_scope.dart';
import '../../data/models.dart';
import '../../ui/widgets/feedback.dart';
import '../../ui/widgets/page_body.dart';
import '../../ui/widgets/stream_view.dart';

/// Members of one role in one organization: add by email, list, remove,
/// and pending invites. Used for organizers (admin) and committee (organizer).
class MembersSection extends StatelessWidget {
  const MembersSection({
    super.key,
    required this.orgId,
    required this.role,
    required this.title,
    required this.subtitle,
  });

  final String orgId;
  final UserRole role;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final backend = BackendScope.of(context);
    final noun = memberNoun(role);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title, subtitle: subtitle),
        _AddByEmail(orgId: orgId, role: role),
        const SizedBox(height: 8),
        StreamView<List<Member>>(
          streamKey: (orgId, role),
          create: () => backend.watchMembers(orgId, role),
          isEmpty: (members) => members.isEmpty,
          empty: EmptyNote(icon: Icons.group_outlined, message: 'No ${noun}s yet. Add one by email above.'),
          builder: (context, members) => Card(
            child: Column(
              children: [
                for (final member in members)
                  ListTile(
                    leading: CircleAvatar(child: Text(member.label.characters.first.toUpperCase())),
                    title: Text(member.label),
                    subtitle: member.email == null || member.email == member.label ? null : Text(member.email!),
                    trailing: IconButton(
                      tooltip: 'Remove ${member.label}',
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () => _remove(context, backend, member),
                    ),
                  ),
              ],
            ),
          ),
        ),
        StreamView<List<Invite>>(
          streamKey: (orgId, role),
          create: () => backend.watchInvites(orgId, role),
          isEmpty: (invites) => invites.isEmpty,
          builder: (context, invites) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text('Waiting for first sign-in', style: Theme.of(context).textTheme.titleSmall),
              ),
              Card(
                child: Column(
                  children: [
                    for (final invite in invites)
                      ListTile(
                        leading: const Icon(Icons.schedule_send_outlined),
                        title: Text(invite.email),
                        subtitle: Text('Gets ${role.label.toLowerCase()} access when they first sign in with Google.'),
                        trailing: IconButton(
                          tooltip: 'Cancel invite for ${invite.email}',
                          icon: const Icon(Icons.close),
                          onPressed: () => runAction(
                            context,
                            () => backend.cancelInvite(invite.email),
                            success: 'Invite for ${invite.email} cancelled.',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _remove(BuildContext context, Backend backend, Member member) async {
    final noun = memberNoun(role);
    final ok = await confirm(
      context,
      title: 'Remove ${member.label}?',
      message: role == UserRole.committee
          ? 'They lose committee access and are removed from every event they were assigned to. They keep their account as an attendee.'
          : 'They lose $noun access to this organization. They keep their account as an attendee.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runAction(context, () => backend.removeMember(member.uid), success: '${member.label} removed.');
  }
}

class _AddByEmail extends StatefulWidget {
  const _AddByEmail({required this.orgId, required this.role});

  final String orgId;
  final UserRole role;

  @override
  State<_AddByEmail> createState() => _AddByEmailState();
}

class _AddByEmailState extends State<_AddByEmail> {
  final _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim().toLowerCase();
    final noun = memberNoun(widget.role);
    final backend = BackendScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      final outcome = await backend.inviteMember(email: email, role: widget.role, orgId: widget.orgId);
      _email.clear();
      messenger.showSnackBar(SnackBar(
        content: Text(switch (outcome) {
          InviteOutcome.granted => '$email is now ${withArticle(noun)}.',
          InviteOutcome.invited => 'Invite saved. $email becomes ${withArticle(noun)} at first sign-in.',
        }),
      ));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noun = memberNoun(widget.role);
    return Form(
      key: _formKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'Google account email',
                hintText: 'name@example.com',
                helperText: 'They get ${widget.role.label.toLowerCase()} access now, or at first sign-in if they are new.',
                border: const OutlineInputBorder(),
              ),
              validator: (value) => _emailPattern.hasMatch((value ?? '').trim()) ? null : 'Enter a valid email address.',
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.person_add_alt),
              label: Text('Add $noun'),
            ),
          ),
        ],
      ),
    );
  }
}

/// How one person with [role] is called in sentences: "organizer",
/// "committee member".
String memberNoun(UserRole role) => role == UserRole.committee ? 'committee member' : role.label.toLowerCase();

/// "an organizer", "a committee member".
String withArticle(String noun) => '${'aeiou'.contains(noun[0]) ? 'an' : 'a'} $noun';
