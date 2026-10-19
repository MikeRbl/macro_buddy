import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/exercise_thumbnail.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../create_program/add_exercises_sheet.dart';
import 'active_workout_screen.dart';
import 'workout_models.dart';

class WorkoutPreviewScreen extends ConsumerStatefulWidget {
  const WorkoutPreviewScreen({
    super.key,
    required this.title,
    this.exercises = const [],
    this.workoutId,
  });

  final String title;
  final List<PreviewExercise> exercises;
  final String? workoutId;

  @override
  ConsumerState<WorkoutPreviewScreen> createState() =>
      _WorkoutPreviewScreenState();
}

class _WorkoutPreviewScreenState extends ConsumerState<WorkoutPreviewScreen> {
  late List<PreviewExercise> _exercises;

  @override
  void initState() {
    super.initState();
    _exercises = List.of(widget.exercises);
  }

  Map<String, int> _muscleCounts() {
    final counts = <String, int>{};
    for (final exercise in _exercises) {
      for (final muscle in exercise.muscles) {
        counts[muscle] = (counts[muscle] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> _addExtraExercise() async {
    if (ref.read(isGuidedModeProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ThemeColors.dark.card,
          content: Text(
            'Modo guiado: tu profesional fija las rutinas.',
            style: TextStyle(color: ThemeColors.dark.textPrimary),
          ),
        ),
      );
      return;
    }
    final catalog = await showAddExercisesSheet(context);
    if (catalog == null) return;
    setState(() {
      _exercises.add(PreviewExercise.fromCatalog(catalog));
    });
  }

  void _showExerciseOptions(int index) {
    final c = ThemeColors.of(context);
    final exercise = _exercises[index];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              _OptionTile(
                icon: Icons.info_outline,
                label: 'Información',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${exercise.name} · ${exercise.muscles.join(', ')}',
                      ),
                    ),
                  );
                },
              ),
              // Modo guiado: el profesional fija la rutina, así que solo
              // queda la información; nada de editar objetivos, cambiar o
              // quitar ejercicios.
              if (!ref.watch(isGuidedModeProvider)) ...[
                _OptionTile(
                  icon: Icons.edit_outlined,
                  label: 'Objetivos',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final targets = await _editTargets(exercise);
                    if (targets == null || !mounted) return;
                    setState(() {
                      _exercises[index] = exercise.copyWith(
                        sets: targets.sets,
                        minReps: targets.minReps,
                        maxReps: targets.maxReps,
                        rir: targets.rir,
                      );
                    });
                  },
                ),
                _OptionTile(
                  icon: Icons.swap_horiz,
                  label: 'Cambiar',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final replacement = await showAddExercisesSheet(context);
                    if (replacement == null || !mounted) return;
                    setState(() {
                      _exercises[index] = PreviewExercise.fromCatalog(
                        replacement,
                        sets: exercise.sets,
                        minReps: exercise.minReps,
                        maxReps: exercise.maxReps,
                        rir: exercise.rir,
                      );
                    });
                  },
                ),
                _OptionTile(
                  icon: Icons.remove_circle_outline,
                  label: 'Quitar del entrenamiento',
                  isDestructive: true,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() => _exercises.removeAt(index));
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<({int sets, int minReps, int maxReps, int rir})?> _editTargets(
    PreviewExercise exercise,
  ) {
    final c = ThemeColors.of(context);
    return showModalBottomSheet<
      ({int sets, int minReps, int maxReps, int rir})
    >(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TargetsSheet(exercise: exercise),
    );
  }

  void _startWorkout() {
    if (_exercises.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActiveWorkoutScreen(
          exercises: _exercises,
          workoutName: widget.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final counts = _muscleCounts();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _exercises.isEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(AppColors.radiusCard),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.fitness_center,
                      color: c.textSecondary,
                      size: 28,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Este entrenamiento no tiene ejercicios.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 118,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: counts.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final muscle = counts.keys.elementAt(index);
                        final count = counts[muscle]!;
                        return Container(
                          width: 100,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(
                              AppColors.radiusCard,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.accessibility_new,
                                color: AppColors.accentOrange,
                                size: 26,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                muscle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$count ${count == 1 ? 'ejercicio' : 'ejercicios'}',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_exercises.length} ${_exercises.length == 1 ? 'Ejercicio' : 'Ejercicios'}',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: _addExtraExercise,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c.input,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add,
                            color: c.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _exercises.length; i++) ...[
                    _ExerciseTile(
                      exercise: _exercises[i],
                      onMenu: () => _showExerciseOptions(i),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: c.scaffold,
          child: ElevatedButton(
            onPressed: _startWorkout,
            child: const Text('Iniciar entrenamiento'),
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final color = isDestructive ? AppColors.danger : c.textPrimary;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontSize: 16)),
      onTap: onTap,
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise, required this.onMenu});

  final PreviewExercise exercise;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExerciseThumbnail(url: exercise.thumbnailUrl, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (
                    var setNumber = 1;
                    setNumber <= exercise.sets;
                    setNumber++
                  )
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Text(
                            '$setNumber | ${exercise.minReps}-${exercise.maxReps} reps',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.local_fire_department,
                            color: AppColors.danger,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'RIR ${exercise.rir}',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: exercise.muscles
                        .map(
                          (muscle) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: c.input,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              muscle,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onMenu,
              icon: Icon(Icons.more_vert, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetsSheet extends StatefulWidget {
  const _TargetsSheet({required this.exercise});

  final PreviewExercise exercise;

  @override
  State<_TargetsSheet> createState() => _TargetsSheetState();
}

class _TargetsSheetState extends State<_TargetsSheet> {
  late final TextEditingController _setsController;
  late final TextEditingController _minRepsController;
  late final TextEditingController _maxRepsController;
  late int _rir;

  @override
  void initState() {
    super.initState();
    _setsController = TextEditingController(text: '${widget.exercise.sets}');
    _minRepsController = TextEditingController(
      text: '${widget.exercise.minReps}',
    );
    _maxRepsController = TextEditingController(
      text: '${widget.exercise.maxReps}',
    );
    _rir = widget.exercise.rir;
  }

  @override
  void dispose() {
    _setsController.dispose();
    _minRepsController.dispose();
    _maxRepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Objetivos',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _smallInput(_setsController, 'Series')),
              const SizedBox(width: 8),
              Expanded(child: _smallInput(_minRepsController, 'Reps mín')),
              const SizedBox(width: 8),
              Expanded(child: _smallInput(_maxRepsController, 'Reps máx')),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: c.input,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<int>(
                    value: _rir,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    dropdownColor: c.card,
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                    items: [
                      for (var rir = 0; rir <= 5; rir++)
                        DropdownMenuItem(value: rir, child: Text('RIR $rir')),
                    ],
                    onChanged: (value) => setState(() => _rir = value ?? 0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop((
              sets: int.tryParse(_setsController.text) ?? 3,
              minReps: int.tryParse(_minRepsController.text) ?? 8,
              maxReps: int.tryParse(_maxRepsController.text) ?? 12,
              rir: _rir,
            )),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _smallInput(TextEditingController controller, String label) {
    final c = ThemeColors.of(context);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.textSecondary, fontSize: 11),
        isDense: true,
      ),
    );
  }
}
