import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Create a new event, or edit one when [event] is passed.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, required this.team, this.event});

  final Json team;
  final Json? event;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _opponent;
  late final TextEditingController _notes;
  late String _type;
  late DateTime _start;
  late Duration _length;
  bool _repeatWeekly = false;
  late DateTime _repeatUntil;
  bool _busy = false;

  bool get _editing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _type = e?['type'] as String? ?? 'practice';
    _title = TextEditingController(text: e?['title'] as String? ?? 'Team practice');
    _location = TextEditingController(text: e?['location'] as String?);
    _opponent = TextEditingController(text: e?['opponent'] as String?);
    _notes = TextEditingController(text: e?['notes'] as String?);

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _start = e != null ? parseTime(e['starts_at'] as String) : DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 17, 30);
    _length = e?['ends_at'] != null ? parseTime(e!['ends_at'] as String).difference(_start) : const Duration(minutes: 90);
    _repeatUntil = _start.add(const Duration(days: 56));
  }

  @override
  void dispose() {
    for (final c in [_title, _location, _opponent, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _repeatCount => _repeatUntil.difference(_start).inDays ~/ 7 + 1;

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (time == null) return;

    setState(() {
      _start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (!_repeatUntil.isAfter(_start)) _repeatUntil = _start.add(const Duration(days: 56));
    });
  }

  Future<void> _pickRepeatUntil() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _repeatUntil,
      firstDate: _start.add(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 360)),
    );
    if (date != null) setState(() => _repeatUntil = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    String? orNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final teamId = widget.team['id'] as int;
    final api = ref.read(apiClientProvider);
    final body = <String, dynamic>{
      'type': _type,
      'title': _title.text.trim(),
      // Sent in UTC so the server never has to guess the phone's timezone.
      'starts_at': _start.toUtc().toIso8601String(),
      'ends_at': _start.add(_length).toUtc().toIso8601String(),
      'location': orNull(_location),
      'opponent': _type == 'game' ? orNull(_opponent) : null,
      'notes': orNull(_notes),
      if (!_editing && _repeatWeekly) 'repeat_until': DateFormat('yyyy-MM-dd').format(_repeatUntil),
    };

    final ok = await runAction(
      context,
      () => _editing ? api.updateEvent(widget.event!['id'] as int, body) : api.createEvent(teamId, body),
      success: _editing ? 'Event updated. Parents were notified.' : 'Added. The team has been notified.',
    );

    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.invalidate(teamEventsProvider(teamId));
      ref.invalidate(upcomingEventsProvider);
      if (_editing) ref.invalidate(eventDetailProvider(widget.event!['id'] as int));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit event' : 'New event')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'practice', label: Text('Practice'), icon: Icon(Icons.fitness_center_rounded)),
                ButtonSegment(value: 'game', label: Text('Game'), icon: Icon(Icons.emoji_events_outlined)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                // Swap the default title, but never overwrite one the coach typed.
                if (_title.text == 'Team practice' || _title.text.startsWith('vs ')) {
                  _title.text = _type == 'game' ? 'vs ${_opponent.text}' : 'Team practice';
                }
              }),
            ),
            const SizedBox(height: 16),
            if (_type == 'game') ...[
              TextFormField(
                controller: _opponent,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Opponent'),
                onChanged: (v) {
                  if (_title.text.startsWith('vs ')) _title.text = 'vs $v';
                },
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Give it a title' : null,
            ),
            const SizedBox(height: 12),
            _PickerTile(icon: Icons.event_rounded, label: 'Starts', value: fullDateTime(_start), onTap: _pickStart),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _length.inMinutes,
              decoration: const InputDecoration(labelText: 'Length'),
              items: {30, 45, 60, 75, 90, 120, 150, 180, _length.inMinutes}
                  .map((m) => DropdownMenuItem(value: m, child: Text(m % 60 == 0 ? '${m ~/ 60} h' : m > 60 ? '${m ~/ 60} h ${m % 60} min' : '$m min')))
                  .toList(),
              onChanged: (m) => setState(() => _length = Duration(minutes: m!)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Location', hintText: 'e.g. Riverside Park, Field 2'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes for parents (optional)', hintText: 'Bring water and shin guards'),
            ),
            if (!_editing) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeat every week'),
                subtitle: Text('Every ${DateFormat('EEEE').format(_start)} at ${timeLabel(_start)}'),
                value: _repeatWeekly,
                onChanged: (v) => setState(() => _repeatWeekly = v),
              ),
              if (_repeatWeekly)
                _PickerTile(
                  icon: Icons.repeat_rounded,
                  label: 'Until',
                  value: '${DateFormat('EEE, MMM d').format(_repeatUntil)}  ·  $_repeatCount events',
                  onTap: _pickRepeatUntil,
                ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving...' : _editing ? 'Save changes' : 'Add to schedule'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(value),
      ),
    );
  }
}

/// For reuse elsewhere: shows a "Cancel event" choice for a single event or
/// the rest of its weekly series.
Future<void> showCancelEventSheet(BuildContext context, WidgetRef ref, Json event) async {
  final reason = TextEditingController();
  final inSeries = event['series_id'] != null;

  final choice = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Cancel event', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Everyone on the team gets a push notification right away.', style: TextStyle(color: AppColors.slate)),
          const SizedBox(height: 16),
          TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason (optional)', hintText: 'Field is flooded')),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, 'one'),
            child: const Text('Cancel this event'),
          ),
          if (inSeries) ...[
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => Navigator.pop(context, 'series'), child: const Text('Cancel this and all later weeks')),
          ],
        ],
      ),
    ),
  );
  final reasonText = reason.text.trim();
  reason.dispose();
  if (choice == null || !context.mounted) return;

  final ok = await runAction(
    context,
    () => ref.read(apiClientProvider).cancelEvent(
          event['id'] as int,
          wholeSeries: choice == 'series',
          reason: reasonText.isEmpty ? null : reasonText,
        ),
    success: 'Cancelled. Parents have been notified.',
  );
  if (ok) {
    ref.invalidate(eventDetailProvider(event['id'] as int));
    ref.invalidate(teamEventsProvider(event['team_id'] as int));
    ref.invalidate(upcomingEventsProvider);
  }
}
