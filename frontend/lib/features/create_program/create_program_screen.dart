import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/exercise_thumbnail.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../workouts/workouts_provider.dart';
import 'add_exercises_sheet.dart';
import 'program_models.dart';

Future<int?> showDaysCycleDialog(BuildContext context) {
  final c = ThemeColors.of(context);
  return showDialog<int>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: const _DaysCycleDialogContent(),
    ),
  );
}

class _DaysCycleDialogContent extends StatefulWidget {
  const _DaysCycleDialogContent();

  @override
  State<_DaysCycleDialogContent> createState() =>
      _DaysCycleDialogContentState();
}

class _DaysCycleDialogContentState extends State<_DaysCycleDialogContent> {
  int _days = 7;

  void _adjust(int delta) {
    setState(() => _days = (_days + delta).clamp(1, 30));
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '¿Cuántos días tiene tu ciclo de entrenamiento?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CounterButton(icon: Icons.remove, onTap: () => _adjust(-1)),
              const SizedBox(width: 24),
              SizedBox(
                width: 80,
                child: Text(
                  '$_days',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              _CounterButton(icon: Icons.add, onTap: () => _adjust(1)),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_days),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: c.input, shape: BoxShape.circle),
        child: Icon(icon, color: c.textPrimary),
      ),
    );
  }
}

class CreateProgramScreen extends ConsumerStatefulWidget {
  const CreateProgramScreen({super.key, required this.days});

  final int days;

  @override
  ConsumerState<CreateProgramScreen> createState() =>
      _CreateProgramScreenState();
}

