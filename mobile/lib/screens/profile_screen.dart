import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final _user = ref.read(authProvider).user ?? {};
  late final _name = TextEditingController(text: _user['name'] as String?);
  late final _phone = TextEditingController(text: _user['phone'] as String?);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showMessage(context, 'Your name can\'t be empty.');
      return;
    }
    setState(() => _busy = true);
    await runAction(context, () async {
      final user = await ref.read(apiClientProvider).updateProfile(name: _name.text.trim(), phone: _phone.text.trim());
      ref.read(authProvider.notifier).updateUser(user);
    }, success: 'Profile saved.');
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _logout() async {
    if (await confirm(context, title: 'Log out?', action: 'Log out')) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user ?? {};
    final name = user['name'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              child: Text(initials(name), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text(user['email'] as String? ?? '', style: const TextStyle(color: AppColors.slate))),
          const SizedBox(height: 24),
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone', helperText: 'Coaches on your teams can call you about your child.'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'Save')),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
