import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppTab { home, teams, inbox, profile }

class SelectedTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void select(AppTab tab) => state = tab;
}

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, AppTab>(SelectedTabNotifier.new);

/// A counter that goes up when a push arrives while the app is open. Data
/// providers watch it, so the home feed and inbox refresh on their own.
class RefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final refreshTickProvider = NotifierProvider<RefreshTickNotifier, int>(RefreshTickNotifier.new);
