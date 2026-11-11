import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/food_repository.dart';
import '../auth/auth_controller.dart';

/// Conecta el catálogo de alimentos con la sesión: le pasa el token al
/// repositorio y, al iniciar sesión, sincroniza en segundo plano (como
/// mucho cada 12 h). Se activa con `ref.watch` en `AuthGate`.
final foodCatalogBootstrapProvider = Provider<void>((ref) {
  final token = ref.watch(authControllerProvider.select((s) => s.token));
  FoodRepository.shared.token = token;
  if (token != null) {
    // Nunca bloquea la UI: la app funciona con la copia local mientras tanto.
    unawaited(FoodRepository.shared.syncIfStale().catchError((Object _) {}));
  }
});
