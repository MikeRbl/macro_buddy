import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_controller.dart';
import 'onboarding_content.dart';

/// Qué partes del onboarding ya vio el usuario con sesión iniciada.
/// Se guarda por usuario en el teléfono (`SharedPreferences`), así que otra
/// cuenta en el mismo equipo ve su propia bienvenida.
class OnboardingState {
  const OnboardingState({
    this.loaded = false,
    this.welcomeDone = false,
    this.seen = const {},
  });

  /// `false` mientras se lee del almacenamiento o si no hay sesión: en ese
  /// caso no se muestra nada automáticamente.
  final bool loaded;
  final bool welcomeDone;
  final Set<AppSection> seen;

  bool get showWelcome => loaded && !welcomeDone;

  bool shouldShowSection(AppSection s) =>
      loaded && welcomeDone && !seen.contains(s);
}

class OnboardingController extends Notifier<OnboardingState> {
  String? _userId;

  @override
  OnboardingState build() {
    _userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
    if (_userId == null) return const OnboardingState();
    _load(_userId!);
    return const OnboardingState();
  }

  String _welcomeKey(String id) => 'onboarding.$id.welcome';
  String _sectionKey(String id, AppSection s) =>
      'onboarding.$id.section.${s.name}';

  Future<void> _load(String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (_userId != id) return; // cambió la sesión mientras leíamos
    state = OnboardingState(
      loaded: true,
      welcomeDone: prefs.getBool(_welcomeKey(id)) ?? false,
      seen: {
        for (final s in AppSection.values)
          if (prefs.getBool(_sectionKey(id, s)) ?? false) s,
      },
    );
  }

  Future<void> completeWelcome() async {
    final id = _userId;
    if (id == null) return;
    state = OnboardingState(loaded: true, welcomeDone: true, seen: state.seen);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeKey(id), true);
  }

  Future<void> markSectionSeen(AppSection s) async {
    final id = _userId;
    if (id == null || state.seen.contains(s)) return;
    state = OnboardingState(
      loaded: state.loaded,
      welcomeDone: state.welcomeDone,
      seen: {...state.seen, s},
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sectionKey(id, s), true);
  }

  /// Vuelve a mostrar los recorridos de todas las secciones (la bienvenida
  /// la abre quien llama, para no sacar al usuario de la pantalla actual).
  Future<void> resetSections() async {
    final id = _userId;
    if (id == null) return;
    state = OnboardingState(
      loaded: state.loaded,
      welcomeDone: state.welcomeDone,
    );
    final prefs = await SharedPreferences.getInstance();
    for (final s in AppSection.values) {
      await prefs.remove(_sectionKey(id, s));
    }
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );
