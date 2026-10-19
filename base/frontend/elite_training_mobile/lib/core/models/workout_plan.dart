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