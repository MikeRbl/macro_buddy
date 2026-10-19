class WorkoutPlanExercise {
  const WorkoutPlanExercise({
    this.exerciseId,
    this.name,
    this.isBodyweight = false,
    this.thumbnailUrl,
    this.muscleGroup,
    this.target,
    this.gifUrl,
    this.equipment,
    this.instructions,
    this.sets = 3,
    this.minReps,
    this.maxReps,
    this.rir = 0,
    this.previousPerformance,
    this.suggestedNext,
  });

  final String? exerciseId;
  final String? name;
  final bool isBodyweight;
  final String? thumbnailUrl;
  final String? muscleGroup;
  final String? target;
  final String? gifUrl;
  final String? equipment;
  final String? instructions;
  final int sets;
  final int? minReps;
  final int? maxReps;
  final int rir;

  /// Mejor set de la última sesión + sugerencia de progresión (backend).
  final PerformanceRecord? previousPerformance;
  final OverloadSuggestion? suggestedNext;

  factory WorkoutPlanExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutPlanExercise(
      exerciseId: json['exercise_id'] as String?,
      name: json['name'] as String?,
      isBodyweight: json['is_bodyweight'] as bool? ?? false,
      thumbnailUrl: json['thumbnail_url'] as String?,
      muscleGroup: json['muscle_group'] as String?,
      target: json['target'] as String?,
      gifUrl: json['gif_url'] as String?,
      equipment: json['equipment'] as String?,
      instructions: json['instructions'] as String?,
      sets: json['sets'] as int? ?? 3,
      minReps: json['min_reps'] as int?,
      maxReps: json['max_reps'] as int?,
      rir: json['rir'] as int? ?? 0,
      previousPerformance:
          json['previous_performance'] == null
              ? null
              : PerformanceRecord.fromJson(
                  json['previous_performance'] as Map<String, dynamic>,
                ),
      suggestedNext:
          json['suggested_next'] == null
              ? null
              : OverloadSuggestion.fromJson(
                  json['suggested_next'] as Map<String, dynamic>,
                ),
    );
  }
}

/// Mejor set de la última sesión con este ejercicio (backend).
class PerformanceRecord {
  const PerformanceRecord({this.weight, this.reps, this.date});

  final double? weight;
  final int? reps;
  final DateTime? date;

  factory PerformanceRecord.fromJson(Map<String, dynamic> json) {
    return PerformanceRecord(
      weight: (json['weight'] as num?)?.toDouble(),
      reps: json['reps'] as int?,
      date: json['date'] == null
          ? null
          : DateTime.tryParse(json['date'] as String),
    );
  }
}

/// Sugerencia de sobrecarga progresiva calculada por el backend
/// (doble progresión: +reps hasta el tope, luego +2.5 kg volviendo al mínimo).
class OverloadSuggestion {
  const OverloadSuggestion({this.weight, this.reps});

  final double? weight;
  final int? reps;

  factory OverloadSuggestion.fromJson(Map<String, dynamic> json) {
    return OverloadSuggestion(
      weight: (json['weight'] as num?)?.toDouble(),
      reps: json['reps'] as int?,
    );
  }
}

class WorkoutPlan {
  const WorkoutPlan({required this.id, required this.name, this.exercises = const []});

  final String id;
  final String name;
  final List<WorkoutPlanExercise> exercises;

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      exercises: (json['exercises'] as List<dynamic>? ?? [])
          .map((e) => WorkoutPlanExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}