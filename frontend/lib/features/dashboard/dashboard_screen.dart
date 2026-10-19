import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/models/workout_session.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../nutrition/nutrition_provider.dart';
import '../nutrition/steps_provider.dart';
import '../workouts/workouts_provider.dart';
import 'dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _weekDays = [
    'LUNES',
    'MARTES',
    'MIÉRCOLES',
    'JUEVES',
    'VIERNES',
    'SÁBADO',
    'DOMINGO',
  ];
  static const _months = [
    'ENERO',
    'FEBRERO',
    'MARZO',
    'ABRIL',
    'MAYO',
    'JUNIO',
    'JULIO',
    'AGOSTO',
    'SEPTIEMBRE',
    'OCTUBRE',
    'NOVIEMBRE',
    'DICIEMBRE',
  ];

  String _headerDate(DateTime now) {
    return '${_weekDays[now.weekday - 1]}, ${now.day} DE ${_months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ThemeColors.of(context);
    final historyAsync = ref.watch(dashboardProvider);
    final sessions = historyAsync.value ?? [];
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekly = sessions.where((s) => s.date.isAfter(weekAgo)).toList();

    final nutrition = ref.watch(nutritionProvider);
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    final steps = ref.watch(stepsProvider);

    // Entrenamiento: sesiones de la semana vs los entreno del ciclo
    // (una pasada completa del programa).
    final workoutState = ref.watch(workoutProvider);
    final cycleGoal = workoutState.workouts.length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _headerDate(now),
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'DASHBOARD',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Hoy'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ProgressRing(
                    size: 80,
                    value: (user?.targetCalories ?? 0) > 0
                        ? ((nutrition.log?.totalCalories ?? 0) /
                                user!.targetCalories!)
                            .clamp(0.0, 1.0)
                        : 0.0,
                    color: AppColors.coral,
                    strokeWidth: 6,
                    centerText:
                        '${(nutrition.log?.totalCalories ?? 0).round()}',
                    subText: 'kcal hoy',
                    label: 'Calorías',
                    target: user?.targetCalories != null
                        ? '${user!.targetCalories!.round()} objetivo'
                        : 'Sin objetivo',
                  ),
                  _ProgressRing(
                    size: 120,
                    value: cycleGoal > 0
                        ? (weekly.length / cycleGoal).clamp(0.0, 1.0)
                        : 0.0,
                    color: AppColors.accentTeal,
                    strokeWidth: 8,
                    centerText: '${weekly.length}',
                    subText: 'sesiones semana',
                    label: 'Entrenamiento',
                    target: cycleGoal > 0
                        ? '$cycleGoal objetivo'
                        : 'Sin programa',
                  ),
                  _ProgressRing(
                    size: 80,
                    value: steps.stepsToday / dailyStepsGoal,
                    color: AppColors.accentBlue,
                    strokeWidth: 6,
                    centerText: '${steps.stepsToday}',
                    subText: 'pasos hoy',
                    label: 'Pasos',
                    target: '$dailyStepsGoal objetivo',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const _SectionTitle('Insights y análisis'),
              const SizedBox(height: 16),
              if (sessions.isEmpty)
                const _EmptyInsightsCard()
              else
                _InsightsChartCard(sessions: sessions),
              const SizedBox(height: 28),
              const _SectionTitle('Hábitos'),
              const SizedBox(height: 16),
              _HabitsCalendarCard(sessions: sessions),
            ],
          ),
        ),
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

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.size,
    required this.value,
    required this.color,
    required this.strokeWidth,
    required this.centerText,
    required this.subText,
    required this.label,
    required this.target,
  });

  final double size;
  final double value;
  final Color color;
  final double strokeWidth;
  final String centerText;
  final String subText;
  final String label;
  final String target;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: value,
                backgroundColor: c.input,
                color: color,
                strokeWidth: strokeWidth,
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerText,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: size * 0.25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subText,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: size * 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(target, style: TextStyle(color: c.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _EmptyInsightsCard extends StatelessWidget {
  const _EmptyInsightsCard();

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: Column(
        children: [
          Icon(Icons.insights_outlined, color: c.textSecondary, size: 28),
          const SizedBox(height: 12),
          Text(
            'Sin datos todavía. Completa tu primer entrenamiento para ver tus métricas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _InsightsChartCard extends StatelessWidget {
  const _InsightsChartCard({required this.sessions});

  final List<WorkoutSession> sessions;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final recent = sessions.take(7).toList().reversed.toList();
    final volumes = recent.map((s) {
      return s.sets.fold<double>(
        0.0,
        (sum, st) => sum + ((st.weight ?? 0.0) * (st.reps ?? 0)),
      );
    }).toList();
    final setsList = recent.map((s) => s.sets.length).toList();

    final hasVolume = volumes.any((v) => v > 0);
    final totalVol = volumes.fold<double>(0.0, (sum, v) => sum + v);
    final totalAllSets = setsList.fold<int>(0, (sum, s) => sum + s);

    final values =
        hasVolume ? volumes : setsList.map((s) => s.toDouble()).toList();
    final maxVal =
        values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal > 0 ? maxVal : 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasVolume ? 'Volumen total (Lb)' : 'Total de series',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Últimas ${recent.length} ${recent.length == 1 ? 'sesión' : 'sesiones'}',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.input,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasVolume
                      ? 'Total: ${totalVol.toInt()} lb'
                      : 'Total: $totalAllSets series',
                  style: const TextStyle(
                    color: AppColors.accentOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < recent.length; i++)
                  _BarItem(
                    value: values[i],
                    maxValue: safeMax,
                    label: '${recent[i].date.day}/${recent[i].date.month}',
                    displayValue: hasVolume
                        ? (volumes[i] >= 1000
                            ? '${(volumes[i] / 1000).toStringAsFixed(1)}k'
                            : '${volumes[i].toInt()}')
                        : '${setsList[i]}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.value,
    required this.maxValue,
    required this.label,
    required this.displayValue,
  });

  final double value;
  final double maxValue;
  final String label;
  final String displayValue;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.08, 1.0) : 0.08;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              displayValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 80 * ratio,
                  width: 22,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.accentOrange,
                        Color(0xFFFFB340),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitsCalendarCard extends StatefulWidget {
  const _HabitsCalendarCard({required this.sessions});

  final List<WorkoutSession> sessions;

  @override
  State<_HabitsCalendarCard> createState() => _HabitsCalendarCardState();
}

class _HabitsCalendarCardState extends State<_HabitsCalendarCard> {
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final trainedDates = widget.sessions
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet();

    final monthTrainedCount = trainedDates
        .where(
          (d) => d.year == _focusedDay.year && d.month == _focusedDay.month,
        )
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actividad mensual',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    monthTrainedCount == 0
                        ? 'Sin entrenos en este mes'
                        : '$monthTrainedCount ${monthTrainedCount == 1 ? 'entreno registrado' : 'entrenos registrados'}',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Entrenado',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TableCalendar<String>(
            firstDay: DateTime.utc(DateTime.now().year - 1, 1, 1),
            lastDay: DateTime.utc(DateTime.now().year + 1, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableGestures: AvailableGestures.horizontalSwipe,
            onPageChanged: (focused) => setState(() => _focusedDay = focused),
            eventLoader: (day) {
              final normalized = DateTime(day.year, day.month, day.day);
              return trainedDates.contains(normalized)
                  ? const ['workout']
                  : const [];
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon:
                  Icon(Icons.chevron_left, color: c.textPrimary, size: 20),
              rightChevronIcon:
                  Icon(Icons.chevron_right, color: c.textPrimary, size: 20),
              headerPadding: const EdgeInsets.only(bottom: 8),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: c.textSecondary, fontSize: 12),
              weekendStyle: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: TextStyle(color: c.textPrimary, fontSize: 13),
              weekendTextStyle: TextStyle(color: c.textPrimary, fontSize: 13),
              todayDecoration: BoxDecoration(
                color: c.input,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1,
              markerSize: 6,
              markerMargin: const EdgeInsets.only(top: 2),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    bottom: 2,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}
