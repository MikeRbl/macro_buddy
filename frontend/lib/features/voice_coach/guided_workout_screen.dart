import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/exercise_thumbnail.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../community/community_provider.dart';
import '../dashboard/dashboard_provider.dart';
import '../workout/workout_models.dart';
import 'guided_workout_controller.dart';
import 'speaker_setup_screen.dart';

/// Entrenamiento guiado por voz: el entrenador (clips de voz o TTS) dice cada
/// serie por la bocina y los botones `<<  >||  >>` de la bocina o de la app
/// controlan el flujo.
class GuidedWorkoutScreen extends ConsumerStatefulWidget {
  const GuidedWorkoutScreen({
    super.key,
    required this.exercises,
    this.workoutName,
  });

  final List<PreviewExercise> exercises;
  final String? workoutName;

  @override
  ConsumerState<GuidedWorkoutScreen> createState() =>
      _GuidedWorkoutScreenState();
}

class _GuidedWorkoutScreenState extends ConsumerState<GuidedWorkoutScreen> {
  late final GuidedWorkoutController _controller;
  bool _loading = true;
  bool _saving = false;
  CommunityController? _community;

  @override
  void initState() {
    super.initState();
    try {
      WakelockPlus.enable();
    } catch (_) {}
    _community = ref.read(communityProvider.notifier);
    _community?.updatePresence('training');
    _controller = GuidedWorkoutController(
      exercises: widget.exercises,
      workoutName: widget.workoutName,
    );
    _controller.addListener(_onChange);
    _boot();
  }

  Future<void> _boot() async {
    await _controller.init();
    if (!mounted) return;
    setState(() => _loading = false);
    await _controller.start();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    _community?.updatePresence('online');
    try {
      WakelockPlus.disable();
    } catch (_) {}
    super.dispose();
  }

