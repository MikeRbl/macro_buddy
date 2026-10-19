import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../profile/more_screen.dart';
import '../workouts/workouts_screen.dart';
import 'liquid_glass_nav_bar.dart';
import 'shortcuts_sheet.dart';

/// Pestañas (indices del `LiquidGlassNavBar`): 0 Perfil · 1 Entrenos ·
/// 2 acción rápida · 3 Nutrición · 4 Dashboard.
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _index = 4; // Arranca en Dashboard.

  static const _screens = <Widget>[
    MoreScreen(), // pestaña 0: Perfil
    WorkoutsScreen(), // pestaña 1: Entrenos
    SizedBox.shrink(), // pestaña 2: acción rápida (no es pantalla)
    NutritionScreen(), // pestaña 3: Nutrición
    DashboardScreen(), // pestaña 4: Dashboard
  ];

  void _openQuickAction() {
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
    return Scaffold(
      extendBody: true, // el cristal flota sobre el contenido que se desliza
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: LiquidGlassNavBar(
        selectedIndex: _index,
        onTabSelected: (index) => setState(() => _index = index),
        onQuickAction: _openQuickAction,
      ),
    );
  }
}
