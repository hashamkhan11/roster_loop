import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../screens/event_screen.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'common.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.showTeam = false, this.color});

  final Json event;
  final bool showTeam;

  /// Team schedule lists don't include the team object, so they pass its color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final start = parseTime(event['starts_at'] as String);
    final cancelled = event['status'] == 'cancelled';
    final isGame = event['type'] == 'game';
    final team = event['team'] as Json?;
    final children = (event['my_children'] as List<dynamic>? ?? []).cast<Json>();
    final counts = event['rsvp_counts'] as Json? ?? {};

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventScreen(eventId: event['id'] as int))),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: cancelled ? AppColors.line : (color ?? AppColors.fromHex(team?['color'] as String?))),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (cancelled)
                            const Pill('CANCELLED', color: AppColors.red, background: AppColors.redSoft)
                          else
                            Pill(isGame ? 'GAME' : 'PRACTICE',
                                color: isGame ? const Color(0xFFB45309) : AppColors.tealDark,
                                background: isGame ? AppColors.amberSoft : AppColors.tealSoft),
                          const Spacer(),
                          if (showTeam && team != null)
                            Text(team['name'] as String, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event['title'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: cancelled ? TextDecoration.lineThrough : null,
                          color: cancelled ? AppColors.slate : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _InfoLine(Icons.schedule_rounded, '${dayLabel(start)} · ${timeLabel(start)}'),
                      if (event['location'] != null) _InfoLine(Icons.place_outlined, event['location'] as String),
                      if (!cancelled) ...[
                        for (final child in children)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: RsvpRow(eventId: event['id'] as int, teamId: event['team_id'] as int, child: child),
                          ),
                        if (children.isEmpty && (counts['going'] ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('${counts['going']} going · ${counts['maybe']} maybe · ${counts['not_going']} can\'t make it',
                                style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.slate),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.slate), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// "Is Ayaan coming?" with Going / Maybe / No buttons for one child.
class RsvpRow extends ConsumerStatefulWidget {
  const RsvpRow({super.key, required this.eventId, required this.teamId, required this.child});

  final int eventId;
  final int teamId;
  final Json child;

  @override
  ConsumerState<RsvpRow> createState() => _RsvpRowState();
}

class _RsvpRowState extends ConsumerState<RsvpRow> {
  // Shown straight away when tapped (an "optimistic update"), so the button
  // feels instant; it goes back to the old answer if the server says no.
  String? _answer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _answer = widget.child['rsvp'] as String?;
  }

  @override
  void didUpdateWidget(RsvpRow old) {
    super.didUpdateWidget(old);
    if (!_saving) _answer = widget.child['rsvp'] as String?;
  }

  Future<void> _set(String answer) async {
    if (_saving || answer == _answer) return;
    final previous = _answer;
    setState(() {
      _answer = answer;
      _saving = true;
    });

    final ok = await runAction(
      context,
      () => ref.read(apiClientProvider).rsvp(widget.eventId, widget.child['player_id'] as int, answer),
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) _answer = previous;
    });
    if (ok) {
      ref.invalidate(upcomingEventsProvider);
      ref.invalidate(teamEventsProvider(widget.teamId));
      ref.invalidate(eventDetailProvider(widget.eventId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _answer == null ? 'Is ${widget.child['first_name']} coming?' : widget.child['first_name'] as String,
            style: TextStyle(fontSize: 13, fontWeight: _answer == null ? FontWeight.w600 : FontWeight.w500),
          ),
        ),
        _choice('going', 'Going', AppColors.green, AppColors.greenSoft),
        const SizedBox(width: 6),
        _choice('maybe', 'Maybe', const Color(0xFFB45309), AppColors.amberSoft),
        const SizedBox(width: 6),
        _choice('not_going', 'No', AppColors.red, AppColors.redSoft),
      ],
    );
  }

  Widget _choice(String value, String label, Color color, Color soft) {
    final selected = _answer == value;
    return GestureDetector(
      onTap: () => _set(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? soft : Colors.white,
          border: Border.all(color: selected ? color : AppColors.line),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? color : AppColors.slate)),
      ),
    );
  }
}
