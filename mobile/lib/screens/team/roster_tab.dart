import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class RosterTab extends ConsumerWidget {
  const RosterTab({super.key, required this.team, this.justJoined = false});

  final Json team;
  final bool justJoined;

  int get _teamId => team['id'] as int;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCoach = team['role'] == 'coach';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerFormScreen(teamId: _teamId, isCoach: isCoach))),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(isCoach ? 'Add player' : 'Add my child'),
      ),
      body: AsyncBody(
        value: ref.watch(teamDetailProvider(_teamId)),
        onRefresh: () => ref.refresh(teamDetailProvider(_teamId).future),
        builder: (data) {
          final players = (data['players'] as List<dynamic>).cast<Json>();
          final coaches = (data['coaches'] as List<dynamic>).cast<Json>();
          final hasChild = players.any((p) => p['is_my_child'] == true);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              if (!isCoach && !hasChild) _LinkChildBanner(justJoined: justJoined),
              if (isCoach && team['join_code'] != null) _JoinCodeCard(code: team['join_code'] as String, parents: data['parent_count'] as int),
              const SectionTitle('Coaches'),
              Card(
                child: Column(children: [
                  for (final c in coaches)
                    ListTile(
                      leading: CircleAvatar(backgroundColor: AppColors.tealSoft, child: Text(initials(c['name'] as String))),
                      title: Text(c['name'] as String),
                      subtitle: Text(c['email'] as String? ?? ''),
                      trailing: c['phone'] == null ? null : _CallButton(phone: c['phone'] as String),
                    ),
                  if (coaches.isEmpty) const ListTile(title: Text('No coach assigned yet')),
                ]),
              ),
              SectionTitle('Players (${players.length})'),
              Card(
                child: Column(children: [
                  for (final p in players) ...[
                    if (p != players.first) const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: p['is_my_child'] == true ? AppColors.teal : AppColors.background,
                        foregroundColor: p['is_my_child'] == true ? Colors.white : AppColors.ink,
                        child: Text(p['jersey_number']?.toString() ?? '–', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      title: Text(p['full_name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text([p['position'], if (p['is_my_child'] == true) 'Your child'].whereType<String>().join(' · ')),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
                      onTap: () => _showPlayer(context, ref, p, isCoach),
                    ),
                  ],
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPlayer(BuildContext context, WidgetRef ref, Json p, bool isCoach) {
    final mine = p['is_my_child'] == true;
    final guardians = (p['guardians'] as List<dynamic>).cast<Json>();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p['full_name'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text([if (p['jersey_number'] != null) '#${p['jersey_number']}', p['position']].whereType<String>().join(' · '),
                  style: const TextStyle(color: AppColors.slate)),
              const SizedBox(height: 12),
              for (final g in guardians)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.family_restroom_rounded),
                  title: Text(g['name'] as String),
                  subtitle: const Text('Parent'),
                  trailing: g['phone'] == null ? null : _CallButton(phone: g['phone'] as String),
                ),
              // Only filled in by the server for coaches and the child's own parents.
              if (p['date_of_birth'] != null) _Private('Birthday', p['date_of_birth'] as String),
              if (p['emergency_contact_name'] != null)
                _Private('Emergency contact', '${p['emergency_contact_name']}  ${p['emergency_contact_phone'] ?? ''}'),
              if (p['medical_notes'] != null) _Private('Medical notes', p['medical_notes'] as String, warn: true),
              const SizedBox(height: 12),
              if (mine || isCoach)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheet);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerFormScreen(teamId: _teamId, isCoach: isCoach, player: p)));
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit details'),
                ),
              if (!mine && !isCoach)
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheet);
                    final ok = await runAction(context, () => ref.read(apiClientProvider).claimPlayer(p['id'] as int),
                        success: '${p['first_name']} is now linked to you.');
                    if (ok) {
                      ref.invalidate(teamDetailProvider(_teamId));
                      ref.invalidate(upcomingEventsProvider);
                    }
                  },
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('This is my child'),
                ),
              if (isCoach)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.red),
                  onPressed: () async {
                    Navigator.pop(sheet);
                    final sure = await confirm(context, title: 'Remove ${p['full_name']}?', message: 'Their RSVPs and attendance history will be deleted.', action: 'Remove', danger: true);
                    if (sure && context.mounted && await runAction(context, () => ref.read(apiClientProvider).removePlayer(p['id'] as int))) {
                      ref.invalidate(teamDetailProvider(_teamId));
                    }
                  },
                  child: const Text('Remove from team'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkChildBanner extends StatelessWidget {
  const _LinkChildBanner({required this.justJoined});

  final bool justJoined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.tealSoft, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(justJoined ? 'You\'re in! One last step.' : 'Link your child',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.tealDark)),
        const SizedBox(height: 4),
        const Text(
          'Find your child below and tap "This is my child", or add them if the coach hasn\'t yet. '
          'Then you can RSVP for practices and games.',
          style: TextStyle(color: AppColors.tealDark),
        ),
      ]),
    );
  }
}

