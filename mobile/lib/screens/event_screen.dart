import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/event_card.dart';
import 'event_form_screen.dart';

class EventScreen extends ConsumerWidget {
  const EventScreen({super.key, required this.eventId});

  final int eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(eventDetailProvider(eventId));
    final event = detail.value?['event'] as Json?;
    final team = event?['team'] as Json?;

    // The event payload has no role, but the teams list does.
    final teams = ref.watch(teamsProvider).value ?? [];
    final isCoach = teams.any((t) => (t as Json)['id'] == event?['team_id'] && t['role'] == 'coach');
    final cancelled = event?['status'] == 'cancelled';

    return Scaffold(
      appBar: AppBar(
        title: Text(team?['name'] as String? ?? 'Event'),
        actions: [
          if (isCoach && event != null && !cancelled)
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => EventFormScreen(team: {...team!, 'role': 'coach'}, event: event)));
                } else {
                  showCancelEventSheet(context, ref, event);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'cancel', child: Text('Cancel event', style: TextStyle(color: AppColors.red))),
              ],
            ),
        ],
      ),
      body: AsyncBody(
        value: detail,
        onRefresh: () => ref.refresh(eventDetailProvider(eventId).future),
        builder: (data) {
          final event = data['event'] as Json;
          final players = (data['players'] as List<dynamic>).cast<Json>();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _Header(event: event),
              for (final child in (event['my_children'] as List<dynamic>).cast<Json>())
                if (!cancelled)
                  Card(
                    margin: const EdgeInsets.only(top: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: RsvpRow(eventId: eventId, teamId: event['team_id'] as int, child: child),
                    ),
                  ),
              if (isCoach)
                _CoachPanel(event: event, players: players)
              else
                _RsvpSummary(counts: event['rsvp_counts'] as Json),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.event});

  final Json event;

  @override
  Widget build(BuildContext context) {
    final start = parseTime(event['starts_at'] as String);
    final end = event['ends_at'] == null ? null : parseTime(event['ends_at'] as String);
    final cancelled = event['status'] == 'cancelled';
    final location = event['location'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cancelled)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.redSoft, borderRadius: BorderRadius.circular(12)),
            child: const Text('This event has been cancelled.', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
          ),
        Text(event['title'] as String, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _Detail(Icons.event_rounded, '${fullDateTime(start)}${end != null ? ' – ${timeLabel(end)}' : ''}'),
        if (location != null)
          _Detail(
            Icons.place_outlined,
            location,
            trailing: TextButton(
              onPressed: () => launchUrl(
                Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': location}),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Directions'),
            ),
          ),
        if (event['notes'] != null) _Detail(Icons.notes_rounded, event['notes'] as String),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.icon, this.text, {this.trailing});

  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.slate),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
          ?trailing,
        ],
      ),
    );
  }
}

class _RsvpSummary extends StatelessWidget {
  const _RsvpSummary({required this.counts});

  final Json counts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Team RSVPs'),
        Row(children: [
          _Count('${counts['going']}', 'Going', AppColors.green),
          _Count('${counts['maybe']}', 'Maybe', AppColors.amber),
          _Count('${counts['not_going']}', "Can't", AppColors.red),
        ]),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.only(right: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: const TextStyle(color: AppColors.slate, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

/// The coach sees every player's RSVP, and once the event has started,
/// ticks off who actually showed up.
class _CoachPanel extends ConsumerStatefulWidget {
  const _CoachPanel({required this.event, required this.players});

  final Json event;
  final List<Json> players;

  @override
  ConsumerState<_CoachPanel> createState() => _CoachPanelState();
}

class _CoachPanelState extends ConsumerState<_CoachPanel> {
  // Local edits that haven't been saved yet.
  final Map<int, bool> _present = {};
  bool _saving = false;

  bool get _started => parseTime(widget.event['starts_at'] as String).isBefore(DateTime.now().add(const Duration(minutes: 30)));

  /// Before attendance was taken, assume RSVP "going" players came, so the
  /// coach usually only has to untick one or two.
  bool _isPresent(Json p) => _present[p['id']] ?? p['present'] as bool? ?? p['rsvp'] == 'going';

  Future<void> _save() async {
    setState(() => _saving = true);
    final all = {for (final p in widget.players) p['id'] as int: _isPresent(p)};
    final ok = await runAction(
      context,
      () => ref.read(apiClientProvider).saveAttendance(widget.event['id'] as int, all),
      success: 'Attendance saved: ${all.values.where((v) => v).length} of ${all.length} present.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _present.clear();
      ref.invalidate(eventDetailProvider(widget.event['id'] as int));
      ref.invalidate(attendanceReportProvider(widget.event['team_id'] as int));
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = widget.event['rsvp_counts'] as Json;
    final noAnswer = widget.players.where((p) => p['rsvp'] == null).length;
    final cancelled = widget.event['status'] == 'cancelled';
    final taken = widget.players.any((p) => p['present'] != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          _started && !cancelled ? 'Attendance' : 'Who\'s coming',
          trailing: Text('${counts['going']} going · ${counts['maybe']} maybe · $noAnswer no reply',
              style: const TextStyle(fontSize: 12, color: AppColors.slate)),
        ),
        Card(
          child: Column(
            children: [
              for (final p in widget.players) ...[
                if (p != widget.players.first) const Divider(indent: 16, endIndent: 16),
                if (_started && !cancelled)
                  CheckboxListTile(
                    value: _isPresent(p),
                    onChanged: (v) => setState(() => _present[p['id'] as int] = v!),
                    title: Text(_name(p)),
                    subtitle: Text(_rsvpText(p['rsvp'] as String?), style: TextStyle(color: _rsvpColor(p['rsvp'] as String?))),
                    dense: true,
                  )
                else
                  ListTile(
                    dense: true,
                    title: Text(_name(p)),
                    trailing: Text(_rsvpText(p['rsvp'] as String?),
                        style: TextStyle(color: _rsvpColor(p['rsvp'] as String?), fontWeight: FontWeight.w600)),
                  ),
              ],
            ],
          ),
        ),
        if (_started && !cancelled) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : taken ? 'Update attendance' : 'Save attendance'),
          ),
        ],
      ],
    );
  }

  static String _name(Json p) => '${p['jersey_number'] != null ? '#${p['jersey_number']}  ' : ''}${p['full_name']}';

  static String _rsvpText(String? rsvp) => switch (rsvp) {
        'going' => 'Going',
        'maybe' => 'Maybe',
        'not_going' => "Can't make it",
        _ => 'No reply',
      };

  static Color _rsvpColor(String? rsvp) => switch (rsvp) {
        'going' => AppColors.green,
        'maybe' => const Color(0xFFB45309),
        'not_going' => AppColors.red,
        _ => AppColors.slate,
      };
}
