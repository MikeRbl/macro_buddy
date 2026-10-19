import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../community/community_screen.dart';
import 'edit_profile_screen.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  void _openEditProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final user = ref.watch(authControllerProvider).user;
    final username = user?.username ?? '';
    final initial = username.isNotEmpty
        ? username.substring(0, 1).toUpperCase()
        : '?';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppColors.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'PERFIL',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: c.textPrimary,
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: c.scaffold,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.username ?? '',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ProfessionalLinkCard(user: user),
              const SizedBox(height: 24),
              Material(
                color: c.card,
                borderRadius: BorderRadius.circular(AppColors.radiusCard),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.person_outline, color: c.textPrimary),
                      title: Text(
                        'Perfil',
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
                      leading: Icon(Icons.people_outline, color: c.textPrimary),
                      title: Text(
                        'Comunidad',
                        style: TextStyle(color: c.textPrimary, fontSize: 16),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: c.textSecondary,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CommunityScreen(),
                        ),
                      ),
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
              // Zona inferior para que el contenido no choque con la barra glass.
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
    );
  }
}


/// Tarjeta "Professional Link": estado del vínculo con el profesional.
/// Con el modo guiado activo los macros los fija el coach (el backend
/// responde 403 a cualquier PATCH de macros) y la edición de rutinas
/// queda deshabilitada en la app.
class _ProfessionalLinkCard extends ConsumerStatefulWidget {
  const _ProfessionalLinkCard({required this.user});

  final AuthUser? user;

  @override
  ConsumerState<_ProfessionalLinkCard> createState() =>
      _ProfessionalLinkCardState();
}

class _ProfessionalLinkCardState extends ConsumerState<_ProfessionalLinkCard> {
  bool _busy = false;

  Future<void> _toggle(bool toGuided) async {
    if (_busy) return;
    setState(() => _busy = true);
    final error =
        await ref.read(authControllerProvider.notifier).setGuidedMode(toGuided);
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

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final guided = widget.user?.isGuidedMode ?? false;
    final message = guided
        ? 'Tu profesional define tus macros. La edición de macros y rutinas '
            'está bloqueada mientras dure el vínculo.'
        : 'Sin profesional vinculado. Al vincular, el coach fija tus macros '
            'y la edición de rutinas queda deshabilitada.';

    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: guided ? AppColors.accentTeal : c.input,
                  foregroundColor: guided ? c.textPrimary : c.textSecondary,
                  child: Icon(guided ? Icons.link : Icons.link_off, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Professional Link',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  guided ? 'Modo guiado' : 'Sin vínculo',
                  style: TextStyle(
                    color: guided ? AppColors.accentTeal : c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: c.textSecondary, fontSize: 12),
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
                        guided ? 'Desvincular' : 'Vincular profesional',
                        style: TextStyle(
                          color: guided ? c.textSecondary : AppColors.accentTeal,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
