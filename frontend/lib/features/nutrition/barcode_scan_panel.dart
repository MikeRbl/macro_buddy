import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/services/open_food_facts_service.dart';
import '../../theme/app_theme.dart';

/// Resultado de la lectura de un código: el código crudo, el producto de
/// OpenFoodFacts (`null` si no existe) y un mensaje si la consulta falló
/// (red / servidor / saturación) — distinto de "no existe".
typedef BarcodeScanResult = ({String code, OffProduct? product, String? error});

/// Panel reutilizable del escáner: cámara limitada a [cameraHeight],
/// recuadro de enfoque, e ingreso manual del código de barras.
///
/// La cámara y el campo manual llaman al mismo `_lookup`, de modo que ambos
/// caminos comparten la consulta a OpenFoodFacts y el manejo de errores.
class BarcodeScanPanel extends StatefulWidget {
  const BarcodeScanPanel({
    super.key,
    required this.onResult,
    this.title = 'Alinea el código de barras dentro del recuadro',
    this.cameraHeight = 300,
  });

  final ValueChanged<BarcodeScanResult> onResult;
  final String title;
  final double cameraHeight;

  @override
  State<BarcodeScanPanel> createState() => BarcodeScanPanelState();
}

class BarcodeScanPanelState extends State<BarcodeScanPanel> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _manualController = TextEditingController();
  final _manualFocus = FocusNode();

  bool _isProcessing = false;
  String? _error;

  @override
  void dispose() {
    _manualController.dispose();
    _manualFocus.dispose();
    unawaited(_controller.dispose());
    super.dispose();
  }

  /// Reactiva la cámara tras cerrar la hoja de registro o un error.
  Future<void> resume() async {
    if (!mounted) return;
    try {
      await _controller.start();
    } catch (_) {
      // La vista de error de la cámara ya explica cómo seguir con el
      // ingreso manual; no hay que romper el flujo por esto.
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || !mounted) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (code == null || code.isEmpty) return;
    HapticFeedback.mediumImpact();
    await _lookup(code);
  }

  Future<void> _lookup(String raw) async {
    final code = raw.trim();
    if (code.isEmpty || _isProcessing || !mounted) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    // La cámara es un recurso caro: se apaga antes de consultar.
    try {
      await _controller.stop();
    } catch (_) {
      // Si ya estaba detenida no impide continuar con la consulta.
    }

    String? error;
    OffProduct? product;
    try {
      product = await OpenFoodFactsService.shared.fetchByBarcode(code);
    } on OffException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'No se pudo contactar OpenFoodFacts. Revisa tu conexión.';
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (error != null) {
      setState(() => _error = error);
      await resume();
      return;
    }

    widget.onResult((code: code, product: product, error: null));
  }

  Future<void> _submitManual() async {
    final code = _manualController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Ingresa un código de barras.');
      return;
    }
    if (code.length < 8) {
      setState(() => _error = 'El código debe tener al menos 8 dígitos.');
      return;
    }
    FocusScope.of(context).unfocus();
    await _lookup(code);
  }

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: widget.cameraHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error) => const _CameraErrorView(),
                ),
                const IgnorePointer(
                  child: CustomPaint(painter: _ScannerOverlayPainter()),
                ),
                if (_isProcessing)
                  ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.secondaryCyan,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Buscando producto...',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Divider(color: c.border, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'O ingresa el código',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: c.border, height: 1)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _manualController,
                focusNode: _manualFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(14),
                ],
                onSubmitted: (_) => _submitManual(),
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ej. 737628064502',
                  hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
                  isDense: true,
                  filled: true,
                  fillColor: c.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryCoral),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton.filled(
                onPressed: _isProcessing ? null : _submitManual,
                tooltip: 'Buscar código',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryCoral,
                  foregroundColor: AppColors.inkOnAccent,
                  disabledBackgroundColor: AppColors.primaryCoral.withValues(
                    alpha: 0.5,
                  ),
                  disabledForegroundColor: AppColors.inkOnAccent.withValues(
                    alpha: 0.6,
                  ),
                  shape: const CircleBorder(),
                ),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.inkOnAccent,
                        ),
                      )
                    : const Icon(Icons.search, size: 22),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.warningAmber, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// Recuadro de enfoque: oscurece el resto de la cámara, deja un hueco
/// cuadrado al centro, dibuja una cuadrícula sutil y esquinas blancas.
class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height) * 0.64;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    final hole = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    final overlay = Path()..addRect(Offset.zero & size);
    final cutout = Path()..addRRect(hole);
    canvas.drawPath(
      Path.combine(PathOperation.difference, overlay, cutout),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (final fraction in const [1 / 3, 2 / 3]) {
      final x = rect.left + rect.width * fraction;
      final y = rect.top + rect.height * fraction;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
    }

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const length = 24.0;
    final l = rect.left;
    final t = rect.top;
    final r = rect.right;
    final b = rect.bottom;

    // Esquina superior izquierda.
    canvas.drawLine(Offset(l, t + length), Offset(l, t), cornerPaint);
    canvas.drawLine(Offset(l, t), Offset(l + length, t), cornerPaint);
    // Esquina superior derecha.
    canvas.drawLine(Offset(r - length, t), Offset(r, t), cornerPaint);
    canvas.drawLine(Offset(r, t), Offset(r, t + length), cornerPaint);
    // Esquina inferior izquierda.
    canvas.drawLine(Offset(l, b - length), Offset(l, b), cornerPaint);
    canvas.drawLine(Offset(l, b), Offset(l + length, b), cornerPaint);
    // Esquina inferior derecha.
    canvas.drawLine(Offset(r - length, b), Offset(r, b), cornerPaint);
    canvas.drawLine(Offset(r, b), Offset(r, b - length), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView();

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return ColoredBox(
      color: c.card,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_camera_outlined,
                size: 36,
                color: c.textSecondary,
              ),
              const SizedBox(height: 10),
              Text(
                'No se pudo abrir la cámara.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Revisa los permisos o usa el código manual.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
