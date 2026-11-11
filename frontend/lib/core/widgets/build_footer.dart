import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Número de build visible en el pie de página del login y del perfil:
/// sirve para confirmar a qué APK corresponde lo que se prueba en físico.
/// Actualiza junto con `version:` en `pubspec.yaml` en cada release.
const String appBuildNumber = '3.6';

/// Atribución obligatoria (ODbL) de la base de datos de alimentos.
/// Va en el pie del perfil; al tocarla abre "Acerca de".
class FoodDataCredit extends StatelessWidget {
  const FoodDataCredit({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'Datos de alimentos: Open Food Facts · openfoodfacts.org',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ),
    );
  }
}

/// Pie de página pequeño y centrado: "Macrobuddy · Build 3.6".
class BuildFooter extends StatelessWidget {
  const BuildFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Macrobuddy · Build $appBuildNumber',
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
    );
  }
}
