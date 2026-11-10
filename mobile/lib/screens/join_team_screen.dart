import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../theme/app_theme.dart';
import 'team_screen.dart';

class JoinTeamScreen extends ConsumerStatefulWidget {
  const JoinTeamScreen({super.key});

  @override
  ConsumerState<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends ConsumerState<JoinTeamScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Team codes are 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final team = await ref.read(apiClientProvider).joinTeam(_code.text);
      ref.invalidate(teamsProvider);
      ref.invalidate(upcomingEventsProvider);
      if (!mounted) return;
      // Straight to the roster, where the parent links their child.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TeamScreen(teamId: team['id'] as int, initialTab: TeamTab.roster, justJoined: true)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a team')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Enter the code from your coach', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('It\'s 6 letters and numbers, like LIONS7.', style: TextStyle(color: AppColors.slate)),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            autofocus: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')), _UpperCase()],
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 8),
            decoration: InputDecoration(counterText: '', errorText: _error, hintText: '······'),
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _join,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Join team'),
          ),
        ],
      ),
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