  String _clock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  String _mmss(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  // --------------------------------------------------------- Guardado -----

  Future<void> _save() async {
    if (_saving) return;
    final sets = _controller.buildSetsPayload();
    if (sets.isEmpty) {
      _snack('No hay series completadas para guardar.');
      return;
    }
    final token = ref.read(authControllerProvider).token;
    if (token == null) {
      _snack('Sesión expirada. Inicia sesión de nuevo.');
      return;
    }
    setState(() => _saving = true);
    _controller.finishNow();
    try {
      final res = await ref.read(apiClientProvider).createUserWorkout(
            token: token,
            duration: _controller.elapsed.inSeconds,
            note: 'Entrenamiento con voz',
            sets: sets,
          );
      ref.invalidate(dashboardProvider);
      ref.read(communityProvider.notifier).postWorkout(
            widget.workoutName ?? 'Entrenamiento con voz',
            workoutId: res['id'] as String?,
          );
      if (!mounted) return;
      _snack('Entrenamiento guardado');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      _snack(e.message);
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      _snack('Ocurrió un error al guardar.');
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _confirmFinish() async {
    final c = ThemeColors.of(context);
    final pending = _controller.sets.length - _controller.completedSets;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text(
          '¿Terminar el entrenamiento?',
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          pending > 0
              ? 'Faltan $pending series. Se guardan solo las completadas.'
              : 'Se guardarán todas las series.',
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Volver', style: TextStyle(color: c.textPrimary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Terminar y guardar'),
          ),
        ],
      ),
    );
    if (ok == true) await _save();
  }

  Future<void> _confirmDiscard() async {
    final c = ThemeColors.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text(
          '¿Descartar este entrenamiento?',
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Tu progreso se perderá y no se guardará.',
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Volver', style: TextStyle(color: c.textPrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Descartar',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  void _showMenu() {
    final c = ThemeColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.speaker, color: c.textPrimary),
              title: Text(
                'Bocina y voces',
                style: TextStyle(color: c.textPrimary, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheet).pop();
                _openSpeaker();
              },
            ),
            ListTile(
              leading: Icon(Icons.flag_outlined, color: c.textPrimary),
              title: Text(
                'Terminar y guardar',
                style: TextStyle(color: c.textPrimary, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheet).pop();
                _confirmFinish();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text(
                'Descartar entrenamiento',
                style: TextStyle(color: AppColors.danger, fontSize: 16),
              ),
              onTap: () {
                Navigator.of(sheet).pop();
                _confirmDiscard();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openSpeaker() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SpeakerSetupScreen(exercises: widget.exercises),
      ),
    );
  }

  // -------------------------------------------------------------- UI ------

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_controller.phase == GuidedPhase.finished && _saving) return;
        _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _showMenu,
            icon: Icon(Icons.menu, color: c.textPrimary),
          ),
          centerTitle: true,
          title: Text(
            _loading ? 'Entrenamiento con voz' : _clock(_controller.elapsed),
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 20,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Bocina y voces',
              onPressed: _openSpeaker,
              icon: Icon(Icons.speaker, color: c.textPrimary),
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accentOrange),
              )
            : _controller.phase == GuidedPhase.finished
                ? _buildFinished()
                : _buildActive(),
        bottomNavigationBar: _loading || _controller.phase == GuidedPhase.finished
            ? null
            : _buildTransport(),
      ),
    );
  }

  Widget _buildActive() {
    final c = ThemeColors.of(context);
    final total = _controller.sets.length;
    final done = _controller.completedSets;
    final ex = _controller.currentExercise;
    final set = _controller.currentSet;
    final resting = _controller.phase == GuidedPhase.resting;

    return ListView(
      padding: const EdgeInsets.all(AppColors.screenPadding),
      children: [
        Row(
          children: [
            Text(
              '$done de $total series',
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
            const Spacer(),
            if (_controller.paused)
              const _Pill(label: 'EN PAUSA', color: AppColors.warningAmber),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 6,
            backgroundColor: c.input,
            color: AppColors.accentTeal,
          ),
        ),
        const SizedBox(height: 16),
        if (resting) _buildRestCard() else if (ex != null && set != null)
          _buildSetCard(ex, set),
        const SizedBox(height: 16),
        _buildSpeakingBubble(),
        const SizedBox(height: 16),
        _buildUpNext(),
      ],
    );
  }

  Widget _buildSetCard(PreviewExercise ex, GuidedSet set) {
    final c = ThemeColors.of(context);
    final target = GuidedWorkoutController.targetRepsFor(ex);
    final targetText = target != null
        ? '$target reps'
        : '${ex.minReps}-${ex.maxReps} reps';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExerciseThumbnail(url: ex.thumbnailUrl, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.name,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Serie ${set.setIndex + 1} de ${ex.sets} · Objetivo $targetText',
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stepper(
                  label: 'Reps',
                  value: '${set.reps}',
                  onMinus: () => setState(() {
                    if (set.reps > 0) set.reps--;
                  }),
                  onPlus: () => setState(() => set.reps++),
                ),
              ),
              if (!ex.isBodyweight) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _WeightField(
                    key: ValueKey('w-${_controller.position}'),
                    initial: set.weight,
                    onChanged: (v) => set.weight = v,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestCard() {
    final c = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: AppColors.accentOrange, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            'Descanso',
            style: TextStyle(color: c.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            _mmss(_controller.restRemaining),
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 56,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SmallButton(
                label: '−15s',
                onTap: () => _controller.adjustRest(-15),
              ),
              const SizedBox(width: 8),
              _SmallButton(
                label: '+15s',
                onTap: () => _controller.adjustRest(15),
              ),
              const SizedBox(width: 8),
              _SmallButton(label: 'Saltar', onTap: _controller.next),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakingBubble() {
    final c = ThemeColors.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: _controller.speaking,
      builder: (context, text, _) {
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: text == null ? 0.5 : 1,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.input,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.record_voice_over,
                  color: text == null ? c.iconMuted : AppColors.accentOrange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text ?? 'Usa los botones de la bocina: ⏮ anterior · ⏯ pausa · ⏭ siguiente',
                    style: TextStyle(
                      color: text == null ? c.textSecondary : c.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Repetir',
                  onPressed: _controller.repeatAnnouncement,
                  icon: Icon(Icons.replay, color: c.textSecondary, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpNext() {
    final c = ThemeColors.of(context);
    final start = _controller.phase == GuidedPhase.resting
        ? _controller.position
        : _controller.position + 1;
    final upcoming = _controller.sets.skip(start).take(3).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A continuación',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        for (final s in upcoming)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.chevron_right, color: c.iconMuted, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${_controller.exercises[s.exerciseIndex].name} · '
                    'serie ${s.setIndex + 1} · ${s.reps} reps',
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTransport() {
    final c = ThemeColors.of(context);
    final paused = _controller.paused;
    return SafeArea(
      top: false,
      child: Container(
        color: c.scaffold,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RoundButton(
                  icon: Icons.skip_previous_rounded,
                  tooltip: 'Serie anterior',
                  onTap: _controller.previous,
                ),
                _RoundButton(
                  icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  tooltip: paused ? 'Reanudar' : 'Pausa',
                  big: true,
                  onTap: _controller.togglePause,
                ),
                _RoundButton(
                  icon: Icons.skip_next_rounded,
                  tooltip: 'Siguiente',
                  onTap: _controller.next,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _saving ? null : _confirmFinish,
                child: const Text('Terminar entrenamiento'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinished() {
    final c = ThemeColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.emoji_events, color: AppColors.warningAmber, size: 64),
        const SizedBox(height: 16),
        Text(
          '¡Terminaste!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_controller.completedSets} de ${_controller.sets.length} series · '
          '${_clock(_controller.elapsed)}',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Guardar entrenamiento'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _saving ? null : _confirmDiscard,
          child: const Text(
            'Descartar',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.big = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final size = big ? 76.0 : 60.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: big ? AppColors.accentOrange : c.input,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: big ? 40 : 32,
              color: big ? AppColors.inkOnAccent : c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Material(
      color: c.input,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: c.input,
        borderRadius: BorderRadius.circular(AppColors.radiusInput),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onMinus,
            icon: Icon(Icons.remove, color: c.textPrimary),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onPlus,
            icon: Icon(Icons.add, color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _WeightField extends StatefulWidget {
  const _WeightField({super.key, this.initial, required this.onChanged});

  final double? initial;
  final ValueChanged<double?> onChanged;

  @override
  State<_WeightField> createState() => _WeightFieldState();
}

class _WeightFieldState extends State<_WeightField> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    final w = widget.initial;
    _text = TextEditingController(
      text: w == null
          ? ''
          : (w == w.roundToDouble() ? w.toInt().toString() : w.toString()),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return TextField(
      controller: _text,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      textAlign: TextAlign.center,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      decoration: const InputDecoration(labelText: 'Peso (kg)'),
      onChanged: (v) => widget.onChanged(
        double.tryParse(v.replaceAll(',', '.')),
      ),
    );
  }
}