class _CreateProgramScreenState extends ConsumerState<CreateProgramScreen>
    with TickerProviderStateMixin {
  late List<ProgramDay> _days;
  late TabController _tabController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _days = List.generate(
      widget.days,
      (i) => ProgramDay(name: 'Entreno ${String.fromCharCode(65 + i)}'),
    );
    _tabController = TabController(length: _days.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  ProgramDay get _currentDay => _days[_tabController.index];

  void _rebuildTabs() {
    final oldIndex = _tabController.index;
    final old = _tabController;
    _tabController = TabController(
      length: _days.length,
      vsync: this,
      initialIndex: oldIndex.clamp(0, _days.length - 1),
    );
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) old.dispose();
    });
  }

  Future<void> _renameDay() async {
    final name = await _promptText(
      'Renombrar',
      _currentDay.name,
      'Nombre del entrenamiento',
    );
    if (name == null || name.isEmpty) return;
    setState(() => _currentDay.name = name);
  }

  Future<void> _setGymName() async {
    final name = await _promptText(
      'Nombre del gym',
      _currentDay.gymName ?? '',
      'Nombre del gym',
    );
    if (name == null) return;
    setState(() => _currentDay.gymName = name.isEmpty ? null : name);
  }

  Future<void> _reorderDay() async {
    final c = ThemeColors.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (value, label) in const [
                ('left', 'Mover a la izquierda'),
                ('right', 'Mover a la derecha'),
              ])
                ListTile(
                  title: Text(
                    label,
                    style: TextStyle(color: c.textPrimary, fontSize: 16),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(value),
                ),
            ],
          ),
        );
      },
    );
    if (action == null) return;
    final index = _tabController.index;
    final target = action == 'left' ? index - 1 : index + 1;
    if (target < 0 || target >= _days.length) return;
    setState(() {
      final day = _days.removeAt(index);
      _days.insert(target, day);
    });
    _rebuildTabs();
  }

  Future<String?> _promptText(String title, String initial, String hint) {
    final c = ThemeColors.of(context);
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(hintText: hint),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addExercises() async {
    final exercise = await showAddExercisesSheet(context);
    if (exercise == null) return;
    setState(() {
      _currentDay.exercises.add(ProgramExercise(exercise: exercise));
    });
  }

  void _removeExercise(ProgramExercise entry) {
    setState(() => _currentDay.exercises.remove(entry));
  }

  void _showExerciseMenu(ProgramExercise entry) {
    final c = ThemeColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
            title: const Text(
              'Eliminar del día',
              style: TextStyle(color: AppColors.danger, fontSize: 16),
            ),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _removeExercise(entry);
            },
          ),
        );
      },
    );
  }

  void _removeDay() {
    if (_days.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se requiere al menos un día')),
      );
      return;
    }
    setState(() => _days.removeAt(_tabController.index));
    _rebuildTabs();
  }

  void _addDay() {
    setState(() {
      _days.add(
        ProgramDay(name: 'Entreno ${String.fromCharCode(65 + _days.length)}'),
      );
    });
    _rebuildTabs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tabController.animateTo(_days.length - 1);
      }
    });
  }

  void _reorderDayTab(int oldIndex, int newIndex) {
    final selected = _days[_tabController.index];
    setState(() {
      final day = _days.removeAt(oldIndex);
      _days.insert(newIndex, day);
    });
    _rebuildTabs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tabController.index = _days.indexOf(selected);
      }
    });
  }

  Future<void> _saveProgram() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) {
      setState(() => _error = 'Sesión expirada. Inicia sesión de nuevo.');
      return;
    }
    final exercises = <Map<String, dynamic>>[
      for (final day in _days)
        for (final entry in day.exercises)
          {
            'exercise_id': entry.exercise.id,
            'sets': entry.sets,
            'min_reps': entry.minReps,
            'max_reps': entry.maxReps,
            'rir': entry.rir,
          },
    ];
    if (exercises.isEmpty) {
      setState(() => _error = 'Agrega al menos un ejercicio al programa.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .createWorkout(
            token: token,
            name: 'Mi programa',
            exercises: exercises,
          );
      ref.invalidate(workoutProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Programa guardado')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Ocurrió un error inesperado. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear programa'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
        ),
      ),
      body: Column(
        children: [
          _DaysTabBar(
            days: _days,
            selectedIndex: _tabController.index,
            onSelect: (index) => _tabController.animateTo(index),
            onReorder: _reorderDayTab,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _ActionChip(
                  icon: Icons.remove,
                  label: 'Eliminar',
                  onTap: _removeDay,
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.home_outlined,
                  label: 'Nombre del gym',
                  onTap: _setGymName,
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.edit_outlined,
                  label: 'Renombrar',
                  onTap: _renameDay,
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.compare_arrows,
                  label: 'Reordenar',
                  onTap: _reorderDay,
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.add,
                  label: '+ Agregar Día',
                  onTap: _addDay,
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [for (var i = 0; i < _days.length; i++) _buildDay(i)],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildFooter(),
    );
  }

  Widget _buildDay(int index) {
    final c = ThemeColors.of(context);
    final day = _days[index];
    return Column(
      children: [
        Expanded(
          child: day.exercises.isEmpty
              ? Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(AppColors.radiusCard),
                    border: Border.all(color: c.input),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.hotel_outlined,
                        color: c.textSecondary,
                        size: 28,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Puedes convertir el día de descanso en un día de entrenamiento agregando ejercicios abajo',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ReorderableListView(
                  padding: const EdgeInsets.all(16),
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final entry = day.exercises.removeAt(oldIndex);
                      day.exercises.insert(newIndex, entry);
                    });
                  },
                  children: [
                    for (final entry in day.exercises)
                      Padding(
                        key: ValueKey(entry),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExerciseConfigCard(
                          entry: entry,
                          onMenu: () => _showExerciseMenu(entry),
                        ),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addExercises,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.input,
                foregroundColor: c.textPrimary,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Exercises'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final c = ThemeColors.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
            ElevatedButton(
              onPressed: _saving ? null : _saveProgram,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.input,
                foregroundColor: c.textPrimary,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Guardar en biblioteca'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _saving ? null : _saveProgram,
              child: const Text('Activar programa'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaysTabBar extends StatelessWidget {
  const _DaysTabBar({
    required this.days,
    required this.selectedIndex,
    required this.onSelect,
    required this.onReorder,
  });

  final List<ProgramDay> days;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return SizedBox(
      height: 46,
      child: ReorderableListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        proxyDecorator: (child, index, animation) => Material(
          color: c.card,
          borderRadius: BorderRadius.circular(8),
          elevation: 2,
          child: child,
        ),
        onReorderItem: onReorder,
        children: [
          for (var i = 0; i < days.length; i++)
            _DayTab(
              key: ValueKey('day-$i-${days[i].name}'),
              label: days[i].name,
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _DayTab extends StatelessWidget {
  const _DayTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? c.textPrimary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c.textPrimary : c.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.input,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c.textPrimary, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: c.textPrimary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ExerciseConfigCard extends StatefulWidget {
  const _ExerciseConfigCard({required this.entry, required this.onMenu});

  final ProgramExercise entry;
  final VoidCallback onMenu;

  @override
  State<_ExerciseConfigCard> createState() => _ExerciseConfigCardState();
}

class _ExerciseConfigCardState extends State<_ExerciseConfigCard> {
  late final TextEditingController _setsController;
  late final TextEditingController _minRepsController;
  late final TextEditingController _maxRepsController;

  @override
  void initState() {
    super.initState();
    _setsController = TextEditingController(text: '${widget.entry.sets}');
    _minRepsController = TextEditingController(text: '${widget.entry.minReps}');
    _maxRepsController = TextEditingController(text: '${widget.entry.maxReps}');
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
              onPressed: widget.onMenu,
              icon: Icon(Icons.more_vert, color: c.textSecondary),
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
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
