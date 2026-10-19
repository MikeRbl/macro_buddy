import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
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
                'MÁS',
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
                    SwitchListTile(
                      secondary: Icon(
                        Icons.dark_mode_outlined,
                        color: c.textPrimary,
                      ),
                      title: Text(
                        'Modo Oscuro',
                        style: TextStyle(color: c.textPrimary, fontSize: 16),
                      ),
                      value: ref.watch(themeModeProvider) == ThemeMode.dark,
                      activeTrackColor: AppColors.accentOrange,
                      onChanged: (value) => ref
                          .read(themeModeProvider.notifier)
                          .setDarkMode(value),
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
            ],
          ),
        ),
      ),
    );
  }
}
