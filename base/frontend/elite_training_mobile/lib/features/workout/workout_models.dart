import '../../core/models/exercise.dart';

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
    );
  }
}
