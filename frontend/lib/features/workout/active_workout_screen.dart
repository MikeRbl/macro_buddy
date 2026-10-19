import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/api/api_client.dart';
import '../../core/models/workout_session.dart';
import '../../core/utils/sound_util.dart';
import '../../core/widgets/exercise_thumbnail.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../community/community_provider.dart';
import '../create_program/add_exercises_sheet.dart';
import '../dashboard/dashboard_provider.dart';
import 'exercise_info_sheet.dart';
import 'workout_models.dart';

class _SetRow {
  _SetRow({this.warmup = false});

  String weight = '';
  String reps = '';
  String rir = '';
  bool done = false;
  final bool warmup;
}

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({
    super.key,
    required this.exercises,
    this.workoutName,
  });

  final List<PreviewExercise> exercises;
  final String? workoutName;

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  static const _restDuration = 90;

  int _currentIndex = 0;
  late List<PreviewExercise> _exercises;
  late List<List<_SetRow>> _rows;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  Timer? _restTimer;
  int _restSeconds = 0;
  String _sessionNote = '';
  bool _saving = false;
  List<WorkoutSession> _history = [];

  PreviewExercise? get _current =>
      _currentIndex < _exercises.length ? _exercises[_currentIndex] : null;

  CommunityController? _communityController;

  @override
  void initState() {
    super.initState();
    try {
      WakelockPlus.enable();
    } catch (_) {}
    _communityController = ref.read(communityProvider.notifier);
    _communityController?.updatePresence('training');
    _exercises = List.of(widget.exercises);
    _rows = _exercises
        .map((e) => List.generate(e.sets, (_) => _SetRow()))
        .toList();
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) return;
    try {
      final items =
          await ref.read(apiClientProvider).fetchUserWorkouts(token: token);
      final sessions = items
          .map((e) => WorkoutSession.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() => _history = sessions);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _restTimer?.cancel();
    _stopwatch.stop();
    _communityController?.updatePresence('online');
    try {
      WakelockPlus.disable();
    } catch (_) {}
    super.dispose();
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  void _startRestFrom(int seconds) {
    _restTimer?.cancel();
    _restSeconds = seconds;
    if (seconds <= 0) return;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _restSeconds--;
        if (_restSeconds <= 0) {
          timer.cancel();
          SoundUtil.playBeep();
        }
      });
    });
  }

  void _startRest() => _startRestFrom(_restDuration);

  void _cancelRest() {
    _restTimer?.cancel();
    _restTimer = null;
    if (mounted) setState(() => _restSeconds = 0);
  }

  void _adjustRest(int delta) {
    final next = _restSeconds + delta;
    if (next <= 0) {
      _cancelRest();
    } else {
      _startRestFrom(next);
    }
  }

  void _finishWorkout() {
    if (_saving) return;
    final hasIncomplete = _rows.expand((l) => l).any((r) => !r.done);
    if (hasIncomplete) {
      _showFinishDialog();
      return;
    }
    _executeSave();
  }

  void _showFinishDialog() {
    final c = ThemeColors.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
        title: Text(
          'Tienes series incompletas',
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Hay series sin marcar como completadas.',
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: c.textPrimary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _executeSave();
            },
            child: const Text('Solo guardar completadas'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSave({bool markAll = false}) async {
    if (_saving) return;
    if (markAll) {
      setState(() {
        for (final list in _rows) {
          for (final row in list) {
            row.done = true;
          }
        }
      });
    }
    setState(() => _saving = true);
    _ticker?.cancel();
    _restTimer?.cancel();
    _stopwatch.stop();

    final sets = <Map<String, dynamic>>[];
    for (var e = 0; e < _exercises.length; e++) {
      final exercise = _exercises[e];
      if (exercise.id == null) continue;
      final rows = _rows[e];
      var setNumber = 0;
      for (final row in rows) {
        if (!row.done) continue;
        setNumber += 1;
        sets.add({
          'exercise_id': exercise.id,
          'set_number': setNumber,
          'weight': exercise.isBodyweight || row.weight.trim().isEmpty
              ? null
              : double.tryParse(row.weight),
          'reps': int.tryParse(row.reps),
          'rir': exercise.isBodyweight || row.rir.trim().isEmpty
              ? null
              : int.tryParse(row.rir),
          'is_warmup': row.warmup,
        });
      }
    }

    String? workoutId;
    final token = ref.read(authControllerProvider).token;
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión expirada. Inicia sesión de nuevo.'),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (mounted) setState(() => _saving = false);
      return;
    }

    try {
      final res = await ref.read(apiClientProvider).createUserWorkout(
            token: token,
            duration: _stopwatch.elapsed.inSeconds,
            note: _sessionNote.isEmpty ? null : _sessionNote,
            sets: sets,
          );
      workoutId = res['id'] as String?;
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (mounted) setState(() => _saving = false);
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error al guardar.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (mounted) setState(() => _saving = false);
      return;
    }

    ref.invalidate(dashboardProvider);
    ref.read(communityProvider.notifier).postWorkout(
          widget.workoutName ?? 'Entrenamiento libre',
          workoutId: workoutId,
          note: _sessionNote.isEmpty ? null : _sessionNote,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrenamiento guardado')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _openSessionNote() async {
    final c = ThemeColors.of(context);
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SessionNoteSheet(initial: _sessionNote),
    );
    if (note != null && mounted) {
      setState(() => _sessionNote = note);
    }
  }

  void _showMenu() {
    final c = ThemeColors.of(context);
    showModalBottomSheet<void>(
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
              ListTile(
                leading: const Icon(Icons.note_alt_outlined),
                title: Text(
                  'Nota de sesión',
                  style: TextStyle(color: c.textPrimary, fontSize: 16),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openSessionNote();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Descartar entrenamiento',
                  style: TextStyle(color: AppColors.danger, fontSize: 16),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDiscard();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDiscard() async {
    final c = ThemeColors.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Descartar este entrenamiento?',
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Tu progreso se perderá y este entrenamiento no se guardará.',
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Volver', style: TextStyle(color: c.textPrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Descartar',
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  String _previousText(int index) {
    final row = _rows[_currentIndex][index];
    final exercise = _exercises[_currentIndex];
    for (final session in _history) {
      for (final set in session.sets.reversed) {
        final matchesId = set.exerciseId != null && set.exerciseId == exercise.id;
        final matchesName = set.exerciseName != null && set.exerciseName == exercise.name;
        if (!matchesId && !matchesName) continue;
        if (set.isWarmup != row.warmup) continue;
        if (exercise.isBodyweight) {
          return '${set.reps ?? '—'} reps\nRIR ${set.rir ?? 0}';
        } else {
          return '${set.weight ?? '—'} lb x ${set.reps ?? '—'}\nRIR ${set.rir ?? 0}';
        }
      }
    }
    return '—';
  }

  void _copyPrevious(int index, _SetRow row, bool bodyweight) {
    final text = _previousText(index);
    if (text.isEmpty || text == '—') return;
    if (!row.warmup) {
      final rirMatch = RegExp(r'RIR\s*(\d+)').firstMatch(text);
      if (rirMatch != null) row.rir = rirMatch.group(1)!;
    }
    if (bodyweight) {
      final repsMatch = RegExp(r'(\d+)\s*reps').firstMatch(text);
      if (repsMatch != null) row.reps = repsMatch.group(1)!;
    } else {
      final weightMatch = RegExp(r'(\d+)\s*lb').firstMatch(text);
      if (weightMatch != null) row.weight = weightMatch.group(1)!;
      final repsMatch = RegExp(r'x\s*(\d+)').firstMatch(text);
      if (repsMatch != null) row.reps = repsMatch.group(1)!;
    }
    setState(() {});
  }

  void _onSetChecked(_SetRow row, bool bodyweight) {
    if (row.done) {
      setState(() => row.done = false);
      return;
    }
    if (row.reps.trim().isEmpty || (!bodyweight && row.weight.trim().isEmpty)) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Ingresa peso y repeticiones'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    setState(() {
      row.done = true;
      if (!row.warmup) _startRest();
    });
    if (_rows[_currentIndex].every((r) => r.done) &&
        _currentIndex < _exercises.length - 1) {
      setState(() => _currentIndex += 1);
    }
  }

  void _removeCurrentExercise() {
    if (_exercises.isEmpty || _currentIndex >= _exercises.length) return;
    setState(() {
      _exercises.removeAt(_currentIndex);
      _rows.removeAt(_currentIndex);
      if (_currentIndex >= _exercises.length && _currentIndex > 0) {
        _currentIndex = _exercises.length - 1;
      }
    });
  }

  void _addWarmupSet() {
    setState(() => _rows[_currentIndex].insert(0, _SetRow(warmup: true)));
  }

  void _completeExercise() {
    final rows = _rows[_currentIndex];
    if (rows.every((r) => r.done)) return;
    setState(() {
      for (final row in rows) {
        row.done = true;
      }
    });
    if (rows.any((r) => !r.warmup)) _startRest();
    if (_rows[_currentIndex].every((r) => r.done) &&
        _currentIndex < _exercises.length - 1) {
      setState(() => _currentIndex += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final guided = ref.watch(isGuidedModeProvider);
    final restText = _restSeconds > 0
        ? 'Descanso ${(_restSeconds ~/ 60).toString().padLeft(1, '0')}:${(_restSeconds % 60).toString().padLeft(2, '0')}'
        : 'Descanso';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _showMenu,
          icon: Icon(Icons.menu, color: c.textPrimary),
        ),
        centerTitle: true,
        title: Text(
          _format(_stopwatch.elapsed),
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 20,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _restSeconds > 0 ? AppColors.accentOrange : c.input,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  restText,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCarousel(),
          const SizedBox(height: 16),
          if (_current == null) ...[
            _buildEmptyFreeWorkout(),
            const SizedBox(height: 16),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    _current!.name,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _removeCurrentExercise,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                  ),
                  tooltip: 'Eliminar ejercicio',
                ),
              ],
            ),
            const SizedBox(height: 10),
          Row(
            children: [
              _ToolChip(label: 'Info', onTap: _showInfo),
              const SizedBox(width: 8),
              // En modo guiado el profesional fija la rutina: fuera los
              // chips que la modifican.
              if (!guided) ...[
                _ToolChip(label: 'Objetivos', onTap: _showTargets),
                const SizedBox(width: 8),
                _ToolChip(label: 'Cambiar', onTap: _showSwap),
                const SizedBox(width: 8),
                _ToolChip(label: 'Agregar', onTap: _addExercise),
                const SizedBox(width: 8),
              ],
              _ToolChip(label: 'Completar', onTap: _completeExercise),
            ],
          ),
            if (_restSeconds > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RestControl(label: '−15s', onTap: () => _adjustRest(-15)),
                  const SizedBox(width: 8),
                  _RestControl(label: '+15s', onTap: () => _adjustRest(15)),
                  const SizedBox(width: 8),
                  _RestControl(label: 'Saltar', onTap: _cancelRest),
                ],
              ),
            ],
            const SizedBox(height: 20),
            _buildSetTable(),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _finishWorkout,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Finalizar Entrenamiento'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFreeWorkout() {
    final c = ThemeColors.of(context);
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.fitness_center, color: c.textSecondary, size: 32),
            const SizedBox(height: 12),
            Text(
              'Entrenamiento libre. Agrega ejercicios para comenzar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addExercise,
              child: const Text('Agregar ejercicio'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addExercise() async {
    final replacement = await showAddExercisesSheet(context);
    if (replacement == null || !mounted) return;
    final exercise = PreviewExercise.fromCatalog(replacement);
    setState(() {
      _exercises.add(exercise);
      _rows.add(List.generate(exercise.sets, (_) => _SetRow()));
      _currentIndex = _exercises.length - 1;
    });
  }

  Widget _buildCarousel() {
    final c = ThemeColors.of(context);
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _exercises.length,
        itemBuilder: (context, index) {
          final selected = index == _currentIndex;
          final rows = _rows[index];
          final complete = rows.isNotEmpty && rows.every((r) => r.done);
          final borderColor = complete
              ? AppColors.accentTeal
              : (selected ? c.textPrimary : Colors.transparent);
          return GestureDetector(
            onTap: () => setState(() => _currentIndex = index),
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Opacity(
                opacity: selected ? 1 : 0.4,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor, width: 2.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ExerciseThumbnail(
                        url: _exercises[index].thumbnailUrl,
                        size: 60,
                      ),
                    ),
                    if (complete)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppColors.accentTeal,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            color: c.textPrimary,
                            size: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showInfo() {
    final c = ThemeColors.of(context);
    final current = _current;
    if (current == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ExerciseInfoSheet(exercise: current),
    );
  }

  Future<void> _showTargets() async {
    final c = ThemeColors.of(context);
    final current = _current;
    if (current == null) return;
    final result =
        await showModalBottomSheet<
          ({int sets, int minReps, int maxReps, int rir})
        >(
          context: context,
          isScrollControlled: true,
          backgroundColor: c.card,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => _ActiveTargetsSheet(exercise: current),
        );
    if (result == null || !mounted) return;
    setState(() {
      _exercises[_currentIndex] = current.copyWith(
        sets: result.sets,
        minReps: result.minReps,
        maxReps: result.maxReps,
        rir: result.rir,
      );
      _rows[_currentIndex] = List.generate(result.sets, (_) => _SetRow());
    });
  }

  Future<void> _showSwap() async {
    final current = _current;
    if (current == null) return;
    final replacement = await showAddExercisesSheet(context);
    if (replacement == null || !mounted) return;
    final updated = current.copyWith(
      name: replacement.name,
      muscles: [
        if (replacement.muscleGroup != null) replacement.muscleGroup!,
        ...replacement.secondaryMuscles.take(2),
      ],
      isBodyweight: replacement.isBodyweight,
      thumbnailUrl: replacement.thumbnailUrl,
      gifUrl: replacement.gifUrl,
      target: replacement.target,
      equipment: replacement.equipment,
      instructions: replacement.instructions,
    );
    setState(() {
      _exercises[_currentIndex] = updated;
      _rows[_currentIndex] = List.generate(updated.sets, (_) => _SetRow());
    });
  }

  String _fmtWeight(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  /// Banner de sobrecarga progresiva: los datos vienen del backend
  /// (previous_performance + suggested_next por ejercicio).
  Widget _suggestionBanner(
    BuildContext context,
    ThemeColors c,
    PreviewExercise current,
    bool bodyweight,
  ) {
    final s = current.suggestedNext;
    final pp = current.previousPerformance;
    final valid = s != null &&
        (bodyweight ? s.reps != null : (s.reps != null && s.weight != null));
    if (!valid) return const SizedBox.shrink();

    final suggestion = bodyweight
        ? '${s.reps} reps'
        : '${_fmtWeight(s.weight!)} lb × ${s.reps} reps';
    final previous = pp == null
        ? null
        : bodyweight
            ? '${pp.reps ?? '—'} reps'
            : '${pp.weight == null ? '—' : _fmtWeight(pp.weight!)} lb × ${pp.reps ?? '—'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: AppColors.coral, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sugerencia de sobrecarga',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  suggestion,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ).merge(AppTypography.numeric),
                ),
                if (previous != null)
                  Text(
                    'Anterior: $previous',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11,
                    ).merge(AppTypography.numeric),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _applySuggestion(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.coral,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  /// Rellena la siguiente fila pendiente con la sugerencia del backend.
  void _applySuggestion() {
    final current = _current;
    final s = current?.suggestedNext;
    if (current == null || s == null) return;
    final rows = _rows[_currentIndex];
    for (final row in rows) {
      if (row.done || row.reps.trim().isNotEmpty ||
          (!current.isBodyweight && row.weight.trim().isNotEmpty)) {
        continue;
      }
      if (!current.isBodyweight) {
        // El banner solo se muestra con weight/reps completos.
        row.weight = _fmtWeight(s.weight!);
      }
      row.reps = '${s.reps}';
      break;
    }
    setState(() {});
  }

  Widget _buildSetTable() {
    final c = ThemeColors.of(context);
    final current = _current;
    if (current == null) return const SizedBox.shrink();
    final bodyweight = current.isBodyweight;
    final rows = _rows[_currentIndex];
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _suggestionBanner(context, c, current, bodyweight),
            _headerRow(bodyweight),
            Divider(height: 20, color: c.input),
            for (var i = 0; i < rows.length; i++)
              Dismissible(
                key: ValueKey(rows[i]),
                direction: DismissDirection.endToStart,
                onDismissed: (_) =>
                    setState(() => _rows[_currentIndex].removeAt(i)),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete, color: c.textPrimary),
                ),
                child: Opacity(
                  opacity: rows[i].warmup && rows[i].done
                      ? 0.35
                      : (rows[i].done ? 0.6 : 1.0),
                  child: _setRow(i, rows[i], bodyweight),
                ),
              ),
            Divider(height: 16, color: c.input),
            TextButton.icon(
              onPressed: _addWarmupSet,
              icon: Icon(Icons.local_fire_department, color: c.textSecondary),
              label: Text(
                'Agregar serie de calentamiento (W)',
                style: TextStyle(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerRow(bool bodyweight) {
    return Row(
      children: [
        Expanded(flex: 2, child: _headerText('Serie')),
        Expanded(flex: 3, child: _headerText('Anterior')),
        if (!bodyweight) Expanded(flex: 2, child: _headerText('Lb')),
        Expanded(flex: 2, child: _headerText('Reps')),
        Expanded(flex: 2, child: _headerText('RIR')),
        const SizedBox(width: 28),
      ],
    );
  }

  Widget _setRow(int index, _SetRow row, bool bodyweight) {
    final c = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.input, shape: BoxShape.circle),
              child: Text(
                row.warmup ? 'W' : '${index + 1}',
                style: TextStyle(
                  color: row.warmup ? AppColors.accentOrange : c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => _copyPrevious(index, row, bodyweight),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _previousText(index),
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
              ),
            ),
          ),
          if (!bodyweight)
            Expanded(
              flex: 2,
              child: _SetInput(
                key: ValueKey('$_currentIndex-$index-weight'),
                initial: row.weight,
                onChanged: (v) => setState(() => row.weight = v),
              ),
            ),
          Expanded(
            flex: 2,
            child: _SetInput(
              key: ValueKey('$_currentIndex-$index-reps'),
              initial: row.reps,
              onChanged: (v) => setState(() => row.reps = v),
            ),
          ),
          if (!row.warmup)
            Expanded(
              flex: 2,
              child: _SetInput(
                key: ValueKey('$_currentIndex-$index-rir'),
                initial: row.rir,
                onChanged: (v) => setState(() => row.rir = v),
              ),
            )
          else
            const Expanded(
              flex: 2,
              child: Center(
                child: Text('—', style: TextStyle(color: Colors.grey)),
              ),
            ),
          const SizedBox(width: 6),
          Checkbox(
            value: row.done,
            onChanged: (value) => _onSetChecked(row, bodyweight),
            activeColor: AppColors.accentTeal,
            checkColor: c.textPrimary,
            side: BorderSide(color: c.textSecondary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerText(String label) {
    final c = ThemeColors.of(context);
    return Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11));
  }
}

class _SetInput extends StatefulWidget {
  const _SetInput({super.key, required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_SetInput> createState() => _SetInputState();
}

class _SetInputState extends State<_SetInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void didUpdateWidget(covariant _SetInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initial != oldWidget.initial &&
        _controller.text != widget.initial) {
      _controller.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      onChanged: (value) => widget.onChanged(value),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: c.input,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RestControl extends StatelessWidget {
  const _RestControl({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: c.input,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SessionNoteSheet extends StatefulWidget {
  const _SessionNoteSheet({required this.initial});

  final String initial;

  @override
  State<_SessionNoteSheet> createState() => _SessionNoteSheetState();
}

class _SessionNoteSheetState extends State<_SessionNoteSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
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
            'Nota de sesión',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Escribe tu nota aquí'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _ActiveTargetsSheet extends StatefulWidget {
  const _ActiveTargetsSheet({required this.exercise});

  final PreviewExercise exercise;

  @override
  State<_ActiveTargetsSheet> createState() => _ActiveTargetsSheetState();
}

class _ActiveTargetsSheetState extends State<_ActiveTargetsSheet> {
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
              Expanded(child: _input(_setsController, 'Series')),
              const SizedBox(width: 8),
              Expanded(child: _input(_minRepsController, 'Reps mín')),
              const SizedBox(width: 8),
              Expanded(child: _input(_maxRepsController, 'Reps máx')),
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

  Widget _input(TextEditingController controller, String label) {
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
