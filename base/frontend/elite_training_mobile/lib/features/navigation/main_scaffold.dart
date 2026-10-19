import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../community/community_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/more_screen.dart';
import '../workouts/workouts_screen.dart';
import 'shortcuts_sheet.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _index = 0;

  static const _tabs = <Widget>[
    DashboardScreen(),
    WorkoutsScreen(),
    CommunityScreen(),
    MoreScreen(),
  ];

  void _onTabTapped(int index) => setState(() => _index = index);

  void _openShortcuts() {
    final c = ThemeColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ShortcutsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButton: FloatingActionButton(
        onPressed: _openShortcuts,
        backgroundColor: c.textPrimary,
        foregroundColor: c.scaffold,
        elevation: 4.0,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: c.scaffold,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  selected: _index == 0,
                  onTap: () => _onTabTapped(0),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.fitness_center_outlined,
                  activeIcon: Icons.fitness_center,
                  label: 'Entrenos',
                  selected: _index == 1,
                  onTap: () => _onTabTapped(1),
                ),
              ),
              const SizedBox(width: 56),
              Expanded(
                child: _NavItem(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Comunidad',
                  selected: _index == 2,
                  onTap: () => _onTabTapped(2),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.more_horiz,
                  activeIcon: Icons.more_horiz,
                  label: 'Más',
                  selected: _index == 3,
                  onTap: () => _onTabTapped(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final color = selected ? c.textPrimary : c.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
