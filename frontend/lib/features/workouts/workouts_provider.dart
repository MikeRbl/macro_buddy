import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/models/workout_plan.dart';
import '../auth/auth_controller.dart';

class WorkoutsState {
  const WorkoutsState({
    this.workouts = const [],
    this.programs = const [],
    this.activeWorkoutId,
    this.loading = false,
    this.error,
    this.doneThisWeek = const {},
    this.programName = defaultProgramName,
  });

  static const defaultProgramName = 'Mi programa';

  /// Entrenamientos del programa activo.
  final List<WorkoutPlan> workouts;

  /// Todos los programas del usuario (el activo primero).
  final List<TrainingProgram> programs;
  final String? activeWorkoutId;
  final bool loading;
  final String? error;

  /// Ids de entrenamientos completados en la semana actual (lunes a domingo).
  final Set<String> doneThisWeek;

  /// Nombre del programa activo.
  final String programName;

  /// Programa activo, o `null` si no hay ninguno activado.
  TrainingProgram? get activeProgram {
    for (final p in programs) {
      if (p.isActive) return p;
    }
    return null;
  }

  /// Programas guardados que no están activos.
  List<TrainingProgram> get otherPrograms =>
      [for (final p in programs) if (!p.isActive) p];

  WorkoutsState copyWith({
    List<WorkoutPlan>? workouts,
    List<TrainingProgram>? programs,
    String? activeWorkoutId,
    bool clearActive = false,
    bool? loading,
    String? error,
    bool clearError = false,
    Set<String>? doneThisWeek,
    String? programName,
  }) {
    return WorkoutsState(
      workouts: workouts ?? this.workouts,
      programs: programs ?? this.programs,
      activeWorkoutId: clearActive ? null : (activeWorkoutId ?? this.activeWorkoutId),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      doneThisWeek: doneThisWeek ?? this.doneThisWeek,
      programName: programName ?? this.programName,
    );
  }
}

final workoutProvider =
    NotifierProvider<WorkoutController, WorkoutsState>(WorkoutController.new);

class WorkoutController extends Notifier<WorkoutsState> {
  static const _activeKey = 'active_workout_id';
  static const _doneKeyPrefix = 'workouts_done_';

