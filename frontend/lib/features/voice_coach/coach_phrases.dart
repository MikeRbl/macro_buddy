import 'dart:math';

import 'coach_voice.dart';
import 'voice_clip_library.dart';

/// Arma las frases del entrenador con claves de clip + texto de respaldo.
///
/// Todas las claves están documentadas en `Assets/voces/README.md`.
class CoachPhrases {
  CoachPhrases(this.library, {Random? random}) : _random = random ?? Random();

  final VoiceClipLibrary library;
  final Random _random;
  String? _lastEncouragement;

  // ------------------------------------------------------------ Piezas ----

  static VoiceSegment number(int n) => VoiceSegment('num_$n', '$n');

  static VoiceSegment word(String key, String text) =>
      VoiceSegment(key, text);

  VoiceSegment exercise(String name) {
    final voice = library.exerciseVoice(name);
    return VoiceSegment(voice.key, voice.text);
  }

  // ----------------------------------------------------------- Frases -----

  VoicePhrase start() => const VoicePhrase([
        VoiceSegment('frase_comenzamos', '¡Vamos a entrenar!'),
      ]);

  /// "Siguiente ejercicio: lagartijas." / "Último ejercicio: ..."
  VoicePhrase exerciseIntro({
    required bool isFirst,
    required bool isLast,
  }) {
    final intro = isFirst
        ? const VoiceSegment('frase_primer_ejercicio', 'Primer ejercicio.')
        : isLast
            ? const VoiceSegment('frase_ultimo_ejercicio', 'Último ejercicio.')
            : const VoiceSegment(
                'frase_siguiente_ejercicio',
                'Siguiente ejercicio.',
              );
    return VoicePhrase([intro]);
  }

  /// "Diez lagartijas. Serie uno de tres."
  /// Con rango: "De ocho a doce lagartijas. Serie uno de tres."
  VoicePhrase setAnnouncement({
    required String name,
    required int setNumber,
    required int totalSets,
    required int minReps,
    required int maxReps,
    int? targetReps,
  }) {
    final reps = <VoiceSegment>[];
    if (targetReps != null && targetReps > 0) {
      reps.add(number(targetReps));
    } else if (minReps == maxReps || minReps <= 0) {
      reps.add(number(maxReps));
    } else {
      reps
        ..add(word('palabra_de', 'De'))
        ..add(number(minReps))
        ..add(word('palabra_a', 'a'))
        ..add(number(maxReps));
    }
    return VoicePhrase([
      ...reps,
      exercise(name),
      word('palabra_serie', '. Serie'),
      number(setNumber),
      word('palabra_de', 'de'),
      number(totalSets),
    ]);
  }

  /// "Descanso. Noventa segundos."
  VoicePhrase rest(int seconds) => VoicePhrase([
        word('palabra_descanso', 'Descanso.'),
        number(seconds),
        word('palabra_segundos', 'segundos'),
      ]);

  /// "Diez segundos." (aviso antes de terminar el descanso)
  VoicePhrase restWarning(int seconds) => VoicePhrase([
        number(seconds),
        word('palabra_segundos', 'segundos'),
      ]);

  VoicePhrase lastSet() => const VoicePhrase([
        VoiceSegment('frase_ultima_serie', 'Última serie.'),
      ]);

  VoicePhrase paused() => const VoicePhrase([
        VoiceSegment('frase_pausa', 'Pausa.'),
      ]);

  VoicePhrase resumed() => const VoicePhrase([
        VoiceSegment('frase_continuamos', 'Continuamos.'),
      ]);

  VoicePhrase finished() => const VoicePhrase([
        VoiceSegment('frase_terminaste', '¡Terminaste! Excelente trabajo.'),
      ]);

  VoicePhrase hello() => const VoicePhrase([
        VoiceSegment(
          'frase_hola',
          'Hola, soy tu entrenador MacroBuddy. La bocina está lista.',
        ),
      ]);

  // ------------------------------------------------------------ Ánimos ----

  static const List<VoiceSegment> _defaultEncouragements = [
    VoiceSegment('animo_eso_es', '¡Eso es!'),
    VoiceSegment('animo_sigue_asi', '¡Sigue así!'),
    VoiceSegment('animo_muy_bien', '¡Muy bien!'),
    VoiceSegment('animo_vamos', '¡Vamos, tú puedes!'),
  ];

  static const VoiceSegment _almostDone = VoiceSegment(
    'animo_casi_terminamos',
    'Estamos a punto de terminar.',
  );

  static const VoiceSegment _halfway = VoiceSegment(
    'animo_mitad',
    'Ya vamos a la mitad.',
  );

  /// Ánimo al azar. Prefiere los clips grabados (cualquier `animo_*`); si no
  /// hay ninguno, usa los textos por defecto con TTS. Nunca repite el último.
  VoicePhrase encouragement() {
    final recorded = library
        .keysWithPrefix('animo_')
        .where((k) => k != _almostDone.key && k != _halfway.key)
        .map((k) => VoiceSegment(k, _textFor(k)))
        .toList();
    final pool = recorded.isNotEmpty
        ? recorded
        : [
            ..._defaultEncouragements,
            ...library.encouragementTexts.map(VoiceSegment.tts),
          ];
    var options = pool.where((s) => s.key != _lastEncouragement || s.key == null).toList();
    if (options.isEmpty) options = pool;
    final pick = options[_random.nextInt(options.length)];
    _lastEncouragement = pick.key;
    return VoicePhrase([pick]);
  }

  VoicePhrase almostDone() => const VoicePhrase([_almostDone]);

  VoicePhrase halfway() => const VoicePhrase([_halfway]);

  String _textFor(String key) {
    for (final s in [..._defaultEncouragements, _almostDone, _halfway]) {
      if (s.key == key) return s.text;
    }
    return key.replaceFirst('animo_', '').replaceAll('_', ' ');
  }

  /// Decide si toca decir un ánimo después de una serie (no siempre, para no
  /// saturar): ~40 % de las veces.
  bool shouldEncourage() => _random.nextDouble() < 0.4;
}
