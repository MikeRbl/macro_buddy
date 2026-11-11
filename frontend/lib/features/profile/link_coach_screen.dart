import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api/api_client.dart';
import '../../core/models/coach_link.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';

/// Saca el código `MB-XXXX-XX` de lo que traiga el QR
/// (`macrobuddy://link?code=MB-7K4Q-29`) o de lo que escriba el usuario.
String? extractLinkCode(String raw) {
  final m = RegExp(
    r'MB[-\s]?([A-Z0-9]{4})[-\s]?([A-Z0-9]{2})(?![A-Z0-9])',
  ).firstMatch(raw.toUpperCase());
  return m == null ? null : 'MB-${m[1]}-${m[2]}';
}

/// "Vincular entrenador": escanea el QR del profesional o escribe su código.
/// Al vincular regresa (`pop`) el [CoachLink] creado.
class LinkCoachScreen extends ConsumerStatefulWidget {
  const LinkCoachScreen({super.key});

  @override
  ConsumerState<LinkCoachScreen> createState() => _LinkCoachScreenState();
}

class _LinkCoachScreenState extends ConsumerState<LinkCoachScreen> {
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Último código que falló: la cámara lo sigue viendo y no debe reintentarlo.
  String? _failedCode;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final code = extractLinkCode(b.rawValue ?? '');
      if (code != null && code != _failedCode) {
        _redeem(code);
        return;
      }
    }
  }

  Future<void> _redeem(String? code) async {
    if (_busy) return;
    if (code == null) {
      setState(() => _error = 'El código tiene el formato MB-XXXX-XX.');
      return;
    }
    final token = ref.read(authControllerProvider).token;
    if (token == null) {
      setState(() => _error = 'Sesión expirada. Inicia sesión de nuevo.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).redeemLinkCode(token: token, code: code);
      ref.invalidate(coachLinksProvider);
      final links = await ref.read(coachLinksProvider.future);
      if (!mounted) return;
      Navigator.of(context).pop(links.isEmpty ? null : links.last);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failedCode = code;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final error = _error;
    return Scaffold(
      appBar: AppBar(title: const Text('Vincular entrenador')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppColors.screenPadding),
          children: [
            Text(
              'Escanea el QR que te muestra tu profesional o escribe su '
              'código. Cada código sirve una sola vez.',
              style: TextStyle(color: c.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 260,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      onDetect: _onDetect,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error) => ColoredBox(
                        color: c.card,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'No se pudo abrir la cámara. Revisa los '
                              'permisos o escribe el código.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: c.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_busy)
                      const ColoredBox(
                        color: Colors.black54,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.tertiaryPurple,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Código',
                hintText: 'MB-XXXX-XX',
              ),
              onSubmitted: (v) => _redeem(extractLinkCode(v)),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy
                  ? null
                  : () => _redeem(extractLinkCode(_codeController.text)),
              child: const Text('Vincular'),
            ),
          ],
        ),
      ),
    );
  }
}
