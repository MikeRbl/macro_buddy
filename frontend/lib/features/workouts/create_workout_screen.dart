import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/exercise_thumbnail.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../create_program/add_exercises_sheet.dart';
import '../create_program/program_models.dart';
import 'workouts_provider.dart';

class CreateWorkoutScreen extends ConsumerStatefulWidget {
  const CreateWorkoutScreen({super.key});

  @override
  ConsumerState<CreateWorkoutScreen> createState() =>
      _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends ConsumerState<CreateWorkoutScreen> {
  late final TextEditingController _nameController;
  final List<ProgramExercise> _exercises = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Mi entrenamiento');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addExercise() async {
    final exercise = await showAddExercisesSheet(context);
    if (exercise == null) return;
    setState(() {
      _exercises.add(ProgramExercise(exercise: exercise));
      _error = null;
    });
  }

  void _removeExercise(int index) {
    setState(() => _exercises.removeAt(index));
  }

  Future<void> _saveWorkout() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) {
      setState(() => _error = 'Sesión expirada. Inicia sesión de nuevo.');
      return;
    }
    if (_exercises.isEmpty) {
      setState(() => _error = 'Agrega al menos un ejercicio al entrenamiento.');
      return;
    }

    final name = _nameController.text.trim().isEmpty
        ? 'Mi entrenamiento'
        : _nameController.text.trim();

    final exercisesPayload = _exercises
        .map((entry) => {
              'exercise_id': entry.exercise.id,
              'sets': entry.sets,
              'min_reps': entry.minReps,
              'max_reps': entry.maxReps,
              'rir': entry.rir,
            })
        .toList();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(apiClientProvider).createWorkout(
            token: token,
            name: name,
            exercises: exercisesPayload,
          );
      ref.invalidate(workoutProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrenamiento guardado en la biblioteca'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Error al guardar el entrenamiento.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    if (ref.watch(isGuidedModeProvider)) {
      // Modo guiado: las rutinas las fija el profesional; no hay nada
      // que editar aquí.
      return Scaffold(
        appBar: AppBar(title: const Text('Crear entrenamiento')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 44, color: c.textSecondary),
                const SizedBox(height: 12),
                Text(
                  'Rutinas fijadas por tu profesional.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'La creación de rutinas está deshabilitada en modo guiado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear entrenamiento'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _nameController,
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nombre del entrenamiento',
                  labelStyle: TextStyle(color: c.textSecondary),
                  hintText: 'Ej. Upper Body, Pierna, Rutina A...',
                  filled: true,
                  fillColor: c.input,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusInput),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _exercises.isEmpty
                  ? _buildEmptyState(c)
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _exercises.length,
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          final item = _exercises.removeAt(oldIndex);
                          _exercises.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final entry = _exercises[index];
                        return Padding(
                          key: ValueKey(entry),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _WorkoutExerciseConfigCard(
                            entry: entry,
                            onDelete: () => _removeExercise(index),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addExercise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.input,
                    foregroundColor: c.textPrimary,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar ejercicios'),
                ),
              ),
            ),
            _buildFooter(c),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, color: c.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(
              'Sin ejercicios todavía',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega ejercicios para configurar tus series y repeticiones.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: c.scaffold,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveWorkout,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Guardar en biblioteca'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutExerciseConfigCard extends StatefulWidget {
  const _WorkoutExerciseConfigCard({
    required this.entry,
    required this.onDelete,
  });

  final ProgramExercise entry;
  final VoidCallback onDelete;

  @override
  State<_WorkoutExerciseConfigCard> createState() =>
      _WorkoutExerciseConfigCardState();
}

class _WorkoutExerciseConfigCardState
    extends State<_WorkoutExerciseConfigCard> {
  late final TextEditingController _setsController;
  late final TextEditingController _minRepsController;
  late final TextEditingController _maxRepsController;

  @override
  void initState() {
    super.initState();
    _setsController = TextEditingController(text: '${widget.entry.sets}');
    _minRepsController =
        TextEditingController(text: '${widget.entry.minReps}');
    _maxRepsController =
        TextEditingController(text: '${widget.entry.maxReps}');
  }

  @override
  void dispose() {
    _setsController.dispose();
    _minRepsController.dispose();
    _maxRepsController.dispose();
    super.dispose();
  }

  void _onIntChanged(
    TextEditingController controller,
    void Function(int) setter,
  ) {
    setter(int.tryParse(controller.text) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final exercise = widget.entry.exercise;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: ExerciseThumbnail(url: exercise.thumbnailUrl, size: 52),
            title: Text(
              exercise.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (exercise.muscleGroup != null)
                    _MuscleChip(exercise.muscleGroup!),
                  for (final muscle in exercise.secondaryMuscles.take(2))
                    _MuscleChip(muscle),
                ],
              ),
            ),
            trailing: IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              tooltip: 'Eliminar ejercicio',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.input),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _MetricInput(
                      label: 'Series',
                      controller: _setsController,
                      onChanged: () => _onIntChanged(
                        _setsController,
                        (v) => widget.entry.sets = v,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricInput(
                      label: 'Reps mín',
                      controller: _minRepsController,
                      onChanged: () => _onIntChanged(
                        _minRepsController,
                        (v) => widget.entry.minReps = v,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricInput(
                      label: 'Reps máx',
                      controller: _maxRepsController,
                      onChanged: () => _onIntChanged(
                        _maxRepsController,
                        (v) => widget.entry.maxReps = v,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _MetricLabel('RIR'),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: c.input,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<int>(
                            value: widget.entry.rir,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            dropdownColor: c.card,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 14,
                            ),
                            items: [
                              for (var rir = 0; rir <= 5; rir++)
                                DropdownMenuItem(
                                  value: rir,
                                  child: Text('$rir'),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => widget.entry.rir = value ?? 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.input,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: c.textSecondary, fontSize: 11),
      ),
    );
  }
}

class _MetricLabel extends StatelessWidget {
  const _MetricLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11));
  }
}

class _MetricInput extends StatelessWidget {
  const _MetricInput({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricLabel(label),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => onChanged(),
          style: TextStyle(color: c.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
