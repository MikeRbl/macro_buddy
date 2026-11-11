import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/food_catalog/food_api.dart';
import '../../core/services/food_repository.dart';
import '../../theme/app_theme.dart';

/// Después de guardar un producto nuevo con código de barras, pregunta si
/// el usuario quiere mandarlo a verificación. Se llama con la hoja de
/// registro todavía abierta (su `context` sigue montado).
Future<void> offerContribution(BuildContext context, UserFood food) async {
  if (food.barcode == null || food.status != ContributionStatus.local) return;
  const c = ThemeColors.dark;

  final send = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.card,
      title: Text(
        '¿Quieres contribuir?',
        style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800),
      ),
      content: Text(
        'Si quieres contribuir a tener "${food.name}" en MacroBuddy, manda '
        'una solicitud de verificación. Si no, este producto solo se '
        'almacenará en tu equipo.',
        style: TextStyle(color: c.textSecondary, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Solo en mi equipo', style: TextStyle(color: c.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('Enviar solicitud', style: TextStyle(color: c.scaffold)),
        ),
      ],
    ),
  );
  if (!context.mounted) return;

  if (send != true) {
    await FoodRepository.shared.markDeclined(food.localId);
    return;
  }

  final check = checkMacros(
    kcal: food.kcal,
    protein: food.protein,
    carbs: food.carbs,
    fat: food.fat,
  );
  if (!check.ok) {
    _snack(
      context,
      'No se envió: ${check.reason} Revisa los valores; el producto quedó '
      'guardado en tu equipo.',
    );
    return;
  }

  final photos = await showModalBottomSheet<List<XFile>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _PhotoStep(),
  );
  if (photos == null || !context.mounted) return;

  try {
    final status = await FoodRepository.shared.contribute(food, photos: photos);
    if (!context.mounted) return;
    _snack(
      context,
      status == ContributionStatus.approved
          ? '¡Gracias! Otros usuarios confirmaron los mismos datos: '
                '"${food.name}" ya está en MacroBuddy.'
          : '¡Gracias! Revisaremos "${food.name}". Mientras tanto lo '
                'tienes disponible en tu equipo.',
    );
  } on FoodApiException catch (e) {
    if (!context.mounted) return;
    _snack(
      context,
      e.isNetwork
          ? 'Sin conexión: el producto quedó en tu equipo. Te lo '
                'preguntaremos de nuevo la próxima vez que lo registres.'
          : 'No se pudo enviar: ${e.message}',
    );
  }
}

void _snack(BuildContext context, String message) {
  const c = ThemeColors.dark;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: c.card,
      content: Text(message, style: TextStyle(color: c.textPrimary)),
    ),
  );
}

/// Pide la foto de la tabla nutrimental (y opcionalmente el frente).
/// Con la foto, un revisor confirma los datos en segundos.
class _PhotoStep extends StatefulWidget {
  const _PhotoStep();

  @override
  State<_PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<_PhotoStep> {
  final _picker = ImagePicker();
  final _photos = <XFile>[];

  Future<void> _add(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (file != null && mounted) setState(() => _photos.add(file));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la cámara o la galería.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final safe = MediaQuery.paddingOf(context).bottom;
    final full = _photos.length >= 3;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + safe),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Foto de la tabla nutrimental',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Con una foto clara de la tabla verificamos el producto mucho más '
            'rápido. Puedes agregar también el frente del empaque.',
            style: TextStyle(color: c.textSecondary, height: 1.4),
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_photos[i].path),
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(i)),
                        child: const CircleAvatar(
                          radius: 11,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: full ? null : () => _add(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Cámara'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: full ? null : () => _add(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galería'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(List.of(_photos)),
            child: Text(
              _photos.isEmpty ? 'Enviar sin foto' : 'Enviar solicitud',
              style: TextStyle(color: c.scaffold),
            ),
          ),
        ],
      ),
    );
  }
}
