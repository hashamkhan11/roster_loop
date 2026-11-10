import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class BroadcastsTab extends ConsumerWidget {
  const BroadcastsTab({super.key, required this.team});

  final Json team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = team['id'] as int;
    final isCoach = team['role'] == 'coach';

    return Scaffold(
      floatingActionButton: isCoach
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ComposeBroadcastScreen(team: team))),
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('Message team'),
            )
          : null,
      body: AsyncBody(
        value: ref.watch(broadcastsProvider(teamId)),
        onRefresh: () => ref.refresh(broadcastsProvider(teamId).future),
        builder: (list) {
          if (list.isEmpty) {
            return ListView(children: [
              EmptyState(
                icon: Icons.campaign_outlined,
                title: 'No messages yet',
                message: isCoach
                    ? 'Send one message to every parent, and see exactly who read it.'
                    : 'Announcements from your coach will show up here.',
              ),
            ]);
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _BroadcastCard(broadcast: list[i] as Json, isCoach: isCoach),
          );
        },
      ),
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard({required this.broadcast, required this.isCoach});

  final Json broadcast;
  final bool isCoach;

  @override
  Widget build(BuildContext context) {
    final unread = broadcast['read_by_me'] != true && !isCoach;
    final urgent = broadcast['is_urgent'] == true;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: urgent ? AppColors.red.withValues(alpha: 0.4) : AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => BroadcastScreen(broadcast: broadcast, isCoach: isCoach))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (unread) ...[
                  const CircleAvatar(radius: 4, backgroundColor: AppColors.teal),
                  const SizedBox(width: 8),
                ],
                if (urgent) ...[
                  const Pill('URGENT', color: AppColors.red, background: AppColors.redSoft),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(broadcast['title'] as String,
                      style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w600, fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(timeAgo(broadcast['created_at'] as String), style: const TextStyle(fontSize: 12, color: AppColors.slate)),
              ]),
              const SizedBox(height: 6),
              Text(broadcast['body'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.slate)),
              const SizedBox(height: 8),
              Row(children: [
                Text((broadcast['sender'] as Json?)?['name'] as String? ?? '', style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                const Spacer(),
                if (isCoach) _SeenBy(broadcast: broadcast),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeenBy extends StatelessWidget {
  const _SeenBy({required this.broadcast});

  final Json broadcast;

  @override
  Widget build(BuildContext context) {
    final seen = broadcast['reads_count'] as int;
    final total = broadcast['audience_count'] as int;
    final all = total > 0 && seen >= total;

    return Row(children: [
      Icon(all ? Icons.done_all_rounded : Icons.visibility_outlined, size: 15, color: all ? AppColors.teal : AppColors.slate),
      const SizedBox(width: 4),
      Text('Seen by $seen/$total',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: all ? AppColors.teal : AppColors.slate)),
    ]);
  }
}

class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key, required this.broadcast, required this.isCoach});

  final Json broadcast;
  final bool isCoach;

  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen> {
  Future<Json>? _readers;

  int get _id => widget.broadcast['id'] as int;
  int get _teamId => widget.broadcast['team_id'] as int;

  @override
  void initState() {
    super.initState();
    if (widget.isCoach) {
      _readers = ref.read(apiClientProvider).broadcastReaders(_id);
    } else if (widget.broadcast['read_by_me'] != true) {
      // Opening the message is what counts as "read" for the coach's receipt.
      ref.read(apiClientProvider).markBroadcastRead(_id).then((_) {
        ref.invalidate(broadcastsProvider(_teamId));
      }).catchError((_) {});
    }
  }

  Future<void> _delete() async {
    final sure = await confirm(context, title: 'Delete this message?', message: 'Parents will no longer see it.', action: 'Delete', danger: true);
    if (!sure || !mounted) return;
    final ok = await runAction(context, () => ref.read(apiClientProvider).deleteBroadcast(_id));
    if (ok && mounted) {
      ref.invalidate(broadcastsProvider(_teamId));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.broadcast;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message'),
        actions: [if (widget.isCoach) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (b['is_urgent'] == true) const Align(alignment: Alignment.centerLeft, child: Pill('URGENT', color: AppColors.red, background: AppColors.redSoft)),
          const SizedBox(height: 8),
          Text(b['title'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('${(b['sender'] as Json?)?['name'] ?? ''} · ${fullDateTime(parseTime(b['created_at'] as String))}',
              style: const TextStyle(color: AppColors.slate)),
          const SizedBox(height: 20),
          SelectableText(b['body'] as String, style: const TextStyle(fontSize: 16, height: 1.5)),
          if (_readers != null) _Readers(future: _readers!),
        ],
      ),
    );
  }
}

/// The coach's follow-up list: who hasn't opened the message, with a call button.
class _Readers extends StatelessWidget {
  const _Readers({required this.future});

  final Future<Json> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Json>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) return Padding(padding: const EdgeInsets.only(top: 24), child: Text('${snap.error}'));
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));

        final seen = (snap.data!['seen'] as List<dynamic>).cast<Json>();
        final notSeen = (snap.data!['not_seen'] as List<dynamic>).cast<Json>();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            SectionTitle('Not seen yet (${notSeen.length})'),
            if (notSeen.isEmpty)
              const Text('Everyone has read it.', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600)),
            for (final m in notSeen)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: AppColors.amberSoft, child: Text(initials(m['name'] as String))),
                title: Text(m['name'] as String),
                trailing: m['phone'] == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.call_outlined, color: AppColors.teal),
                        onPressed: () => launchUrl(Uri(scheme: 'tel', path: m['phone'] as String)),
                      ),
              ),
            SectionTitle('Seen (${seen.length})'),
            for (final m in seen)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: AppColors.tealSoft, child: Text(initials(m['name'] as String))),
                title: Text(m['name'] as String),
                trailing: Text(timeAgo(m['read_at'] as String), style: const TextStyle(color: AppColors.slate, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }
}

class ComposeBroadcastScreen extends ConsumerStatefulWidget {
  const ComposeBroadcastScreen({super.key, required this.team});

  final Json team;

  @override
  ConsumerState<ComposeBroadcastScreen> createState() => _ComposeBroadcastScreenState();
}

class _ComposeBroadcastScreenState extends ConsumerState<ComposeBroadcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _urgent = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final teamId = widget.team['id'] as int;

    final ok = await runAction(
      context,
      () => ref.read(apiClientProvider).sendBroadcast(teamId, title: _title.text.trim(), body: _body.text.trim(), urgent: _urgent),
      success: 'Sent to every parent on ${widget.team['name']}.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.invalidate(broadcastsProvider(teamId));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Message ${widget.team['name']}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Subject', hintText: 'Picture day on Saturday'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Add a subject' : null,
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _body,
              minLines: 5,
              maxLines: 12,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Write your message' : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _urgent,
              onChanged: (v) => setState(() => _urgent = v),
              title: const Text('Mark as urgent'),
              subtitle: const Text('For same-day changes, like a cancelled practice.'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _send,
              icon: const Icon(Icons.send_rounded),
              label: Text(_busy ? 'Sending...' : 'Send to team'),
            ),
          ],
        ),
      ),
    );
  }
}
