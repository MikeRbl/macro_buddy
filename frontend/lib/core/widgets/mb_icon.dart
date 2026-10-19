import 'package:flutter/material.dart';

/// Rutas de los íconos y logos del proyecto dentro de `Assets/`.
/// Siempre usar estas constantes en lugar de strings sueltos.
abstract final class MbAssets {
  static const String dashboard = 'Assets/dashboard_icon.png';
  static const String fruit = 'Assets/fruit_icon.png';
  static const String dumbbell = 'Assets/dumbbell_icon.png';
  static const String profile = 'Assets/profile_icon.png';
  static const String plus = 'Assets/plus_icon.png';
  static const String protein = 'Assets/protein_icon.png';
  static const String carb = 'Assets/carb_icon.png';
  static const String fat = 'Assets/fat_icon.png';
  static const String scanBarcode = 'Assets/scan_barcode_icon.png';
  static const String burn = 'Assets/burn_icon.png';
  static const String steps = 'Assets/steps_icon.png';
  static const String alert = 'Assets/alert_icon.png';
  static const String calendar = 'Assets/calender_icon.png';
  static const String logo = 'Assets/logo_no_background.png';
}

/// Ícono monocromo del proyecto: colorea el asset con `BlendMode.srcIn`
/// para alternar entre estado activo (acento) e inactivo (`iconMuted`).
class MbIcon extends StatelessWidget {
  const MbIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.color,
    this.filterQuality = FilterQuality.high,
  });

  final String asset;
  final double size;
  final Color? color;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: filterQuality,
      gaplessPlayback: true,
    );
  }
}
