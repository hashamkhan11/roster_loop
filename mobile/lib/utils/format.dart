import 'package:intl/intl.dart';

/// The server stores every time in UTC; the phone shows it in local time.
DateTime parseTime(String iso) => DateTime.parse(iso).toLocal();

String dayLabel(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = day.difference(today).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff > 1 && diff < 7) return DateFormat('EEEE').format(t);
  return DateFormat('EEE, MMM d').format(t);
}

String timeLabel(DateTime t) => DateFormat('h:mm a').format(t);

String fullDateTime(DateTime t) => DateFormat("EEE, MMM d 'at' h:mm a").format(t);

/// "5m ago", "3h ago", "Mon".
String timeAgo(String iso) {
  final t = parseTime(iso);
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return DateFormat('EEE').format(t);
  return DateFormat('MMM d').format(t);
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
}
