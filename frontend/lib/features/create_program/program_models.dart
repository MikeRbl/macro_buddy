import '../../core/models/exercise.dart';

class ProgramExercise {
  ProgramExercise({
    required this.exercise,
    this.sets = 3,
    this.minReps = 8,
    this.maxReps = 12,
    this.rir = 0,
  });

  final Exercise exercise;
  int sets;
  int minReps;
  int maxReps;
  int rir;
}

class ProgramDay {
  ProgramDay({
    required this.name,
    this.gymName,
    List<ProgramExercise>? exercises,
  }) : exercises = exercises ?? [];

  String name;
  String? gymName;
  final List<ProgramExercise> exercises;
}
