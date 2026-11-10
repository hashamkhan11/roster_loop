import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'event_screen.dart';
import 'team_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    if (await runAction(context, () => ref.read(apiClientProvider).markNotificationsRead())) {
      ref.invalidate(notificationsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(notificationsProvider);
    final unread = value.value?['unread_count'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          if (unread > 0) TextButton(onPressed: () => _markAllRead(context, ref), child: const Text('Mark all read')),
        ],
      ),
      body: AsyncBody(
        value: value,
        onRefresh: () => ref.refresh(notificationsProvider.future),
        builder: (data) {
          final list = (data['notifications'] as List<dynamic>).cast<Json>();
          if (list.isEmpty) {
            return ListView(children: const [
              EmptyState(icon: Icons.inbox_outlined, title: 'All quiet', message: 'Schedule changes, reminders and team messages land here.'),
            ]);
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) => _NotificationTile(n: list[i]),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.n});

  final Json n;

  @override
  Widget build(BuildContext context) {
    final unread = n['read_at'] == null;
    final type = n['type'] as String;
    final (icon, color) = switch (type) {
      'event_cancelled' => (Icons.event_busy_rounded, AppColors.red),
      'event_reminder' => (Icons.alarm_rounded, AppColors.amber),
      'broadcast' => (Icons.campaign_rounded, AppColors.teal),
      'signup' => (Icons.volunteer_activism_rounded, AppColors.green),
      _ => (Icons.event_rounded, AppColors.teal),
    };

    return ListTile(
      tileColor: unread ? AppColors.tealSoft.withValues(alpha: 0.35) : null,
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 20)),
      title: Text(n['title'] as String, style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
      subtitle: Text(n['body'] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(timeAgo(n['created_at'] as String), style: const TextStyle(fontSize: 12, color: AppColors.slate)),
      onTap: () => _open(context, type),
    );
  }

  /// Jump to whatever the notification is about. The push payload stores ids
  /// as strings (FCM data must be strings), so parse them back.
  void _open(BuildContext context, String type) {
    final data = (n['data'] as Map?)?.cast<String, dynamic>() ?? {};
    final eventId = int.tryParse('${data['event_id']}');
    final teamId = n['team_id'] as int?;

    final Widget? screen = eventId != null
        ? EventScreen(eventId: eventId)
        : teamId == null
            ? null
            : TeamScreen(teamId: teamId, initialTab: type == 'signup' ? TeamTab.signups : TeamTab.messages);
    if (screen != null) Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
