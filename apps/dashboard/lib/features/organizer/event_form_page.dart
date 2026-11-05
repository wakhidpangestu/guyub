import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/user_role.dart';
import '../../data/backend_scope.dart';
import '../../data/models.dart';
import '../../ui/shell/role_shell.dart';
import '../../ui/widgets/feedback.dart';
import '../../ui/widgets/page_body.dart';
import '../../ui/widgets/stream_view.dart';
import 'organizer_session.dart';

/// Create a draft ([eventId] null) or edit an existing event's details.
class EventFormPage extends StatefulWidget {
  const EventFormPage({super.key, this.eventId});

  final String? eventId;

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  Future<GuyubEvent?>? _existing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = widget.eventId;
    _existing ??= id == null ? Future.value(null) : BackendScope.of(context).watchEvent(id).first;
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.eventId != null;
    return RoleShell(
      role: UserRole.organizer,
      title: editing ? 'Edit event' : 'New event',
      child: PageBody(
        maxWidth: 720,
        children: [
          FutureBuilder<GuyubEvent?>(
            future: _existing,
            builder: (context, snapshot) {
              if (snapshot.hasError) return ErrorNote(describeError(snapshot.error!));
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }
              final existing = snapshot.data;
              if (editing && existing == null) return const ErrorNote('This event no longer exists.');
              return _EventForm(eventId: widget.eventId, initial: existing?.toDraft());
            },
          ),
        ],
      ),
    );
  }
}

class _EventForm extends StatefulWidget {
  const _EventForm({required this.eventId, required this.initial});

  final String? eventId;
  final EventDraft? initial;

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _description = TextEditingController(text: widget.initial?.description);
  late final _location = TextEditingController(text: widget.initial?.location);
  late final _capacity = TextEditingController(text: widget.initial?.capacity?.toString());
  late DateTime _date = widget.initial?.date.toLocal() ?? _defaultDate();
  bool _busy = false;

  /// Tomorrow at 09:00 local time.
  static DateTime _defaultDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 9);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (picked != null) {
      setState(() => _date = DateTime(_date.year, _date.month, _date.day, picked.hour, picked.minute));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final backend = BackendScope.of(context);
    final router = GoRouter.of(context);
    final orgId = organizerOrgId(context);
    final draft = EventDraft(
      title: _title.text,
      description: _description.text,
      location: _location.text,
      date: _date,
      capacity: EventDraft.parseCapacity(_capacity.text),
    );

    setState(() => _busy = true);
    final id = widget.eventId;
    String? createdId;
    final ok = await runAction(
      context,
      () async {
        if (id == null) {
          if (orgId == null) throw StateError('No organization');
          createdId = await backend.createEvent(orgId, draft);
        } else {
          await backend.updateEvent(id, draft);
        }
      },
      success: id == null ? 'Draft created.' : 'Changes saved.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    router.go('/organizer/events/${id ?? createdId}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    const gap = SizedBox(height: 16);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          TextFormField(
            controller: _title,
            enabled: !_busy,
            maxLength: EventDraft.titleMax,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            validator: (value) => EventDraft.titleError(value ?? ''),
          ),
          gap,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(l10n.formatMediumDate(_date)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(l10n.formatTimeOfDay(TimeOfDay.fromDateTime(_date))),
                ),
              ),
            ],
          ),
          gap,
          TextFormField(
            controller: _location,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Location', hintText: 'Aula Timur ITB', border: OutlineInputBorder()),
            validator: (value) => EventDraft.locationError(value ?? ''),
          ),
          gap,
          TextFormField(
            controller: _capacity,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Capacity',
              helperText: 'Leave empty for no limit.',
              border: OutlineInputBorder(),
            ),
            validator: (value) => EventDraft.capacityError(value ?? ''),
          ),
          gap,
          TextFormField(
            controller: _description,
            enabled: !_busy,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true, border: OutlineInputBorder()),
            validator: (value) => EventDraft.descriptionError(value ?? ''),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(widget.eventId == null ? 'Create draft' : 'Save changes'),
            ),
          ),
        ],
      ),
    );
  }
}
