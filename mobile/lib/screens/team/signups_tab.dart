import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class SignupsTab extends ConsumerWidget {
  const SignupsTab({super.key, required this.team});

  final Json team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = team['id'] as int;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewSignupScreen(team: team))),
        icon: const Icon(Icons.add_rounded),
        label: Text(team['role'] == 'coach' ? 'New sign-up' : 'Start a carpool'),
      ),
      body: AsyncBody(
        value: ref.watch(signupsProvider(teamId)),
        onRefresh: () => ref.refresh(signupsProvider(teamId).future),
        builder: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              EmptyState(
                icon: Icons.volunteer_activism_outlined,
                title: 'No sign-ups yet',
                message: 'Snack duty, scorekeepers and carpools live here, with no double-booking.',
              ),
            ]);
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _SignupCard(signup: list[i] as Json, team: team),
          );
        },
      ),
    );
  }
}

class _SignupCard extends ConsumerWidget {
  const _SignupCard({required this.signup, required this.team});

  final Json signup;
  final Json team;

  int get _teamId => team['id'] as int;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider.select((s) => s.user?['id'] as int?));
    final isCoach = team['role'] == 'coach';
    final isCarpool = signup['type'] == 'carpool';
    final event = signup['event'] as Json?;
    final slots = (signup['slots'] as List<dynamic>).cast<Json>();
    final canDelete = isCoach || signup['created_by'] == me;

    void refresh() => ref.invalidate(signupsProvider(_teamId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(isCarpool ? Icons.directions_car_outlined : Icons.volunteer_activism_outlined, color: AppColors.teal, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(signup['title'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              if (canDelete)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.more_horiz_rounded, color: AppColors.slate),
                  onPressed: () async {
                    final sure = await confirm(context, title: 'Delete "${signup['title']}"?', action: 'Delete', danger: true);
                    if (sure && context.mounted && await runAction(context, () => ref.read(apiClientProvider).deleteSignup(signup['id'] as int))) {
                      refresh();
                    }
                  },
                ),
            ]),
            if (event != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Text('For ${event['title']} · ${dayLabel(parseTime(event['starts_at'] as String))}',
                    style: const TextStyle(fontSize: 13, color: AppColors.slate)),
              ),
            if (signup['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Text(signup['description'] as String),
              ),
            const SizedBox(height: 6),
            if (slots.isEmpty && isCarpool)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No drivers yet. Can you offer a ride?', style: TextStyle(color: AppColors.slate)),
              ),
            for (final slot in slots) _SlotRow(slot: slot, signup: signup, team: team, me: me, onChanged: refresh),
            if (isCarpool)
              TextButton.icon(
                onPressed: () => _offerRide(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Offer a ride'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _offerRide(BuildContext context, WidgetRef ref) async {
    final label = TextEditingController(text: 'My car');
    final note = TextEditingController();
    var seats = 3;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Offer a ride'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: label, decoration: const InputDecoration(labelText: 'Car', hintText: 'Blue minivan')),
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(child: Text('Free seats')),
              IconButton(onPressed: seats > 1 ? () => setState(() => seats--) : null, icon: const Icon(Icons.remove_circle_outline)),
              Text('$seats', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              IconButton(onPressed: seats < 8 ? () => setState(() => seats++) : null, icon: const Icon(Icons.add_circle_outline)),
            ]),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'Leaving from the school at 8:15')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
            FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(minimumSize: Size.zero), child: const Text('Add my car')),
          ],
        ),
      ),
    );

    if (ok == true && context.mounted) {
      final added = await runAction(
        context,
        () => ref.read(apiClientProvider).addSlot(signup['id'] as int,
            label: label.text.trim().isEmpty ? 'My car' : label.text.trim(),
            capacity: seats,
            note: note.text.trim().isEmpty ? null : note.text.trim()),
        success: 'Thanks! Parents can now book a seat.',
      );
      if (added) ref.invalidate(signupsProvider(_teamId));
    }
    label.dispose();
    note.dispose();
  }
}

class _SlotRow extends ConsumerWidget {
  const _SlotRow({required this.slot, required this.signup, required this.team, required this.me, required this.onChanged});

  final Json slot;
  final Json signup;
  final Json team;
  final int? me;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = (slot['claims'] as List<dynamic>).cast<Json>();
    final capacity = slot['capacity'] as int;
    final full = claims.length >= capacity;
    final myClaims = claims.where((c) => c['user_id'] == me).toList();
    final owner = slot['owner'] as Json?;
    final isCarpool = signup['type'] == 'carpool';
    final canRemoveSlot = team['role'] == 'coach' || slot['owner_id'] == me;

    final who = claims.map((c) {
      final player = c['player'] as Json?;
      return player != null ? player['first_name'] as String : (c['user'] as Json?)?['name'] as String? ?? '';
    }).join(', ');

    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onLongPress: canRemoveSlot ? () => _removeSlot(context, ref) : null,
                child: Text(
                  owner != null ? '${slot['label']} · ${owner['name']}' : slot['label'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (slot['note'] != null) Text(slot['note'] as String, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
              const SizedBox(height: 4),
              Row(children: [
                // One dot per spot: filled = taken.
                for (var i = 0; i < capacity && i < 10; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i < claims.length ? AppColors.teal : AppColors.line),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    claims.isEmpty ? '${capacity - claims.length} open' : who,
                    style: const TextStyle(fontSize: 12, color: AppColors.slate),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          if (myClaims.isNotEmpty)
            OutlinedButton(
              onPressed: () async {
                if (await runAction(context, () => ref.read(apiClientProvider).unclaim(myClaims.first['id'] as int))) onChanged();
              },
              child: const Text('Remove me'),
            )
          else if (full)
            const Padding(padding: EdgeInsets.only(top: 8), child: Pill('FULL'))
          else if (slot['owner_id'] != me)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              onPressed: () => _claim(context, ref, isCarpool),
              child: Text(isCarpool ? 'Book seat' : 'Sign up'),
            ),
        ],
      ),
    );
  }

