import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/coach_link.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import 'link_coach_screen.dart';

/// Tarjeta "Mi Entrenador": profesionales vinculados, su rol y lo que cada
/// uno controla. Los bloqueos salen de los permisos reales del vínculo.
class CoachCard extends ConsumerWidget {
  const CoachCard({super.key});

  void _snack(BuildContext context, String message) {
    const c = ThemeColors.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: c.card,
        content: Text(message, style: TextStyle(color: c.textPrimary)),
      ),
    );
  }

  Future<void> _link(BuildContext context) async {
    final link = await Navigator.of(context).push(
      MaterialPageRoute<CoachLink>(builder: (_) => const LinkCoachScreen()),
    );
    if (link == null || !context.mounted) return;
    _snack(
      context,
      link.isActive
          ? 'Vinculado con ${link.professionalName}.'
          : 'Solicitud enviada. ${link.professionalName} debe aprobarla.',
    );
  }

  Future<void> _unlink(BuildContext context, WidgetRef ref, CoachLink link) async {
    const c = ThemeColors.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text(
          link.isActive ? 'Desvincular' : 'Cancelar solicitud',
          style: TextStyle(color: c.textPrimary),
        ),
        content: Text(
          link.isActive
              ? '${link.professionalName} dejará de ver tus datos y podrás '
                    'editar de nuevo tus macros y rutinas.'
              : 'Se cancelará tu solicitud con ${link.professionalName}.',
          style: TextStyle(color: c.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Volver', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              link.isActive ? 'Desvincular' : 'Cancelar solicitud',
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    final token = ref.read(authControllerProvider).token;
    if (ok != true || token == null) return;
    try {
      await ref.read(apiClientProvider).unlinkCoach(token: token, linkId: link.id);
      ref.invalidate(coachLinksProvider);
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  Widget _chip(String text, {required bool locked}) {
    const c = ThemeColors.dark;
    final color = locked ? AppColors.tertiaryPurple : c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: locked ? AppColors.tertiaryPurple.withValues(alpha: 0.14) : c.input,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(locked ? Icons.lock : Icons.lock_open, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _linkTile(BuildContext context, WidgetRef ref, CoachLink link) {
    const c = ThemeColors.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.professionalName,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      link.isActive
                          ? link.roleLabel
                          : '${link.roleLabel} · Pendiente de aprobación',
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _unlink(context, ref, link),
                child: Text(
                  link.isActive ? 'Desvincular' : 'Cancelar',
                  style: TextStyle(color: c.textSecondary),
                ),
              ),
            ],
          ),
          if (link.isActive)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Macros fijados', locked: link.setMacros),
                _chip('Rutinas del coach', locked: link.manageRoutines),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const c = ThemeColors.dark;
    final async = ref.watch(coachLinksProvider);
    final links = async.value ?? const <CoachLink>[];
    final anyActive = links.any((l) => l.isActive);

    return Container(
      decoration: BoxDecoration(
        // Fondo púrpura profundo del blueprint.
        color: const Color(0xFF1A1426),
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: AppColors.tertiaryPurple, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: anyActive ? AppColors.tertiaryPurple : c.input,
                foregroundColor: anyActive ? c.textPrimary : c.textSecondary,
                child: Icon(anyActive ? Icons.link : Icons.link_off, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'MI ENTRENADOR',
                  style: TextStyle(
                    color: AppColors.tertiaryPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Text(
                anyActive ? 'Activo' : 'Sin vínculo',
                style: TextStyle(
                  color: anyActive ? AppColors.tertiaryPurple : c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (async.hasError && links.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No se pudo consultar tu vínculo. Verifica tu conexión.',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => ref.invalidate(coachLinksProvider),
                child: const Text(
                  'Reintentar',
                  style: TextStyle(color: AppColors.tertiaryPurple),
                ),
              ),
            ),
          ] else ...[
            if (links.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Sin entrenador vinculado. Al vincular, tu profesional puede '
                'fijar tus macros y rutinas según los permisos que elija.',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ],
            for (final link in links) _linkTile(context, ref, link),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _link(context),
                child: Text(
                  links.isEmpty ? 'Vincular entrenador' : 'Vincular otro profesional',
                  style: const TextStyle(color: AppColors.tertiaryPurple),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
