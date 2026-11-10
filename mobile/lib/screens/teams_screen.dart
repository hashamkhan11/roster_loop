import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/data_providers.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'join_team_screen.dart';
import 'team_screen.dart';

class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openJoin() => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinTeamScreen()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My teams'),
        actions: [IconButton(onPressed: openJoin, icon: const Icon(Icons.add_rounded), tooltip: 'Join a team')],
      ),
      body: AsyncBody(
        value: ref.watch(teamsProvider),
        onRefresh: () => ref.refresh(teamsProvider.future),
        builder: (teams) {
          if (teams.isEmpty) {
            return ListView(children: [
              EmptyState(
                icon: Icons.groups_rounded,
                title: 'No teams yet',
                message: 'Join with the code from your coach.',
                action: FilledButton(onPressed: openJoin, child: const Text('Enter team code')),
              ),
            ]);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: teams.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _TeamTile(team: teams[i] as Json),
          );
        },
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({required this.team});

  final Json team;

  @override
  Widget build(BuildContext context) {
    final isCoach = team['role'] == 'coach';
    final color = AppColors.fromHex(team['color'] as String?);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color,
          child: Text(_badge(team), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        title: Text(team['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${(team['league'] as Json?)?['name'] ?? ''}\n${team['players_count']} players'),
        isThreeLine: true,
        trailing: isCoach
            ? const Pill('COACH', color: AppColors.tealDark, background: AppColors.tealSoft)
            : const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeamScreen(teamId: team['id'] as int))),
      ),
    );
  }

  /// "Under 10" -> "U10". Every team name tends to start with "U", so a plain
  /// first letter can't tell teams apart.
  static String _badge(Json team) {
    final age = RegExp(r'\d+').firstMatch(team['age_group'] as String? ?? '')?.group(0);
    return age != null ? 'U$age' : (team['name'] as String).characters.first;
  }
}
