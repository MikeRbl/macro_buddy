import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/navigation/main_scaffold.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: EliteTrainingApp()));
}

class EliteTrainingApp extends ConsumerWidget {
  const EliteTrainingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Elite Training',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
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
