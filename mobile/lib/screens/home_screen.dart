import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/event_card.dart';
import 'join_team_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authProvider.select((s) => s.user?['name'] as String?));
    final events = ref.watch(upcomingEventsProvider);
    final teams = ref.watch(teamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Logo(size: 22)),
      body: AsyncBody(
        value: events,
        onRefresh: () async {
          ref.invalidate(teamsProvider);
          return ref.refresh(upcomingEventsProvider.future);
        },
        builder: (list) {
          if (teams.value?.isEmpty ?? false) {
            return ListView(children: [
              EmptyState(
                icon: Icons.sports_soccer_rounded,
                title: 'Join your first team',
                message: 'Ask your coach for the 6-letter team code.',
                action: FilledButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinTeamScreen())),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Enter team code'),
                ),
              ),
            ]);
          }

          final events = list.cast<Json>();
          // Only nag about this week; later events still have RSVP buttons below.
          final weekAhead = DateTime.now().add(const Duration(days: 7));
          bool urgent(Json e) => _waitingOnMe(e) && parseTime(e['starts_at'] as String).isBefore(weekAhead);
          final needsAnswer = events.where(urgent).toList();
          final rest = events.where((e) => !urgent(e)).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text(name == null ? 'Hello!' : 'Hi, ${name.split(' ').first}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(_summary(events), style: const TextStyle(color: AppColors.slate)),
              if (needsAnswer.isNotEmpty) ...[
                SectionTitle('Needs your answer (${needsAnswer.length})'),
                for (final e in needsAnswer) _spaced(EventCard(event: e, showTeam: true)),
              ],
              if (rest.isNotEmpty) ...[
                const SectionTitle('Coming up'),
                for (final e in rest) _spaced(EventCard(event: e, showTeam: true)),
              ],
              if (events.isEmpty)
                const EmptyState(icon: Icons.event_available_rounded, title: 'Nothing scheduled', message: 'New practices and games will show up here.'),
            ],
          );
        },
      ),
    );
  }

  /// A scheduled event where one of my kids hasn't been answered for yet.
  static bool _waitingOnMe(Json e) =>
      e['status'] != 'cancelled' && (e['my_children'] as List<dynamic>).any((c) => (c as Json)['rsvp'] == null);

  static String _summary(List<Json> events) {
    final today = events.where((e) => e['status'] != 'cancelled' && dayLabel(parseTime(e['starts_at'] as String)) == 'Today').length;
    if (today == 0) return 'Nothing on today.';
    return today == 1 ? 'You have 1 event today.' : 'You have $today events today.';
  }

  static Widget _spaced(Widget child) => Padding(padding: const EdgeInsets.only(bottom: 10), child: child);
}
