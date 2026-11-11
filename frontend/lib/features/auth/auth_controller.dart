import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/exercises_provider.dart';
import '../../core/models/coach_link.dart';
import '../../core/models/user.dart';

class AuthState {
  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
    this.initialized = false,
  });

  final AuthUser? user;
  final String? token;
  final bool isLoading;
  final String? error;
  final bool initialized;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AuthUser? user,
    String? token,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? initialized,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      initialized: initialized ?? this.initialized,
    );
  }
}

/// Vínculos del usuario con profesionales (activos y pendientes).
final coachLinksProvider = FutureProvider<List<CoachLink>>((ref) async {
  final token = ref.watch(authControllerProvider.select((s) => s.token));
  if (token == null) return const [];
  final raw = await ref.read(apiClientProvider).myLinks(token: token);
  return raw.map((e) => CoachLink.fromJson(e as Map<String, dynamic>)).toList();
});

bool _locked(Ref ref, bool Function(CoachLink) permission) {
  final links = ref.watch(coachLinksProvider).value;
  // Sin red se usa la última bandera que mandó el servidor al iniciar sesión.
  if (links == null) {
    return ref.watch(authControllerProvider).user?.isGuidedMode ?? false;
  }
  return links.any((l) => l.isActive && permission(l));
}

/// true si un profesional administra las rutinas: bloquea su edición (UI).
final isGuidedModeProvider = Provider<bool>(
  (ref) => _locked(ref, (l) => l.manageRoutines),
);

/// true si un profesional fija los macros: el backend responde 403 al PATCH.
final macrosLockedProvider = Provider<bool>(
  (ref) => _locked(ref, (l) => l.setMacros),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  String? _token;

  @override
  AuthState build() {
    _restoreSession();
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final rawUser = prefs.getString(_userKey);
    AuthUser? user;
    if (token != null && rawUser != null) {
      try {
        user = AuthUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
      } catch (_) {
        user = null;
      }
    }
    _token = user != null ? token : null;
    state = AuthState(user: user, token: _token, initialized: true);
  }

  Future<void> login(String identifier, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ref
          .read(apiClientProvider)
          .login(identifier: identifier, password: password);
      final user = await _persistSession(res);
      state = AuthState(user: user, token: _token, initialized: true);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Ocurrió un error inesperado. Intenta de nuevo.',
      );
    }
  }

  Future<void> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    double? weight,
    double? height,
    String? gender,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ref
          .read(apiClientProvider)
          .register(
            fullName: fullName,
            username: username,
            email: email,
            password: password,
            weight: weight,
            height: height,
            gender: gender,
          );
      final user = await _persistSession(res);
      state = AuthState(user: user, token: _token, initialized: true);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Ocurrió un error inesperado. Intenta de nuevo.',
      );
    }
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    ref.invalidate(exercisesProvider);
    state = const AuthState(initialized: true);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<AuthUser> _persistSession(Map<String, dynamic> res) async {
    final token = res['token'] as String;
    final user = AuthUser.fromJson(res['user'] as Map<String, dynamic>);
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    return user;
  }

  Future<String?> updateProfile({
    required String fullName,
    required String username,
    double? weight,
    double? bodyFat,
    double? height,
    String? gender,
    String? currentPassword,
    String? newPassword,
    double? targetCalories,
    double? targetProtein,
    double? targetCarbs,
    double? targetFats,
  }) async {
    final token = _token;
    if (token == null) return 'Sesión expirada. Inicia sesión de nuevo.';
    try {
      final res = await ref
          .read(apiClientProvider)
          .updateProfile(
            token: token,
            fullName: fullName,
            username: username,
            weight: weight,
            height: height,
            bodyFat: bodyFat,
            gender: gender,
            currentPassword: currentPassword,
            newPassword: newPassword,
            targetCalories: targetCalories,
            targetProtein: targetProtein,
            targetCarbs: targetCarbs,
            targetFats: targetFats,
          );
      final updated = AuthUser.fromJson(res['user'] as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(updated.toJson()));
      state = AuthState(user: updated, token: _token, initialized: true);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
  }

  /// "Validarme como profesional". Devuelve el error, o `null` si salió bien.
  Future<String?> becomeProfessional({
    required String displayName,
    required String specialty,
  }) async {
    final token = _token;
    if (token == null) return 'Sesión expirada. Inicia sesión de nuevo.';
    try {
      final res = await ref
          .read(apiClientProvider)
          .becomeProfessional(
            token: token,
            displayName: displayName,
            specialty: specialty,
          );
      final updated = AuthUser.fromJson(res['user'] as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(updated.toJson()));
      state = AuthState(user: updated, token: _token, initialized: true);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
  }
}