  Future<void> _claim(BuildContext context, WidgetRef ref, bool isCarpool) async {
    int? playerId;
    if (isCarpool) {
      // Seats are for kids, so ask which child is riding.
      final detail = await ref.read(teamDetailProvider(team['id'] as int).future);
      final kids = (detail['players'] as List<dynamic>).cast<Json>().where((p) => p['is_my_child'] == true).toList();
      if (!context.mounted) return;
      if (kids.isEmpty) {
        showMessage(context, 'Add your child on the Roster tab first.');
        return;
      }
      playerId = kids.length == 1 ? kids.first['id'] as int : await _pickChild(context, kids);
      if (playerId == null) return;
    }

    if (!context.mounted) return;
    await runAction(
      context,
      () => ref.read(apiClientProvider).claimSlot(slot['id'] as int, playerId: playerId),
      success: isCarpool ? 'Seat booked.' : 'You\'re signed up. Thank you!',
    );
    // Refresh on failure too: "spot is full" means someone just beat us to it.
    onChanged();
  }

  Future<int?> _pickChild(BuildContext context, List<Json> kids) => showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Who is riding?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            for (final k in kids)
              ListTile(
                leading: const Icon(Icons.child_care_rounded),
                title: Text(k['full_name'] as String),
                onTap: () => Navigator.pop(context, k['id'] as int),
              ),
          ]),
        ),
      );

  Future<void> _removeSlot(BuildContext context, WidgetRef ref) async {
    final sure = await confirm(context, title: 'Remove "${slot['label']}"?', message: 'Anyone signed up for it will be removed too.', action: 'Remove', danger: true);
    if (sure && context.mounted && await runAction(context, () => ref.read(apiClientProvider).removeSlot(slot['id'] as int))) {
      onChanged();
    }
  }
}

class NewSignupScreen extends ConsumerStatefulWidget {
  const NewSignupScreen({super.key, required this.team});

  final Json team;

  @override
  ConsumerState<NewSignupScreen> createState() => _NewSignupScreenState();
}

class _NewSignupScreenState extends ConsumerState<NewSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final List<({TextEditingController label, int capacity})> _slots = [];
  late String _type = widget.team['role'] == 'coach' ? 'volunteer' : 'carpool';
  int? _eventId;
  bool _busy = false;

  int get _teamId => widget.team['id'] as int;

  @override
  void initState() {
    super.initState();
    _addSlot('Snacks', 2);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final s in _slots) {
      s.label.dispose();
    }
    super.dispose();
  }

  void _addSlot([String label = '', int capacity = 1]) =>
      setState(() => _slots.add((label: TextEditingController(text: label), capacity: capacity)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final body = <String, dynamic>{
      'type': _type,
      'title': _title.text.trim(),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'event_id': _eventId,
      if (_type == 'volunteer')
        'slots': [
          for (final s in _slots)
            if (s.label.text.trim().isNotEmpty) {'label': s.label.text.trim(), 'capacity': s.capacity},
        ],
    };

    final ok = await runAction(context, () => ref.read(apiClientProvider).createSignup(_teamId, body),
        success: 'Posted. The team has been notified.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.invalidate(signupsProvider(_teamId));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCoach = widget.team['role'] == 'coach';
    final events = ref.watch(teamEventsProvider(_teamId)).value?.cast<Json>().where((e) => e['status'] != 'cancelled').take(12).toList() ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(_type == 'carpool' ? 'Start a carpool' : 'New volunteer sign-up')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isCoach) ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'volunteer', label: Text('Volunteers'), icon: Icon(Icons.volunteer_activism_outlined)),
                  ButtonSegment(value: 'carpool', label: Text('Carpool'), icon: Icon(Icons.directions_car_outlined)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Title', hintText: _type == 'carpool' ? 'Carpool to Westfield' : 'Game day helpers'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Add a title' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _eventId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'For which event? (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Not linked to an event')),
                for (final e in events)
                  DropdownMenuItem(
                    value: e['id'] as int,
                    child: Text('${e['title']} · ${dayLabel(parseTime(e['starts_at'] as String))}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _eventId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Details (optional)'),
            ),
            if (_type == 'volunteer') ...[
              const SectionTitle('Spots to fill'),
              for (var i = 0; i < _slots.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _slots[i].label,
                        decoration: const InputDecoration(hintText: 'e.g. Scorekeeper', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _slots[i].capacity,
                      items: [for (var n = 1; n <= 6; n++) DropdownMenuItem(value: n, child: Text('$n ${n == 1 ? 'person' : 'people'}'))],
                      onChanged: (n) => setState(() => _slots[i] = (label: _slots[i].label, capacity: n!)),
                    ),
                    IconButton(
                      onPressed: _slots.length == 1 ? null : () => setState(() => _slots.removeAt(i).label.dispose()),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ]),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(onPressed: _addSlot, icon: const Icon(Icons.add_rounded), label: const Text('Add spot')),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('After posting, drivers tap "Offer a ride" to add their car and free seats.',
                    style: TextStyle(color: AppColors.slate)),
              ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Posting...' : 'Post to team')),
          ],
        ),
      ),
    );
  }
}
