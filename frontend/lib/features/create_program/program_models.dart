import 'package:flutter/material.dart';

import '../../core/models/exercise.dart';
import '../../core/models/workout_plan.dart';
import '../../theme/app_theme.dart';

class ProgramExercise {
  ProgramExercise({
    required this.exercise,
    this.sets = 3,
    this.minReps = 8,
    this.maxReps = 12,
    this.rir = 0,
  });

  /// Ejercicio de un entrenamiento ya guardado, listo para editarse.
  factory ProgramExercise.fromPlan(WorkoutPlanExercise ex) {
    return ProgramExercise(
      exercise: Exercise(
        id: ex.exerciseId ?? '',
        name: ex.name ?? 'Ejercicio',
        muscleGroup: ex.muscleGroup,
        target: ex.target,
        equipment: ex.equipment,
        isBodyweight: ex.isBodyweight,
        gifUrl: ex.gifUrl,
        thumbnailUrl: ex.thumbnailUrl,
        instructions: ex.instructions,
      ),
      sets: ex.sets,
      minReps: ex.minReps ?? 8,
      maxReps: ex.maxReps ?? 12,
      rir: ex.rir,
    );
  }

  final Exercise exercise;
  int sets;
  int minReps;
  int maxReps;
  int rir;

  Map<String, dynamic> toJson() => {
    'exercise_id': exercise.id,
    'sets': sets < 1 ? 1 : sets,
    'min_reps': minReps < 1 ? 1 : minReps,
    'max_reps': maxReps < 1 ? 1 : maxReps,
    'rir': rir,
  };
}

class ProgramDay {
  ProgramDay({
    this.id,
    required this.name,
    List<ProgramExercise>? exercises,
  }) : exercises = exercises ?? [];

  /// Id del entrenamiento guardado; `null` si el día es nuevo.
  final String? id;
  String name;
  final List<ProgramExercise> exercises;

  Map<String, dynamic> toJson() => {
    'id': ?id,
    'name': name,
    'exercises': [
      for (final e in exercises)
        if (e.exercise.id.isNotEmpty) e.toJson(),
    ],
  };
}

/// Colores e íconos que el usuario puede elegir para un programa.
/// Se guardan por nombre para que la web y el móvil los entiendan igual.
const programColors = <String, Color>{
  'cyan': AppColors.secondaryCyan,
  'coral': AppColors.primaryCoral,
  'orange': AppColors.coralLight,
  'amber': AppColors.warningAmber,
  'green': AppColors.successGreen,
  'blue': Color(0xFF4D8DFF),
  'purple': AppColors.tertiaryPurple,
};

const programColorNames = <String, String>{
  'cyan': 'Cian',
  'coral': 'Coral',
  'orange': 'Naranja',
  'amber': 'Ámbar',
  'green': 'Verde',
  'blue': 'Azul',
  'purple': 'Morado',
};

const programIcons = <String, IconData>{
  'rocket': Icons.rocket_launch_rounded,
  'dumbbell': Icons.fitness_center,
  'bolt': Icons.bolt,
  'flame': Icons.local_fire_department,
  'star': Icons.star_rounded,
  'heart': Icons.favorite,
  'trophy': Icons.emoji_events,
  'mountain': Icons.terrain,
  'run': Icons.directions_run,
  'timer': Icons.timer,
  'shield': Icons.shield,
  'target': Icons.track_changes,
};

Color programColor(String key) => programColors[key] ?? AppColors.secondaryCyan;
IconData programIcon(String key) => programIcons[key] ?? Icons.rocket_launch_rounded;

/// Cuadro de color con el ícono del programa.
class ProgramBadge extends StatelessWidget {
  const ProgramBadge({
    super.key,
    required this.color,
    required this.icon,
    this.size = 48,
  });

  final String color;
  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: programColor(color),
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Icon(
        programIcon(icon),
        color: AppColors.inkOnAccent,
        size: size * 0.5,
      ),
    );
  }
}
