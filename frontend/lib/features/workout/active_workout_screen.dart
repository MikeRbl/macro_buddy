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
import '../workouts/workouts_provider.dart';
import 'exercise_info_sheet.dart';
import 'workout_models.dart';
import 'workout_ui.dart';

class _SetRow {
  _SetRow({this.warmup = false});

  String weight = '';
  String reps = '';
  String rir = '';
  bool done = false;
  bool warmup;
}

/// Celda editable de una serie.
enum _Field { weight, reps }

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({
    super.key,
    required this.exercises,
    this.workoutName,
    this.planId,
  });

  final List<PreviewExercise> exercises;
  final String? workoutName;

  /// Entrenamiento del programa que se está haciendo (si aplica). Al
  /// guardar se marca como hecho esta semana.
  final String? planId;

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

  /// Celda seleccionada para el teclado numérico (null = teclado oculto).
  ({int row, _Field field})? _sel;

  /// La primera tecla tras seleccionar reemplaza el valor (como "seleccionar
  /// todo"); las siguientes lo extienden.
  bool _replaceOnType = true;
  final Map<int, GlobalKey> _rowKeys = {};

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
            workoutId: widget.planId,
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
    final planId = widget.planId;
    if (planId != null) {
      await ref.read(workoutProvider.notifier).markDone(planId);
    }
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

  /// Series de la última sesión en la que apareció este ejercicio.
  List<WorkoutSessionSet> _previousSetsFor(PreviewExercise exercise) {
    final sessions = List.of(_history)
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final session in sessions) {
      final matches = session.sets.where((set) {
        final byId = set.exerciseId != null && set.exerciseId == exercise.id;
        final byName =
            set.exerciseName != null && set.exerciseName == exercise.name;
        return byId || byName;
      }).toList();
      if (matches.isNotEmpty) {
        matches.sort((a, b) => a.setNumber.compareTo(b.setNumber));
        return matches;
      }
    }
    return const [];
  }

  /// Serie equivalente de la sesión anterior: la N-ésima de calentamiento
  /// o la N-ésima efectiva, según el tipo de la fila.
  WorkoutSessionSet? _previousFor(
    List<_SetRow> rows,
    int index,
    List<WorkoutSessionSet> previous,
  ) {
    final row = rows[index];
    final ordinal = rows.take(index).where((r) => r.warmup == row.warmup).length;
    final same = previous.where((s) => s.isWarmup == row.warmup).toList();
    return ordinal < same.length ? same[ordinal] : null;
  }

  void _copyPrevious(_SetRow row, WorkoutSessionSet? prev, bool bodyweight) {
    if (prev == null) return;
    setState(() {
      if (!bodyweight && prev.weight != null) {
        row.weight = _fmtWeight(prev.weight!);
      }
      if (prev.reps != null) row.reps = '${prev.reps}';
      if (!row.warmup && prev.rir != null) row.rir = '${prev.rir}';
    });
  }

  /// Marca/desmarca una serie. Si faltan datos pero hay referencia de la
  /// sesión anterior, la usa (como hacen los placeholders grises).
  /// Devuelve true si la serie quedó completada.
  bool _onSetChecked(_SetRow row, bool bodyweight, WorkoutSessionSet? prev) {
    if (row.done) {
      setState(() => row.done = false);
      return false;
    }
    if (prev != null) {
      if (row.reps.trim().isEmpty && prev.reps != null) {
        row.reps = '${prev.reps}';
      }
      if (!bodyweight && row.weight.trim().isEmpty && prev.weight != null) {
        row.weight = _fmtWeight(prev.weight!);
      }
    }
    if (row.reps.trim().isEmpty || (!bodyweight && row.weight.trim().isEmpty)) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            bodyweight ? 'Ingresa las repeticiones' : 'Ingresa peso y repeticiones',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return false;
    }
    HapticFeedback.lightImpact();
    setState(() {
      row.done = true;
      if (!row.warmup) _startRest();
    });
    if (_rows[_currentIndex].every((r) => r.done) &&
        _currentIndex < _exercises.length - 1) {
      _goTo(_currentIndex + 1);
    }
    return true;
  }

  void _goTo(int index) {
    setState(() {
      _currentIndex = index;
      _sel = null;
      _rowKeys.clear();
    });
  }

  // --- Teclado numérico --------------------------------------------------

  String _valueOf(_SetRow row, _Field f) =>
      f == _Field.weight ? row.weight : row.reps;

  void _setValue(_SetRow row, _Field f, String v) {
    if (f == _Field.weight) {
      row.weight = v;
    } else {
      row.reps = v;
    }
  }

  void _select(int row, _Field field) {
    setState(() {
      _sel = (row: row, field: field);
      _replaceOnType = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _rowKeys[row]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.4,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  _SetRow? get _selectedRow {
    final sel = _sel;
    if (sel == null || _current == null) return null;
    final rows = _rows[_currentIndex];
    return sel.row < rows.length ? rows[sel.row] : null;
  }

  void _onKey(String key) {
    final sel = _sel;
    final row = _selectedRow;
    if (sel == null || row == null) return;
    var v = _replaceOnType ? '' : _valueOf(row, sel.field);
    if (key == '.') {
      if (sel.field == _Field.reps || v.contains('.')) return;
      v = v.isEmpty ? '0.' : '$v.';
    } else {
      if (v.length >= 6) return;
      v = v == '0' ? key : '$v$key';
    }
    setState(() {
      _replaceOnType = false;
      _setValue(row, sel.field, v);
    });
  }

  void _onBackspace() {
    final sel = _sel;
    final row = _selectedRow;
    if (sel == null || row == null) return;
    final v = _valueOf(row, sel.field);
    setState(() {
      _setValue(
        row,
        sel.field,
        _replaceOnType || v.isEmpty ? '' : v.substring(0, v.length - 1),
      );
      _replaceOnType = false;
    });
  }

  void _onRir(int rir) {
    final row = _selectedRow;
    if (row == null || row.warmup) return;
    HapticFeedback.selectionClick();
    setState(() => row.rir = row.rir == '$rir' ? '' : '$rir');
  }

  /// Avanza: peso → reps → peso de la siguiente serie.
  void _onNext() {
    final sel = _sel;
    final current = _current;
    if (sel == null || current == null) return;
    final rows = _rows[_currentIndex];
    if (sel.field == _Field.weight) {
      _select(sel.row, _Field.reps);
      return;
    }
    if (sel.row + 1 < rows.length) {
      _select(
        sel.row + 1,
        current.isBodyweight ? _Field.reps : _Field.weight,
      );
    } else {
      setState(() => _sel = null);
    }
  }

  /// ✓ del teclado: completa la serie seleccionada y salta a la siguiente
  /// pendiente.
  void _onKeypadCheck() {
    final sel = _sel;
    final current = _current;
    final row = _selectedRow;
    if (sel == null || current == null || row == null) return;
    final exerciseIndex = _currentIndex;
    final rows = _rows[exerciseIndex];
    final prev = _previousFor(rows, sel.row, _previousSetsFor(current));
    if (!row.done) {
      final ok = _onSetChecked(row, current.isBodyweight, prev);
      if (!ok) return;
    }
    if (_currentIndex != exerciseIndex) return; // ya pasó al siguiente ejercicio
    final next = rows.indexWhere((r) => !r.done);
    if (next == -1) {
      setState(() => _sel = null);
    } else {
      _select(next, current.isBodyweight ? _Field.reps : _Field.weight);
    }
  }

  void _removeCurrentExercise() {
    if (_exercises.isEmpty || _currentIndex >= _exercises.length) return;
    setState(() {
      _sel = null;
      _rowKeys.clear();
      _exercises.removeAt(_currentIndex);
      _rows.removeAt(_currentIndex);
      if (_currentIndex >= _exercises.length && _currentIndex > 0) {
        _currentIndex = _exercises.length - 1;
      }
    });
  }

  void _addWarmupSet() {
    if (_current == null) return;
    setState(() {
      _sel = null;
      final rows = _rows[_currentIndex];
      final firstWorking = rows.indexWhere((r) => !r.warmup);
      rows.insert(
        firstWorking == -1 ? rows.length : firstWorking,
        _SetRow(warmup: true),
      );
    });
  }

  void _addSet() {
    if (_current == null) return;
    setState(() => _rows[_currentIndex].add(_SetRow()));
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
      _goTo(_currentIndex + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final guided = ref.watch(isGuidedModeProvider);
    final current = _current;
    final restText = _restSeconds > 0
        ? '${_restSeconds ~/ 60}:${(_restSeconds % 60).toString().padLeft(2, '0')}'
        : '0:00';

    final selRow = _selectedRow;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _showMenu,
          icon: Icon(Icons.menu, color: c.textPrimary),
          tooltip: 'Menú',
        ),
        titleSpacing: 0,
        title: Text(
          _format(_stopwatch.elapsed),
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 20,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _restSeconds > 0 ? _cancelRest : _startRest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _restSeconds > 0 ? AppColors.coral : c.input,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: _restSeconds > 0
                        ? AppColors.inkOnAccent
                        : c.textPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    restText,
                    style: TextStyle(
                      color: _restSeconds > 0
                          ? AppColors.inkOnAccent
                          : c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: _saving ? null : _finishWorkout,
            child: const Text(
              'Terminar',
              style: TextStyle(
                color: AppColors.secondaryCyan,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: GestureDetector(
        // Tocar fuera de la tabla cierra el teclado.
        onTap: _sel == null ? null : () => setState(() => _sel = null),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildCarousel(),
            const SizedBox(height: 16),
            if (current == null) ...[
              _buildEmptyFreeWorkout(),
              const SizedBox(height: 16),
            ] else ...[
              Text(
                current.name,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _progressLabel(current),
                style: TextStyle(color: c.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: ListView(
                  key: const ValueKey('exercise-tools'),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _ToolChip(
                      icon: Icons.info_outline,
                      label: 'Info',
                      onTap: _showInfo,
                    ),
                    _ToolChip(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Calentamiento',
                      onTap: _addWarmupSet,
                    ),
                    // En modo guiado el profesional fija la rutina: fuera
                    // los chips que la modifican.
                    if (!guided) ...[
                      _ToolChip(
                        icon: Icons.track_changes,
                        label: 'Objetivos',
                        onTap: _showTargets,
                      ),
                      _ToolChip(
                        icon: Icons.swap_horiz,
                        label: 'Cambiar',
                        onTap: _showSwap,
                      ),
                      _ToolChip(
                        icon: Icons.add,
                        label: 'Agregar ejercicio',
                        onTap: _addExercise,
                      ),
                    ],
                    _ToolChip(
                      icon: Icons.done_all,
                      label: 'Completar todo',
                      onTap: _completeExercise,
                    ),
                    _ToolChip(
                      icon: Icons.delete_outline,
                      label: 'Quitar',
                      color: AppColors.danger,
                      onTap: _removeCurrentExercise,
                    ),
                  ],
                ),
              ),
              if (_restSeconds > 0) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Descanso',
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    _RestControl(label: '−15s', onTap: () => _adjustRest(-15)),
                    const SizedBox(width: 8),
                    _RestControl(label: '+15s', onTap: () => _adjustRest(15)),
                    const SizedBox(width: 8),
                    _RestControl(label: 'Saltar', onTap: _cancelRest),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _buildSetTable(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: selRow != null
            ? _NumericKeypad(
                key: const ValueKey('keypad'),
                showRir: !selRow.warmup,
                selectedRir: int.tryParse(selRow.rir),
                allowDecimal: _sel?.field == _Field.weight,
                nextLabel: _sel?.field == _Field.weight ? 'Reps' : 'Sig.',
                onKey: _onKey,
                onBackspace: _onBackspace,
                onRir: _onRir,
                onNext: _onNext,
                onHide: () => setState(() => _sel = null),
                onCheck: _onKeypadCheck,
              )
            : SafeArea(
                key: const ValueKey('finish'),
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _finishWorkout,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Terminar entrenamiento'),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// "Serie 2 de 4 · Objetivo 8–12 reps".
  String _progressLabel(PreviewExercise current) {
    final rows = _rows[_currentIndex];
    final working = rows.where((r) => !r.warmup).toList();
    final reps = current.minReps == current.maxReps
        ? '${current.minReps}'
        : '${current.minReps}–${current.maxReps}';
    if (working.isEmpty) return 'Objetivo $reps reps';
    final doneCount = working.where((r) => r.done).length;
    final shown = doneCount >= working.length ? working.length : doneCount + 1;
    final prefix = doneCount >= working.length
        ? 'Completado · ${working.length} series'
        : 'Serie $shown de ${working.length}';
    return '$prefix · Objetivo $reps reps';
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
      _sel = null;
      _rowKeys.clear();
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
            onTap: () => _goTo(index),
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
      _sel = null;
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
      _sel = null;
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
    final previous = _previousSetsFor(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _suggestionBanner(context, c, current, bodyweight),
        _headerRow(bodyweight),
        const SizedBox(height: 4),
        for (var i = 0; i < rows.length; i++)
          Dismissible(
            key: ObjectKey(rows[i]),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => setState(() {
              _sel = null;
              _rows[_currentIndex].removeAt(i);
            }),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete, color: c.textPrimary),
            ),
            child: KeyedSubtree(
              key: _rowKeys.putIfAbsent(i, GlobalKey.new),
              child: _setRow(
                rows,
                i,
                bodyweight,
                _previousFor(rows, i, previous),
                current,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _addSet,
                icon: Icon(Icons.add, color: c.textPrimary, size: 18),
                label: Text(
                  'Agregar serie',
                  style: TextStyle(color: c.textPrimary),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Toca una casilla para escribir · toca "Anterior" para copiar '
            'tu última sesión · desliza a la izquierda para borrar una serie.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.iconMuted, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _headerRow(bool bodyweight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SizedBox(width: 40, child: _headerText('Serie')),
          Expanded(flex: 3, child: _headerText('Anterior')),
          if (!bodyweight) ...[
            Expanded(flex: 2, child: _headerText('Lb')),
            const SizedBox(width: 8),
          ],
          Expanded(flex: 2, child: _headerText('Reps')),
          const SizedBox(width: 48, child: Icon(Icons.check, size: 16)),
        ],
      ),
    );
  }

  Widget _setRow(
    List<_SetRow> rows,
    int index,
    bool bodyweight,
    WorkoutSessionSet? prev,
    PreviewExercise current,
  ) {
    final c = ThemeColors.of(context);
    final row = rows[index];
    final number = rows.take(index + 1).where((r) => !r.warmup).length;
    final sel = _sel;

    String prevText = '—';
    if (prev != null) {
      final w = prev.weight;
      prevText = bodyweight || w == null
          ? '${prev.reps ?? '—'} reps'
          : '${_fmtWeight(w)} lb × ${prev.reps ?? '—'}';
    }

    // Placeholders grises: lo de la sesión anterior o el objetivo.
    final weightHint = prev?.weight != null ? _fmtWeight(prev!.weight!) : '';
    final repsHint = prev?.reps != null
        ? '${prev!.reps}'
        : (row.warmup
              ? ''
              : (current.minReps == current.maxReps
                    ? '${current.minReps}'
                    : '${current.minReps}-${current.maxReps}'));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: row.done
            ? AppColors.successGreen.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: 'Toca para cambiar entre serie y calentamiento',
                child: GestureDetector(
                  onTap: () => setState(() {
                    row.warmup = !row.warmup;
                    if (row.warmup) row.rir = '';
                  }),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.input,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      row.warmup ? 'W' : '$number',
                      style: TextStyle(
                        color: row.warmup
                            ? AppColors.warningAmber
                            : c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: prev == null
                  ? null
                  : () => _copyPrevious(row, prev, bodyweight),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Text(
                      prevText,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                    if (prev?.rir != null && !row.warmup)
                      Text(
                        '${prev!.rir} RIR',
                        style: TextStyle(color: c.iconMuted, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!bodyweight) ...[
            Expanded(
              flex: 2,
              child: _cell(
                value: row.weight,
                hint: weightHint,
                selected: sel?.row == index && sel?.field == _Field.weight,
                onTap: () => _select(index, _Field.weight),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: _cell(
              value: row.reps,
              hint: repsHint,
              selected: sel?.row == index && sel?.field == _Field.reps,
              onTap: () => _select(index, _Field.reps),
              rir: row.warmup ? null : int.tryParse(row.rir),
            ),
          ),
          SizedBox(
            width: 48,
            child: Center(
              child: GestureDetector(
                key: ValueKey('set-check-$index'),
                onTap: () => _onSetChecked(row, bodyweight, prev),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: row.done
                        ? AppColors.successGreen
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: row.done
                          ? AppColors.successGreen
                          : c.textSecondary,
                      width: 2,
                    ),
                  ),
                  child: row.done
                      ? const Icon(
                          Icons.check,
                          size: 20,
                          color: AppColors.inkOnAccent,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell({
    required String value,
    required String hint,
    required bool selected,
    required VoidCallback onTap,
    int? rir,
  }) {
    final c = ThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.input,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? c.textPrimary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Text(
              value.isEmpty ? hint : value,
              style: TextStyle(
                color: value.isEmpty ? c.iconMuted : c.textPrimary,
                fontSize: 16,
                fontWeight: value.isEmpty ? FontWeight.w400 : FontWeight.w600,
              ).merge(AppTypography.numeric),
            ),
          ),
          if (rir != null)
            Positioned(
              right: -6,
              bottom: -6,
              child: RirBadge(rir, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _headerText(String label) {
    final c = ThemeColors.of(context);
    return Text(
      label,
      textAlign: label == 'Serie' ? TextAlign.left : TextAlign.center,
      style: TextStyle(
        color: c.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final fg = color ?? c.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: c.input,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Teclado numérico propio para registrar series sin abrir el teclado del
/// sistema: dígitos, borrar, RIR por colores, avanzar y completar serie.
class _NumericKeypad extends StatelessWidget {
  const _NumericKeypad({
    super.key,
    required this.showRir,
    required this.selectedRir,
    required this.allowDecimal,
    required this.nextLabel,
    required this.onKey,
    required this.onBackspace,
    required this.onRir,
    required this.onNext,
    required this.onHide,
    required this.onCheck,
  });

  final bool showRir;
  final int? selectedRir;
  final bool allowDecimal;
  final String nextLabel;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final ValueChanged<int> onRir;
  final VoidCallback onNext;
  final VoidCallback onHide;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);

    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onTap();
                    },
              child: SizedBox(
                height: 50,
                child: Center(
                  child: child ??
                      Text(
                        label,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget side({
      required Widget child,
      required VoidCallback onTap,
      Color? color,
    }) {
      return Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: color ?? c.input,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(height: 50, child: Center(child: child)),
          ),
        ),
      );
    }

    return Material(
      color: c.card,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: AppColors.border),
            if (showRir)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(
                  children: [
                    Text(
                      'RIR',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    for (var r = 0; r <= 6; r++)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onRir(r),
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedRir == r
                                      ? c.textPrimary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: RirBadge(r, size: 30),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Row(children: [
                          key('1', onTap: () => onKey('1')),
                          key('2', onTap: () => onKey('2')),
                          key('3', onTap: () => onKey('3')),
                        ]),
                        Row(children: [
                          key('4', onTap: () => onKey('4')),
                          key('5', onTap: () => onKey('5')),
                          key('6', onTap: () => onKey('6')),
                        ]),
                        Row(children: [
                          key('7', onTap: () => onKey('7')),
                          key('8', onTap: () => onKey('8')),
                          key('9', onTap: () => onKey('9')),
                        ]),
                        Row(children: [
                          key(
                            allowDecimal ? '.' : '',
                            onTap: allowDecimal ? () => onKey('.') : null,
                          ),
                          key('0', onTap: () => onKey('0')),
                          key(
                            '',
                            onTap: onBackspace,
                            child: Icon(
                              Icons.backspace_outlined,
                              color: c.textPrimary,
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        side(
                          onTap: onHide,
                          child: Icon(
                            Icons.keyboard_hide_outlined,
                            color: c.textPrimary,
                          ),
                        ),
                        side(
                          onTap: onNext,
                          child: Text(
                            nextLabel,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(3),
                          child: Material(
                            color: c.textPrimary,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: onCheck,
                              child: const SizedBox(
                                height: 106,
                                child: Center(
                                  child: Icon(
                                    Icons.check,
                                    color: AppColors.inkOnAccent,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
