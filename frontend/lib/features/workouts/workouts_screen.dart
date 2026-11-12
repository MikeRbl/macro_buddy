import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/api/api_client.dart';
import '../../core/models/workout_plan.dart';
import '../../core/widgets/glass_card.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../dashboard/dashboard_provider.dart';
import '../workout/active_workout_screen.dart';
import '../workout/workout_models.dart';
import '../workout/workout_preview_screen.dart';
import '../workout/workout_ui.dart';
import 'create_workout_screen.dart';
import 'workout_history_screen.dart';
import 'workouts_provider.dart';

/// Pestaña Workout.
///
/// Flujo pensado para ser directo:
///   1. Semana arriba (días entrenados marcados).
///   2. "Programa activo": tarjeta desplegable con cada entrenamiento,
///      sus ejercicios, músculos y una casilla de "hecho esta semana".
///   3. Botón grande "Empezar" con el siguiente entrenamiento pendiente.
///   4. Tocar un entrenamiento abre su detalle (músculos, ejercicios y
///      botón Iniciar), y de ahí al registro de series.
class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  static const _dayNames = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  late final List<DateTime> _days;
  late DateTime _selectedDay;
  Set<DateTime> _trainedDays = {};
  bool _programExpanded = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Semana actual de lunes a domingo.
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    _days = List.generate(7, (i) => monday.add(Duration(days: i)));
    _selectedDay = DateTime(now.year, now.month, now.day);
    _loadTrainedDays();
  }

  Future<void> _loadTrainedDays() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) return;
    try {
      final items = await ref
          .read(apiClientProvider)
          .fetchUserWorkouts(token: token);
      final dates = <DateTime>{};
      for (final item in items) {
        final parsed = DateTime.tryParse(
          (item as Map)['date'] as String? ?? '',
        );
        if (parsed != null) {
          final local = parsed.toLocal();
          dates.add(DateTime(local.year, local.month, local.day));
        }
      }
      if (mounted) setState(() => _trainedDays = dates);
    } catch (_) {
      // ignore load errors; calendar/history handle their own retries
    }
  }

  bool _hasWorkoutOn(DateTime day) =>
      _trainedDays.contains(DateTime(day.year, day.month, day.day));

  void _openAddSheet() {
    final c = ThemeColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return _AddSheet(
          onStartEmptyWorkout: () {
            Navigator.of(sheetContext).pop();
            _openFreeWorkout();
          },
          onCreateWorkout: () {
            Navigator.of(sheetContext).pop();
            _openCreateWorkout();
          },
        );
      },
    );
  }

  Future<void> _openCreateWorkout() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CreateWorkoutScreen(),
      ),
    );
    _loadTrainedDays();
  }

  Future<void> _openFreeWorkout() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ActiveWorkoutScreen(exercises: []),
      ),
    );
    _loadTrainedDays();
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WorkoutHistoryScreen()),
    );
  }

  Future<void> _openCalendar() async {
    await _loadTrainedDays();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _MonthlyCalendarDialog(trainedDates: _trainedDays),
    );
  }

  Future<void> _openPreview(WorkoutPlan plan) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutPreviewScreen(
          title: plan.name,
          workoutId: plan.id,
          exercises: [
            for (final ex in plan.exercises) PreviewExercise.fromPlan(ex),
          ],
        ),
      ),
    );
    _loadTrainedDays();
  }

  Future<void> _renameProgram(String current) async {
    final c = ThemeColors.of(context);
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text(
          'Nombre del programa',
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) {
      await ref.read(workoutProvider.notifier).renameProgram(name);
    }
  }

  int _weekNumber() {
    final sessions = ref.watch(dashboardProvider).value ?? const [];
    DateTime? first;
    for (final s in sessions) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      if (first == null || d.isBefore(first)) first = d;
    }
    if (first == null) return 1;
    final week = (DateTime.now().difference(first).inDays / 7).floor() + 1;
    return week < 1 ? 1 : week;
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final ws = ref.watch(workoutProvider);

    // Siguiente entrenamiento: el primero no hecho esta semana.
    WorkoutPlan? next;
    for (final p in ws.workouts) {
      if (!ws.doneThisWeek.contains(p.id)) {
        next = p;
        break;
      }
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(workoutProvider.notifier).refresh(),
            _loadTrainedDays(),
          ]);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppColors.screenPadding,
                  8,
                  AppColors.screenPadding,
                  12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'WORKOUT',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    _RoundIconButton(
                      icon: Icons.calendar_today_outlined,
                      tooltip: 'Calendario',
                      onTap: _openCalendar,
                    ),
                    const SizedBox(width: 8),
                    _RoundIconButton(
                      icon: Icons.history,
                      tooltip: 'Historial',
                      onTap: _openHistory,
                    ),
                    const SizedBox(width: 8),
                    _RoundIconButton(
                      icon: Icons.add,
                      tooltip: 'Agregar',
                      onTap: _openAddSheet,
                    ),
                  ],
                ),
              ),
            ),
            _WeekStrip(
              days: _days,
              dayNames: _dayNames,
              selectedDay: _selectedDay,
              hasWorkout: _hasWorkoutOn,
              onSelect: (day) => setState(() => _selectedDay = day),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Programa activo',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryCyan.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'Semana ${_weekNumber()}',
                      style: const TextStyle(
                        color: AppColors.secondaryCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildProgram(ws, next),
            if (next != null && !ws.loading) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _StartNextButton(
                  plan: next,
                  onTap: () => _openPreview(next!),
                ),
              ),
            ] else if (ws.workouts.isNotEmpty && !ws.loading) ...[
              const SizedBox(height: 16),
              const _WeekCompleteBanner(),
            ],
            const SizedBox(height: 24),
            const _PersonalRecordsCard(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Más',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _MoreActions(
              onEmptyWorkout: _openFreeWorkout,
              onCreateWorkout: _openCreateWorkout,
              onHistory: _openHistory,
            ),
            // Zona inferior para no quedar oculto bajo el navbar ni el FAB.
            const SizedBox(height: 170),
          ],
        ),
      ),
    );
  }

  Widget _buildProgram(WorkoutsState ws, WorkoutPlan? next) {
    if (ws.loading) {
      return const _ProgramLoading();
    }
    if (ws.error != null) {
      return _ProgramMessage(
        icon: Icons.cloud_off,
        title: 'No pudimos cargar tus entrenamientos',
        message: ws.error!,
        primaryLabel: 'Reintentar',
        onPrimary: () => ref.read(workoutProvider.notifier).refresh(),
      );
    }
    if (ws.workouts.isEmpty) {
      return _ProgramMessage(
        icon: Icons.fitness_center,
        title: 'Aún no tienes entrenamientos',
        message:
            'Crea tu primer entrenamiento (por ejemplo "Pecho y tríceps") '
            'y aparecerá aquí listo para empezar.',
        primaryLabel: 'Crear entrenamiento',
        onPrimary: _openCreateWorkout,
        secondaryLabel: 'Entrenar sin rutina',
        onSecondary: _openFreeWorkout,
      );
    }

    final c = ThemeColors.of(context);
    final doneCount =
        ws.workouts.where((w) => ws.doneThisWeek.contains(w.id)).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _programExpanded = !_programExpanded),
            onLongPress: () => _renameProgram(ws.programName),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryCyan,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: AppColors.inkOnAccent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ws.programName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ws.workouts.length} '
                          '${ws.workouts.length == 1 ? 'entrenamiento' : 'entrenamientos'}'
                          ' · $doneCount/${ws.workouts.length} esta semana',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Renombrar programa',
                    onPressed: () => _renameProgram(ws.programName),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: c.textSecondary,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _programExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Barra de progreso semanal.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: ws.workouts.isEmpty
                    ? 0
                    : doneCount / ws.workouts.length,
                backgroundColor: c.input,
                color: AppColors.secondaryCyan,
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _programExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            secondChild: const SizedBox(width: double.infinity, height: 8),
            firstChild: ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) {
                ref
                    .read(workoutProvider.notifier)
                    .reorderItem(oldIndex, newIndex);
              },
              children: [
                for (var i = 0; i < ws.workouts.length; i++)
                  ReorderableDelayedDragStartListener(
                    key: ValueKey(ws.workouts[i].id),
                    index: i,
                    child: _ProgramWorkoutRow(
                      plan: ws.workouts[i],
                      isNext: ws.workouts[i].id == next?.id,
                      done: ws.doneThisWeek.contains(ws.workouts[i].id),
                      showDivider: i > 0,
                      onTap: () => _openPreview(ws.workouts[i]),
                      onToggleDone: () => ref
                          .read(workoutProvider.notifier)
                          .toggleDone(ws.workouts[i].id),
                    ),
                  ),
              ],
            ),
          ),
          if (_programExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Mantén presionado un entrenamiento para reordenarlo.',
                style: TextStyle(color: c.iconMuted, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.input,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: c.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Semana actual (L–D). Los días con entrenamiento registrado llevan
/// borde cyan; hoy va relleno.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.days,
    required this.dayNames,
    required this.selectedDay,
    required this.hasWorkout,
    required this.onSelect,
  });

  final List<DateTime> days;
  final List<String> dayNames;
  final DateTime selectedDay;
  final bool Function(DateTime) hasWorkout;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Builder(
                builder: (context) {
                  final day = days[i];
                  final trained = hasWorkout(day);
                  final isToday = day == today;
                  final selected = day == selectedDay;
                  return GestureDetector(
                    onTap: () => onSelect(day),
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.secondaryCyan.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: trained || selected
                              ? AppColors.secondaryCyan
                              : c.input,
                          width: selected ? 2 : 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            dayNames[day.weekday - 1],
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? c.textPrimary
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila de un entrenamiento dentro del programa: nombre, ejercicios,
/// músculos y casilla de "hecho esta semana".
class _ProgramWorkoutRow extends StatelessWidget {
  const _ProgramWorkoutRow({
    required this.plan,
    required this.isNext,
    required this.done,
    required this.showDivider,
    required this.onTap,
    required this.onToggleDone,
  });

  final WorkoutPlan plan;
  final bool isNext;
  final bool done;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final names = plan.exercises
        .map((e) => e.name)
        .whereType<String>()
        .join(', ');
    final muscles = <String>{
      for (final e in plan.exercises)
        if (e.muscleGroup != null && e.muscleGroup!.isNotEmpty)
          muscleLabel(e.muscleGroup!),
    }.toList()
      ..sort();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (showDivider) Divider(height: 1, color: c.input),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  plan.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: done
                                        ? c.textSecondary
                                        : c.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              if (isNext) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.coral,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'SIGUIENTE',
                                    style: TextStyle(
                                      color: AppColors.inkOnAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            names.isEmpty ? 'Sin ejercicios' : names,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                          if (muscles.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 22,
                              child: ShaderMask(
                                // Desvanece el borde derecho si hay más chips.
                                shaderCallback: (rect) => const LinearGradient(
                                  colors: [Colors.white, Colors.white, Colors.transparent],
                                  stops: [0, 0.85, 1],
                                ).createShader(rect),
                                blendMode: BlendMode.dstIn,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: muscles.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 6),
                                  itemBuilder: (_, i) => MuscleChip(muscles[i]),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _DoneBox(done: done, onTap: onToggleDone),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneBox extends StatelessWidget {
  const _DoneBox({required this.done, required this.onTap});

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Tooltip(
      message: done ? 'Hecho esta semana' : 'Marcar como hecho',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: done ? AppColors.secondaryCyan : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: done ? AppColors.secondaryCyan : c.textSecondary,
                width: 2,
              ),
            ),
            child: done
                ? const Icon(
                    Icons.check,
                    size: 18,
                    color: AppColors.inkOnAccent,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Botón grande para arrancar el siguiente entrenamiento pendiente.
class _StartNextButton extends StatelessWidget {
  const _StartNextButton({required this.plan, required this.onTap});

  final WorkoutPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sets = plan.exercises.fold<int>(0, (a, e) => a + e.sets);
    final minutes = estimatedMinutes(sets);
    return Material(
      color: AppColors.coral,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.play_circle_fill,
                color: AppColors.inkOnAccent,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EMPEZAR SIGUIENTE',
                      style: TextStyle(
                        color: AppColors.inkOnAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkOnAccent,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${plan.exercises.length} ej · ~$minutes min',
                style: const TextStyle(
                  color: AppColors.inkOnAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.inkOnAccent),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekCompleteBanner extends StatelessWidget {
  const _WeekCompleteBanner();

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.successGreen.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: AppColors.successGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '¡Semana completa! Todos tus entrenamientos están hechos.',
              style: TextStyle(color: c.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramLoading extends StatelessWidget {
  const _ProgramLoading();

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Skeleton(width: 120, height: 14, color: c.input),
                      const SizedBox(height: 8),
                      _Skeleton(
                        width: double.infinity,
                        height: 10,
                        color: c.input,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _Skeleton(width: 26, height: 26, color: c.input),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// Tarjeta de estado (vacío o error) con acciones claras.
class _ProgramMessage extends StatelessWidget {
  const _ProgramMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, color: AppColors.secondaryCyan, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onPrimary, child: Text(primaryLabel)),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel!,
                style: TextStyle(color: c.textPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Récords personales: mejor peso por ejercicio del historial.
class _PersonalRecordsCard extends ConsumerWidget {
  const _PersonalRecordsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ThemeColors.of(context);
    final sessions = ref.watch(dashboardProvider).value ?? const [];
    final best = <String, ({double weight, int reps})>{};
    for (final s in sessions) {
      for (final set in s.sets) {
        if (set.isWarmup) continue;
        final name = set.exerciseName?.trim();
        final w = set.weight ?? 0;
        if (name == null || name.isEmpty || w <= 0) continue;
        final prev = best[name];
        if (prev == null || w > prev.weight) {
          best[name] = (weight: w, reps: set.reps ?? 0);
        }
      }
    }
    final entries = best.entries.toList()
      ..sort((a, b) => b.value.weight.compareTo(a.value.weight));

    String fmt(double v) =>
        v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.warningAmber,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Récords personales',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Text(
                'Completa tu primer entrenamiento y aquí verás tu mejor '
                'marca en cada ejercicio.',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              )
            else
              for (final e in entries.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        '${fmt(e.value.weight)} lb × ${e.value.reps}',
                        style: TextStyle(
                          color: AppColors.secondaryCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ).merge(AppTypography.numeric),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _MoreActions extends StatelessWidget {
  const _MoreActions({
    required this.onEmptyWorkout,
    required this.onCreateWorkout,
    required this.onHistory,
  });

  final VoidCallback onEmptyWorkout;
  final VoidCallback onCreateWorkout;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    Widget tile(IconData icon, String title, String subtitle, VoidCallback onTap) {
      return ListTile(
        leading: Icon(icon, color: c.textPrimary),
        title: Text(
          title,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: c.textSecondary, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: c.textSecondary),
        onTap: onTap,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            tile(
              Icons.play_arrow_rounded,
              'Entrenamiento libre',
              'Empieza ahora y agrega ejercicios sobre la marcha',
              onEmptyWorkout,
            ),
            Divider(height: 1, color: c.input),
            tile(
              Icons.add_box_outlined,
              'Crear entrenamiento',
              'Arma una rutina para tu programa',
              onCreateWorkout,
            ),
            Divider(height: 1, color: c.input),
            tile(
              Icons.receipt_long,
              'Historial',
              'Revisa tus sesiones anteriores',
              onHistory,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSheet extends StatelessWidget {
  const _AddSheet({
    required this.onStartEmptyWorkout,
    required this.onCreateWorkout,
  });

  final VoidCallback onStartEmptyWorkout;
  final VoidCallback onCreateWorkout;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: c.textPrimary),
                ),
                Text(
                  'Agregar',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            Divider(height: 1, color: c.input),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.play_arrow, color: c.textPrimary),
              title: Text(
                'Iniciar entrenamiento libre',
                style: TextStyle(color: c.textPrimary, fontSize: 16),
              ),
              onTap: onStartEmptyWorkout,
            ),
            ListTile(
              leading: Icon(Icons.fitness_center, color: c.textPrimary),
              title: Text(
                'Crear entrenamiento',
                style: TextStyle(color: c.textPrimary, fontSize: 16),
              ),
              onTap: onCreateWorkout,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyCalendarDialog extends StatefulWidget {
  const _MonthlyCalendarDialog({required this.trainedDates});

  final Set<DateTime> trainedDates;

  @override
  State<_MonthlyCalendarDialog> createState() => _MonthlyCalendarDialogState();
}

class _MonthlyCalendarDialogState extends State<_MonthlyCalendarDialog> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = now;
    _selectedDay = now;
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Dialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TableCalendar(
          firstDay: DateTime.utc(DateTime.now().year - 1, 1, 1),
          lastDay: DateTime.utc(DateTime.now().year + 1, 12, 31),
          focusedDay: _focusedDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            });
          },
          onPageChanged: (focused) => setState(() => _focusedDay = focused),
          eventLoader: (day) => widget.trainedDates
                  .contains(DateTime(day.year, day.month, day.day))
              ? const [1]
              : const [],
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            leftChevronIcon: Icon(Icons.chevron_left, color: c.textPrimary),
            rightChevronIcon: Icon(Icons.chevron_right, color: c.textPrimary),
            headerPadding: const EdgeInsets.only(bottom: 8),
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            todayDecoration: BoxDecoration(
              color: c.input,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.accentOrange,
              shape: BoxShape.circle,
            ),
            defaultTextStyle: TextStyle(color: c.textPrimary, fontSize: 13),
            weekendTextStyle: TextStyle(color: c.textPrimary, fontSize: 13),
            todayTextStyle: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: c.textSecondary, fontSize: 12),
            weekendStyle: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