  /// Clave semanal: fecha del lunes de la semana actual (yyyy-mm-dd).
  static String _weekKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final monday = DateTime(d.year, d.month, d.day - (d.weekday - 1));
    String two(int n) => n.toString().padLeft(2, '0');
    return '$_doneKeyPrefix${monday.year}-${two(monday.month)}-${two(monday.day)}';
  }

  @override
  WorkoutsState build() {
    final token = ref.watch(authControllerProvider.select((s) => s.token));
    if (token == null) return const WorkoutsState();
    // Defer async load to avoid side-effect during build.
    Future.microtask(() => _loadWithToken(token));
    return const WorkoutsState(loading: true);
  }

  Future<void> _loadWithToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeId = prefs.getString(_activeKey);
      final done = (prefs.getStringList(_weekKey()) ?? const []).toSet();
      final items = await ref.read(apiClientProvider).fetchPrograms(token: token);
      final programs = items
          .map((e) => TrainingProgram.fromJson(e as Map<String, dynamic>))
          .toList();
      TrainingProgram? active;
      for (final p in programs) {
        if (p.isActive) active = p;
      }
      state = WorkoutsState(
        programs: programs,
        workouts: active?.workouts ?? const [],
        activeWorkoutId: activeId,
        doneThisWeek: done,
        programName: active?.name ?? WorkoutsState.defaultProgramName,
      );
    } on ApiException catch (e) {
      state = WorkoutsState(error: e.message);
    } catch (_) {
      state = const WorkoutsState(error: 'Error al cargar los programas.');
    }
  }

  Future<void> _load() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) return;
    await _loadWithToken(token);
  }

  Future<void> refresh() async => _load();

  Future<void> setActive(String workoutId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, workoutId);
    state = state.copyWith(activeWorkoutId: workoutId);
  }

  /// Marca/desmarca un entrenamiento como hecho esta semana.
  Future<void> toggleDone(String workoutId) async {
    final next = Set.of(state.doneThisWeek);
    if (!next.add(workoutId)) next.remove(workoutId);
    await _saveDone(next);
  }

  /// Marca un entrenamiento como hecho esta semana (al guardar la sesión).
  Future<void> markDone(String workoutId) async {
    if (state.doneThisWeek.contains(workoutId)) return;
    await _saveDone({...state.doneThisWeek, workoutId});
  }

  Future<void> _saveDone(Set<String> done) async {
    state = state.copyWith(doneThisWeek: done);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_weekKey(), done.toList());
  }

  /// Deja `programId` como el programa activo (vuelve al ciclo 1).
  /// Devuelve el mensaje de error, o `null` si salió bien.
  Future<String?> activateProgram(String programId) =>
      _change((api, token) => api.activateProgram(token: token, programId: programId));

  Future<String?> deleteProgram(String programId) =>
      _change((api, token) => api.deleteProgram(token: token, programId: programId));

  /// Crea (sin `programId`) o guarda un programa completo.
  Future<String?> saveProgram({
    String? programId,
    required Map<String, dynamic> body,
  }) => _change(
    (api, token) => programId == null
        ? api.createProgram(token: token, body: body)
        : api.updateProgram(token: token, programId: programId, body: body),
  );

  Future<String?> _change(
    Future<void> Function(ApiClient api, String token) action,
  ) async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) return 'Sesión expirada. Inicia sesión de nuevo.';
    try {
      await action(ref.read(apiClientProvider), token);
      await _loadWithToken(token);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
  }

  void reorderItem(int oldIndex, int newIndex) {
    final items = List.of(state.workouts);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    final active = state.activeProgram;
    state = state.copyWith(
      workouts: items,
      programs: [
        for (final p in state.programs)
          if (active != null && p.id == active.id)
            TrainingProgram(
              id: p.id,
              name: p.name,
              color: p.color,
              icon: p.icon,
              cycles: p.cycles,
              isActive: p.isActive,
              currentCycle: p.currentCycle,
              byCoach: p.byCoach,
              coachName: p.coachName,
              workouts: items,
            )
          else
            p,
      ],
    );

    final token = ref.read(authControllerProvider).token;
    if (token != null) {
      final ids = items.map((w) => w.id).toList();
      ref
          .read(apiClientProvider)
          .reorderWorkouts(token: token, workoutIds: ids)
          .catchError((_) => <String, dynamic>{});
    }
  }
}

/// Avisos sin leer (p. ej. "tu entrenador cambió tu programa"). Se consultan
/// al abrir la app y cada medio minuto mientras está abierta.
final notificationsProvider =
    NotifierProvider<NotificationsController, List<AppNotification>>(
      NotificationsController.new,
    );

class NotificationsController extends Notifier<List<AppNotification>> {
  static const _interval = Duration(seconds: 30);

  @override
  List<AppNotification> build() {
    final token = ref.watch(authControllerProvider.select((s) => s.token));
    if (token == null) return const [];
    final timer = Timer.periodic(_interval, (_) => refresh());
    ref.onDispose(timer.cancel);
    Future.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) return;
    try {
      final res = await ref.read(apiClientProvider).fetchNotifications(token: token);
      final unread = (res['items'] as List<dynamic>? ?? [])
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .where((n) => !n.read)
          .toList();
      final isNew = unread.any((n) => !state.any((old) => old.id == n.id));
      state = unread;
      // Un aviso nuevo significa que el programa cambió: se vuelve a cargar.
      if (isNew) await ref.read(workoutProvider.notifier).refresh();
    } catch (_) {
      // Sin red: se reintenta en la siguiente vuelta.
    }
  }

  /// "Entendido": los marca como leídos y los quita de la pantalla.
  Future<void> markAllRead() async {
    final token = ref.read(authControllerProvider).token;
    state = const [];
    if (token == null) return;
    try {
      await ref.read(apiClientProvider).markNotificationsRead(token: token);
    } catch (_) {
      // Si falla, reaparecen en la siguiente consulta.
    }
  }
}
