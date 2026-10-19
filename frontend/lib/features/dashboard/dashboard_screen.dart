import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/models/workout_session.dart';
import '../../core/models/user.dart' show WeightEntry;
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/mb_icon.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../nutrition/nutrition_provider.dart';
import '../nutrition/steps_provider.dart';
import '../workouts/workouts_provider.dart';
import 'dashboard_provider.dart';

/// Ventanas de datos del segmented control.
enum _Window { hoy, semana, tendencia }

/// Eje semanal L M X J V S D para la línea de tendencia.
const _weekShort = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const _months = [
    'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
    'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE',
  ];

  _Window _window = _Window.hoy;

  /// Días que alimenta cada pestaña del segmented: 1 / 7 / 30.
  int get _days => switch (_window) {
        _Window.hoy => 1,
        _Window.semana => 7,
        _Window.tendencia => 30,
      };

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.dark;
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    final nutrition = ref.watch(nutritionProvider);
    final steps = ref.watch(stepsProvider);
    final workoutState = ref.watch(workoutProvider);
    final sessions = ref.watch(dashboardProvider).value ?? [];
    final now = DateTime.now();

    final windowDays = _days;
    final withinWindow = sessions
        .where((s) => s.date.isAfter(now.subtract(Duration(days: windowDays))))
        .toList();
    final cycleGoal = workoutState.workouts.length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppColors.screenPadding,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: logo + marca + fecha + campana ───────────────
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Image.asset(
                      MbAssets.logo,
                      width: 32,
                      height: 32,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MACROBUDDY',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          '${now.day} DE ${_months[now.month - 1]}',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ).merge(AppTypography.numeric),
                        ),
                      ],
                    ),
                  ),
                  _BellButton(hasAlert: true),
                ],
              ),
              const SizedBox(height: 20),
              // ── Segmented: Hoy / Semana / Tendencia ──────────────────
              GlassCard(
                padding: const EdgeInsets.all(4),
                color: c.input,
                child: Row(
                  children: [
                    for (final w in _Window.values)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _window = w),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _window == w
                                  ? AppColors.primaryCoral
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              switch (w) {
                                _Window.hoy => 'Hoy',
                                _Window.semana => 'Semana',
                                _Window.tendencia => 'Tendencia',
                              },
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _window == w
                                    ? AppColors.inkOnAccent
                                    : c.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Card 1: anillos kcal / entrenos / pasos ─────────────
              _RingsCard(
                kcal: nutrition.log?.totalCalories ?? 0,
                kcalTarget: user?.targetCalories ?? 0,
                workouts: withinWindow.length,
                workoutTarget: cycleGoal,
                steps: steps.stepsToday,
                stepsTarget: dailyStepsGoal,
                windowLabel: _days == 1 ? 'hoy' : '$_days días',
              ),
              const SizedBox(height: 16),
              // ── Card 2: macros P / C / F ─────────────────────────────
              _MacrosCard(
                protein: nutrition.log?.totalProtein ?? 0,
                proteinTarget: user?.targetProtein ?? 0,
                carbs: nutrition.log?.totalCarbs ?? 0,
                carbsTarget: user?.targetCarbs ?? 0,
                fats: nutrition.log?.totalFats ?? 0,
                fatsTarget: user?.targetFats ?? 0,
              ),
              const SizedBox(height: 16),
              // ── Card 3: tendencia de peso ────────────────────────────
              _WeightTrendCard(
                history: user?.weightHistory ?? const [],
                windowDays: windowDays,
              ),
              const SizedBox(height: 28),
              // ── Insights y actividad mensual (se mantienen) ──────────
              Text(
                'Insights y análisis',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (sessions.isEmpty)
                const _EmptyInsightsCard()
              else
                _InsightsChartCard(sessions: sessions),
              const SizedBox(height: 28),
              Text(
                'Hábitos',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _HabitsCalendarCard(sessions: sessions),
              const SizedBox(height: 170),
            ],
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.hasAlert});

  final bool hasAlert;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.input,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: MbIcon(MbAssets.alert, size: 20, color: c.textPrimary),
          ),
        ),
        if (hasAlert)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.danger,
                border: Border.all(color: c.scaffold, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Card 1: tres anillos (kcal coral, entrenos cian, pasos púrpura) pintados
/// con `CustomPainter` + leyenda a la derecha.
class _RingsCard extends StatelessWidget {
  const _RingsCard({
    required this.kcal,
    required this.kcalTarget,
    required this.workouts,
    required this.workoutTarget,
    required this.steps,
    required this.stepsTarget,
    required this.windowLabel,
  });

  final double kcal;
  final double kcalTarget;
  final int workouts;
  final int workoutTarget;
  final int steps;
  final int stepsTarget;
  final String windowLabel;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    String intFmt(num v) =>
        v >= 1000
            ? '${(v / 1000).toStringAsFixed(1)}k'
            : v.round().toString();

    final rows = [
      (
        AppColors.primaryCoral,
        'Calorías',
        '${intFmt(kcal)} / ${kcalTarget > 0 ? intFmt(kcalTarget) : '—'} kcal',
        kcalTarget > 0 ? (kcal / kcalTarget).clamp(0.0, 1.0) : 0.0,
      ),
      (
        AppColors.secondaryCyan,
        'Entrenamiento',
        '$workouts / ${workoutTarget > 0 ? workoutTarget : '—'} sesiones',
        workoutTarget > 0 ? (workouts / workoutTarget).clamp(0.0, 1.0) : 0.0,
      ),
      (
        AppColors.tertiaryPurple,
        'Pasos',
        '$steps / ${intFmt(stepsTarget)}',
        stepsTarget > 0 ? (steps / stepsTarget).clamp(0.0, 1.0) : 0.0,
      ),
    ];

    return GlassCard(
      accent: AppColors.primaryCoral,
      child: Row(
        children: [
          SizedBox(
            width: 128,
            height: 128,
            child: CustomPaint(
              painter: _TripleRingPainter(
                values: [rows[0].$4, rows[1].$4, rows[2].$4],
              ),
              child: Center(
                child: Text(
                  '${(rows[0].$4 * 100).round()}%',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ).merge(AppTypography.numeric),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in rows) ...[
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration:
                            BoxDecoration(color: r.$1, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.$2,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        r.$3,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11,
                        ).merge(AppTypography.numeric),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  'Últimos $windowLabel',
                  style: TextStyle(color: c.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripleRingPainter extends CustomPainter {
  _TripleRingPainter({required this.values});

  /// Progreso kcal / entrenos / pasos en [0, 1].
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide / 2;
    const colors = [
      AppColors.primaryCoral,
      AppColors.secondaryCyan,
      AppColors.tertiaryPurple,
    ];
    for (var i = 0; i < values.length; i++) {
      final r = maxR - i * 14;
      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = AppColors.border;
      canvas.drawCircle(center, r, track);
      if (values[i] > 0) {
        final arc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = colors[i];
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          -math.pi / 2,
          -2 * math.pi * values[i],
          false,
          arc,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TripleRingPainter old) =>
      old.values != values;
}

/// Card 2: objetivo del día con 3 sub-tarjetas `#1C1C1F` para P / C / F.
class _MacrosCard extends StatelessWidget {
  const _MacrosCard({
    required this.protein,
    required this.proteinTarget,
    required this.carbs,
    required this.carbsTarget,
    required this.fats,
    required this.fatsTarget,
  });

  final double protein;
  final double proteinTarget;
  final double carbs;
  final double carbsTarget;
  final double fats;
  final double fatsTarget;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    Widget sub(String icon, double value, double target, Color color) {
      final pct = target > 0 ? (value / target * 100).round() : 0;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MbIcon(icon, size: 18, color: color),
              const SizedBox(height: 8),
              Text(
                '${value.round()}g',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ).merge(AppTypography.numeric),
              ),
              Text(
                target > 0 ? '$pct% de ${target.round()}g' : 'sin objetivo',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 9,
                ).merge(AppTypography.numeric),
              ),
            ],
          ),
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macros de hoy',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              sub(MbAssets.protein, protein, proteinTarget, AppColors.secondaryCyan),
              const SizedBox(width: 10),
              sub(MbAssets.carb, carbs, carbsTarget, AppColors.successGreen),
              const SizedBox(width: 10),
              sub(MbAssets.fat, fats, fatsTarget, AppColors.warningAmber),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card 3: tendencia de peso (línea púrpura sobre eje semanal) + delta.
class _WeightTrendCard extends StatelessWidget {
  const _WeightTrendCard({required this.history, required this.windowDays});

  final List<WeightEntry> history;
  final int windowDays;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Puntos dentro de la ventana, más recientes al final.
    final points = <WeightEntry>[];
    for (final e in history) {
      final d = DateTime.tryParse(e.date);
      if (d != null && today.difference(d).inDays < windowDays) {
        points.add(e);
      }
    }
    points.sort((a, b) => a.date.compareTo(b.date));

    final delta = points.length >= 2
        ? points.last.weight - points.first.weight
        : 0.0;

    return GlassCard(
      accent: AppColors.tertiaryPurple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tendencia de peso',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (points.length >= 2)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (delta <= 0 ? AppColors.successGreen : AppColors.warningAmber)
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      color: delta <= 0
                          ? AppColors.successGreen
                          : AppColors.warningAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ).merge(AppTypography.numeric),
                  ),
                ),
              if (points.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${points.last.weight.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ).merge(AppTypography.numeric),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 96,
            child: points.length >= 2
                ? CustomPaint(
                    painter: _WeightLinePainter(
                      columns: _bucketPoints(points, windowDays),
                    ),
                    size: Size.infinite,
                  )
                : Center(
                    child: Text(
                      'Registra tu peso en tu perfil para ver la tendencia.',
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                  ),
          ),
          if (points.length >= 2) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final w in _weekShort)
                  Expanded(
                    child: Text(
                      w,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textSecondary, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Reparte los puntos en 7 columnas equidistantes a lo largo de la ventana
/// y devuelve el último peso de cada columna (null si la columna está vacía).
List<double?> _bucketPoints(List<WeightEntry> points, int windowDays) {
  final cols = List<double?>.filled(7, null);
  for (final e in points) {
    final d = DateTime.tryParse(e.date);
    if (d == null) continue;
    // 0 = inicio de la ventana, 6 = hoy.
    final rel = DateTime.now().difference(d).inDays;
    final idx = (6 * (windowDays - 1 - rel.clamp(0, windowDays - 1)) /
            math.max(windowDays - 1, 1))
        .round();
    cols[idx.clamp(0, 6)] = e.weight;
  }
  return cols;
}

class _WeightLinePainter extends CustomPainter {
  _WeightLinePainter({required this.columns});

  /// Peso por columna (null = sin registro en esa columna).
  final List<double?> columns;

  @override
  void paint(Canvas canvas, Size size) {
    final present =
        columns.whereType<double>().toList(growable: false);
    if (present.length < 2) {
      // Con un solo punto: solo el marcador.
      final paintDot = Paint()..color = AppColors.tertiaryPurple;
      final only = columns.indexOf(present.firstOrNull ?? 0);
      if (only >= 0) {
        canvas.drawCircle(
          Offset(size.width / 6 * only, size.height / 2),
          4,
          paintDot,
        );
      }
      return;
    }
    final minW = present.reduce((a, b) => math.min(a, b));
    final maxW = present.reduce((a, b) => math.max(a, b));
    Offset? colOffset(int i) {
      final w = columns[i];
      if (w == null) return null;
      final span = (maxW - minW).abs() < 0.01 ? 1.0 : maxW - minW;
      final y = size.height - 8 - (w - minW) / span * (size.height - 16);
      return Offset(size.width / 6 * i, y);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = AppColors.tertiaryPurple
      ..strokeCap = StrokeCap.round;

    // Se conectan las columnas consecutivas con registro.
    Offset? last;
    for (var i = 0; i < 7; i++) {
      final o = colOffset(i);
      if (o == null) continue;
      if (last != null) canvas.drawLine(last, o, paint);
      last = o;
    }

    final dotPaint = Paint()..color = AppColors.tertiaryPurple;
    for (var i = 0; i < 7; i++) {
      final o = colOffset(i);
      if (o != null) canvas.drawCircle(o, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightLinePainter old) =>
      old.columns != columns;
}

class _EmptyInsightsCard extends StatelessWidget {
  const _EmptyInsightsCard();

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(Icons.insights_outlined, color: c.textSecondary, size: 28),
            const SizedBox(height: 12),
            Text(
              'Sin datos todavía. Completa tu primer entrenamiento para ver '
              'tus métricas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsChartCard extends StatelessWidget {
  const _InsightsChartCard({required this.sessions});

  final List<WorkoutSession> sessions;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
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

    return GlassCard(
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
                    'Últimas ${recent.length} '
                    '${recent.length == 1 ? 'sesión' : 'sesiones'}',
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
                  style: TextStyle(
                    color: AppColors.primaryCoral,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ).merge(AppTypography.numeric),
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
    const c = ThemeColors.dark;
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
              ).merge(AppTypography.numeric),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 80 * ratio,
                  width: 22,
                  decoration: BoxDecoration(
                    gradient: AppColors.caloriesGradient,
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
              ).merge(AppTypography.numeric),
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
    const c = ThemeColors.dark;
    final trainedDates = widget.sessions
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet();

    final monthTrainedCount = trainedDates
        .where(
          (d) => d.year == _focusedDay.year && d.month == _focusedDay.month,
        )
        .length;

    return GlassCard(
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
                        : '$monthTrainedCount '
                            '${monthTrainedCount == 1 ? 'entreno registrado' : 'entrenos registrados'}',
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
                      color: AppColors.successGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Entrenado',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
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
                color: AppColors.successGreen,
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
                        color: AppColors.successGreen,
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
