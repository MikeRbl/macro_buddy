import 'dart:math' as math;

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
import 'create_workout_screen.dart';
import 'workout_history_screen.dart';
import 'workouts_provider.dart';

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
  // Checkbox de rutinas de la semana (estado de la vista).
  final Set<int> _checkedRoutines = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 3);
    _days = List.generate(7, (i) => start.add(Duration(days: i)));
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
          dates.add(DateTime(parsed.year, parsed.month, parsed.day));
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

  void _openCreateWorkout() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CreateWorkoutScreen(),
      ),
    );
  }

  void _openFreeWorkout() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ActiveWorkoutScreen(exercises: []),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppColors.screenPadding,
                  vertical: 8,
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
                    IconButton(
                      onPressed: _openHistory,
                      icon: Icon(Icons.history, color: c.textPrimary),
                    ),
                    IconButton(
                      onPressed: _openCalendar,
                      icon: Icon(
                        Icons.calendar_today,
                        color: AppColors.secondaryCyan,
                      ),
                    ),
                    IconButton(
                      onPressed: _openAddSheet,
                      icon: const Icon(
                        Icons.add_circle,
                        color: AppColors.secondaryCyan,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _DayCarousel(
              days: _days,
              dayNames: _dayNames,
              selectedDay: _selectedDay,
              hasWorkout: _hasWorkoutOn,
              onSelect: (day) => setState(() => _selectedDay = day),
            ),
            const SizedBox(height: 16),
            _ActiveProgramCard(
              checkedRoutines: _checkedRoutines,
              onToggleRoutine: (i) => setState(() {
                if (!_checkedRoutines.add(i)) _checkedRoutines.remove(i);
              }),
            ),
            const SizedBox(height: 16),
            const _MinMaxPersonalCard(),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Biblioteca de entrenos', action: ''),
            const SizedBox(height: 12),
            _buildLibrary(c),
            const SizedBox(height: 24),
            const _SectionTitle('Más'),
            const SizedBox(height: 12),
            _MoreActions(
              onEmptyWorkout: _openFreeWorkout,
              onHistory: _openHistory,
            ),
            const SizedBox(height: 24),
            // Zona inferior para no quedar oculto bajo el navbar ni el FAB.
            const SizedBox(height: 170),
          ],
        ),
      ),
    );
  }

  List<PreviewExercise> _toPreview(WorkoutPlan plan) {
    return [
      for (final ex in plan.exercises) PreviewExercise.fromPlan(ex),
    ];
  }

  void _openPreview(WorkoutPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutPreviewScreen(
          title: plan.name,
          workoutId: plan.id,
          exercises: _toPreview(plan),
        ),
      ),
    );
  }

  Widget _buildLibrary(ThemeColors c) {
    final ws = ref.watch(workoutProvider);
    if (ws.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (ws.error != null) {
      return _EmptySectionCard(message: ws.error!);
    }
    if (ws.workouts.isEmpty) {
      return const _EmptySectionCard(
        message: 'La biblioteca está vacía.\nCrea un programa con el botón +.',
      );
    }
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorderItem: (oldIndex, newIndex) {
        ref.read(workoutProvider.notifier).reorderItem(oldIndex, newIndex);
      },
      children: [
        for (final plan in ws.workouts)
          Padding(
            key: ValueKey(plan.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: _LibraryCard(
              plan: plan,
              active: plan.id == ws.activeWorkoutId,
              onTap: () => _openPreview(plan),
            ),
          ),
      ],
    );
  }

}

