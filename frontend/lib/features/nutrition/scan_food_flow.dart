import 'package:flutter/material.dart';

import '../../core/services/open_food_facts_service.dart';
import '../../theme/app_theme.dart';
import 'barcode_scanner_screen.dart';
import 'nutrition_entry_sheets.dart';

/// Flujo completo de escaneo: cámara → OpenFoodFacts (ya resuelto dentro
/// del escáner) → hoja de registro con el producto o manual.
/// Lo usan el FAB de Nutrición, la búsqueda y el atajo "Escanear comida".
Future<void> scanFoodFlow(BuildContext context) async {
  final result = await Navigator.of(context).push<BarcodeScanResult>(
    MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
  );
  if (result == null || !context.mounted) return;

  if (result.error != null) {
    // Fallo de red / servidor en OFF: NO es "no existe"; no abre el
    // registro manual para que la causa no se confunda.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ThemeColors.dark.card,
        content: Text(
          result.error!,
          style: TextStyle(color: ThemeColors.dark.textPrimary),
        ),
      ),
    );
    return;
  }
  if (result.product == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ThemeColors.dark.card,
        content: Text(
          'Producto no encontrado en OpenFoodFacts (${result.code}). '
          'Regístralo manualmente.',
          style: TextStyle(color: ThemeColors.dark.textPrimary),
        ),
      ),
    );
  }
  showManualEntrySheet(
    context,
    product:
        result.product ??
        OffProduct(
          barcode: result.code,
          name: '',
          calories: 0,
          protein: 0,
          carbs: 0,
          fats: 0,
          per100g: true,
        ),
  );
}
