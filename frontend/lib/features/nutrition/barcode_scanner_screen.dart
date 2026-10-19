import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/services/open_food_facts_service.dart';
import '../../theme/app_theme.dart';

/// Resultado del escaneo: el código crudo, el producto de OpenFoodFacts
/// (`null` si no existe) y un mensaje si la consulta a OFF falló
/// (red/servidor) — distinto de "no existe".
typedef BarcodeScanResult = ({String code, OffProduct? product, String? error});

/// Escáner de códigos de barras a pantalla completa.
///
/// Al detectar el primer código: vibra, detiene la cámara (`stop()`, un
/// recurso caro), consulta OpenFoodFacts con un guard único
/// (`_isProcessing`) y devuelve el resultado
/// `Navigator.pop(context, (code, product))`.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isProcessing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || !mounted) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    // La cámara se apaga antes de la consulta: sin fotogramas extra.
    await _controller.stop();

    String? error;
    OffProduct? product;
    try {
      product =
          await OpenFoodFactsService.shared.fetchByBarcode(code);
    } on OffException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'No se pudo contactar OpenFoodFacts. Revisa tu conexión.';
    }
    if (!mounted) return;
    Navigator.of(context).pop((code: code, product: product, error: error));
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return Scaffold(
      backgroundColor: Colors.black,
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ErrorView(error: error),
          ),
          if (_isProcessing)
            const ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.secondaryCyan),
                    SizedBox(height: 16),
                    Text(
                      'Buscando producto...',
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  0,
                  24,
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Text(
                  'Apunta al código de barras del producto',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textPrimary, fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_camera_outlined, size: 48, color: c.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No se pudo abrir la cámara.',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Revisa los permisos de cámara de la app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
