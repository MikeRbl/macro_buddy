import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Tarjeta opaca de la capa de contenido según el blueprint Macrobuddy:
/// `#141416` con borde 1px `#262629` y radio 20.
///
/// Sin `BackdropFilter`: el cristal desenfocado es la capa funcional
/// flotante (navbar) y no entra al contenido (`liquid-glass.md › Restraint`).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.color,
    this.borderColor,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? borderRadius;
  final Color? color;
  final Color? borderColor;

  /// Glow suave del acento para las tarjetas destacadas (coral/cyan/púrpura).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppColors.radiusCard;
    final c = ThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: accent?.withValues(alpha: 0.10) ?? Colors.black.withValues(alpha: 0.25),
            blurRadius: accent != null ? 24 : 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
