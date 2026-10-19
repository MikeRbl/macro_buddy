import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/widgets/mb_icon.dart';
import '../../theme/app_theme.dart';

/// Píldora flotante de cristal líquido con exactamente 4 pestañas.
/// Las pestañas navegan; las acciones viven fuera de la barra
/// (`liquid-glass.md › Best practices`): el `+` contextual es un FAB
/// aparte en `main_scaffold.dart`.
class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  /// 0 Dashboard · 1 Nutrición · 2 Workouts · 3 Perfil
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  static const double _height = 68;
  static const double _iconSize = 24;
  static const double _labelSize = 11;
  static const double _radius = 34;

  static const _tabs = <({String asset, String label, Color accent})>[
    (asset: MbAssets.dashboard, label: 'Dash', accent: AppColors.primaryCoral),
    (asset: MbAssets.fruit, label: 'Nutrición', accent: AppColors.primaryCoral),
    (asset: MbAssets.dumbbell, label: 'Workout', accent: AppColors.secondaryCyan),
    (asset: MbAssets.profile, label: 'Perfil', accent: AppColors.primaryCoral),
  ];

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    // Flutter no expone reduce-transparency: contraste alto como señal
    // (liquid-glass.md › Accessibility states).
    final noTransparency = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(_radius);
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
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: _pill(c, translucent: true),
              ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        20 + MediaQuery.paddingOf(context).bottom,
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final (index, tab) in _tabs.indexed)
            _NavTab(
              asset: tab.asset,
              label: tab.label,
              accent: tab.accent,
              selected: selectedIndex == index,
              onTap: () => onTabSelected(index),
            ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.asset,
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    // Inactivo: ícono 3.63:1 (gráfico, pasa 3:1) + label 7.04:1 (pasa 4.5:1).
    final iconColor = selected ? accent : c.iconMuted;
    final labelColor = selected ? accent : c.textSecondary;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: LiquidGlassNavBar._height,
          width: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MbIcon(asset, size: LiquidGlassNavBar._iconSize, color: iconColor),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: labelColor,
                  fontSize: LiquidGlassNavBar._labelSize,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              // Punto de 4px reservado siempre: la píldora no salta al
              // aparecer el indicador.
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? accent : accent.withValues(alpha: 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
