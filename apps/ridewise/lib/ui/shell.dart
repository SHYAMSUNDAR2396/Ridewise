import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'mini_player.dart';
import 'plan_screen.dart';

/// Which bottom tab is showing; screens switch tabs through it.
class ShellController extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  static const listenNow = 0;
  static const plan = 1;
  static const library = 2;

  void goTo(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }
}

/// Bottom tabs with the mini player docked above the bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    return Scaffold(
      body: IndexedStack(
        index: shell.index,
        children: const [HomeScreen(), PlanScreen(), LibraryScreen()],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: NavigationBar(
              selectedIndex: shell.index,
              onDestinationSelected: shell.goTo,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.headphones_rounded),
                  label: 'Listen Now',
                ),
                NavigationDestination(
                  icon: Icon(Icons.alt_route_rounded),
                  label: 'Plan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_rounded),
                  label: 'Library',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
