import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Píldora flotante de cristal líquido: la capa funcional de la app.
///
/// Única superficie glass del proyecto (`liquid-glass.md › Restraint`). Las 4
/// pestañas navegan con etiqueta visible en la activa; el `+` central es una
/// acción prominente separada por divisores (patrón de la barra de Fotos de
/// iOS). El acento coral se reserva para esa acción primaria; pestañas y
/// etiquetas quedan en monocromo sobre el glass (`liquid-glass.md › Color on
/// glass`). Apariencia fija en oscuro: no hay modo claro en la app.
class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onQuickAction,
  });

  /// 0 Perfil · 1 Entrenos · 2 Acción rápida · 3 Nutrición · 4 Dashboard
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onQuickAction;

  static const double _height = 68;
  static const double _iconSize = 26;
  static const double _labelSize = 11;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    // Flutter no expone reduce-transparency: contraste alto como señal
    // (liquid-glass.md › Accessibility states).
    final noTransparency = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(AppColors.radiusGlass);
    final pill = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: noTransparency
            ? _pill(c, translucent: false)
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: _pill(c, translucent: true),
              ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: SizedBox(height: _height, child: pill),
    );
  }

  Widget _pill(ThemeColors c, {required bool translucent}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: translucent ? c.glassFill : c.card,
        // Volumen del vaso: sheen arriba, sombra abajo al ras del borde.
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.3, 0.3, 1.0],
          colors: [
            Color(0x24FFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Color(0x15000000),
          ],
        ),
        border: Border.all(color: c.glassBorder, width: 1),
      ),
      child: Row(
        children: [
          _tab(index: 0, label: 'Perfil', icon: Icons.person_outline, activeIcon: Icons.person),
          _tab(
            index: 1,
            label: 'Entrenos',
            icon: Icons.fitness_center_outlined,
            activeIcon: Icons.fitness_center,
          ),
          _divider(c),
          _quickAction(),
          _divider(c),
          _tab(
            index: 3,
            label: 'Nutrición',
            icon: Icons.apple_outlined,
            activeIcon: Icons.apple,
          ),
          _tab(
            index: 4,
            label: 'Dashboard',
            icon: Icons.grid_view_outlined,
            activeIcon: Icons.grid_view,
          ),
        ],
      ),
    );
  }

  Widget _divider(ThemeColors c) =>
      Container(width: 1, height: 40, color: c.glassBorder);

  /// Acción primaria: fondo acento, símbolo en tinta oscura (6.75:1..8.25:1
  /// sobre el gradiente coral, por encima del 3:1 de controles gráficos).
  Widget _quickAction() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Semantics(
          label: 'Acción rápida',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onQuickAction,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.caloriesGradient,
              ),
              child: const Icon(Icons.add, color: AppColors.inkOnAccent, size: 28),
            ),
          ),
        ),
      );

  Widget _tab({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    const c = ThemeColors.dark;
    final selected = selectedIndex == index;
    final color = selected ? c.textPrimary : c.textSecondary;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTabSelected(index),
        child: Center(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? activeIcon : icon, size: _iconSize, color: color),
                if (selected) ...[
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: color,
                      fontSize: _labelSize,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