class _DayCarousel extends StatelessWidget {
  const _DayCarousel({
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
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = day == selectedDay;
          final rested = day.weekday == DateTime.sunday;
          final reload = day.weekday == DateTime.wednesday;
          return GestureDetector(
            onTap: () => onSelect(day),
            child: Container(
              width: 52,
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: selected
                      ? AppColors.secondaryCyan
                      : c.input,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNames[day.weekday - 1],
                    style: TextStyle(
                      color: selected ? c.textPrimary : c.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: selected ? c.textPrimary : c.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (hasWorkout(day))
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryCyan,
                        shape: BoxShape.circle,
                      ),
                    )
                  else if (rested)
                    const _DayBadge(
                      'DESCANSO',
                      color: AppColors.tertiaryPurple,
                    )
                  else if (reload)
                    const _DayBadge(
                      'RECARGA',
                      color: AppColors.secondaryCyan,
                    )
                  else
                    const SizedBox(height: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Badge micro bajo el día: DESCANSO (púrpura) o RECARGA (cian).
class _DayBadge extends StatelessWidget {
  const _DayBadge(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 6.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Tarjeta "Active Program": plan activo + número de semana derivado de la
/// primera sesión registrada (fallback "Semana 1") + rutinas A–E.
class _ActiveProgramCard extends ConsumerWidget {
  const _ActiveProgramCard({
    required this.checkedRoutines,
    required this.onToggleRoutine,
  });

  final Set<int> checkedRoutines;
  final ValueChanged<int> onToggleRoutine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ThemeColors.of(context);
    final ws = ref.watch(workoutProvider);
    WorkoutPlan? active;
    if (ws.workouts.isNotEmpty) {
      for (final p in ws.workouts) {
        if (p.id == ws.activeWorkoutId) {
          active = p;
          break;
        }
      }
      active ??= ws.workouts.first;
    }

    // Semana derivada de la primera sesión registrada (fallback "Semana 1").
    final sessions = ref.watch(dashboardProvider).value ?? const [];
    DateTime? first;
    for (final s in sessions) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      if (first == null || d.isBefore(first)) first = d;
    }
    int week = 1;
    if (first != null) {
      week = (DateTime.now().difference(first).inDays / 7).floor() + 1;
      if (week < 1) week = 1;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVE PROGRAM',
                        style: TextStyle(
                          color: AppColors.secondaryCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        active?.name ?? 'Sin programa activo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryCyan.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Semana $week',
                    style: const TextStyle(
                      color: AppColors.secondaryCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (ws.workouts.isEmpty)
              Text(
                'Crea tu primer programa con el botón + para ver rutinas aquí.',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < ws.workouts.length && i < 5; i++)
                    FilterChip(
                      label: Text(
                        '${String.fromCharCode(65 + i)} · ${ws.workouts[i].name}',
                        style: TextStyle(
                          color: checkedRoutines.contains(i)
                              ? AppColors.inkOnAccent
                              : c.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                      selected: checkedRoutines.contains(i),
                      selectedColor: AppColors.secondaryCyan,
                      backgroundColor: c.input,
                      checkmarkColor: AppColors.inkOnAccent,
                      side: BorderSide(
                        color: checkedRoutines.contains(i)
                            ? AppColors.secondaryCyan
                            : c.border,
                      ),
                      onSelected: (_) => onToggleRoutine(i),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Récords personales: peso máximo y mínimo por ejercicio del historial.
class _MinMaxPersonalCard extends ConsumerWidget {
  const _MinMaxPersonalCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const c = ThemeColors.dark;
    final sessions = ref.watch(dashboardProvider).value ?? const [];
    final stats = <String, ({double max, double min})>{};
    for (final s in sessions) {
      for (final set in s.sets) {
        final name = set.exerciseName?.trim();
        final w = set.weight ?? 0;
        if (name == null || name.isEmpty || w <= 0) continue;
        final prev = stats[name];
        stats[name] = (
          max: w > (prev?.max ?? 0) ? w : (prev?.max ?? 0),
          min: prev == null ? w : math.min(prev.min, w),
        );
      }
    }
    final entries = stats.entries.take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MIN MAX PERSONAL',
              style: TextStyle(
                color: AppColors.secondaryCyan,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Text(
                'Registra tus series para ver tus máximos.',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              )
            else
              for (final e in entries) ...[
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
                        'MAX ${e.value.max.round()} kg · '
                        'MIN ${e.value.min.round()} kg',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11,
                        ).merge(AppTypography.numeric),
                      ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SectionTitle(title),
          if (action.isNotEmpty)
            Text(
              action,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Text(
      title,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({
    this.message = 'No hay programas todavía.\nUsa el botón + para crear tu primer programa.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: Column(
        children: [
          Icon(Icons.fitness_center, color: c.textSecondary, size: 28),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.plan,
    required this.onTap,
    this.active = false,
  });

  final WorkoutPlan plan;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active ? AppColors.accentOrange : c.input,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fitness_center, color: c.textPrimary),
          ),
          title: Text(
            plan.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textPrimary, fontSize: 16),
          ),
          subtitle: Text(
            '${plan.exercises.length} ${plan.exercises.length == 1 ? 'ejercicio' : 'ejercicios'}',
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
          trailing: Icon(
            active ? Icons.check_circle : Icons.chevron_right,
            color: active ? AppColors.accentTeal : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MoreActions extends StatelessWidget {
  const _MoreActions({required this.onEmptyWorkout, required this.onHistory});

  final VoidCallback onEmptyWorkout;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.start, color: c.textPrimary),
              title: Text(
                'Entrenamiento vacío',
                style: TextStyle(color: c.textPrimary, fontSize: 16),
              ),
              onTap: onEmptyWorkout,
            ),
            Divider(height: 1, color: c.input),
            ListTile(
              leading: Icon(Icons.receipt_long, color: c.textPrimary),
              title: Text(
                'Historial de entrenos',
                style: TextStyle(color: c.textPrimary, fontSize: 16),
              ),
              onTap: onHistory,
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
                'Iniciar entrenamiento vacío',
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
