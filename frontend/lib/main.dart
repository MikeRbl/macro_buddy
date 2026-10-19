import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/navigation/main_scaffold.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: MacrobuddyApp()));
}

class MacrobuddyApp extends ConsumerWidget {
  const MacrobuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Apariencia fija en oscuro: Dark Mode First (designe.md) y sin ajuste
    // propio de apariencia (dark-mode.md › Best practices).
    return MaterialApp(
      title: 'Macrobuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    if (!authState.initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentOrange),
        ),
      );
    }

    return authState.isAuthenticated
        ? const MainScaffold()
        : const LoginScreen();
  }
}
