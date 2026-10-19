import 'package:flutter/material.dart';

import '../../core/services/open_food_facts_service.dart';
import '../../theme/app_theme.dart';
import 'barcode_scanner_screen.dart';
import 'nutrition_entry_sheets.dart';

/// Cliente compartido de OpenFoodFacts (vive toda la sesión de la app).
final _off = OpenFoodFactsService();

/// Flujo completo de escaneo: cámara → OpenFoodFacts → hoja de registro.
/// Lo usan el FAB de Nutrición y el atajo "Escanear comida".
Future<void> scanFoodFlow(BuildContext context) async {
  final code = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
  );
  if (code == null || !context.mounted) return;

  final product = await _off.fetchByBarcode(code);
  if (!context.mounted) return;

  if (product == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ThemeColors.dark.card,
        content: Text(
          'Producto no encontrado en OpenFoodFacts. Regístralo manualmente.',
          style: TextStyle(color: ThemeColors.dark.textPrimary),
        ),
      ),
    );
  }
  showManualEntrySheet(
    context,
    product: product ??
        OffProduct(
          barcode: code,
          name: '',
          calories: 0,
          protein: 0,
          carbs: 0,
          fats: 0,
          per100g: true,
        ),
  );
}
