import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/models/workout_plan.dart';
import '../auth/auth_controller.dart';

class WorkoutsState {
  const WorkoutsState({
    this.workouts = const [],
    this.activeWorkoutId,
    this.loading = false,
    this.error,
    this.doneThisWeek = const {},
    this.programName = defaultProgramName,
  });

  static const defaultProgramName = 'Mi programa';

  final List<WorkoutPlan> workouts;
  final String? activeWorkoutId;
  final bool loading;
  final String? error;

  /// Ids de entrenamientos completados en la semana actual (lunes a domingo).
  final Set<String> doneThisWeek;

  /// Nombre del programa que agrupa los entrenamientos del usuario.
  final String programName;

  WorkoutsState copyWith({
    List<WorkoutPlan>? workouts,
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
  static const _programNameKey = 'program_name';
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
      final programName = prefs.getString(_programNameKey) ??
          WorkoutsState.defaultProgramName;
      final done = (prefs.getStringList(_weekKey()) ?? const []).toSet();
      final items = await ref.read(apiClientProvider).fetchWorkouts(token: token);
      final workouts = items
          .map((e) => WorkoutPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      state = WorkoutsState(
        workouts: workouts,
        activeWorkoutId: activeId,
        doneThisWeek: done,
        programName: programName,
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

  Future<void> renameProgram(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    state = state.copyWith(programName: clean);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_programNameKey, clean);
  }

  void reorderItem(int oldIndex, int newIndex) {
    final items = List.of(state.workouts);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = state.copyWith(workouts: items);

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