class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({required this.code, required this.parents});

  final String code;
  final int parents;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Parent join code', style: TextStyle(color: AppColors.slate, fontSize: 12)),
              Text(code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 4)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$parents', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.teal)),
            const Text('parents joined', style: TextStyle(color: AppColors.slate, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

class _Private extends StatelessWidget {
  const _Private(this.label, this.value, {this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: warn ? AppColors.amberSoft : AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Call',
      icon: const Icon(Icons.call_outlined, color: AppColors.teal),
      onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
    );
  }
}

/// Add a player (coach), add my child (parent), or edit an existing player.
class PlayerFormScreen extends ConsumerStatefulWidget {
  const PlayerFormScreen({super.key, required this.teamId, required this.isCoach, this.player});

  final int teamId;
  final bool isCoach;
  final Json? player;

  @override
  ConsumerState<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends ConsumerState<PlayerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _f = {
    for (final key in ['first_name', 'last_name', 'jersey_number', 'position', 'date_of_birth', 'emergency_contact_name', 'emergency_contact_phone', 'medical_notes'])
      key: TextEditingController(text: widget.player?[key]?.toString()),
  };
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_f['date_of_birth']!.text) ?? DateTime(now.year - 9),
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (date != null) _f['date_of_birth']!.text = date.toIso8601String().substring(0, 10);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final body = {
      for (final e in _f.entries) e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
      'jersey_number': int.tryParse(_f['jersey_number']!.text.trim()),
    };
    final api = ref.read(apiClientProvider);
    final editing = widget.player != null;

    final ok = await runAction(
      context,
      () => editing ? api.updatePlayer(widget.player!['id'] as int, body) : api.addPlayer(widget.teamId, body).then((_) {}),
      success: editing ? 'Saved.' : '${_f['first_name']!.text.trim()} added to the roster.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.invalidate(teamDetailProvider(widget.teamId));
      ref.invalidate(upcomingEventsProvider);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.player != null;
    String? required(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit player' : widget.isCoach ? 'Add player' : 'Add my child')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(child: _field('first_name', 'First name', validator: required)),
              const SizedBox(width: 12),
              Expanded(child: _field('last_name', 'Last name', validator: required)),
            ]),
            Row(children: [
              SizedBox(width: 110, child: _field('jersey_number', 'Jersey #', keyboard: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _field('position', 'Position')),
            ]),
            _field('date_of_birth', 'Birthday', readOnly: true, onTap: _pickBirthday),
            const SectionTitle('Private: only coaches and this child\'s parents see this'),
            _field('emergency_contact_name', 'Emergency contact name'),
            _field('emergency_contact_phone', 'Emergency contact phone', keyboard: TextInputType.phone),
            _field('medical_notes', 'Allergies or medical notes', lines: 3),
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'Save')),
          ],
        ),
      ),
    );
  }

  Widget _field(String key, String label,
      {String? Function(String?)? validator, TextInputType? keyboard, int lines = 1, bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _f[key],
        validator: validator,
        keyboardType: keyboard,
        maxLines: lines,
        readOnly: readOnly,
        onTap: onTap,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: label, suffixIcon: readOnly ? const Icon(Icons.calendar_today_outlined, size: 18) : null),
      ),
    );
  }
}
