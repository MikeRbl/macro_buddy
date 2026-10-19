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
  });

  final List<WorkoutPlan> workouts;
  final String? activeWorkoutId;
  final bool loading;
  final String? error;

  WorkoutsState copyWith({
    List<WorkoutPlan>? workouts,
    String? activeWorkoutId,
    bool clearActive = false,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return WorkoutsState(
      workouts: workouts ?? this.workouts,
      activeWorkoutId: clearActive ? null : (activeWorkoutId ?? this.activeWorkoutId),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final workoutProvider =
    NotifierProvider<WorkoutController, WorkoutsState>(WorkoutController.new);

class WorkoutController extends Notifier<WorkoutsState> {
  static const _activeKey = 'active_workout_id';

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
      final items = await ref.read(apiClientProvider).fetchWorkouts(token: token);
      final workouts = items
          .map((e) => WorkoutPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      state = WorkoutsState(
        workouts: workouts,
        activeWorkoutId: activeId,
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