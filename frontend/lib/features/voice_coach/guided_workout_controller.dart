import 'dart:async';

import 'package:flutter/foundation.dart';

import '../workout/workout_models.dart';
import 'coach_media_session.dart';
import 'coach_phrases.dart';
import 'coach_voice.dart';
import 'voice_clip_library.dart';

enum GuidedPhase { ready, working, resting, finished }

/// Una serie dentro del entrenamiento guiado.
class GuidedSet {
  GuidedSet({
    required this.exerciseIndex,
    required this.setIndex,
    required this.reps,
    this.weight,
  });

  final int exerciseIndex;
  final int setIndex;

  /// Lo que el usuario hizo (prellenado con el objetivo; editable en la app).
  int reps;
  double? weight;
  bool done = false;
}

/// Flujo del entrenamiento guiado por voz.
///
/// Recorre las series una por una:
///   anuncio ("Diez lagartijas. Serie uno de tres") → el usuario las hace →
///   ">>" (bocina o app) → ánimo + descanso con cuenta regresiva → siguiente.
///
/// `<<` regresa a la serie anterior, `play/pausa` pausa todo (cronómetro y
/// descanso). Terminar o descartar solo se hace desde la app.
class GuidedWorkoutController extends ChangeNotifier
    implements CoachMediaControls {
  GuidedWorkoutController({
    required List<PreviewExercise> exercises,
    this.workoutName,
    this.restSeconds = 90,
    CoachMediaBackend? mediaSession,
    this.voiceFactory,
  })  : exercises = List.unmodifiable(exercises),
        _media = mediaSession ?? CoachMediaSession.instance {
    for (var e = 0; e < exercises.length; e++) {
      final ex = exercises[e];
      final target = targetRepsFor(ex);
      final weight = ex.isBodyweight
          ? null
          : ex.suggestedNext?.weight ?? ex.previousPerformance?.weight;
      for (var s = 0; s < ex.sets; s++) {
        sets.add(
          GuidedSet(
            exerciseIndex: e,
            setIndex: s,
            reps: target ?? ex.maxReps,
            weight: weight,
          ),
        );
      }
    }
  }

  final List<PreviewExercise> exercises;
  final String? workoutName;
  final CoachMediaBackend _media;
  /// Para pruebas: reemplaza la voz real.
  final CoachVoice Function(VoiceClipLibrary library)? voiceFactory;

  /// Descanso entre series, en segundos (ajustable desde la app).
  int restSeconds;

  final List<GuidedSet> sets = [];

  late VoiceClipLibrary library;
  late CoachVoice voice;
  late CoachPhrases phrases;

  GuidedPhase phase = GuidedPhase.ready;
  bool paused = false;
  int position = 0;
  int restRemaining = 0;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _restTimer;
  Timer? _ticker;
  bool _disposed = false;

  Duration get elapsed => _stopwatch.elapsed;

  GuidedSet? get currentSet =>
      position < sets.length ? sets[position] : null;

  PreviewExercise? get currentExercise {
    final set = currentSet;
    return set == null ? null : exercises[set.exerciseIndex];
  }

  /// Siguiente serie (la que viene después del descanso).
  GuidedSet? get upcomingSet => currentSet;

  int get completedSets => sets.where((s) => s.done).length;

  /// Texto que está diciendo el entrenador, para mostrarlo en pantalla.
  ValueListenable<String?> get speaking => voice.speaking;

  static int? targetRepsFor(PreviewExercise ex) {
    final suggested = ex.suggestedNext?.reps;
    if (suggested != null && suggested > 0) return suggested;
    if (ex.minReps == ex.maxReps) return ex.maxReps;
    return null;
  }

  // ------------------------------------------------------------ Ciclo -----

  bool _initialized = false;

  Future<void> init() async {
    library = await VoiceClipLibrary.load();
    voice = voiceFactory?.call(library) ?? CoachVoice(library: library);
    phrases = CoachPhrases(library);
    _initialized = true;
    await voice.init();
  }

  Future<void> start() async {
    if (sets.isEmpty || !_initialized || phase != GuidedPhase.ready) return;
    await _media.attach(this);
    phase = GuidedPhase.working;
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
    _syncMedia();
    _notify();
    unawaited(voice.say(phrases.start() + _announcementFor(position)));
  }

  /// ">>": termina la serie actual (o salta el descanso).
  @override
  void onNext() => next();

  /// "<<": regresa a la serie anterior.
  @override
  void onPrevious() => previous();

  @override
  void onPlay() => resume();

  @override
  void onPause() => pause();

  void next() {
    if (phase == GuidedPhase.finished || phase == GuidedPhase.ready) return;
    if (paused) _setPaused(false, speak: false);

    if (phase == GuidedPhase.resting) {
      _cancelRest();
      phase = GuidedPhase.working;
      _syncMedia();
      _notify();
      unawaited(voice.say(_announcementFor(position)));
      return;
    }

    // Trabajando: la serie actual quedó hecha.
    final set = currentSet;
    if (set == null) return;
    set.done = true;

    if (position >= sets.length - 1) {
      _finish();
      return;
    }

    position++;
    final remaining = sets.length - position;
    var phrase = const VoicePhrase([]);
    if (remaining <= 2) {
      phrase += phrases.almostDone();
    } else if (position == sets.length ~/ 2) {
      phrase += phrases.halfway();
    } else if (phrases.shouldEncourage()) {
      phrase += phrases.encouragement();
    }

    if (restSeconds > 0) {
      phrase += phrases.rest(restSeconds);
      _startRest(restSeconds);
    } else {
      phrase += _announcementFor(position);
    }
    _syncMedia();
    _notify();
    unawaited(voice.say(phrase));
  }

  void previous() {
    if (phase == GuidedPhase.finished || phase == GuidedPhase.ready) return;
    if (paused) _setPaused(false, speak: false);
    if (phase == GuidedPhase.resting) {
      // Descansando después de la serie N: regresa a la serie N.
      _cancelRest();
    }
    if (position > 0 &&
        (phase == GuidedPhase.resting || phase == GuidedPhase.working)) {
      // En reposo, la serie anterior es la que se acaba de hacer; en trabajo,
      // es la previa a la actual.
      position--;
      sets[position].done = false;
    }
    phase = GuidedPhase.working;
    _syncMedia();
    _notify();
    unawaited(voice.say(_announcementFor(position)));
  }

  void togglePause() => paused ? resume() : pause();

  void pause() {
    if (paused || phase == GuidedPhase.finished || phase == GuidedPhase.ready) {
      return;
    }
    _setPaused(true);
  }

  void resume() {
    if (!paused) return;
    _setPaused(false);
  }

  void _setPaused(bool value, {bool speak = true}) {
    paused = value;
    if (value) {
      _stopwatch.stop();
      _restTimer?.cancel();
      if (speak) unawaited(voice.say(phrases.paused()));
    } else {
      _stopwatch.start();
      if (phase == GuidedPhase.resting && restRemaining > 0) {
        _runRestTimer();
      }
      if (speak) unawaited(voice.say(phrases.resumed()));
    }
    _syncMedia();
    _notify();
  }

  /// Ajusta el descanso en curso (+15 s / −15 s).
  void adjustRest(int delta) {
    if (phase != GuidedPhase.resting) return;
    restRemaining = (restRemaining + delta).clamp(0, 600);
    if (restRemaining == 0) {
      next();
      return;
    }
    _notify();
  }

  void _startRest(int seconds) {
    phase = GuidedPhase.resting;
    restRemaining = seconds;
    _runRestTimer();
  }

  void _runRestTimer() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (paused) return;
      restRemaining--;
      if (restRemaining == 10 && restSeconds > 20) {
        unawaited(voice.say(phrases.restWarning(10)));
      } else if (restRemaining > 0 && restRemaining <= 3) {
        unawaited(voice.say(VoicePhrase([CoachPhrases.number(restRemaining)])));
      }
      if (restRemaining <= 0) {
        _cancelRest();
        phase = GuidedPhase.working;
        _syncMedia();
        unawaited(voice.say(_announcementFor(position)));
      }
      _notify();
    });
  }

  void _cancelRest() {
    _restTimer?.cancel();
    _restTimer = null;
    restRemaining = 0;
  }

  void _finish() {
    _cancelRest();
    phase = GuidedPhase.finished;
    paused = false;
    _stopwatch.stop();
    _ticker?.cancel();
    _syncMedia();
    _notify();
    unawaited(voice.say(phrases.finished()));
  }

  /// Termina el entrenamiento desde la app (aunque falten series).
  void finishNow() {
    if (phase == GuidedPhase.finished) return;
    _finish();
  }

  // ------------------------------------------------------------ Frases ----

  VoicePhrase _announcementFor(int index) {
    if (index >= sets.length) return const VoicePhrase([]);
    final set = sets[index];
    final ex = exercises[set.exerciseIndex];
    var phrase = const VoicePhrase([]);
    if (set.setIndex == 0) {
      final isFirst = set.exerciseIndex == 0;
      final isLast = set.exerciseIndex == exercises.length - 1 && !isFirst;
      phrase += phrases.exerciseIntro(isFirst: isFirst, isLast: isLast);
    } else if (set.setIndex == ex.sets - 1 && ex.sets > 1) {
      phrase += phrases.lastSet();
    }
    phrase += phrases.setAnnouncement(
      name: ex.name,
      setNumber: set.setIndex + 1,
      totalSets: ex.sets,
      minReps: ex.minReps,
      maxReps: ex.maxReps,
      targetReps: targetRepsFor(ex),
    );
    return phrase;
  }

  /// Repite el anuncio de la serie actual (botón "Repetir" en la app).
  void repeatAnnouncement() {
    if (phase == GuidedPhase.working) {
      unawaited(voice.say(_announcementFor(position)));
    } else if (phase == GuidedPhase.resting) {
      unawaited(voice.say(phrases.restWarning(restRemaining)));
    }
  }

  // ------------------------------------------------------- Persistencia ---

  /// Series hechas, en el formato de `POST /api/user_workouts`.
  List<Map<String, dynamic>> buildSetsPayload() {
    final payload = <Map<String, dynamic>>[];
    final counters = <int, int>{};
    for (final set in sets) {
      if (!set.done) continue;
      final ex = exercises[set.exerciseIndex];
      if (ex.id == null) continue;
      final n = (counters[set.exerciseIndex] ?? 0) + 1;
      counters[set.exerciseIndex] = n;
      payload.add({
        'exercise_id': ex.id,
        'set_number': n,
        'weight': ex.isBodyweight ? null : set.weight,
        'reps': set.reps,
        'rir': null,
        'is_warmup': false,
      });
    }
    return payload;
  }

  // -------------------------------------------------------------- Media ---

  void _syncMedia() {
    final ex = currentExercise;
    final set = currentSet;
    String title;
    String subtitle;
    switch (phase) {
      case GuidedPhase.finished:
        title = '¡Entrenamiento terminado!';
        subtitle = '$completedSets series completadas';
      case GuidedPhase.resting:
        title = 'Descanso';
        subtitle = ex == null ? '' : 'Sigue: ${ex.name}';
      case GuidedPhase.ready:
      case GuidedPhase.working:
        title = ex?.name ?? 'Entrenamiento';
        subtitle = set == null || ex == null
            ? ''
            : 'Serie ${set.setIndex + 1} de ${ex.sets} · ${set.reps} reps';
    }
    _media.update(
      title: title,
      subtitle: paused ? 'En pausa · $subtitle' : subtitle,
      album: workoutName,
      playing: !paused && phase != GuidedPhase.finished,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _restTimer?.cancel();
    _ticker?.cancel();
    _stopwatch.stop();
    unawaited(_media.release(this));
    if (_initialized) unawaited(voice.dispose());
    super.dispose();
  }
}
