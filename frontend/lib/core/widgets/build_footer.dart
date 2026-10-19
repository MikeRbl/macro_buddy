import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Número de build visible en el pie de página del login y del perfil:
/// sirve para confirmar a qué APK corresponde lo que se prueba en físico.
/// Actualiza junto con `version:` en `pubspec.yaml` en cada release.
const String appBuildNumber = '3.2';

/// Pie de página pequeño y centrado: "Macrobuddy · Build 3.2".
class BuildFooter extends StatelessWidget {
  const BuildFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Macrobuddy · Build $appBuildNumber',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
      ),
    );
  }
}
