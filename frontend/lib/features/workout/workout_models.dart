import '../../core/models/exercise.dart';
import '../../core/models/workout_plan.dart';

class PreviewExercise {
  const PreviewExercise({
    this.id,
    required this.name,
    this.muscles = const [],
    this.sets = 3,
    this.minReps = 8,
    this.maxReps = 12,
    this.rir = 0,
    required this.isBodyweight,
    this.thumbnailUrl,
    this.gifUrl,
    this.target,
    this.equipment,
    this.instructions,
    this.previousPerformance,
    this.suggestedNext,
  });

  final String? id;
  final String name;
  final List<String> muscles;
  final int sets;
  final int minReps;
  final int maxReps;
  final int rir;
  final bool isBodyweight;
  final String? thumbnailUrl;
  final String? gifUrl;
  final String? target;
  final String? equipment;
  final String? instructions;

  /// Datos de progresión que viven con el plan (backend).
  final PerformanceRecord? previousPerformance;
  final OverloadSuggestion? suggestedNext;

  factory PreviewExercise.fromPlan(WorkoutPlanExercise ex) {
    return PreviewExercise(
      id: ex.exerciseId,
      name: ex.name ?? 'Ejercicio',
      muscles: [if (ex.muscleGroup != null) ex.muscleGroup!],
      sets: ex.sets,
      minReps: ex.minReps ?? 8,
      maxReps: ex.maxReps ?? 12,
      rir: ex.rir,
      isBodyweight: ex.isBodyweight,
      thumbnailUrl: ex.thumbnailUrl,
      gifUrl: ex.gifUrl,
      target: ex.target,
      equipment: ex.equipment,
      instructions: ex.instructions,
      previousPerformance: ex.previousPerformance,
      suggestedNext: ex.suggestedNext,
    );
  }

  factory PreviewExercise.fromCatalog(
    Exercise e, {
    int sets = 3,
    int minReps = 8,
    int maxReps = 12,
    int rir = 0,
  }) {
    return PreviewExercise(
      id: e.id,
      name: e.name,
      muscles: [
        if (e.muscleGroup != null) e.muscleGroup!,
        ...e.secondaryMuscles.take(2),
      ],
      sets: sets,
      minReps: minReps,
      maxReps: maxReps,
      rir: rir,
      isBodyweight: e.isBodyweight,
      thumbnailUrl: e.thumbnailUrl,
      gifUrl: e.gifUrl,
      target: e.target,
      equipment: e.equipment,
      instructions: e.instructions,
    );
  }

  PreviewExercise copyWith({
    String? id,
    String? name,
    List<String>? muscles,
    int? sets,
    int? minReps,
    int? maxReps,
    int? rir,
    bool? isBodyweight,
    String? thumbnailUrl,
    String? gifUrl,
    String? target,
    String? equipment,
    String? instructions,
    PerformanceRecord? previousPerformance,
    OverloadSuggestion? suggestedNext,
  }) {
    return PreviewExercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscles: muscles ?? this.muscles,
      sets: sets ?? this.sets,
      minReps: minReps ?? this.minReps,
      maxReps: maxReps ?? this.maxReps,
      rir: rir ?? this.rir,
      isBodyweight: isBodyweight ?? this.isBodyweight,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      gifUrl: gifUrl ?? this.gifUrl,
      target: target ?? this.target,
      equipment: equipment ?? this.equipment,
      instructions: instructions ?? this.instructions,
      previousPerformance: previousPerformance ?? this.previousPerformance,
      suggestedNext: suggestedNext ?? this.suggestedNext,
    );
  }
}
