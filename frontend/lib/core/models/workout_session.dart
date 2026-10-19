class WorkoutSessionSet {
  const WorkoutSessionSet({
    required this.setNumber,
    this.exerciseId,
    this.exerciseName,
    this.weight,
    this.reps,
    this.rir,
    this.isWarmup = false,
  });

  final int setNumber;
  final String? exerciseId;
  final String? exerciseName;
  final double? weight;
  final int? reps;
  final int? rir;
  final bool isWarmup;

  factory WorkoutSessionSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionSet(
      setNumber: json['set_number'] as int? ?? 0,
      exerciseId: json['exercise_id'] as String?,
      exerciseName: json['exercise_name'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      reps: json['reps'] as int?,
      rir: json['rir'] as int?,
      isWarmup: json['is_warmup'] as bool? ?? false,
    );
  }
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.date,
    this.duration,
    this.note,
    this.sets = const [],
  });

  final String id;
  final DateTime date;
  final int? duration;
  final String? note;
  final List<WorkoutSessionSet> sets;

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      duration: json['duration'] as int?,
      note: json['note'] as String?,
      sets: (json['sets'] as List<dynamic>? ?? [])
          .map((s) => WorkoutSessionSet.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
