import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/api/api_client.dart';
import '../../core/models/workout_plan.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
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
      appBar: AppBar(
        leading: IconButton(
          onPressed: _openCalendar,
          icon: Icon(Icons.calendar_today, color: c.textPrimary),
        ),
        centerTitle: true,
        title: Text(
          'Entrenos',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openAddSheet,
            icon: Icon(Icons.add, color: c.textPrimary),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayCarousel(
              days: _days,
              dayNames: _dayNames,
              selectedDay: _selectedDay,
              hasWorkout: _hasWorkoutOn,
              onSelect: (day) => setState(() => _selectedDay = day),
            ),
            const SizedBox(height: 16),
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
          ],
        ),
      ),
    );
  }

  List<PreviewExercise> _toPreview(WorkoutPlan plan) {
    return [
      for (final ex in plan.exercises)
        PreviewExercise(
          id: ex.exerciseId,
          name: ex.name ?? 'Ejercicio',
          muscles: [if (ex.muscleGroup != null) ex.muscleGroup!],
          sets: ex.sets,
          minReps: ex.minReps ?? 8,
          maxReps: ex.maxReps ?? 12,
          rir: ex.rir,
          isBodyweight: ex.isBodyweight,
          thumbnailUrl: ex.thumbnailUrl,
          gifUrl: ex.gifUrl,
          target: ex.target,
          equipment: ex.equipment,
          instructions: ex.instructions,
        ),
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
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = day == selectedDay;
          return GestureDetector(
            onTap: () => onSelect(day),
            child: Container(
              width: 50,
              height: 65,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: selected ? AppColors.accentTeal : c.input,
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
                  const SizedBox(height: 4),
                  if (hasWorkout(day))
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.accentOrange,
                        shape: BoxShape.circle,
                      ),
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
