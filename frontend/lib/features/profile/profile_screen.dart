import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user.dart';
import '../../core/widgets/build_footer.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/mb_icon.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../dashboard/dashboard_provider.dart';
import '../navigation/shortcuts_sheet.dart';
import 'edit_profile_screen.dart';

/// Tab de Perfil: atleta, vínculo con el entrenador y configuración.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _openEditProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()));
  }

  void _openShortcuts() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeColors.dark.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ShortcutsSheet(),
    );
  }

  /// Racha de días entrenados consecutivos (terminando hoy o ayer).
  int _streak() {
    final sessions = ref.watch(dashboardProvider).value ?? const [];
    final dates = sessions
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet();
    if (dates.isEmpty) return 0;
    final today = DateTime.now();
    var day = DateTime(today.year, today.month, today.day);
    if (!dates.contains(day)) {
      day = day.subtract(const Duration(days: 1));
      if (!dates.contains(day)) return 0;
    }
    var streak = 0;
    while (dates.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final user = ref.watch(authControllerProvider).user;
    final username = user?.username ?? '';
    final streak = _streak();
    final guided = user?.isGuidedMode ?? false;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppColors.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar con el logo de la marca.
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Image.asset(
                      MbAssets.logo,
                      width: 32,
                      height: 32,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'CONFIGURACIÓN PERSONAL',
                style: TextStyle(
                  color: AppColors.primaryCoral,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 20),
              // ── Tarjeta atleta ────────────────────────────────────────
              GlassCard(
                child: Row(
                  children: [
                    // Avatar con degradado coral.
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.caloriesGradient,
                      ),
                      child: Text(
                        username.isNotEmpty
                            ? username.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.inkOnAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (guided
                                          ? AppColors.tertiaryPurple
                                          : AppColors.secondaryCyan)
                                      .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              guided ? 'GUIADO' : 'MANUAL',
                              style: TextStyle(
                                color: guided
                                    ? AppColors.tertiaryPurple
                                    : AppColors.secondaryCyan,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Métricas del atleta: peso / grasa corporal / racha.
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'PESO',
                      value: user?.weight != null
                          ? '${user!.weight!.round()} kg'
                          : '—',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(
                      label: 'GRASA',
                      value: user?.bodyFat != null
                          ? '${user!.bodyFat!.toStringAsFixed(1)} %'
                          : '—',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(label: 'RACHA', value: '$streak d'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // ── Mi Entrenador (modo guiado) ───────────────────────────
              _CoachCard(user: user),
              const SizedBox(height: 20),
              // ── Configuración ────────────────────────────────────────
              _SectionLabel('CONFIGURACIÓN'),
              const SizedBox(height: 12),
              Material(
                color: c.card,
                borderRadius: BorderRadius.circular(AppColors.radiusCard),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.person_outline, color: c.textPrimary),
                      title: Text(
                        'Editar perfil',
                        style: TextStyle(color: c.textPrimary, fontSize: 16),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: c.textSecondary,
                      ),
                      onTap: _openEditProfile,
                    ),
                    Divider(height: 1, color: c.input),
                    ListTile(
                      leading: Icon(Icons.timer_outlined, color: c.textPrimary),
                      title: Text(
                        'Herramientas',
                        style: TextStyle(color: c.textPrimary, fontSize: 16),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: c.textSecondary,
                      ),
                      onTap: _openShortcuts,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                child: const Text('Cerrar sesión'),
              ),
              const SizedBox(height: 16),
              const BuildFooter(),
              const SizedBox(height: 170),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return GlassCard(
      padding: const EdgeInsets.all(10),
      color: c.input,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ).merge(AppTypography.numeric),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: ThemeColors.dark.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    );
  }
}

/// Tarjeta "Mi Entrenador": estado del vínculo con el profesional.
/// Con el modo guiado activo los macros los fija el coach (el backend
/// responde 403 a cualquier PATCH de macros) y la edición de rutinas
/// queda deshabilitada en la app.
class _CoachCard extends ConsumerStatefulWidget {
  const _CoachCard({required this.user});

  final AuthUser? user;

  @override
  ConsumerState<_CoachCard> createState() => _CoachCardState();
}

class _CoachCardState extends ConsumerState<_CoachCard> {
  bool _busy = false;

  Future<void> _toggle(bool toGuided) async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await ref
        .read(authControllerProvider.notifier)
        .setGuidedMode(toGuided);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ThemeColors.dark.card,
        content: Text(
          error ??
              (toGuided
                  ? 'Profesional vinculado: modo guiado activo.'
                  : 'Modo guiado desactivado.'),
          style: TextStyle(color: ThemeColors.dark.textPrimary),
        ),
      ),
    );
  }

  Widget _lockChip({required bool locked, required String text}) {
    const c = ThemeColors.dark;
    final color = locked ? AppColors.tertiaryPurple : c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: locked
            ? AppColors.tertiaryPurple.withValues(alpha: 0.14)
            : ThemeColors.dark.input,
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

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final guided = widget.user?.isGuidedMode ?? false;
    final message = guided
        ? 'Tu entrenador define tus macros y rutinas mientras dure el vínculo.'
        : 'Sin entrenador vinculado. Al vincular, el coach fija tus macros '
              'y la edición de rutinas queda deshabilitada.';

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
                backgroundColor: guided
                    ? AppColors.tertiaryPurple
                    : ThemeColors.dark.input,
                foregroundColor: guided ? c.textPrimary : c.textSecondary,
                child: Icon(guided ? Icons.link : Icons.link_off, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
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
                guided ? 'Activo' : 'Sin vínculo',
                style: TextStyle(
                  color: guided ? AppColors.tertiaryPurple : c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _lockChip(locked: guided, text: 'Macros fijados'),
              _lockChip(locked: guided, text: 'Rutinas del coach'),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : () => _toggle(!guided),
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      guided ? 'Desvincular' : 'Vincular entrenador',
                      style: TextStyle(
                        color: guided
                            ? c.textSecondary
                            : AppColors.tertiaryPurple,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
