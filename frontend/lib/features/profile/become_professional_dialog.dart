import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';

const _specialties = {
  'nutritionist': 'Nutriólogo',
  'trainer': 'Entrenador',
  'both': 'Nutriólogo y entrenador',
  'doctor': 'Médico',
};

/// "Validarme como profesional": pide el nombre que verán los pacientes y
/// la especialidad. Por ahora no se verifica cédula.
Future<void> showBecomeProfessionalDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _Dialog());

class _Dialog extends ConsumerStatefulWidget {
  const _Dialog();

  @override
  ConsumerState<_Dialog> createState() => _DialogState();
}

class _DialogState extends ConsumerState<_Dialog> {
  late final _name = TextEditingController(
    text: ref.read(authControllerProvider).user?.fullName ?? '',
  );
  String _specialty = 'nutritionist';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribe el nombre que verán tus pacientes.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(authControllerProvider.notifier)
        .becomeProfessional(displayName: name, specialty: _specialty);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: ThemeColors.dark.card,
        content: Text(
          'Listo: tu cuenta es profesional. Entra a la versión web para '
          'vincular y administrar pacientes.',
          style: TextStyle(color: ThemeColors.dark.textPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final error = _error;
    return AlertDialog(
      backgroundColor: c.card,
      title: Text(
        'Validarme como profesional',
        style: TextStyle(color: c.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Con una cuenta profesional puedes vincular pacientes y, según '
              'los permisos que elijas, fijar sus macros y rutinas desde la '
              'versión web.',
              style: TextStyle(color: c.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Nombre profesional',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _specialty,
              dropdownColor: c.card,
              decoration: const InputDecoration(labelText: 'Especialidad'),
              items: [
                for (final e in _specialties.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _specialty = v ?? _specialty),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: c.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: Text('Validarme', style: TextStyle(color: c.scaffold)),
        ),
      ],
    );
  }
}
