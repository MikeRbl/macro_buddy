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
/// Programa (plan) de entrenamiento: agrupa entrenamientos y dura un
/// número de ciclos (un ciclo = una semana). Solo uno está activo.
class TrainingProgram {
  const TrainingProgram({
    required this.id,
    required this.name,
    this.color = 'cyan',
    this.icon = 'rocket',
    this.cycles = 8,
    this.isActive = false,
    this.currentCycle,
    this.coachName,
    this.byCoach = false,
    this.workouts = const [],
  });

  final String id;
  final String name;
  final String color;
  final String icon;

  /// Duración del programa en ciclos.
  final int cycles;
  final bool isActive;

  /// Ciclo en curso (1, 2, …) si el programa está activo.
  final int? currentCycle;

  /// true si lo creó o lo editó un profesional vinculado.
  final bool byCoach;
  final String? coachName;
  final List<WorkoutPlan> workouts;

  /// true cuando ya pasaron todos los ciclos del programa.
  bool get isFinished => isActive && (currentCycle ?? 1) > cycles;

  factory TrainingProgram.fromJson(Map<String, dynamic> json) {
    final coach = json['coach'] as Map<String, dynamic>?;
    return TrainingProgram(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Mi programa',
      color: json['color'] as String? ?? 'cyan',
      icon: json['icon'] as String? ?? 'rocket',
      cycles: json['cycles'] as int? ?? 8,
      isActive: json['isActive'] as bool? ?? false,
      currentCycle: json['currentCycle'] as int?,
      byCoach: coach != null,
      coachName: coach?['name'] as String?,
      workouts: (json['workouts'] as List<dynamic>? ?? [])
          .map((e) => WorkoutPlan.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Aviso dentro de la app (p. ej. "tu entrenador cambió tu programa").
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.details = const [],
    this.read = false,
    this.at,
  });

  final String id;
  final String title;
  final String? body;
  final List<String> details;
  final bool read;
  final DateTime? at;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      details: (json['details'] as List<dynamic>? ?? []).cast<String>(),
      read: json['read'] as bool? ?? false,
      at: json['at'] == null ? null : DateTime.tryParse(json['at'] as String),
    );
  }
}
