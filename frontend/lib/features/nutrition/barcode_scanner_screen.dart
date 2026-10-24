import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'barcode_scan_panel.dart';

export 'barcode_scan_panel.dart' show BarcodeScanResult;

/// Escáner de códigos de barras para los atajos y el FAB.
///
/// Usa el mismo [BarcodeScanPanel] que la pestaña "Escanear" de
/// `FoodEntryScreen`: cámara de altura fija, recuadro de enfoque e ingreso
/// manual. Al obtener un resultado, lo devuelve por `Navigator.pop`.
class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFFFFFFFF)),
        title: const Text(
          'Escanear alimento',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: BarcodeScanPanel(
            onResult: (result) => Navigator.of(context).pop(result),
          ),
        ),
      ),
    );
  }
}
