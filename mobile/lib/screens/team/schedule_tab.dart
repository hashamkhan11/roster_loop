import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/data_providers.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/event_card.dart';
import '../event_form_screen.dart';

class ScheduleTab extends ConsumerStatefulWidget {
  const ScheduleTab({super.key, required this.team});

  final Json team;

  @override
  ConsumerState<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends ConsumerState<ScheduleTab> {
  bool _past = false;

  int get _teamId => widget.team['id'] as int;

  @override
  Widget build(BuildContext context) {
    final isCoach = widget.team['role'] == 'coach';
    final provider = _past ? pastEventsProvider(_teamId) : teamEventsProvider(_teamId);
    final color = AppColors.fromHex(widget.team['color'] as String?);

    return Scaffold(
      floatingActionButton: isCoach
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventFormScreen(team: widget.team))),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New event'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Upcoming')),
                ButtonSegment(value: true, label: Text('Past')),
              ],
              selected: {_past},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _past = s.first),
            ),
          ),
          Expanded(
            child: AsyncBody(
              value: ref.watch(provider),
              onRefresh: () => ref.refresh(provider.future),
              builder: (events) {
                if (events.isEmpty) {
                  return ListView(children: [
                    EmptyState(
                      icon: Icons.event_note_rounded,
                      title: _past ? 'No past events' : 'Nothing scheduled yet',
                      message: isCoach && !_past ? 'Add practices once and repeat them weekly.' : null,
                    ),
                  ]);
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => EventCard(event: events[i] as Json, color: color),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
