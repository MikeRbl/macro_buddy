import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/api_config.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/navigation/main_scaffold.dart';
import 'features/nutrition/food_catalog_bootstrap.dart';
import 'features/onboarding/onboarding_controller.dart';
import 'features/onboarding/onboarding_widgets.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  await ApiConfig.load();
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
    // Token + sync en segundo plano del catálogo de alimentos.
    ref.watch(foodCatalogBootstrapProvider);

    if (!authState.initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentOrange),
        ),
      );
    }

    if (!authState.isAuthenticated) return const LoginScreen();

    // Usuario nuevo (o que nunca la vio): bienvenida antes de la app.
    final onboarding = ref.watch(onboardingProvider);
    if (onboarding.showWelcome) {
      return WelcomeOnboardingScreen(
        onDone: () => ref.read(onboardingProvider.notifier).completeWelcome(),
      );
    }
    return const MainScaffold();
  }
}
