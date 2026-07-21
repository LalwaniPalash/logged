import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../dashboard/dashboard_screen.dart';
import '../history/history_screen.dart';
import '../exercise/progress_screen.dart';
import '../settings/settings_screen.dart';

/// Root scaffold with a persistent bottom navigation bar. Each destination keeps
/// its own state via an [IndexedStack] so switching tabs never rebuilds from
/// scratch.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = const int.fromEnvironment(
    'LOGGED_INITIAL_TAB',
    defaultValue: 0,
  ).clamp(0, 3);

  static const _screens = [
    DashboardScreen(),
    HistoryScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  static const _items = [
    (AppIcons.home, AppIcons.homeFill),
    (AppIcons.history, AppIcons.historyFill),
    (AppIcons.progress, AppIcons.progressFill),
    (AppIcons.settings, AppIcons.settingsFill),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < _items.length; i++)
                    _NavItem(
                      icon: _items[i].$1,
                      activeIcon: _items[i].$2,
                      selected: _index == i,
                      onTap: () => setState(() => _index = i),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single icon-only navigation item with a small underline for the selected
/// tab — deliberately spacious and free of the Material pill indicator.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 26),
            const SizedBox(height: 7),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: selected ? 22 : 0,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
