import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import 'auth_provider.dart';
import 'navigation_provider.dart';

// Every screen reads its data through one of these providers. After a change
// (RSVP, new message...), the screen calls ref.invalidate(provider) and
// everything showing that data reloads by itself. `autoDispose` frees the
// data when no screen is using it, and `family` makes one cache per team or
// event id.

final teamsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(apiClientProvider).teams();
});

final upcomingEventsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  ref.watch(refreshTickProvider);
  return ref.watch(apiClientProvider).upcomingEvents();
});

final teamDetailProvider = FutureProvider.autoDispose.family<Json, int>((ref, teamId) {
  return ref.watch(apiClientProvider).team(teamId);
});

final teamEventsProvider = FutureProvider.autoDispose.family<List<dynamic>, int>((ref, teamId) {
  ref.watch(refreshTickProvider);
  return ref.watch(apiClientProvider).teamEvents(teamId);
});

final pastEventsProvider = FutureProvider.autoDispose.family<List<dynamic>, int>((ref, teamId) {
  return ref.watch(apiClientProvider).teamEvents(teamId, past: true);
});

final eventDetailProvider = FutureProvider.autoDispose.family<Json, int>((ref, eventId) {
  return ref.watch(apiClientProvider).event(eventId);
});

final broadcastsProvider = FutureProvider.autoDispose.family<List<dynamic>, int>((ref, teamId) {
  ref.watch(refreshTickProvider);
  return ref.watch(apiClientProvider).broadcasts(teamId);
});

final signupsProvider = FutureProvider.autoDispose.family<List<dynamic>, int>((ref, teamId) {
  return ref.watch(apiClientProvider).signups(teamId);
});

final attendanceReportProvider = FutureProvider.autoDispose.family<List<dynamic>, int>((ref, teamId) {
  return ref.watch(apiClientProvider).attendanceReport(teamId);
});

final notificationsProvider = FutureProvider.autoDispose<Json>((ref) {
  ref.watch(refreshTickProvider);
  return ref.watch(apiClientProvider).notifications();
});
