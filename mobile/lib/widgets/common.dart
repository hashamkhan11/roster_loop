import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size * 1.3,
          height: size * 1.3,
          decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(size * 0.35)),
          child: Icon(Icons.all_inclusive_rounded, color: Colors.white, size: size * 0.85),
        ),
        SizedBox(width: size * 0.4),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Roster'),
            TextSpan(text: 'Loop', style: TextStyle(color: AppColors.teal)),
          ]),
          style: TextStyle(fontSize: size * 0.8, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
      ],
    );
  }
}

/// Shows a spinner, a friendly error with a retry button, or the data.
/// Pull-to-refresh works in every state, so an offline error can be
/// retried with the same gesture people already use.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.onRefresh, required this.builder});

  final AsyncValue<T> value;
  final Future<void> Function() onRefresh;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: value.when(
        // Keep showing old data while a refresh runs, instead of a blank spinner.
        skipLoadingOnRefresh: true,
        data: builder,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.slate),
            const SizedBox(height: 12),
            Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate)),
            const SizedBox(height: 16),
            Center(child: OutlinedButton(onPressed: onRefresh, child: const Text('Try again'))),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.tealSoft,
            child: Icon(icon, color: AppColors.tealDark, size: 30),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, style: const TextStyle(color: AppColors.slate), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color = AppColors.slate, this.background = AppColors.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.3)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate, letterSpacing: 0.8)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

void showMessage(BuildContext context, Object messageOrError) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$messageOrError'), behavior: SnackBarBehavior.floating));
}

/// Runs a server action, shows its error as a snackbar, and returns whether
/// it worked. Saves writing the same try/catch on every button.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) showMessage(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showMessage(context, e);
    return false;
  }
}

Future<bool> confirm(BuildContext context, {required String title, String? message, String action = 'Confirm', bool danger = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: danger ? TextButton.styleFrom(foregroundColor: AppColors.red) : null,
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}
