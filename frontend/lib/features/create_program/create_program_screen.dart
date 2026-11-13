import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/workout_plan.dart';
import '../../core/widgets/exercise_thumbnail.dart';
import '../../theme/app_theme.dart';
import '../workouts/workouts_provider.dart';
import 'add_exercises_sheet.dart';
import 'program_models.dart';

/// Crear o editar un programa desde cero: sus días de entrenamiento, los
/// ejercicios de cada día y sus ajustes (nombre, color, ícono y duración
/// en ciclos).
///
/// Sin [program] crea uno nuevo; con [program] edita ese.
class ProgramEditorScreen extends ConsumerStatefulWidget {
  const ProgramEditorScreen({super.key, this.program});

  final TrainingProgram? program;

  @override
  ConsumerState<ProgramEditorScreen> createState() =>
      _ProgramEditorScreenState();
}

class _ProgramEditorScreenState extends ConsumerState<ProgramEditorScreen>
    with TickerProviderStateMixin {
  static const _maxCycles = 52;

  late List<ProgramDay> _days;
  late TabController _tabController;
  late String _name;
  late final TextEditingController _nameController;
  late String _color;
  late String _icon;
  late int _cycles;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.program == null;

  @override
  void initState() {
    super.initState();
    final p = widget.program;
    _name = p?.name ?? '';
    _color = p?.color ?? 'cyan';
    _icon = p?.icon ?? 'rocket';
    _cycles = p?.cycles ?? 8;
    _nameController = TextEditingController(text: _name);
    _days = [
      for (final w in p?.workouts ?? const <WorkoutPlan>[])
        ProgramDay(
          id: w.id,
          name: w.name,
          exercises: [
            for (final ex in w.exercises) ProgramExercise.fromPlan(ex),
          ],
        ),
    ];
    if (_days.isEmpty) _days.add(ProgramDay(name: _dayName(0)));
    _tabController = TabController(length: _days.length, vsync: this);
    _tabController.addListener(_onTab);
    if (_isNew) {
      // Programa nuevo: primero se le pone nombre, color y duración.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSettings();
      });
    }
  }

  static String _dayName(int index) =>
      'Entreno ${String.fromCharCode(65 + index % 26)}';

  void _onTab() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  ProgramDay get _currentDay => _days[_tabController.index];

  void _rebuildTabs({int? index}) {
    final old = _tabController;
    _tabController = TabController(
      length: _days.length,
      vsync: this,
      initialIndex: (index ?? old.index).clamp(0, _days.length - 1),
    );
    _tabController.addListener(_onTab);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> _renameDay() async {
    final name = await _promptText(
      'Renombrar entrenamiento',
      _currentDay.name,
      'Ej. Pecho y tríceps',
    );
    if (name == null || name.isEmpty) return;
    setState(() => _currentDay.name = name);
  }

  void _moveDay(int delta) {
    final from = _tabController.index;
    final to = from + delta;
    if (to < 0 || to >= _days.length) return;
    final day = _days.removeAt(from);
    _days.insert(to, day);
    _rebuildTabs(index: to);
  }

  Future<String?> _promptText(String title, String initial, String hint) {
    final c = ThemeColors.of(context);
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: c.card,
          title: Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: c.textPrimary),
            decoration: InputDecoration(hintText: hint, counterText: ''),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancelar', style: TextStyle(color: c.textSecondary)),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addExercises() async {
    final exercise = await showAddExercisesSheet(context);
    if (exercise == null) return;
    setState(() {
      _currentDay.exercises.add(ProgramExercise(exercise: exercise));
      _error = null;
    });
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
              'Quitar del entrenamiento',
              style: TextStyle(color: AppColors.danger, fontSize: 16),
            ),
            onTap: () {
              Navigator.of(sheetContext).pop();
              setState(() => _currentDay.exercises.remove(entry));
            },
          ),
        );
      },
    );
  }

  void _removeDay() {
    if (_days.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El programa necesita al menos un entrenamiento'),
        ),
      );
      return;
    }
    _days.removeAt(_tabController.index);
    _rebuildTabs();
  }

  void _addDay() {
    _days.add(ProgramDay(name: _dayName(_days.length)));
    _rebuildTabs(index: _days.length - 1);
  }

  void _reorderDayTab(int oldIndex, int newIndex) {
    final selected = _days[_tabController.index];
    final day = _days.removeAt(oldIndex);
    _days.insert(newIndex, day);
    _rebuildTabs(index: _days.indexOf(selected));
  }

  /// Ajustes del programa: duración (ciclos), nombre, color e ícono.
  Future<void> _openSettings() async {
    final c = ThemeColors.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            void update(VoidCallback change) {
              setState(change);
              setSheet(() {});
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ajustes del programa',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: Icon(Icons.close, color: c.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SettingLabel('Nombre'),
                      TextField(
                        key: const Key('program-name'),
                        controller: _nameController,
                        maxLength: 60,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(color: c.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Ej. Torso / Pierna',
                          counterText: '',
                        ),
                        onChanged: (v) => update(() {
                          _name = v.trim();
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Duración',
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_cycles ${_cycles == 1 ? 'ciclo' : 'ciclos'}'
                                  ' · un ciclo es una semana',
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _CounterButton(
                            icon: Icons.remove,
                            tooltip: 'Menos ciclos',
                            onTap: _cycles > 1
                                ? () => update(() => _cycles--)
                                : null,
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '$_cycles',
                              key: const Key('program-cycles'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          _CounterButton(
                            icon: Icons.add,
                            tooltip: 'Más ciclos',
                            onTap: _cycles < _maxCycles
                                ? () => update(() => _cycles++)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SettingLabel('Color'),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final entry in programColors.entries)
                            Semantics(
                              button: true,
                              selected: _color == entry.key,
                              label: programColorNames[entry.key],
                              child: GestureDetector(
                                onTap: () => update(() => _color = entry.key),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: entry.value,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _color == entry.key
                                          ? c.textPrimary
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SettingLabel('Ícono'),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final entry in programIcons.entries)
                            GestureDetector(
                              onTap: () => update(() => _icon = entry.key),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _icon == entry.key
                                      ? programColor(_color)
                                      : c.input,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  entry.value,
                                  size: 22,
                                  color: _icon == entry.key
                                      ? AppColors.inkOnAccent
                                      : c.textPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Listo'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _save({required bool activate}) async {
    if (_name.isEmpty) {
      setState(() => _error = 'Ponle un nombre al programa.');
      _openSettings();
      return;
    }
    if (_days.every((d) => d.exercises.isEmpty)) {
      setState(() => _error = 'Agrega al menos un ejercicio al programa.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await ref
        .read(workoutProvider.notifier)
        .saveProgram(
          programId: widget.program?.id,
          body: {
            'name': _name,
            'color': _color,
            'icon': _icon,
            'cycles': _cycles,
            'activate': activate,
            'days': [for (final day in _days) day.toJson()],
          },
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(activate ? 'Programa activado' : 'Programa guardado'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final coach = widget.program?.byCoach ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Crear programa' : 'Editar programa'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: 'Ajustes del programa',
            onPressed: _openSettings,
            icon: Icon(Icons.tune, color: c.textPrimary),
          ),
        ],
      ),
      body: Column(
        children: [
          // Resumen del programa: tocarlo abre los ajustes.
          InkWell(
            onTap: _openSettings,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  ProgramBadge(color: _color, icon: _icon, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name.isEmpty ? 'Programa sin nombre' : _name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _name.isEmpty
                                ? c.textSecondary
                                : c.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Duración: $_cycles '
                          '${_cycles == 1 ? 'ciclo' : 'ciclos'}',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Ajustes',
                    style: TextStyle(
                      color: programColor(_color),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (coach)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tertiaryPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Este programa es de '
                '${widget.program?.coachName ?? 'tu entrenador'}. '
                'Puedes cambiarlo; tu entrenador verá qué cambiaste.',
                style: TextStyle(color: c.textPrimary, fontSize: 13),
              ),
            ),
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
                  icon: Icons.add,
                  label: 'Agregar día',
                  onTap: _addDay,
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.edit_outlined,
                  label: 'Renombrar',
                  onTap: _renameDay,
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.arrow_back,
                  label: 'Mover',
                  onTap: () => _moveDay(-1),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.arrow_forward,
                  label: 'Mover',
                  onTap: () => _moveDay(1),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.remove_circle_outline,
                  label: 'Quitar día',
                  onTap: _removeDay,
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
              ? SingleChildScrollView(
                  child: Container(
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
                          Icons.fitness_center,
                          color: c.textSecondary,
                          size: 28,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Este entrenamiento aún no tiene ejercicios. '
                          'Agrégalos con el botón de abajo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
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
              label: const Text('Agregar ejercicio'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final c = ThemeColors.of(context);
    final active = widget.program?.isActive ?? false;
    const spinner = SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    );
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
            if (active)
              ElevatedButton(
                onPressed: _saving ? null : () => _save(activate: false),
                child: _saving ? spinner : const Text('Guardar cambios'),
              )
            else ...[
              ElevatedButton(
                onPressed: _saving ? null : () => _save(activate: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.input,
                  foregroundColor: c.textPrimary,
                ),
                child: _saving
                    ? spinner
                    : Text(_isNew ? 'Guardar sin activar' : 'Guardar cambios'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _saving ? null : () => _save(activate: true),
                child: const Text('Activar programa'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: c.input,
        minimumSize: const Size(44, 44),
      ),
      icon: Icon(icon, color: onTap == null ? c.textSecondary : c.textPrimary),
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
