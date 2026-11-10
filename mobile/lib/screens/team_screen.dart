import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'team/broadcasts_tab.dart';
import 'team/roster_tab.dart';
import 'team/schedule_tab.dart';
import 'team/signups_tab.dart';

enum TeamTab { schedule, messages, signups, roster }

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key, required this.teamId, this.initialTab = TeamTab.schedule, this.justJoined = false});

  final int teamId;
  final TeamTab initialTab;
  final bool justJoined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(teamDetailProvider(teamId));
    final team = detail.value?['team'] as Json?;
    final isCoach = team?['role'] == 'coach';

    return DefaultTabController(
      length: TeamTab.values.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text(team?['name'] as String? ?? ''),
          actions: [
            if (team != null)
              PopupMenuButton<String>(
                onSelected: (action) => _onMenu(context, ref, action, team),
                itemBuilder: (_) => [
                  if (isCoach) const PopupMenuItem(value: 'code', child: Text('Share join code')),
                  if (isCoach) const PopupMenuItem(value: 'report', child: Text('Attendance report')),
                  const PopupMenuItem(value: 'leave', child: Text('Leave team')),
                ],
              ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [Tab(text: 'Schedule'), Tab(text: 'Messages'), Tab(text: 'Sign-ups'), Tab(text: 'Roster')],
          ),
        ),
        body: detail.hasError && team == null
            ? AsyncBody(value: detail, onRefresh: () => ref.refresh(teamDetailProvider(teamId).future), builder: (_) => const SizedBox())
            : team == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      ScheduleTab(team: team),
                      BroadcastsTab(team: team),
                      SignupsTab(team: team),
                      RosterTab(team: team, justJoined: justJoined),
                    ],
                  ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String action, Json team) async {
    switch (action) {
      case 'code':
        final code = team['join_code'] as String;
        await Clipboard.setData(ClipboardData(text: 'Join ${team['name']} on RosterLoop with code $code'));
        if (context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Parent join code'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                SelectableText(code, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 8)),
                const SizedBox(height: 8),
                const Text('Copied to your clipboard. Paste it in your team group chat one last time!',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.slate)),
              ]),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
            ),
          );
        }
      case 'report':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceReportScreen(team: team)));
      case 'leave':
        final sure = await confirm(context,
            title: 'Leave ${team['name']}?', message: 'You will stop getting its messages and schedule.', action: 'Leave', danger: true);
        if (!sure || !context.mounted) return;
        final ok = await runAction(context, () => ref.read(apiClientProvider).leaveTeam(teamId));
        if (ok && context.mounted) {
          ref.invalidate(teamsProvider);
          ref.invalidate(upcomingEventsProvider);
          Navigator.pop(context);
        }
    }
  }
}

class AttendanceReportScreen extends ConsumerWidget {
  const AttendanceReportScreen({super.key, required this.team});

  final Json team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = team['id'] as int;

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: AsyncBody(
        value: ref.watch(attendanceReportProvider(teamId)),
        onRefresh: () => ref.refresh(attendanceReportProvider(teamId).future),
        builder: (rows) {
          // Lowest attendance first: those are the families a coach checks in with.
          final sorted = rows.cast<Json>().toList()
            ..sort((a, b) => ((a['rate'] as num?) ?? 101).compareTo((b['rate'] as num?) ?? 101));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = sorted[i];
              final rate = (r['rate'] as num?)?.toInt();
              final color = rate == null ? AppColors.slate : rate >= 85 ? AppColors.green : rate >= 70 ? AppColors.amber : AppColors.red;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text('${r['jersey_number'] != null ? '#${r['jersey_number']}  ' : ''}${r['full_name']}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Text(rate == null ? 'No data' : '$rate%', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                            value: (rate ?? 0) / 100, minHeight: 6, color: color, backgroundColor: AppColors.line),
                      ),
                      const SizedBox(height: 4),
                      Text('${r['attended']} of ${r['total']} events', style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
