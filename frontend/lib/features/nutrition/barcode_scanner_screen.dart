import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../theme/app_theme.dart';

/// Escáner de códigos de barras a pantalla completa.
/// Devuelve el código (`Navigator.pop(context, String)`) al detectar el
/// primero y se cierra solo: una cámara abierta es un recurso caro.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _completed = false;

  void _onDetect(BarcodeCapture capture) {
    if (_completed || !mounted) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (code == null || code.isEmpty) return;
    setState(() => _completed = true);
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(code);
  }

  @override
  void dispose() {
    _controller.dispose();
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
        title: const Text('Escanear alimento',
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
