import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/mb_icon.dart';
import '../../theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../profile/profile_screen.dart';
import '../workouts/workouts_screen.dart';
import 'liquid_glass_nav_bar.dart';
import 'quick_action_sheets.dart';

/// Pestañas (indices del `LiquidGlassNavBar`): 0 Dashboard ·
/// 1 Nutrición · 2 Workouts · 3 Perfil.
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _index = 0; // Arranca en Dashboard.

  static const _screens = <Widget>[
    DashboardScreen(), // pestaña 0: Dashboard
    NutritionScreen(), // pestaña 1: Nutrición
    WorkoutsScreen(), // pestaña 2: Workouts
    ProfileScreen(), // pestaña 3: Perfil
  ];

  void _onQuickAction() {
    switch (_index) {
      case 1:
        showNutritionQuickActions(context);
        break;
      case 2:
        showWorkoutQuickActions(context);
        break;
      default:
        showDashboardQuickActions(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // el cristal flota sobre el contenido que se desliza
      body: IndexedStack(index: _index, children: _screens),
      // FAB contextual real: endFloat lo coloca encima del navbar flotante
      // (el Scaffold lo apila sobre el bottomNavigationBar). Oculto en Perfil.
      floatingActionButton: _index == 3
          ? null
          : FloatingActionButton(
              tooltip: _fabTooltip,
              backgroundColor: AppColors.primaryCoral,
              foregroundColor: AppColors.inkOnAccent,
              shape: const CircleBorder(),
              onPressed: _onQuickAction,
              child: MbIcon(
                MbAssets.plus,
                size: 26,
                color: AppColors.inkOnAccent,
              ),
            ),
      floatingActionButtonLocation: const FabAboveNavBarLocation(),
      bottomNavigationBar: LiquidGlassNavBar(
        selectedIndex: _index,
        onTabSelected: (index) => setState(() => _index = index),
      ),
    );
  }

  String get _fabTooltip {
    switch (_index) {
      case 1:
        return 'Ingresar alimento';
      case 2:
        return 'Acciones de entrenamiento';
      default:
        return 'Acciones rápidas';
    }
  }
}

/// Ubicación del FAB: encima del navbar de cristal (~8 px sobre su borde
/// superior, 16 px del borde derecho). `endFloat` por defecto solapaba el
/// tab "Perfil" y le robaba el tap — estos tabs flotan sobre el contenido
/// con `extendBody`, así que el FAB debe quedar claramente arriba de ellos.
/// El alto del navbar (68) + su margen inferior (20) es el contrato de
/// `LiquidGlassNavBar`.
class FabAboveNavBarLocation extends FloatingActionButtonLocation {
  const FabAboveNavBarLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    const navBarHeight = 68.0;
    const navBarBottomMargin = 20.0;
    const gap = 8.0;
    const sideMargin = 16.0;
    final safe = scaffoldGeometry.minViewPadding.bottom;
    final fab = scaffoldGeometry.floatingActionButtonSize;
    return Offset(
      scaffoldGeometry.scaffoldSize.width - fab.width - sideMargin,
      scaffoldGeometry.scaffoldSize.height -
          navBarHeight -
          navBarBottomMargin -
          safe -
          fab.height -
          gap,
    );
  }
}
