import 'package:flutter_test/flutter_test.dart';

import 'package:macrobuddy/features/voice_coach/coach_phrases.dart';
import 'package:macrobuddy/features/voice_coach/coach_voice.dart';
import 'package:macrobuddy/features/voice_coach/guided_workout_controller.dart';
import 'package:macrobuddy/features/voice_coach/voice_clip_library.dart';
import 'package:macrobuddy/features/workout/workout_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceClipLibrary', () {
    test('slugify', () {
      expect(VoiceClipLibrary.slugify('Push-Up'), 'push_up');
      expect(
        VoiceClipLibrary.slugify('Pull Up (Neutral Grip)'),
        'pull_up_neutral_grip',
      );
      expect(VoiceClipLibrary.slugify('Último ejercicio'), 'ultimo_ejercicio');
    });

    test('clave sin clip cae a TTS y voces.json traduce', () async {
      final lib = await VoiceClipLibrary.load();
      // Una clave sin archivo no existe: se dirá con TTS.
      expect(lib.has('num_9999'), isFalse);
      expect(lib.assetFor('num_9999'), isNull);
      final v = lib.exerciseVoice('Push Up');
      expect(v.key, 'ej_lagartijas');
      expect(v.text, 'lagartijas');
      final unknown = lib.exerciseVoice('cable curl');
      expect(unknown.key, 'ej_cable_curl');
      expect(unknown.text, 'cable curl');
    });
  });

  group('CoachPhrases', () {
    test('anuncio de serie encadena claves', () async {
      final lib = await VoiceClipLibrary.load();
      final p = CoachPhrases(lib);
      final phrase = p.setAnnouncement(
        name: 'push up',
        setNumber: 1,
        totalSets: 3,
        minReps: 10,
        maxReps: 10,
      );
      expect(
        phrase.segments.map((s) => s.key).toList(),
        ['num_10', 'ej_lagartijas', 'palabra_serie', 'num_1', 'palabra_de', 'num_3'],
      );
      expect(phrase.text, '10 lagartijas. Serie 1 de 3');
    });

    test('rango de repeticiones', () async {
      final lib = await VoiceClipLibrary.load();
      final phrase = CoachPhrases(lib).setAnnouncement(
        name: 'squat',
        setNumber: 2,
        totalSets: 3,
        minReps: 8,
        maxReps: 12,
      );
      expect(phrase.segments.first.key, 'palabra_de');
      expect(phrase.segments[1].key, 'num_8');
      expect(phrase.segments[3].key, 'num_12');
    });

    test('ánimo sin clips usa textos por defecto', () async {
      final lib = await VoiceClipLibrary.load();
      final e = CoachPhrases(lib).encouragement();
      expect(e.segments.single.key, startsWith('animo_'));
    });
  });

  test('payload solo incluye series hechas', () {
    final c = GuidedWorkoutController(
      exercises: const [
        PreviewExercise(id: 'a', name: 'push up', sets: 2, minReps: 10, maxReps: 10, isBodyweight: true),
        PreviewExercise(id: 'b', name: 'squat', sets: 1, isBodyweight: false),
      ],
    );
    expect(c.sets.length, 3);
    expect(c.sets.first.reps, 10);
    c.sets[0].done = true;
    c.sets[2].done = true;
    c.sets[2].weight = 20;
    final payload = c.buildSetsPayload();
    expect(payload.length, 2);
    expect(payload[0]['exercise_id'], 'a');
    expect(payload[0]['weight'], isNull);
    expect(payload[1]['exercise_id'], 'b');
    expect(payload[1]['set_number'], 1);
    expect(payload[1]['weight'], 20);
  });

  test('VoicePhrase concatena', () {
    const a = VoicePhrase([VoiceSegment.tts('hola')]);
    const b = VoicePhrase([VoiceSegment('num_1', '1')]);
    expect((a + b).text, 'hola 1');
  });
}
